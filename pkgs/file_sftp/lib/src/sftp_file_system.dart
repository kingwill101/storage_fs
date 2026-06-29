import 'package:dartssh2/dartssh2.dart' hide SftpFile;
import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'sftp_config.dart';
import 'sftp_directory.dart';
import 'sftp_file.dart';
import 'sftp_fs.dart';
import 'sftp_fs_client.dart';
import 'sftp_link.dart';

/// An SFTP-backed implementation of [FileSystem] that enables remote file
/// operations over SSH.
///
/// Connects to a remote host via the SSH File Transfer Protocol (SFTP) and
/// exposes files, directories, and symbolic links through [package:file]'s
/// standard [FileSystem] interface. All I/O operations are asynchronous; every
/// synchronous variant throws [UnsupportedError].
///
/// ## Connection lifecycle
///
/// A connection is established lazily on the first file operation. Pass
/// [SftpConfig] to the default constructor for full connection management:
///
/// ```dart
/// final fs = SftpFileSystem(SftpConfig(
///   host: 'example.com',
///   username: 'alice',
///   password: 'secret',
///   root: '/home/alice/project',
/// ));
/// ```
///
/// To reuse an already-authenticated [SftpClient] or [SSHClient], pass them
/// to the default constructor or use [SftpFileSystem.fromClient]:
/// For testing, inject a mock [SftpFs] via [SftpFileSystem.fromSftpFs].
///
/// Close the underlying SSH and SFTP connections with [disconnect]. After
/// disconnecting, the next operation re-establishes the connection.
///
/// ## Path handling
///
/// Paths are treated as POSIX paths (forward-slash separated). Relative paths
/// are resolved against [currentDirectory]. The [SftpConfig.root] setting
/// prepends a remote prefix to all local paths through [toRemotePath]; the
/// inverse conversion is [fromRemotePath].
///
/// ## Error handling
///
/// All failures throw [FileSystemException] with the offending path, mirroring
/// the behavior of [package:file]'s local filesystem implementations.
///
/// ## Thread safety
///
/// This class is **not** thread-safe. Concurrent access from multiple isolates
/// requires external synchronization.
///
/// See [SftpFile], [SftpDirectory], [SftpLink], and [SftpRandomAccessFile]
/// for the individual entity implementations.
class SftpFileSystem implements FileSystem {
  /// Creates an [SftpFileSystem] that establishes its own SSH connection using
  /// the given [config].
  ///
  /// The connection is deferred until the first file operation unless [client]
  /// or [sshClient] is provided. When an existing [SftpClient] is supplied, it
  /// is used immediately and [disconnect] closes it. When an [SSHClient] is
  /// supplied, the SFTP session is derived from it lazily on the first file
  /// operation. Use [disconnect] to close the SSH and SFTP sessions.
  SftpFileSystem(
    this.config, {
    SftpClient? client,
    SSHClient? sshClient,
  }) : path = p.Context(style: p.Style.posix) {
    if (client != null) {
      _fs = SftpFsClient(client);
      _connected = true;
    } else if (sshClient != null) {
      _sshClient = sshClient;
    }
  }

  /// Creates an [SftpFileSystem] wrapping an existing [SftpFs] abstraction.
  ///
  /// Useful for unit testing with mock [SftpFs] instances. The optional
  /// [config] factory supplies the [SftpConfig]; defaults to an empty config
  /// with no host, username, or root set.
  SftpFileSystem.fromSftpFs(SftpFs fs, {SftpConfig Function()? config})
    : _fs = fs,
      _connected = true,
      config = config?.call() ?? const SftpConfig(host: '', username: ''),
      path = p.Context(style: p.Style.posix);

  /// Creates an [SftpFileSystem] wrapping an already-authenticated
  /// [SftpClient].
  ///
  /// The caller retains ownership of the [SftpClient]; calling [disconnect]
  /// on this filesystem closes it. The optional [config] factory supplies the
  /// [SftpConfig]; defaults to an empty config.
  SftpFileSystem.fromClient(
    SftpClient sftp, {
    SftpConfig Function()? config,
  }) : _fs = SftpFsClient(sftp),
       _connected = true,
       config = config?.call() ?? const SftpConfig(host: '', username: ''),
       path = p.Context(style: p.Style.posix);

  /// The configuration used to connect to the remote SFTP server.
  ///
  /// Includes the host, port, credentials, root path, and read-only flag.
  final SftpConfig config;

  @override
  final p.Context path;

  SSHClient? _sshClient;
  SftpFs? _fs;
  bool _connected = false;

  String _currentDirectory = '/';

  @override
  Directory directory(dynamic path) =>
      SftpDirectory(this, _normalizePath(path));

  @override
  File file(dynamic path) => SftpFile(this, _normalizePath(path));

  @override
  Link link(dynamic path) => SftpLink(this, _normalizePath(path));

  @override
  Directory get currentDirectory => directory(_currentDirectory);

  @override
  set currentDirectory(dynamic value) {
    _currentDirectory = _normalizePath(value);
  }

  @override
  Directory get systemTempDirectory {
    throw UnsupportedError(
      'System temp directory not supported by SFTP filesystem.',
    );
  }

  @override
  bool get isWatchSupported => false;

  @override
  String getPath(dynamic target) => _normalizePath(target);

  /// Converts a normalized local path to the remote path by prepending
  /// [SftpConfig.root].
  ///
  /// Returns [SftpConfig.root] unchanged when [normalizedPath] is `'/'` or
  /// empty. When no root is configured, returns the path as-is (stripping the
  /// leading `/`).
  ///
  /// [normalizedPath] must already be normalized (no `..` or `.` segments).
  String toRemotePath(String normalizedPath) {
    if (normalizedPath == '/' || normalizedPath.isEmpty) {
      final root = config.root;
      if (root != null && root.isNotEmpty) return root;
      return '';
    }
    var stripped = normalizedPath;
    if (stripped.startsWith('/')) {
      stripped = stripped.substring(1);
    }
    final root = config.root;
    if (root != null && root.isNotEmpty) {
      final sep = root.endsWith('/') || stripped.isEmpty ? '' : '/';
      return '$root$sep$stripped';
    }
    return stripped;
  }

  /// Converts a remote path returned by the SFTP server back to the local
  /// normalized path by stripping [SftpConfig.root].
  ///
  /// When no root is configured, ensures the result starts with `/`. Returns
  /// `'/'` when [key] equals the root prefix.
  String fromRemotePath(String remote) {
    final root = config.root;
    if (root != null && root.isNotEmpty) {
      if (remote == root) return '/';
      final prefix = root.endsWith('/') ? root : '$root/';
      if (remote.startsWith(prefix)) {
        final relative = remote.substring(prefix.length);
        return relative.isEmpty ? '/' : '/$relative';
      }
    }
    if (remote.isEmpty) return '/';
    return remote.startsWith('/') ? remote : '/$remote';
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

  /// Closes the SSH and SFTP connections and resets internal state.
  ///
  /// Safe to call multiple times. After this method returns, any future file
  /// operations will re-establish the connection via [ensureConnected].
  Future<void> disconnect() async {
    _fs?.close();
    _sshClient?.close();
    _fs = null;
    _sshClient = null;
    _connected = false;
  }

  @override
  Future<FileStat> stat(String targetPath) async {
    final fs = await ensureConnected();
    final remote = toRemotePath(targetPath);
    final attrs = await fs.stat(remote);

    return _SftpFileStat(
      type: _typeFromAttrs(attrs),
      size: attrs.size ?? 0,
      modified: attrs.modifyTime != null
          ? DateTime.fromMillisecondsSinceEpoch(attrs.modifyTime! * 1000)
          : null,
      accessed: attrs.accessTime != null
          ? DateTime.fromMillisecondsSinceEpoch(attrs.accessTime! * 1000)
          : null,
      mode: attrs.mode?.value ?? 0,
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
  Future<bool> isLink(String path) async =>
      (await stat(path)).type == FileSystemEntityType.link;

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

  /// Returns the underlying [SftpFs], establishing a connection if needed.
  ///
  /// When [sshClient] was provided to the constructor, derives the SFTP
  /// session lazily. Otherwise uses [SftpConfig] credentials to open an SSH
  /// socket via [SSHSocket.connect], authenticate with [SSHClient], and start
  /// an SFTP session. This is called automatically by all file operations and
  /// can also be called explicitly to force connection before the first
  /// operation.
  ///
  /// Throws a [FileSystemException] wrapping the underlying SSH or SFTP error
  /// if the connection fails.
  Future<SftpFs> ensureConnected() async {
    if (_connected && _fs != null) return _fs!;

    if (_sshClient != null) {
      final sftp = await _sshClient!.sftp();
      _fs = SftpFsClient(sftp);
      _connected = true;
      return _fs!;
    }

    final socket = await SSHSocket.connect(
      config.host,
      config.port,
      timeout: config.connectTimeout,
    );

    _sshClient = SSHClient(
      socket,
      username: config.username,
      onPasswordRequest:
          config.password != null ? () => config.password! : null,
      identities:
          config.privateKeyPems
              ?.expand(
                (pem) =>
                    SSHKeyPair.fromPem(pem, config.privateKeyPassphrase),
              )
              .toList() ??
          const [],
    );

    await _sshClient!.authenticated;
    final sftp = await _sshClient!.sftp();
    _fs = SftpFsClient(sftp);
    _connected = true;
    return _fs!;
  }

  static FileSystemEntityType _typeFromAttrs(SftpFileAttrs attrs) {
    if (attrs.isDirectory) return FileSystemEntityType.directory;
    if (attrs.isSymbolicLink) return FileSystemEntityType.link;
    if (attrs.isFile) return FileSystemEntityType.file;
    return FileSystemEntityType.file;
  }
}

/// A [FileStat] implementation derived from [SftpFileAttrs] returned by the
/// remote SFTP server.
///
/// Maps the SFTP attribute fields (size, modification time, access time,
/// POSIX mode) to [FileStat] properties, with missing values defaulting to
/// zero or the current time as appropriate.
class _SftpFileStat implements FileStat {
  _SftpFileStat({
    required this.type,
    this.size = 0,
    DateTime? modified,
    DateTime? accessed,
    this.mode = 0,
  }) : _modified = modified ?? DateTime.now(),
       _accessed = accessed ?? DateTime.now(),
       _changed = modified ?? DateTime.now();

  final DateTime _modified;
  final DateTime _accessed;
  final DateTime _changed;

  @override
  final FileSystemEntityType type;

  @override
  final int size;

  @override
  final int mode;

  @override
  DateTime get modified => _modified;

  @override
  DateTime get accessed => _accessed;

  @override
  DateTime get changed => _changed;

  @override
  String modeString() {
    final buf = StringBuffer();
    buf.write(type == FileSystemEntityType.directory ? 'd' : '-');
    buf.write(mode & 0x100 != 0 ? 'r' : '-');
    buf.write(mode & 0x080 != 0 ? 'w' : '-');
    buf.write(mode & 0x040 != 0 ? 'x' : '-');
    buf.write(mode & 0x020 != 0 ? 'r' : '-');
    buf.write(mode & 0x010 != 0 ? 'w' : '-');
    buf.write(mode & 0x008 != 0 ? 'x' : '-');
    buf.write(mode & 0x004 != 0 ? 'r' : '-');
    buf.write(mode & 0x002 != 0 ? 'w' : '-');
    buf.write(mode & 0x001 != 0 ? 'x' : '-');
    return buf.toString();
  }
}
