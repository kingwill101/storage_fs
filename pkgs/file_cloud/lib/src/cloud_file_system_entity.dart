import 'package:file/file.dart';
import 'cloud_file_system.dart';

/// Base class for cloud filesystem entities.
///
/// This abstract class provides common functionality for files, directories,
/// and links in a cloud filesystem, implementing the [FileSystemEntity] interface.
abstract class CloudFileSystemEntity implements FileSystemEntity {
  const CloudFileSystemEntity(this.fileSystem, this.path);

  @override
  final CloudFileSystem fileSystem;

  @override
  final String path;

  @override
  String get dirname => fileSystem.path.dirname(path);

  @override
  String get basename => fileSystem.path.basename(path);

  @override
  Directory get parent => fileSystem.directory(dirname);

  FileSystemEntityType get expectedType;

  String get remotePath => fileSystem.toRemotePath(path);

  @override
  Future<String> resolveSymbolicLinks() async => path;

  @override
  String resolveSymbolicLinksSync() => path;

  @override
  Future<FileStat> stat() => fileSystem.stat(path);

  @override
  FileStat statSync() {
    throw UnsupportedError('Sync operations not supported. Use stat()');
  }

  @override
  Uri get uri {
    final publicUrl = fileSystem.driver.publicUrl(remotePath);
    if (publicUrl != null) {
      return publicUrl;
    }

    return Uri(scheme: 'cloud', path: remotePath);
  }

  @override
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) {
    throw UnsupportedError('File watching not supported');
  }

  @override
  bool get isAbsolute => fileSystem.path.isAbsolute(path);

  Future<bool> existsAsync() async => (await stat()).type == expectedType;

  Future<bool> existsAtPath() async =>
      (await stat()).type != FileSystemEntityType.notFound;
}
