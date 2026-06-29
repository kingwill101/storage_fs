import 'package:file/file.dart';

import 'sftp_file_system_entity.dart';

/// An SFTP-backed implementation of [Link] that represents a symbolic link on
/// a remote SFTP server.
///
/// Supports creating a new symlink ([create]), updating an existing symlink
/// ([update], which removes any existing entry before recreating), resolving
/// the link target ([target]), renaming ([rename]), and deleting ([delete]).
///
/// ## Existence check
///
/// [exists] differs from the base [SftpFileSystemEntity.existsAsync] in that
/// it calls [stat] with `followLink: false` and checks specifically for
/// [SftpFileAttrs.isSymbolicLink]. This ensures the link itself is detected
/// even when its target does not exist.
///
/// ## Update semantics
///
/// [update] removes any existing file, directory, or symlink at the link path
/// (by calling [SftpFs.remove]) before creating the new symlink. This matches
/// `ln -sf` behavior on POSIX systems.
///
/// All synchronous operations throw [UnsupportedError].
class SftpLink extends SftpFileSystemEntity implements Link {
  /// Creates a new SFTP symbolic link at the given [path] within [fileSystem].
  const SftpLink(super.fileSystem, super.path);

  @override
  SftpLink get absolute => SftpLink(fileSystem, fileSystem.path.absolute(path));

  @override
  FileSystemEntityType get expectedType => FileSystemEntityType.link;

  @override
  Future<bool> exists() async {
    try {
      final fs = await fileSystem.ensureConnected();
      final attrs = await fs.stat(remotePath, followLink: false);
      return attrs.isSymbolicLink;
    } catch (_) {
      return false;
    }
  }

  @override
  bool existsSync() {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<Link> create(String target, {bool recursive = false}) async {
    _ensureWritable();

    final fs = await fileSystem.ensureConnected();
    await fs.link(remotePath, target);
    return this;
  }

  @override
  void createSync(String target, {bool recursive = false}) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<Link> update(String target) async {
    _ensureWritable();

    final fs = await fileSystem.ensureConnected();

    try {
      final attrs = await fs.stat(remotePath, followLink: false);
      if (attrs.isSymbolicLink) {
        await fs.remove(remotePath);
      }
    } catch (_) {}

    await fs.link(remotePath, target);
    return this;
  }

  @override
  void updateSync(String target) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<Link> delete({bool recursive = false}) async {
    _ensureWritable();

    final fs = await fileSystem.ensureConnected();
    await fs.remove(remotePath);
    return this;
  }

  @override
  void deleteSync({bool recursive = false}) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<Link> rename(String newPath) async {
    _ensureWritable();

    final fs = await fileSystem.ensureConnected();
    final dest = fileSystem.toRemotePath(fileSystem.getPath(newPath));
    await fs.rename(remotePath, dest);

    return SftpLink(fileSystem, newPath);
  }

  @override
  Link renameSync(String newPath) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<String> target() async {
    final fs = await fileSystem.ensureConnected();
    return fs.readlink(remotePath);
  }

  @override
  String targetSync() {
    throw UnsupportedError('Sync operations not supported.');
  }

  void _ensureWritable() {
    if (fileSystem.config.readOnly) {
      throw FileSystemException('SFTP filesystem is read-only.', path);
    }
  }
}
