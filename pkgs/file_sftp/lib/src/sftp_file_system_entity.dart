import 'package:file/file.dart';

import 'sftp_file_system.dart';

/// An abstract base class for SFTP-backed [FileSystemEntity] implementations.
///
/// Provides shared behavior for [SftpFile], [SftpDirectory], and [SftpLink]:
///
/// * **[remotePath]** — converts the local [path] to a remote path by
///   prepending [SftpConfig.root] via [SftpFileSystem.toRemotePath].
/// * **[stat]** — delegates to [SftpFileSystem.stat], which calls
///   [SftpFs.stat] on the remote server and wraps the result in a
///   [_SftpFileStat].
/// * **[resolveSymbolicLinks]** — calls [SftpFs.readlink] on [remotePath].
/// * **[existsAsync]** — returns `true` when [stat] succeeds and the result
///   matches [expectedType].
/// * **[uri]** — produces an `sftp://` scheme URI.
/// * **[watch]** — throws [UnsupportedError]; file watching is not supported
///   over SFTP.
///
/// All synchronous operations throw [UnsupportedError].
abstract class SftpFileSystemEntity implements FileSystemEntity {
  /// Creates a new SFTP filesystem entity at the given [path] within
  /// [fileSystem].
  const SftpFileSystemEntity(this.fileSystem, this.path);

  /// The filesystem that owns this entity.
  @override
  final SftpFileSystem fileSystem;

  /// The normalized local path of this entity.
  @override
  final String path;

  @override
  String get dirname => fileSystem.path.dirname(path);

  @override
  String get basename => fileSystem.path.basename(path);

  @override
  Directory get parent => fileSystem.directory(dirname);

  /// The expected [FileSystemEntityType] used by [existsAsync] to verify
  /// that the remote entity is of the correct type.
  ///
  /// [SftpFile] returns [FileSystemEntityType.file], [SftpDirectory] returns
  /// [FileSystemEntityType.directory], and [SftpLink] returns
  /// [FileSystemEntityType.link].
  FileSystemEntityType get expectedType;

  /// The remote path on the SFTP server.
  ///
  /// Derived from [path] by prepending [SftpConfig.root] via
  /// [SftpFileSystem.toRemotePath]. This is the path used in all SFTP protocol
  /// operations.
  String get remotePath => fileSystem.toRemotePath(path);

  @override
  Future<String> resolveSymbolicLinks() async {
    final fs = await fileSystem.ensureConnected();
    return fs.readlink(remotePath);
  }

  @override
  String resolveSymbolicLinksSync() {
    throw UnsupportedError(
      'Sync operations not supported. Use resolveSymbolicLinks()',
    );
  }

  @override
  Future<FileStat> stat() => fileSystem.stat(path);

  @override
  FileStat statSync() {
    throw UnsupportedError('Sync operations not supported. Use stat()');
  }

  @override
  Uri get uri => Uri(scheme: 'sftp', path: remotePath);

  @override
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) {
    throw UnsupportedError('File watching not supported');
  }

  @override
  bool get isAbsolute => fileSystem.path.isAbsolute(path);

  /// Whether a remote entity exists at [path] and matches [expectedType].
  ///
  /// Returns `true` if [stat] succeeds and the returned [FileStat.type]
  /// equals [expectedType]. Returns `false` if the entity does not exist or
  /// if any error occurs during the stat call.
  Future<bool> existsAsync() async {
    try {
      return (await stat()).type == expectedType;
    } catch (_) {
      return false;
    }
  }
}
