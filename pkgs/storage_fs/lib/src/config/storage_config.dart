import 'package:meta/meta.dart';
import 'disk_config.dart';

/// Main configuration for the Storage system.
@immutable
class StorageConfig {
  /// The default disk name
  final String defaultDisk;

  /// The default cloud disk name
  final String? cloudDisk;

  /// Map of disk configurations
  final Map<String, DiskConfig> disks;

  const StorageConfig({
    this.defaultDisk = 'local',
    this.cloudDisk,
    required this.disks,
  });

  /// Create a StorageConfig from a map
  factory StorageConfig.fromMap(Map<String, dynamic> map) {
    final filesystems = map['filesystems'] as Map<String, dynamic>? ?? map;

    final disksMap = filesystems['disks'] as Map<String, dynamic>? ?? {};
    final disks = <String, DiskConfig>{};

    disksMap.forEach((key, value) {
      if (value is DiskConfig) {
        disks[key] = value;
      } else if (value is Map<String, dynamic>) {
        disks[key] = DiskConfig.fromMap(value);
      }
    });

    return StorageConfig(
      defaultDisk: filesystems['default'] as String? ?? 'local',
      cloudDisk: filesystems['cloud'] as String?,
      disks: disks,
    );
  }

  /// Convert to a map
  Map<String, dynamic> toMap() {
    return {
      'filesystems': {
        'default': defaultDisk,
        if (cloudDisk != null) 'cloud': cloudDisk,
        'disks': disks.map((key, value) => MapEntry(key, value.toMap())),
      },
    };
  }

  /// Create a copy with updated values
  StorageConfig copyWith({
    String? defaultDisk,
    String? cloudDisk,
    Map<String, DiskConfig>? disks,
  }) {
    return StorageConfig(
      defaultDisk: defaultDisk ?? this.defaultDisk,
      cloudDisk: cloudDisk ?? this.cloudDisk,
      disks: disks ?? this.disks,
    );
  }

  /// Get a disk configuration by name
  DiskConfig? getDisk(String name) => disks[name];

  /// Add or update a disk configuration
  StorageConfig withDisk(String name, DiskConfig config) {
    return copyWith(disks: {...disks, name: config});
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageConfig &&
          runtimeType == other.runtimeType &&
          defaultDisk == other.defaultDisk &&
          cloudDisk == other.cloudDisk;

  @override
  int get hashCode => defaultDisk.hashCode ^ cloudDisk.hashCode;

  @override
  String toString() =>
      'StorageConfig(default: $defaultDisk, disks: ${disks.keys})';
}
