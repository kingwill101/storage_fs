import 'package:file/file.dart';
import 'cloud_file_system_entity.dart';

/// A symbolic link in a cloud filesystem.
///
/// Note: Cloud filesystems typically do not support symbolic links.
/// This implementation throws [UnsupportedError] for all operations.
class CloudLink extends CloudFileSystemEntity implements Link {
  const CloudLink(super.fileSystem, super.path);

  @override
  CloudLink get absolute =>
      CloudLink(fileSystem, fileSystem.path.absolute(path));

  @override
  FileSystemEntityType get expectedType => FileSystemEntityType.link;

  @override
  Future<bool> exists() async => false;

  @override
  bool existsSync() => false;

  @override
  Future<Link> create(String target, {bool recursive = false}) async {
    throw UnsupportedError('Symbolic links not supported');
  }

  @override
  void createSync(String target, {bool recursive = false}) {
    throw UnsupportedError('Symbolic links not supported');
  }

  @override
  Future<Link> update(String target) async {
    throw UnsupportedError('Symbolic links not supported');
  }

  @override
  void updateSync(String target) {
    throw UnsupportedError('Symbolic links not supported');
  }

  @override
  Future<Link> delete({bool recursive = false}) async {
    throw UnsupportedError('Symbolic links not supported');
  }

  @override
  void deleteSync({bool recursive = false}) {
    throw UnsupportedError('Symbolic links not supported');
  }

  @override
  Future<Link> rename(String newPath) async {
    throw UnsupportedError('Symbolic links not supported');
  }

  @override
  Link renameSync(String newPath) {
    throw UnsupportedError('Symbolic links not supported');
  }

  @override
  Future<String> target() async {
    throw UnsupportedError('Symbolic links not supported');
  }

  @override
  String targetSync() {
    throw UnsupportedError('Symbolic links not supported');
  }
}
