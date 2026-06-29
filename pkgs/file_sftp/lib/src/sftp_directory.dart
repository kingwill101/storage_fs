import 'dart:async';

import 'package:file/file.dart';

import 'sftp_file.dart';
import 'sftp_file_system_entity.dart';
import 'sftp_fs.dart';
import 'sftp_link.dart';

/// An SFTP-backed implementation of [Directory] that represents a directory on
/// a remote SFTP server.
///
/// Supports creating directories ([create] with optional [recursive] parent
/// creation), listing contents ([list] with optional [recursive] traversal),
/// renaming ([rename]), and deleting ([delete] with optional [recursive] tree
/// removal).
///
/// ## Recursive operations
///
/// When [create] is called with `recursive: true`, each missing parent
/// directory is created individually by checking its existence first via
/// [stat]. The [delete] method with `recursive: true` traverses the remote
/// directory tree depth-first, deleting files and empty directories before
/// removing the target.
///
/// ## Listing behavior
///
/// [list] delegates to the SFTP `readdir` operation, yielding
/// [SftpLink], [SftpDirectory], or [SftpFile] instances based on each entry's
/// remote file attributes. The `.` and `..` entries are filtered out. When
/// `recursive: true`, the listing descends into subdirectories depth-first.
///
/// ## Temporary directories
///
/// [createTemp] throws [UnsupportedError] because the remote server is not
/// guaranteed to have a writable temp directory.
///
/// All synchronous operations throw [UnsupportedError].
class SftpDirectory extends SftpFileSystemEntity implements Directory {
  /// Creates a new SFTP directory at the given [path] within [fileSystem].
  const SftpDirectory(super.fileSystem, super.path);

  @override
  SftpDirectory get absolute =>
      SftpDirectory(fileSystem, fileSystem.path.absolute(path));

  @override
  FileSystemEntityType get expectedType => FileSystemEntityType.directory;

  @override
  Future<bool> exists() => existsAsync();

  @override
  bool existsSync() {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<Directory> create({bool recursive = false}) async {
    _ensureWritable();

    if (recursive) {
      final parentPath = dirname;
      if (parentPath != path && parentPath.isNotEmpty) {
        try {
          final fs = await fileSystem.ensureConnected();
          await fs.stat(fileSystem.toRemotePath(parentPath));
        } catch (_) {
          await (fileSystem.directory(parentPath) as SftpDirectory).create(
            recursive: true,
          );
        }
      }
    }

    final fs = await fileSystem.ensureConnected();
    try {
      await fs.mkdir(remotePath);
    } catch (_) {}

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
    _ensureWritable();

    final fs = await fileSystem.ensureConnected();

    if (recursive) {
      await _deleteTree(fs, remotePath);
    } else {
      try {
        await fs.rmdir(remotePath);
      } catch (_) {
        final entries = await fs.listdir(remotePath);
        final filtered = entries.where(
          (e) => e.filename != '.' && e.filename != '..',
        );
        if (filtered.isNotEmpty) {
          throw FileSystemException('Directory not empty', path);
        }
        rethrow;
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
    _ensureWritable();

    final fs = await fileSystem.ensureConnected();
    final dest = fileSystem.toRemotePath(fileSystem.getPath(newPath));
    await fs.rename(remotePath, dest);

    return SftpDirectory(fileSystem, newPath);
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
    final fs = await fileSystem.ensureConnected();
    final entries = await fs.listdir(remotePath);

    for (final entry in entries) {
      if (entry.filename == '.' || entry.filename == '..') continue;

      final entryPath = fileSystem.path.join(path, entry.filename);
      final isDir = entry.attr.isDirectory;
      final isLink = entry.attr.isSymbolicLink;

      if (isLink) {
        yield SftpLink(fileSystem, entryPath);
      } else if (isDir) {
        yield SftpDirectory(fileSystem, entryPath);
      } else {
        yield SftpFile(fileSystem, entryPath);
      }
    }

    if (recursive) {
      for (final entry in entries) {
        if (entry.filename == '.' || entry.filename == '..') continue;
        if (!entry.attr.isDirectory) continue;

        final subPath = fileSystem.path.join(path, entry.filename);
        final subDir = SftpDirectory(fileSystem, subPath);
        yield* subDir.list(recursive: true, followLinks: followLinks);
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
      SftpDirectory(fileSystem, fileSystem.path.join(path, basename));

  @override
  File childFile(String basename) =>
      SftpFile(fileSystem, fileSystem.path.join(path, basename));

  @override
  Link childLink(String basename) =>
      SftpLink(fileSystem, fileSystem.path.join(path, basename));

  /// Recursively deletes the directory tree rooted at [dirPath].
  ///
  /// Traverses depth-first, deleting files with [SftpFs.remove] and empty
  /// directories with [SftpFs.rmdir]. Throws on the first error encountered.
  Future<void> _deleteTree(SftpFs fs, String dirPath) async {
    final entries = await fs.listdir(dirPath);
    for (final entry in entries) {
      if (entry.filename == '.' || entry.filename == '..') continue;
      final childPath = '$dirPath/${entry.filename}';
      if (entry.attr.isDirectory) {
        await _deleteTree(fs, childPath);
        await fs.rmdir(childPath);
      } else {
        await fs.remove(childPath);
      }
    }
    await fs.rmdir(dirPath);
  }

  void _ensureWritable() {
    if (fileSystem.config.readOnly) {
      throw FileSystemException('SFTP filesystem is read-only.', path);
    }
  }
}
