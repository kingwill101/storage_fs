import 'contracts/cloud.dart';
import 'contracts/factory.dart';
import 'contracts/filesystem.dart';
import 'adapters/filesystem_adapter.dart';
import 'adapters/cloud_adapter.dart';
import 'config/storage_config.dart';
import 'config/disk_config.dart';

/// Manages filesystem instances and drivers.
class FilesystemManager implements Factory {
  /// The application configuration.
  final StorageConfig config;

  /// The array of resolved filesystem drivers.
  final Map<String, Filesystem> _disks = {};

  /// The registered custom driver creators.
  final Map<String, Function> _customCreators = {};

  FilesystemManager(this.config);

  /// Create from a map configuration (legacy support)
  factory FilesystemManager.fromMap(Map<String, dynamic> map) {
    return FilesystemManager(StorageConfig.fromMap(map));
  }

  /// Get a filesystem instance (alias for [disk]).
  Filesystem drive([String? name]) => disk(name);

  @override
  Filesystem disk([String? name]) {
    name ??= getDefaultDriver();
    return _disks[name] ??= _get(name);
  }

  @override
  Cloud cloud() {
    final name = getDefaultCloudDriver();
    final disk = _disks[name] ??= _get(name);

    if (disk is! Cloud) {
      throw StateError('Disk [$name] does not implement Cloud interface.');
    }

    return disk;
  }

  /// Build an on-demand disk.
  Filesystem build(dynamic config) {
    if (config is String) {
      return _resolve('ondemand', DiskConfig(driver: 'local', root: config));
    } else if (config is DiskConfig) {
      return _resolve('ondemand', config);
    } else if (config is Map<String, dynamic>) {
      return _resolve('ondemand', DiskConfig.fromMap(config));
    }

    throw ArgumentError('Config must be a String, DiskConfig, or Map');
  }

  /// Attempt to get the disk from the local cache.
  Filesystem _get(String name) {
    return _disks[name] ??= _resolve(name);
  }

  /// Resolve the given disk.
  Filesystem _resolve(String name, [DiskConfig? diskConfig]) {
    diskConfig ??= _getConfig(name);

    if (diskConfig.driver.isEmpty) {
      throw ArgumentError('Disk [$name] does not have a configured driver.');
    }

    final driver = diskConfig.driver;

    if (_customCreators.containsKey(driver)) {
      return _callCustomCreator(diskConfig);
    }

    switch (driver) {
      case 'local':
        return createLocalDriver(diskConfig, name);
      case 'scoped':
        return createScopedDriver(diskConfig);
      case 's3':
      case 'minio':
      case 'spaces':
      case 'r2':
        return createS3Driver(diskConfig, name);
      default:
        throw ArgumentError('Driver [$driver] is not supported.');
    }
  }

  /// Call a custom driver creator.
  Filesystem _callCustomCreator(DiskConfig config) {
    final driver = config.driver;
    return _customCreators[driver]!(config);
  }

  /// Create an instance of the local driver.
  Filesystem createLocalDriver(DiskConfig config, [String name = 'local']) {
    final adapter = FilesystemAdapter(config);
    return adapter.diskName(name);
  }

  /// Create an instance of the S3 driver.
  Filesystem createS3Driver(DiskConfig config, [String name = 's3']) {
    return CloudAdapter.fromConfig(config).diskName(name);
  }

  /// Create a scoped driver.
  Filesystem createScopedDriver(DiskConfig config) {
    final parentDiskName = config.options['disk'] as String?;
    final prefix = config.prefix;

    if (parentDiskName == null || parentDiskName.isEmpty) {
      throw ArgumentError(
        'Scoped disk is missing "disk" configuration option.',
      );
    }

    if (prefix == null || prefix.isEmpty) {
      throw ArgumentError(
        'Scoped disk is missing "prefix" configuration option.',
      );
    }

    var parentConfig = _getConfig(parentDiskName);
    final separator = config.directorySeparator;

    final newPrefix =
        parentConfig.prefix == null || parentConfig.prefix!.isEmpty
        ? prefix
        : '${parentConfig.prefix!.replaceAll(RegExp('$separator\$'), '')}$separator${prefix.replaceAll(RegExp('^$separator'), '')}';

    parentConfig = parentConfig.copyWith(
      prefix: newPrefix,
      visibility: config.visibility ?? parentConfig.visibility,
      throw_: config.throw_ || parentConfig.throw_,
    );

    return build(parentConfig);
  }

  /// Set the given disk instance.
  FilesystemManager set(String name, Filesystem disk) {
    _disks[name] = disk;
    return this;
  }

  /// Get the filesystem connection configuration.
  DiskConfig _getConfig(String name) {
    return config.getDisk(name) ?? DiskConfig(driver: 'local');
  }

  /// Get the default driver name.
  String getDefaultDriver() {
    return config.defaultDisk;
  }

  /// Get the default cloud driver name.
  String getDefaultCloudDriver() {
    return config.cloudDisk ?? 's3';
  }

  /// Unset the given disk instances.
  FilesystemManager forgetDisk(dynamic disk) {
    final disks = disk is List ? disk : [disk];

    for (final diskName in disks) {
      _disks.remove(diskName);
    }

    return this;
  }

  /// Disconnect the given disk and remove from local cache.
  void purge([String? name]) {
    name ??= getDefaultDriver();
    _disks.remove(name);
  }

  /// Register a custom driver creator.
  FilesystemManager extend(String driver, Function callback) {
    _customCreators[driver] = callback;
    return this;
  }

  /// Dynamically call methods on the default driver instance.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Forward to default disk
    return Function.apply(disk().noSuchMethod, [invocation], {});
  }
}
