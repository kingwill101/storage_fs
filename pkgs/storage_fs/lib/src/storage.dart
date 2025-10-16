import 'dart:async';
import 'dart:io';
import 'contracts/cloud.dart';
import 'contracts/filesystem.dart';
import 'filesystem_manager.dart';
import 'adapters/filesystem_adapter.dart';
import 'adapters/cloud_adapter.dart';
import 'config/storage_config.dart';
import 'config/disk_config.dart';
import 'package:path/path.dart' as p;

/// Provides a static interface for filesystem operations across multiple storage backends.
///
/// Inspired by Laravel's Storage facade, this class provides a convenient
/// static API for working with both local filesystems and cloud storage services.
///
/// Before using any methods, you must initialize the storage system by calling
/// [initialize] with your configuration.
///
/// ```dart
/// Storage.initialize({
///   'default': 'local',
///   'disks': {
///     'local': {
///       'driver': 'local',
///       'root': '/path/to/storage',
///     },
///   },
/// });
/// ```
class Storage {
  static FilesystemManager? _manager;
  static StorageConfig? _config;

  /// Initializes the Storage facade with the given configuration.
  ///
  /// Accepts either a [StorageConfig] instance or a [Map<String, dynamic>].
  /// This must be called before using any other Storage methods.
  ///
  /// ```dart
  /// Storage.initialize({
  ///   'default': 'local',
  ///   'cloud': 's3',
  ///   'disks': {
  ///     'local': {
  ///       'driver': 'local',
  ///       'root': '/var/storage',
  ///     },
  ///     's3': {
  ///       'driver': 's3',
  ///       'options': {
  ///         'endpoint': 's3.amazonaws.com',
  ///         'key': 'your-key',
  ///         'secret': 'your-secret',
  ///         'bucket': 'my-bucket',
  ///       },
  ///     },
  ///   },
  /// });
  /// ```
  ///
  /// Throws [ArgumentError] if [config] is not a [StorageConfig] or [Map].
  static void initialize(dynamic config) {
    if (config is StorageConfig) {
      _config = config;
      _manager = FilesystemManager(config);
    } else if (config is Map<String, dynamic>) {
      _config = StorageConfig.fromMap(config);
      _manager = FilesystemManager(_config!);
    } else {
      throw ArgumentError(
        'Config must be a StorageConfig or Map<String, dynamic>',
      );
    }
  }

  /// Returns the filesystem manager instance.
  ///
  /// Throws [StateError] if [initialize] has not been called.
  static FilesystemManager get manager {
    if (_manager == null) {
      throw StateError(
        'Storage has not been initialized. Call Storage.initialize() first.',
      );
    }
    return _manager!;
  }

  /// Returns a filesystem instance for the specified disk.
  ///
  /// If [name] is null, returns the default disk. Otherwise, returns the
  /// disk with the given name.
  ///
  /// ```dart
  /// // Get default disk
  /// final disk = Storage.disk();
  ///
  /// // Get specific disk
  /// final s3 = Storage.disk('s3');
  /// await s3.put('file.txt', 'content');
  /// ```
  static Filesystem disk([String? name]) => manager.disk(name);

  /// Returns a filesystem instance for the specified drive.
  ///
  /// This is an alias for [disk]. If [name] is null, returns the default drive.
  static Filesystem drive([String? name]) => manager.drive(name);

  /// Returns the default cloud filesystem instance.
  ///
  /// This returns the disk configured as the 'cloud' disk in your configuration.
  ///
  /// ```dart
  /// final cloud = Storage.cloud();
  /// await cloud.put('file.txt', 'content');
  /// ```
  static Cloud cloud() => manager.cloud();

  /// Builds a filesystem instance on-demand from the given configuration.
  ///
  /// This creates a new filesystem instance without registering it in the manager.
  static Filesystem build(dynamic config) => manager.build(config);

  /// Creates a local filesystem driver with the given configuration.
  ///
  /// The [config] can be either a [DiskConfig] or [Map<String, dynamic>].
  ///
  /// Throws [ArgumentError] if [config] is not a valid type.
  static Filesystem createLocalDriver(dynamic config, [String name = 'local']) {
    if (config is DiskConfig) {
      return manager.createLocalDriver(config, name);
    } else if (config is Map<String, dynamic>) {
      return manager.createLocalDriver(DiskConfig.fromMap(config), name);
    }
    throw ArgumentError('Config must be a DiskConfig or Map<String, dynamic>');
  }

  /// Creates a scoped filesystem driver with the given configuration.
  ///
  /// A scoped driver restricts operations to a specific path prefix.
  ///
  /// Throws [ArgumentError] if [config] is not a valid type.
  static Filesystem createScopedDriver(dynamic config) {
    if (config is DiskConfig) {
      return manager.createScopedDriver(config);
    } else if (config is Map<String, dynamic>) {
      return manager.createScopedDriver(DiskConfig.fromMap(config));
    }
    throw ArgumentError('Config must be a DiskConfig or Map<String, dynamic>');
  }

  /// Sets a custom disk instance with the given name.
  ///
  /// This allows you to register a custom filesystem implementation.
  static FilesystemManager set(String name, Filesystem disk) =>
      manager.set(name, disk);

  /// Returns the name of the default driver.
  static String getDefaultDriver() => manager.getDefaultDriver();

  /// Returns the name of the default cloud driver.
  static String getDefaultCloudDriver() => manager.getDefaultCloudDriver();

  /// Unsets the given disk instances from the manager.
  ///
  /// The [disk] parameter can be a single disk name or a list of names.
  static FilesystemManager forgetDisk(dynamic disk) => manager.forgetDisk(disk);

  /// Disconnects the given disk and removes it from local cache.
  ///
  /// If [name] is null, purges the default disk.
  static void purge([String? name]) => manager.purge(name);

  /// Registers a custom driver creator with the given name.
  ///
  /// This allows you to add support for custom storage backends.
  static FilesystemManager extend(String driver, Function callback) {
    return manager.extend(driver, callback);
  }

  // Filesystem operations delegated to the default disk

  /// Returns the full path to the file on the local filesystem.
  ///
  /// Only works with local filesystem drivers. Throws [UnsupportedError]
  /// for cloud storage drivers.
  ///
  /// ```dart
  /// final fullPath = Storage.path('documents/file.txt');
  /// print(fullPath); // /var/storage/documents/file.txt
  /// ```
  static String path(String path) {
    final adapter = disk();
    if (adapter is FilesystemAdapter) {
      return adapter.path(path);
    }
    throw UnsupportedError('Current disk does not support path() method');
  }

  /// Returns whether a file or directory exists at the given path.
  ///
  /// ```dart
  /// if (await Storage.exists('file.txt')) {
  ///   print('File exists');
  /// }
  /// ```
  static Future<bool> exists(String path) => disk().exists(path);

  /// Returns the contents of a file as a string.
  ///
  /// Returns `null` if the file does not exist.
  ///
  /// ```dart
  /// final content = await Storage.get('file.txt');
  /// print(content);
  /// ```
  static Future<String?> get(String path) => disk().get(path);

  /// Returns the contents of a file as a stream of bytes.
  ///
  /// This is useful for reading large files or streaming data.
  ///
  /// ```dart
  /// final stream = Storage.readStream('large-file.bin');
  /// await for (final chunk in stream!) {
  ///   // Process chunk
  /// }
  /// ```
  static Stream<List<int>>? readStream(String path) => disk().readStream(path);

  /// Writes contents to a file at the given path.
  ///
  /// The [contents] can be a string, bytes, or a list of integers.
  /// Returns `true` if successful, `false` otherwise.
  ///
  /// ```dart
  /// await Storage.put('file.txt', 'Hello, World!');
  /// await Storage.put('data.bin', [1, 2, 3, 4]);
  /// ```
  static Future<bool> put(
    String path,
    dynamic contents, {
    Map<String, dynamic>? options,
  }) {
    return disk().put(path, contents, options: options);
  }

  /// Stores a local file in the given directory using its original filename.
  ///
  /// Returns the stored file's path.
  ///
  /// ```dart
  /// final path = await Storage.putFile('uploads', File('/tmp/photo.jpg'));
  /// print(path); // uploads/photo.jpg
  /// ```
  static Future<String> putFile(
    String path,
    dynamic file, {
    Map<String, dynamic>? options,
  }) {
    return putFileAs(path, file, null, options: options);
  }

  /// Stores a local file in the given directory with a custom name.
  ///
  /// If [name] is null, uses the original filename. If [directory] is null,
  /// stores in the root. Returns the stored file's path.
  ///
  /// ```dart
  /// final path = await Storage.putFileAs(
  ///   'uploads',
  ///   File('/tmp/photo.jpg'),
  ///   'avatar.jpg',
  /// );
  /// print(path); // uploads/avatar.jpg
  /// ```
  static Future<String> putFileAs(
    String? directory,
    dynamic file,
    String? name, {
    Map<String, dynamic>? options,
  }) async {
    final localFile = await _resolveLocalFile(file);

    final originalName = name ?? p.basename(localFile.path);
    final normalizedDirectory = _normalizeDirectory(directory);
    final targetPath = normalizedDirectory == null
        ? originalName
        : p.posix.join(normalizedDirectory, originalName);

    final stream = localFile.openRead();
    final adapter = disk();
    final success = await adapter.writeStream(
      targetPath,
      stream,
      options: options,
    );

    if (!success) {
      throw StateError('Unable to store file at [$targetPath].');
    }

    return targetPath;
  }

  /// Writes a new file using a stream of bytes.
  ///
  /// This is useful for uploading large files or streaming data.
  /// Returns `true` if successful, `false` otherwise.
  ///
  /// ```dart
  /// final stream = File('large-file.bin').openRead();
  /// await Storage.writeStream('uploads/file.bin', stream);
  /// ```
  static Future<bool> writeStream(
    String path,
    Stream<List<int>> resource, {
    Map<String, dynamic>? options,
  }) {
    return disk().writeStream(path, resource, options: options);
  }

  /// Returns the visibility setting for the given path.
  ///
  /// Returns 'public' or 'private' depending on the file's visibility.
  static Future<String> getVisibility(String path) =>
      disk().getVisibility(path);

  /// Sets the visibility for the given path.
  ///
  /// The [visibility] should be either 'public' or 'private'.
  /// Returns `true` if successful.
  static Future<bool> setVisibility(String path, String visibility) {
    return disk().setVisibility(path, visibility);
  }

  /// Prepends data to the beginning of a file.
  ///
  /// The [separator] is added between the new data and existing content.
  /// Returns `true` if successful.
  ///
  /// ```dart
  /// await Storage.prepend('log.txt', 'New log entry', separator: '\n');
  /// ```
  static Future<bool> prepend(
    String path,
    String data, {
    String separator = '\n',
  }) {
    return disk().prepend(path, data, separator: separator);
  }

  /// Appends data to the end of a file.
  ///
  /// The [separator] is added between existing content and the new data.
  /// Returns `true` if successful.
  ///
  /// ```dart
  /// await Storage.append('log.txt', 'New log entry', separator: '\n');
  /// ```
  static Future<bool> append(
    String path,
    String data, {
    String separator = '\n',
  }) {
    return disk().append(path, data, separator: separator);
  }

  /// Deletes the file(s) at the given path(s).
  ///
  /// The [paths] parameter can be a single path string or a list of paths.
  /// Returns `true` if all deletions were successful.
  ///
  /// ```dart
  /// await Storage.delete('file.txt');
  /// await Storage.delete(['file1.txt', 'file2.txt']);
  /// ```
  static Future<bool> delete(dynamic paths) => disk().delete(paths);

  /// Copies a file from one location to another.
  ///
  /// Returns `true` if successful.
  ///
  /// ```dart
  /// await Storage.copy('original.txt', 'copy.txt');
  /// ```
  static Future<bool> copy(String from, String to) => disk().copy(from, to);

  /// Moves a file from one location to another.
  ///
  /// This is equivalent to copying and then deleting the original.
  /// Returns `true` if successful.
  ///
  /// ```dart
  /// await Storage.move('old-path.txt', 'new-path.txt');
  /// ```
  static Future<bool> move(String from, String to) => disk().move(from, to);

  /// Returns the size of the file in bytes.
  ///
  /// ```dart
  /// final size = await Storage.size('file.txt');
  /// print('File size: $size bytes');
  /// ```
  static Future<int> size(String path) => disk().size(path);

  /// Returns the checksum hash for the given file.
  ///
  /// The [algorithm] can be 'md5', 'sha1', 'sha256', etc.
  /// Returns `null` if the checksum cannot be computed.
  static Future<String?> checksum(String path, {String algorithm = 'md5'}) {
    return disk().checksum(path, algorithm: algorithm);
  }

  /// Returns the MIME type for the given file.
  ///
  /// Returns `null` if the MIME type cannot be determined.
  ///
  /// ```dart
  /// final mimeType = await Storage.mimeType('image.jpg');
  /// print(mimeType); // image/jpeg
  /// ```
  static Future<String?> mimeType(String path) => disk().mimeType(path);

  /// Returns the file's last modification time.
  ///
  /// ```dart
  /// final modified = await Storage.lastModified('file.txt');
  /// print('Last modified: $modified');
  /// ```
  static Future<DateTime> lastModified(String path) =>
      disk().lastModified(path);

  /// Returns a list of all files in the given directory.
  ///
  /// If [recursive] is true, includes files in subdirectories.
  ///
  /// ```dart
  /// final files = await Storage.files('documents');
  /// final allFiles = await Storage.files('documents', true);
  /// ```
  static Future<List<String>> files([
    String? directory,
    bool recursive = false,
  ]) {
    return disk().files(directory, recursive);
  }

  /// Returns all files from the given directory recursively.
  ///
  /// This is equivalent to calling `files(directory, true)`.
  static Future<List<String>> allFiles([String? directory]) =>
      disk().allFiles(directory);

  /// Returns a list of all directories within the given directory.
  ///
  /// If [recursive] is true, includes subdirectories at all levels.
  static Future<List<String>> directories([
    String? directory,
    bool recursive = false,
  ]) {
    return disk().directories(directory, recursive);
  }

  /// Returns all directories within the given directory recursively.
  ///
  /// This is equivalent to calling `directories(directory, true)`.
  static Future<List<String>> allDirectories([String? directory]) {
    return disk().allDirectories(directory);
  }

  /// Creates a directory at the given path.
  ///
  /// Parent directories are created automatically if they don't exist.
  /// Returns `true` if successful.
  ///
  /// ```dart
  /// await Storage.makeDirectory('uploads/images');
  /// ```
  static Future<bool> makeDirectory(String path) => disk().makeDirectory(path);

  /// Recursively deletes a directory and all its contents.
  ///
  /// Returns `true` if successful.
  ///
  /// ```dart
  /// await Storage.deleteDirectory('old-uploads');
  /// ```
  static Future<bool> deleteDirectory(String directory) =>
      disk().deleteDirectory(directory);

  /// Returns whether a file or directory is missing at the given path.
  ///
  /// This is the inverse of [exists].
  static Future<bool> missing(String path) async {
    final adapter = disk();
    if (adapter is FilesystemAdapter) {
      return adapter.missing(path);
    }
    return !(await exists(path));
  }

  /// Returns whether a file (not directory) exists at the given path.
  ///
  /// Throws [UnsupportedError] for non-local filesystem drivers.
  static Future<bool> fileExists(String path) async {
    final adapter = disk();
    if (adapter is FilesystemAdapter) {
      return adapter.fileExists(path);
    }
    throw UnsupportedError('Current disk does not support fileExists() method');
  }

  /// Returns whether a file is missing at the given path.
  ///
  /// This is the inverse of [fileExists].
  /// Throws [UnsupportedError] for non-local filesystem drivers.
  static Future<bool> fileMissing(String path) async {
    final adapter = disk();
    if (adapter is FilesystemAdapter) {
      return adapter.fileMissing(path);
    }
    throw UnsupportedError(
      'Current disk does not support fileMissing() method',
    );
  }

  /// Returns whether a directory exists at the given path.
  ///
  /// Throws [UnsupportedError] for non-local filesystem drivers.
  static Future<bool> directoryExists(String path) async {
    final adapter = disk();
    if (adapter is FilesystemAdapter) {
      return adapter.directoryExists(path);
    }
    throw UnsupportedError(
      'Current disk does not support directoryExists() method',
    );
  }

  /// Returns whether a directory is missing at the given path.
  ///
  /// This is the inverse of [directoryExists].
  /// Throws [UnsupportedError] for non-local filesystem drivers.
  static Future<bool> directoryMissing(String path) async {
    final adapter = disk();
    if (adapter is FilesystemAdapter) {
      return adapter.directoryMissing(path);
    }
    throw UnsupportedError(
      'Current disk does not support directoryMissing() method',
    );
  }

  /// Returns the contents of a file as decoded JSON.
  ///
  /// Returns `null` if the file does not exist or is not valid JSON.
  /// Throws [UnsupportedError] for non-local filesystem drivers.
  ///
  /// ```dart
  /// final data = await Storage.json('config.json');
  /// print(data['version']);
  /// ```
  static Future<Map<String, dynamic>?> json(String path) async {
    final adapter = disk();
    if (adapter is FilesystemAdapter) {
      return adapter.json(path);
    }
    throw UnsupportedError('Current disk does not support json() method');
  }

  /// Returns the URL for the file at the given path.
  ///
  /// For local filesystems, returns a file:// URL.
  /// For cloud storage, returns the public URL.
  ///
  /// ```dart
  /// final url = Storage.url('images/photo.jpg');
  /// print(url); // https://cdn.example.com/images/photo.jpg
  /// ```
  static String url(String path) {
    final adapter = disk();
    if (adapter is FilesystemAdapter) {
      return adapter.url(path);
    } else if (adapter is CloudAdapter) {
      return adapter.url(path);
    }
    throw UnsupportedError('Current disk does not support url() method');
  }

  /// Returns whether the current disk supports generating temporary URLs.
  ///
  /// Cloud storage disks typically support this, while local disks do not.
  ///
  /// ```dart
  /// if (Storage.providesTemporaryUrls()) {
  ///   final url = await Storage.getTemporaryUrl('file.pdf', expiration);
  /// }
  /// ```
  static bool providesTemporaryUrls() {
    final adapter = disk();
    if (adapter is CloudAdapter) {
      return adapter.providesTemporaryUrls();
    }
    return false;
  }

  /// Overrides the temporary URL builder for the current cloud disk.
  ///
  /// This allows you to customize how temporary URLs are generated.
  /// Throws [UnsupportedError] if the current disk doesn't support temporary URLs.
  static void buildTemporaryUrlsUsing(
    FutureOr<String> Function(
      String path,
      DateTime expiration,
      Map<String, dynamic> options,
    )
    callback,
  ) {
    final adapter = disk();
    if (adapter is CloudAdapter) {
      adapter.buildTemporaryUrlsUsing(callback);
      return;
    }

    throw UnsupportedError('Current disk does not support temporary URLs.');
  }

  /// Overrides the temporary upload URL builder for the current cloud disk.
  ///
  /// This allows you to customize how temporary upload URLs are generated.
  /// Throws [UnsupportedError] if the current disk doesn't support temporary upload URLs.
  static void buildTemporaryUploadUrlsUsing(
    FutureOr<Map<String, dynamic>> Function(
      String path,
      DateTime expiration,
      Map<String, dynamic> options,
    )
    callback,
  ) {
    final adapter = disk();
    if (adapter is CloudAdapter) {
      adapter.buildTemporaryUploadUrlsUsing(callback);
      return;
    }

    throw UnsupportedError(
      'Current disk does not support temporary upload URLs.',
    );
  }

  /// Clears any custom temporary URL callbacks.
  ///
  /// Resets the temporary URL builders to their default behavior.
  /// Throws [UnsupportedError] if the current disk doesn't support temporary URL callbacks.
  static void clearTemporaryUrlBuilders() {
    final adapter = disk();
    if (adapter is CloudAdapter) {
      adapter.clearTemporaryUrlCallbacks();
      return;
    }

    throw UnsupportedError(
      'Current disk does not support temporary URL callbacks.',
    );
  }

  /// Returns a temporary signed URL for the file at the given path.
  ///
  /// The URL will expire at the given [expiration] time. This is useful for
  /// providing time-limited access to private files in cloud storage.
  ///
  /// ```dart
  /// final url = await Storage.getTemporaryUrl(
  ///   'private/document.pdf',
  ///   DateTime.now().add(Duration(hours: 1)),
  /// );
  /// print('Download URL (expires in 1 hour): $url');
  /// ```
  ///
  /// Throws [UnsupportedError] if the current disk doesn't support temporary URLs.
  static Future<String> getTemporaryUrl(
    String path,
    DateTime expiration, {
    Map<String, dynamic>? options,
  }) {
    return _withCloudAdapter(
      (adapter) => adapter.getTemporaryUrl(path, expiration, options: options),
    );
  }

  /// Returns a temporary upload URL for the file at the given path.
  ///
  /// The URL will expire at the given [expiration] time. Returns a map containing
  /// the URL and any required headers for the upload.
  ///
  /// ```dart
  /// final data = await Storage.getTemporaryUploadUrl(
  ///   'uploads/file.pdf',
  ///   DateTime.now().add(Duration(hours: 1)),
  /// );
  /// print('Upload to: ${data['url']}');
  /// print('Headers: ${data['headers']}');
  /// ```
  ///
  /// Throws [UnsupportedError] if the current disk doesn't support temporary upload URLs.
  static Future<Map<String, dynamic>> getTemporaryUploadUrl(
    String path,
    DateTime expiration, {
    Map<String, dynamic>? options,
  }) {
    return _withCloudAdapter(
      (adapter) =>
          adapter.getTemporaryUploadUrl(path, expiration, options: options),
    );
  }

  /// Returns a temporary URL for the file at the given path.
  ///
  /// This is an alias for [getTemporaryUrl].
  static Future<String> temporaryUrl(
    String path,
    DateTime expiration, {
    Map<String, dynamic>? options,
  }) {
    return getTemporaryUrl(path, expiration, options: options);
  }

  /// Returns a temporary upload URL for the file at the given path.
  ///
  /// This is an alias for [getTemporaryUploadUrl].
  static Future<Map<String, dynamic>> temporaryUploadUrl(
    String path,
    DateTime expiration, {
    Map<String, dynamic>? options,
  }) {
    return getTemporaryUploadUrl(path, expiration, options: options);
  }

  /// Asserts that the given file or directory exists.
  ///
  /// Optionally verifies that the file contains the given [content].
  /// This is useful for testing. Throws an exception if the assertion fails.
  /// Throws [UnsupportedError] for non-local filesystem drivers.
  ///
  /// ```dart
  /// await Storage.assertExists('file.txt');
  /// await Storage.assertExists('file.txt', content: 'expected content');
  /// ```
  static Future<FilesystemAdapter> assertExists(
    dynamic path, {
    String? content,
  }) async {
    final adapter = disk();
    if (adapter is FilesystemAdapter) {
      return adapter.assertExists(path, content: content);
    }
    throw UnsupportedError(
      'Current disk does not support assertExists() method',
    );
  }

  /// Asserts that the number of files in the path equals the expected count.
  ///
  /// If [recursive] is true, counts files in subdirectories as well.
  /// This is useful for testing. Throws an exception if the assertion fails.
  /// Throws [UnsupportedError] for non-local filesystem drivers.
  ///
  /// ```dart
  /// await Storage.assertCount('uploads', 5);
  /// await Storage.assertCount('uploads', 10, recursive: true);
  /// ```
  static Future<FilesystemAdapter> assertCount(
    String path,
    int count, {
    bool recursive = false,
  }) async {
    final adapter = disk();
    if (adapter is FilesystemAdapter) {
      return adapter.assertCount(path, count, recursive: recursive);
    }
    throw UnsupportedError(
      'Current disk does not support assertCount() method',
    );
  }

  /// Asserts that the given file or directory does not exist.
  ///
  /// This is useful for testing. Throws an exception if the assertion fails.
  /// Throws [UnsupportedError] for non-local filesystem drivers.
  ///
  /// ```dart
  /// await Storage.assertMissing('deleted-file.txt');
  /// ```
  static Future<FilesystemAdapter> assertMissing(dynamic path) async {
    final adapter = disk();
    if (adapter is FilesystemAdapter) {
      return adapter.assertMissing(path);
    }
    throw UnsupportedError(
      'Current disk does not support assertMissing() method',
    );
  }

  /// Asserts that the given directory is empty.
  ///
  /// This is useful for testing. Throws an exception if the assertion fails.
  /// Throws [UnsupportedError] for non-local filesystem drivers.
  ///
  /// ```dart
  /// await Storage.assertDirectoryEmpty('temp');
  /// ```
  static Future<FilesystemAdapter> assertDirectoryEmpty(String path) async {
    final adapter = disk();
    if (adapter is FilesystemAdapter) {
      return adapter.assertDirectoryEmpty(path);
    }
    throw UnsupportedError(
      'Current disk does not support assertDirectoryEmpty() method',
    );
  }

  /// Replaces the given disk with a local testing disk.
  ///
  /// Creates a temporary directory for testing file operations without affecting
  /// real storage. The directory is cleaned before use. If [diskName] is null,
  /// uses the default disk.
  ///
  /// ```dart
  /// void main() {
  ///   test('file operations', () async {
  ///     Storage.fake();
  ///     await Storage.put('test.txt', 'content');
  ///     await Storage.assertExists('test.txt');
  ///   });
  /// }
  /// ```
  static Filesystem fake([String? diskName, Map<String, dynamic>? config]) {
    diskName ??= getDefaultDriver();
    final root = _getFakeRootPath(diskName);

    // Clean the directory if it exists
    final dir = Directory(root);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    dir.createSync(recursive: true);

    final fakeConfig = _buildDiskConfiguration(
      diskName,
      config ?? {},
      root: root,
    );
    final fake = createLocalDriver(fakeConfig, diskName);

    set(diskName, fake);

    return fake;
  }

  /// Replaces the given disk with a persistent local testing disk.
  ///
  /// Similar to [fake], but does not clean the directory before use.
  /// This allows data to persist across test runs.
  ///
  /// ```dart
  /// void main() {
  ///   test('persistent data', () async {
  ///     Storage.persistentFake();
  ///     await Storage.put('persisted.txt', 'data');
  ///   });
  /// }
  /// ```
  static Filesystem persistentFake([
    String? diskName,
    Map<String, dynamic>? config,
  ]) {
    diskName ??= getDefaultDriver();
    final root = _getFakeRootPath(diskName);

    final fakeConfig = _buildDiskConfiguration(
      diskName,
      config ?? {},
      root: root,
    );
    final fake = createLocalDriver(fakeConfig, diskName);

    set(diskName, fake);

    return fake;
  }

  static Future<T> _withCloudAdapter<T>(
    Future<T> Function(CloudAdapter adapter) callback,
  ) async {
    final adapter = disk();
    if (adapter is CloudAdapter) {
      return callback(adapter);
    }

    throw UnsupportedError('Current disk does not support cloud operations.');
  }

  static Future<File> _resolveLocalFile(dynamic file) async {
    if (file is File) {
      if (!await file.exists()) {
        throw ArgumentError('File does not exist at path [${file.path}].');
      }

      return file;
    }

    if (file is String) {
      final resolved = File(file);
      if (!await resolved.exists()) {
        throw ArgumentError('File does not exist at path [$file].');
      }

      return resolved;
    }

    throw ArgumentError('File must be a File instance or a filesystem path.');
  }

  static String? _normalizeDirectory(String? directory) {
    if (directory == null) {
      return null;
    }

    final trimmed = directory.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '');
  }

  /// Get the root path for the fake disk.
  static String _getFakeRootPath(String disk) {
    // Use a temporary directory for testing
    return '${Directory.systemTemp.path}/storage_testing/disks/$disk';
  }

  /// Assemble the configuration of the given disk.
  static DiskConfig _buildDiskConfiguration(
    String disk,
    Map<String, dynamic> config, {
    required String root,
  }) {
    final originalConfig = _config?.getDisk(disk);

    return DiskConfig(
      driver: originalConfig?.driver ?? 'local',
      root: root,
      throw_: originalConfig?.throw_ ?? config['throw'] as bool? ?? false,
      visibility: config['visibility'] as String?,
      url: config['url'] as String?,
      report: config['report'] as bool? ?? false,
    );
  }
}
