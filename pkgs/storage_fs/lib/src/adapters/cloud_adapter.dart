import 'dart:async';

import 'package:convert/convert.dart' show AccumulatorSink;
import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:mime/mime.dart';
import '../contracts/cloud.dart' as contracts;
import '../contracts/filesystem.dart';
import '../config/disk_config.dart';
import 'package:file_cloud/file_cloud.dart';
import '../cloud_filesystem_factory.dart';

import '../exceptions/filesystem_exception.dart';

/// Cloud storage adapter that implements the Cloud contract.
///
/// Provides filesystem operations for S3-compatible storage with support
/// for temporary URLs, ACLs, and other cloud-specific features.
class CloudAdapter implements contracts.Cloud {
  /// The cloud filesystem backend
  final CloudFileSystem fileSystem;

  /// The filesystem configuration
  final DiskConfig config;

  /// The disk name
  String? _diskName;

  /// Explicit base URL override.
  final Uri? _explicitBaseUrl;

  static const Duration _cacheTtl = Duration(minutes: 2);
  final Map<String, DateTime> _recentCreates = {};
  final Map<String, DateTime> _recentDeletes = {};

  Future<String> Function(
    String path,
    DateTime expiration,
    Map<String, dynamic> options,
  )?
  _temporaryUrlBuilder;
  Future<Map<String, dynamic>> Function(
    String path,
    DateTime expiration,
    Map<String, dynamic> options,
  )?
  _temporaryUploadUrlBuilder;

  /// Creates a new cloud storage adapter.
  ///
  /// The [fileSystem] is the cloud filesystem backend implementation.
  /// The [config] contains the disk configuration.
  /// The optional [baseUrl] overrides the default base URL for public URLs.
  CloudAdapter({required this.fileSystem, required this.config, Uri? baseUrl})
    : _explicitBaseUrl = baseUrl;

  /// Gets the underlying cloud storage driver.
  CloudStorageDriver get driver => fileSystem.driver;

  /// Create a CloudAdapter from configuration
  factory CloudAdapter.fromConfig(DiskConfig config) {
    final options = config.options;

    if (options.isEmpty) {
      throw ArgumentError('Cloud storage requires configuration options');
    }

    final driverType = config.driver;
    if (driverType != 's3' && driverType != 'minio') {
      throw ArgumentError(
        'Unsupported cloud driver: $driverType. Supported: s3, minio',
      );
    }

    final fs = CloudFileSystemFactory.minio(
      endpoint: options['endpoint'] as String,
      accessKey: options['key'] as String,
      secretKey: options['secret'] as String,
      bucket: options['bucket'] as String,
      useSSL: options['use_ssl'] as bool? ?? false,
      region: options['region'] as String? ?? 'us-east-1',
    );

    final baseUrl =
        config.url ??
        options['url'] as String? ??
        options['base_url'] as String?;

    return CloudAdapter(
      fileSystem: fs,
      config: config,
      baseUrl: baseUrl != null ? Uri.tryParse(baseUrl) : null,
    );
  }

  /// Set the disk name
  CloudAdapter diskName(String name) {
    _diskName = name;
    return this;
  }

  /// Get the disk name
  String? get name => _diskName;

  /// Override temporary URL generation for testing.
  void buildTemporaryUrlsUsing(
    FutureOr<String> Function(
      String path,
      DateTime expiration,
      Map<String, dynamic> options,
    )
    callback,
  ) {
    _temporaryUrlBuilder = (path, expiration, options) async =>
        callback(path, expiration, options);
  }

  /// Override temporary upload URL generation for testing.
  void buildTemporaryUploadUrlsUsing(
    FutureOr<Map<String, dynamic>> Function(
      String path,
      DateTime expiration,
      Map<String, dynamic> options,
    )
    callback,
  ) {
    _temporaryUploadUrlBuilder = (path, expiration, options) async =>
        callback(path, expiration, options);
  }

  /// Reset custom temporary URL callbacks.
  void clearTemporaryUrlCallbacks() {
    _temporaryUrlBuilder = null;
    _temporaryUploadUrlBuilder = null;
  }

  @override
  Future<bool> missing(String path) async {
    return !(await exists(path));
  }

  @override
  Future<bool> exists(String path) async {
    _purgeCaches();
    final key = _normalizeCacheKey(path);

    final deleted = _recentDeletes[key];
    if (deleted != null) {
      return false;
    }

    final created = _recentCreates[key];
    if (created != null) {
      return true;
    }

    return await fileSystem.file(path).exists();
  }

  @override
  Future<String?> get(String path) async {
    try {
      return await fileSystem.file(path).readAsString();
    } catch (e) {
      if (config.throw_) {
        throw UnableToReadFileException(path, cause: e);
      }
      return null;
    }
  }

  @override
  Stream<List<int>>? readStream(String path) {
    try {
      return fileSystem.file(path).openRead();
    } catch (e) {
      if (config.throw_) {
        throw UnableToReadFileException(path, cause: e);
      }
      return null;
    }
  }

  @override
  Future<bool> put(
    String path,
    dynamic contents, {
    Map<String, dynamic>? options,
  }) async {
    try {
      final file = fileSystem.file(path);

      if (contents is String) {
        await file.writeAsString(contents);
      } else if (contents is List<int>) {
        await file.writeAsBytes(contents);
      } else if (contents is Stream<List<int>>) {
        final bytes = await contents.fold<List<int>>(
          [],
          (previous, element) => previous..addAll(element),
        );
        await file.writeAsBytes(bytes);
      } else {
        throw ArgumentError(
          'Unsupported content type: ${contents.runtimeType}',
        );
      }

      _recordCreate(path);
      return true;
    } catch (e) {
      if (config.throw_) {
        throw UnableToWriteFileException(path, cause: e);
      }
      return false;
    }
  }

  @override
  Future<bool> writeStream(
    String path,
    Stream<List<int>> resource, {
    Map<String, dynamic>? options,
  }) async {
    return put(path, resource, options: options);
  }

  @override
  Future<String> getVisibility(String path) async {
    // S3 visibility would require checking ACLs
    // For now, return public as default
    return Filesystem.visibilityPublic;
  }

  @override
  Future<bool> setVisibility(String path, String visibility) async {
    // S3 visibility would require setting ACLs
    // Minio package doesn't have direct ACL support in the current version
    // This would need to be implemented via custom headers in put operations
    return true;
  }

  @override
  Future<bool> prepend(
    String path,
    String data, {
    String separator = '\n',
  }) async {
    if (await exists(path)) {
      final existing = await get(path) ?? '';
      return put(path, '$data$separator$existing');
    }
    return put(path, data);
  }

  @override
  Future<bool> append(
    String path,
    String data, {
    String separator = '\n',
  }) async {
    if (await exists(path)) {
      final existing = await get(path) ?? '';
      return put(path, '$existing$separator$data');
    }
    return put(path, data);
  }

  @override
  Future<bool> delete(dynamic paths) async {
    final pathList = paths is List ? paths : [paths];
    var success = true;

    for (final path in pathList) {
      try {
        final target = path as String;
        await fileSystem.file(target).delete();
        _recordDelete(target);
      } catch (e) {
        if (config.throw_) {
          throw UnableToDeleteFileException(path, cause: e);
        }
        success = false;
      }
    }

    return success;
  }

  @override
  Future<bool> copy(String from, String to) async {
    try {
      await fileSystem.file(from).copy(to);
      _recordCreate(to);
      return true;
    } catch (e) {
      if (config.throw_) {
        throw UnableToCopyFileException(from, to, cause: e);
      }
      return false;
    }
  }

  @override
  Future<bool> move(String from, String to) async {
    try {
      // Copy then delete
      if (await copy(from, to)) {
        return await delete(from);
      }
      return false;
    } catch (e) {
      if (config.throw_) {
        throw UnableToMoveFileException(from, to, cause: e);
      }
      return false;
    }
  }

  @override
  Future<int> size(String path) async {
    try {
      return await fileSystem.file(path).length();
    } catch (e) {
      if (config.throw_) {
        throw FilesystemException('Unable to get file size: $path', cause: e);
      }
      return 0;
    }
  }

  @override
  Future<String?> checksum(String path, {String algorithm = 'md5'}) async {
    try {
      final file = fileSystem.file(path);
      if (!await file.exists()) {
        return null;
      }

      final hash = _hashForAlgorithm(algorithm);
      final sink = AccumulatorSink<Digest>();
      final hasher = hash.startChunkedConversion(sink);

      await for (final chunk in file.openRead()) {
        hasher.add(chunk);
      }

      hasher.close();

      return sink.events.single.toString();
    } catch (e) {
      if (config.throw_) {
        throw UnableToProvideChecksumException(path, cause: e);
      }
      return null;
    }
  }

  @override
  Future<String?> mimeType(String path) async {
    try {
      final file = fileSystem.file(path);
      if (!await file.exists()) {
        return null;
      }

      final buffer = <int>[];
      final stream = file.openRead();
      await for (final chunk in stream) {
        buffer.addAll(chunk);
        if (buffer.length >= 256) {
          break;
        }
      }

      return lookupMimeType(path, headerBytes: buffer);
    } catch (e) {
      if (config.throw_) {
        throw FilesystemException(
          'Unable to determine mime type: $path',
          cause: e,
        );
      }
      return null;
    }
  }

  @override
  Future<DateTime> lastModified(String path) async {
    try {
      final stat = await fileSystem.stat(path);
      return stat.modified;
    } catch (e) {
      if (config.throw_) {
        throw FilesystemException(
          'Unable to get last modified time: $path',
          cause: e,
        );
      }
      return DateTime.now();
    }
  }

  @override
  Future<List<String>> files([
    String? directory,
    bool recursive = false,
  ]) async {
    try {
      final dir = fileSystem.directory(directory ?? '');
      final entities = await dir.list(recursive: recursive).toList();

      return entities.whereType<File>().map((e) => e.path).toList();
    } catch (e) {
      if (config.throw_) {
        throw FilesystemException('Unable to list files: $directory', cause: e);
      }
      return [];
    }
  }

  @override
  Future<List<String>> allFiles([String? directory]) async {
    return files(directory, true);
  }

  @override
  Future<List<String>> directories([
    String? directory,
    bool recursive = false,
  ]) async {
    try {
      final dir = fileSystem.directory(directory ?? '');
      final entities = await dir.list(recursive: recursive).toList();

      return entities.whereType<Directory>().map((e) => e.path).toList();
    } catch (e) {
      if (config.throw_) {
        throw FilesystemException(
          'Unable to list directories: $directory',
          cause: e,
        );
      }
      return [];
    }
  }

  @override
  Future<List<String>> allDirectories([String? directory]) async {
    return directories(directory, true);
  }

  @override
  Future<bool> makeDirectory(String path) async {
    try {
      await fileSystem.directory(path).create(recursive: true);
      _recordCreate(path);
      _recordCreate(_directoryMarker(path));
      return true;
    } catch (e) {
      if (config.throw_) {
        throw FilesystemException(
          'Unable to create directory: $path',
          cause: e,
        );
      }
      return false;
    }
  }

  @override
  Future<bool> deleteDirectory(String directory) async {
    try {
      // First, list all files in the directory to record their deletions
      final files = await allFiles(directory);

      // Delete the directory recursively
      await fileSystem.directory(directory).delete(recursive: true);

      // Record deletions for all files in the cache
      for (final file in files) {
        _recordDelete(file);
      }

      _recordDelete(directory);
      _recordDelete(_directoryMarker(directory));
      return true;
    } catch (e) {
      if (config.throw_) {
        throw FilesystemException(
          'Unable to delete directory: $directory',
          cause: e,
        );
      }
      return false;
    }
  }

  @override
  String url(String path) {
    final explicit = _explicitBaseUrl;
    if (explicit != null) {
      return _concatPathToUrl(explicit, path);
    }

    final uri = driver.publicUrl(path);
    if (uri != null) {
      return uri.toString();
    }

    throw UnsupportedError('This cloud driver does not expose public URLs.');
  }

  @override
  bool providesTemporaryUrls() {
    return driver.supportsTemporaryUrls;
  }

  @override
  String temporaryUrl(
    String path,
    DateTime expiration, {
    Map<String, dynamic>? options,
  }) {
    throw UnsupportedError(
      'Use Storage.getTemporaryUrl for asynchronous temporary URL generation.',
    );
  }

  /// Get a temporary upload URL for the file at the given path (async version).
  Future<Map<String, dynamic>> getTemporaryUploadUrl(
    String path,
    DateTime expiration, {
    Map<String, dynamic>? options,
  }) async {
    try {
      final uploadBuilder = _temporaryUploadUrlBuilder;
      if (uploadBuilder != null) {
        return await uploadBuilder(
          path,
          expiration,
          options ?? <String, dynamic>{},
        );
      }

      final upload = await driver.presignUpload(
        path,
        expiration.difference(DateTime.now()),
        options: options,
      );

      if (upload == null) {
        throw UnsupportedError(
          'Temporary upload URLs are not supported by this driver.',
        );
      }

      return <String, dynamic>{
        'url': upload.url,
        'headers': upload.headers,
        if (upload.fields.isNotEmpty) 'fields': upload.fields,
      };
    } catch (e) {
      if (config.throw_) {
        throw FilesystemException(
          'Unable to generate temporary upload URL: $path',
          cause: e,
        );
      }
      return <String, dynamic>{
        'url': url(path),
        'headers': const <String, String>{},
      };
    }
  }

  /// Get a temporary download URL for the file at the given path (async version).
  Future<String> getTemporaryUrl(
    String path,
    DateTime expiration, {
    Map<String, dynamic>? options,
  }) async {
    try {
      final urlBuilder = _temporaryUrlBuilder;
      if (urlBuilder != null) {
        return await urlBuilder(
          path,
          expiration,
          options ?? <String, dynamic>{},
        );
      }

      final url = await driver.presignDownload(
        path,
        expiration.difference(DateTime.now()),
        options: options,
      );

      if (url == null) {
        throw UnsupportedError(
          'Temporary URLs are not supported by this driver.',
        );
      }

      return url;
    } catch (e) {
      if (config.throw_) {
        throw FilesystemException(
          'Unable to generate temporary URL: $path',
          cause: e,
        );
      }
      return url(path);
    }
  }

  /// Concatenate a path to a URL
  String _concatPathToUrl(Uri url, String path) {
    final base = url.toString().replaceAll(RegExp(r'/+$'), '');
    final relative = path.replaceAll(RegExp(r'^/'), '');
    return '$base/$relative';
  }

  void _recordCreate(String path) {
    _purgeCaches();
    final key = _normalizeCacheKey(path);
    if (key.isEmpty) {
      return;
    }

    _recentCreates[key] = DateTime.now().add(_cacheTtl);
    _recentDeletes.remove(key);
  }

  void _recordDelete(String path) {
    _purgeCaches();
    final key = _normalizeCacheKey(path);
    if (key.isEmpty) {
      return;
    }

    _recentDeletes[key] = DateTime.now().add(_cacheTtl);
    _recentCreates.remove(key);
  }

  void _purgeCaches() {
    final now = DateTime.now();
    _recentCreates.removeWhere((_, expiry) => expiry.isBefore(now));
    _recentDeletes.removeWhere((_, expiry) => expiry.isBefore(now));
  }

  String _normalizeCacheKey(String path) {
    var key = path.trim();
    if (key.isEmpty) {
      return '';
    }

    key = key.replaceAll(RegExp(r'^/+'), '');
    if (key.endsWith('/')) {
      key = key.replaceAll(RegExp(r'/+$'), '');
    }

    return key;
  }

  String _directoryMarker(String path) {
    final base = _normalizeCacheKey(path);
    if (base.isEmpty) {
      return '.keep';
    }
    return '$base/.keep';
  }

  Hash _hashForAlgorithm(String algorithm) {
    switch (algorithm.toLowerCase()) {
      case 'md5':
        return md5;
      case 'sha1':
        return sha1;
      case 'sha256':
        return sha256;
      default:
        throw ArgumentError('Unsupported checksum algorithm [$algorithm].');
    }
  }
}
