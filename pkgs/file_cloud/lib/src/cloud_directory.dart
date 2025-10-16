import 'dart:async';

import 'package:file/file.dart';

import 'cloud_file.dart';
import 'cloud_file_system_entity.dart';
import 'cloud_link.dart';

/// A directory in a cloud filesystem.
///
/// This class provides directory operations like listing contents, creating,
/// and deleting directories in cloud object storage.
class CloudDirectory extends CloudFileSystemEntity implements Directory {
  const CloudDirectory(super.fileSystem, super.path);

  static const Duration _cacheTtl = Duration(minutes: 2);
  static final Map<String, DateTime> _recentCreates = {};
  static final Map<String, DateTime> _recentDeletes = {};

  @override
  CloudDirectory get absolute =>
      CloudDirectory(fileSystem, fileSystem.path.absolute(path));

  @override
  FileSystemEntityType get expectedType => FileSystemEntityType.directory;

  @override
  String get remotePath {
    final base = super.remotePath;
    if (base.isEmpty) {
      return '';
    }
    return base.endsWith('/') ? base : '$base/';
  }

  @override
  Future<bool> exists() async {
    _purgeCaches();

    final key = _normalizeCacheKey(remotePath);
    if (_recentDeletes[key] != null) {
      return false;
    }

    if (_recentCreates[key] != null) {
      return true;
    }

    try {
      final stream = fileSystem.driver.list(remotePath, recursive: false);
      await for (final _ in stream.timeout(Duration(seconds: 5))) {
        // Any content under this prefix means the directory exists
        return true;
      }
      return false;
    } catch (e) {
      // If timeout or error occurs, assume directory doesn't exist
      return false;
    }
  }

  @override
  bool existsSync() {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<Directory> create({bool recursive = false}) async {
    // For cloud storage, directories are virtual
    // We just mark them as created in cache without checking if they exist
    // This avoids the expensive list operation

    if (recursive && parent is CloudDirectory) {
      final parentPath = parent.path;
      // Stop recursion at root or when parent is same as current
      final rootPrefix = fileSystem.path.rootPrefix(parentPath);
      if (parentPath.isNotEmpty &&
          parentPath != '.' &&
          parentPath != path &&
          parentPath != rootPrefix) {
        await (parent as CloudDirectory).create(recursive: true);
      }
    }

    // Record in cache that this directory was created
    // In S3/cloud storage, directories are virtual - they don't need physical markers
    // They exist implicitly when files are created within them
    _recordCreate(remotePath);

    return this;
  }

  @override
  void createSync({bool recursive = false}) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<Directory> createTemp([String? prefix]) async {
    throw UnsupportedError('Temporary directories not supported.');
  }

  @override
  Directory createTempSync([String? prefix]) {
    throw UnsupportedError('Temporary directories not supported.');
  }

  @override
  Future<Directory> delete({bool recursive = false}) async {
    _recordDelete(remotePath);

    if (recursive) {
      final stream = fileSystem.driver.list(remotePath, recursive: true);
      await for (final item in stream) {
        if (item.isDirectory) {
          continue;
        }
        final fullPath = _fullRemote(item.path);
        await fileSystem.driver.delete(fullPath);
      }
    } else {
      final stream = fileSystem.driver.list(remotePath, recursive: false);
      await for (final _ in stream) {
        throw FileSystemException('Directory not empty', path);
      }
    }

    return this;
  }

  @override
  void deleteSync({bool recursive = false}) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<Directory> rename(String newPath) async {
    final newDir = CloudDirectory(fileSystem, newPath);
    final stream = fileSystem.driver.list(remotePath, recursive: true);

    await for (final item in stream) {
      if (item.isDirectory) {
        continue;
      }

      final relative = item.path;
      await fileSystem.driver.copy(
        _fullRemote(relative),
        newDir._fullRemote(relative),
      );
    }

    await delete(recursive: true);

    return newDir;
  }

  @override
  Directory renameSync(String newPath) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) async* {
    final stream = fileSystem.driver.list(remotePath, recursive: recursive);
    await for (final item in stream) {
      final key = item.path;
      final entityPath = fileSystem.fromRemotePath(_fullRemote(key));

      if (item.isDirectory) {
        yield CloudDirectory(fileSystem, entityPath);
      } else {
        yield CloudFile(fileSystem, entityPath);
      }
    }
  }

  @override
  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Directory childDirectory(String basename) =>
      CloudDirectory(fileSystem, fileSystem.path.join(path, basename));

  @override
  File childFile(String basename) =>
      CloudFile(fileSystem, fileSystem.path.join(path, basename));

  @override
  Link childLink(String basename) =>
      CloudLink(fileSystem, fileSystem.path.join(path, basename));

  String _fullRemote(String relative) {
    if (remotePath.isEmpty) {
      return relative;
    }
    return '$remotePath$relative';
  }

  void _recordCreate(String path) {
    final key = _normalizeCacheKey(path);
    if (key.isEmpty) {
      return;
    }

    _recentCreates[key] = DateTime.now().add(_cacheTtl);
    _recentDeletes.remove(key);
  }

  void _recordDelete(String path) {
    final key = _normalizeCacheKey(path);
    if (key.isEmpty) {
      return;
    }

    _recentDeletes[key] = DateTime.now().add(_cacheTtl);
    _recentCreates.remove(key);
  }

  static void _purgeCaches() {
    final now = DateTime.now();
    _recentCreates.removeWhere((_, expiry) => expiry.isBefore(now));
    _recentDeletes.removeWhere((_, expiry) => expiry.isBefore(now));
  }

  String _normalizeCacheKey(String path) {
    if (path.isEmpty) {
      return '';
    }

    return path.replaceAll(RegExp(r'/+$'), '');
  }
}
