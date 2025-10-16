import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'cloud_driver.dart';
import 'cloud_directory.dart';
import 'cloud_file.dart';
import 'cloud_link.dart';

/// A [FileSystem] implementation backed by an abstract [CloudStorageDriver].
class CloudFileSystem implements FileSystem {
  CloudFileSystem({required this.driver, p.Context? context})
    : path = context ?? p.Context(style: p.Style.posix);

  final CloudStorageDriver driver;

  @override
  final p.Context path;

  String _currentDirectory = '/';

  @override
  Directory directory(dynamic path) =>
      CloudDirectory(this, _normalizePath(path));

  @override
  File file(dynamic path) => CloudFile(this, _normalizePath(path));

  @override
  Link link(dynamic path) => CloudLink(this, _normalizePath(path));

  @override
  Directory get currentDirectory => directory(_currentDirectory);

  @override
  set currentDirectory(dynamic value) {
    final normalizedPath = _normalizePath(value);
    _currentDirectory = normalizedPath.endsWith('/') || normalizedPath == '/'
        ? normalizedPath
        : '$normalizedPath/';
  }

  @override
  Future<FileStat> stat(String targetPath) async {
    final remote = toRemotePath(targetPath);
    final stat = await driver.stat(remote);

    if (stat == null) {
      return _CloudFileStat(type: FileSystemEntityType.notFound);
    }

    return _CloudFileStat(
      type: stat.type,
      size: stat.size,
      modified: stat.modified,
    );
  }

  @override
  FileStat statSync(String path) {
    throw UnsupportedError('Sync operations are not supported.');
  }

  @override
  Future<bool> identical(String path1, String path2) async =>
      toRemotePath(path1) == toRemotePath(path2);

  @override
  bool identicalSync(String path1, String path2) {
    throw UnsupportedError('Sync operations are not supported.');
  }

  @override
  Future<bool> isDirectory(String path) async =>
      (await stat(path)).type == FileSystemEntityType.directory;

  @override
  bool isDirectorySync(String path) {
    throw UnsupportedError('Sync operations are not supported.');
  }

  @override
  Future<bool> isFile(String path) async =>
      (await stat(path)).type == FileSystemEntityType.file;

  @override
  bool isFileSync(String path) {
    throw UnsupportedError('Sync operations are not supported.');
  }

  @override
  Future<bool> isLink(String path) async => false;

  @override
  bool isLinkSync(String path) {
    throw UnsupportedError('Sync operations are not supported.');
  }

  @override
  Future<FileSystemEntityType> type(
    String path, {
    bool followLinks = true,
  }) async => (await stat(path)).type;

  @override
  FileSystemEntityType typeSync(String path, {bool followLinks = true}) {
    throw UnsupportedError('Sync operations are not supported.');
  }

  @override
  Directory get systemTempDirectory {
    throw UnsupportedError(
      'System temp directory not supported by cloud filesystem.',
    );
  }

  @override
  String getPath(dynamic target) => _normalizePath(target);

  @override
  bool get isWatchSupported => false;

  /// Convert an absolute path into the remote key used by the driver.
  String toRemotePath(String normalizedPath) {
    if (normalizedPath == '/' || normalizedPath.isEmpty) {
      return '';
    }
    return normalizedPath.startsWith('/')
        ? normalizedPath.substring(1)
        : normalizedPath;
  }

  /// Convert a key returned by the driver into an absolute path.
  String fromRemotePath(String key) {
    if (key.isEmpty) {
      return '/';
    }
    return key.startsWith('/') ? key : '/$key';
  }

  String _normalizePath(dynamic pathOrEntity) {
    String value;
    if (pathOrEntity is String) {
      value = pathOrEntity;
    } else if (pathOrEntity is FileSystemEntity) {
      value = pathOrEntity.path;
    } else {
      value = pathOrEntity.toString();
    }

    if (!path.isAbsolute(value)) {
      value = path.join(_currentDirectory, value);
    }

    return path.normalize(value);
  }
}

class _CloudFileStat implements FileStat {
  _CloudFileStat({required this.type, this.size = 0, DateTime? modified})
    : _modified = modified ?? DateTime.now(),
      _accessed = modified ?? DateTime.now(),
      _changed = modified ?? DateTime.now();

  final DateTime _modified;
  final DateTime _accessed;
  final DateTime _changed;

  @override
  final FileSystemEntityType type;

  @override
  final int size;

  @override
  DateTime get modified => _modified;

  @override
  DateTime get accessed => _accessed;

  @override
  DateTime get changed => _changed;

  @override
  int get mode => 0;

  @override
  String modeString() => '---------';
}
