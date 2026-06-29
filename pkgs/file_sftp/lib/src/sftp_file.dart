import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart' show SftpFileOpenMode, SftpFileAttrs;
import 'package:file/file.dart';

import 'sftp_file_system_entity.dart';
import 'sftp_random_access_file.dart';

/// An SFTP-backed implementation of [File] that represents a file on a remote
/// SFTP server.
///
/// Supports reading the full file content ([readAsBytes], [readAsString],
/// [readAsLines]), streaming ([openRead]), writing ([writeAsBytes],
/// [writeAsString], [openWrite]), copying ([copy]), renaming ([rename]),
/// and deleting ([delete]). Metadata accessors like [length], [lastModified],
/// and [lastAccessed] issue remote stat calls on each invocation.
///
/// ## Writable operations
///
/// All write operations check [SftpConfig.readOnly] and throw
/// [FileSystemException] with the message `'SFTP filesystem is read-only.'`
/// when the filesystem is configured as read-only.
///
/// ## File modes
///
/// [open] and [openWrite] translate [FileMode] to the corresponding SFTP open
/// flags:
/// - [FileMode.read] opens in read-only mode.
/// - [FileMode.write] and [FileMode.writeOnly] create or truncate then write.
/// - [FileMode.append] creates or appends.
///
/// ## Error handling
///
/// All failures throw [FileSystemException] with the local [path] set as the
/// offending path.
///
/// All synchronous operations throw [UnsupportedError].
class SftpFile extends SftpFileSystemEntity implements File {
  /// Creates a new SFTP file at the given [path] within [fileSystem].
  const SftpFile(super.fileSystem, super.path);

  @override
  SftpFile get absolute => SftpFile(fileSystem, fileSystem.path.absolute(path));

  @override
  FileSystemEntityType get expectedType => FileSystemEntityType.file;

  @override
  Future<bool> exists() => existsAsync();

  @override
  bool existsSync() {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) async {
    _ensureWritable();

    if (exclusive && await exists()) {
      throw FileSystemException('File already exists', path);
    }

    if (recursive) {
      final parentDir = parent;
      await parentDir.create(recursive: true);
    }

    final fs = await fileSystem.ensureConnected();
    final file = await fs.open(
      remotePath,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
    );
    await file.close();

    return this;
  }

  @override
  void createSync({bool recursive = false, bool exclusive = false}) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<File> copy(String newPath) async {
    _ensureWritable();

    final destination = fileSystem.toRemotePath(fileSystem.getPath(newPath));

    final fs = await fileSystem.ensureConnected();
    final sourceFile = await fs.open(remotePath);
    final bytes = await sourceFile.readBytes();
    await sourceFile.close();

    final destFile = await fs.open(
      destination,
      mode:
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate |
          SftpFileOpenMode.write,
    );
    await destFile.writeBytes(bytes);
    await destFile.close();

    return SftpFile(fileSystem, newPath);
  }

  @override
  File copySync(String newPath) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<File> rename(String newPath) async {
    _ensureWritable();

    final fs = await fileSystem.ensureConnected();
    final dest = fileSystem.toRemotePath(fileSystem.getPath(newPath));
    await fs.rename(remotePath, dest);

    return SftpFile(fileSystem, newPath);
  }

  @override
  File renameSync(String newPath) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<File> delete({bool recursive = false}) async {
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
  Future<int> length() async {
    final stat = await fileSystem.stat(path);
    return stat.size;
  }

  @override
  int lengthSync() {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<DateTime> lastModified() async {
    final stat = await fileSystem.stat(path);
    return stat.modified;
  }

  @override
  DateTime lastModifiedSync() {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<DateTime> lastAccessed() async {
    final stat = await fileSystem.stat(path);
    return stat.accessed;
  }

  @override
  DateTime lastAccessedSync() {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<File> setLastModified(DateTime time) async {
    _ensureWritable();

    final fs = await fileSystem.ensureConnected();
    await fs.setStat(
      remotePath,
      SftpFileAttrs(modifyTime: time.millisecondsSinceEpoch ~/ 1000),
    );
    return this;
  }

  @override
  void setLastModifiedSync(DateTime time) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<File> setLastAccessed(DateTime time) async {
    _ensureWritable();

    final fs = await fileSystem.ensureConnected();
    await fs.setStat(
      remotePath,
      SftpFileAttrs(accessTime: time.millisecondsSinceEpoch ~/ 1000),
    );
    return this;
  }

  @override
  void setLastAccessedSync(DateTime time) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async {
    final fs = await fileSystem.ensureConnected();
    final sftpMode = _toSftpMode(mode);
    final handle = await fs.open(remotePath, mode: sftpMode);
    return SftpRandomAccessFile(handle, path, fs: fs, remotePath: remotePath);
  }

  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) async* {
    final fs = await fileSystem.ensureConnected();
    final length = end != null && start != null ? end - start : null;
    final offset = start ?? 0;

    final file = await fs.open(remotePath);
    try {
      const chunkSize = 65536;
      var pos = offset;
      while (true) {
        final remaining = length != null ? length - (pos - offset) : chunkSize;
        final readLen = remaining < chunkSize && remaining > 0
            ? remaining
            : chunkSize;
        final chunk = await file.readBytes(length: readLen, offset: pos);
        if (chunk.isEmpty) break;
        yield chunk.toList();
        pos += chunk.length;
        if (length != null && pos - offset >= length) break;
      }
    } finally {
      await file.close();
    }
  }

  @override
  IOSink openWrite({FileMode mode = FileMode.write, Encoding encoding = utf8}) {
    final controller = StreamController<List<int>>();
    final sink = IOSink(controller.sink, encoding: encoding);

    final isAppend = mode == FileMode.append;

    controller.stream
        .fold<List<int>>(<int>[], (prev, chunk) => prev..addAll(chunk))
        .then((bytes) async {
          if (bytes.isEmpty) return;

          final fs = await fileSystem.ensureConnected();
          final sftpMode = isAppend
              ? SftpFileOpenMode.create |
                    SftpFileOpenMode.append |
                    SftpFileOpenMode.write
              : SftpFileOpenMode.create |
                    SftpFileOpenMode.truncate |
                    SftpFileOpenMode.write;

          final file = await fs.open(remotePath, mode: sftpMode);
          await file.writeBytes(Uint8List.fromList(bytes));
          await file.close();
        })
        .catchError((Object error) {
          throw FileSystemException('Failed to write file', path);
        });

    return sink;
  }

  @override
  Future<Uint8List> readAsBytes() async {
    final fs = await fileSystem.ensureConnected();
    final file = await fs.open(remotePath);
    try {
      final bytes = await file.readBytes();
      return bytes;
    } finally {
      await file.close();
    }
  }

  @override
  Uint8List readAsBytesSync() {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<String> readAsString({Encoding encoding = utf8}) async {
    final bytes = await readAsBytes();
    return encoding.decode(bytes);
  }

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<List<String>> readAsLines({Encoding encoding = utf8}) async {
    final content = await readAsString(encoding: encoding);
    return const LineSplitter().convert(content);
  }

  @override
  List<String> readAsLinesSync({Encoding encoding = utf8}) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    _ensureWritable();

    final fs = await fileSystem.ensureConnected();
    final sftpMode = mode == FileMode.append
        ? SftpFileOpenMode.create |
              SftpFileOpenMode.append |
              SftpFileOpenMode.write
        : SftpFileOpenMode.create |
              SftpFileOpenMode.truncate |
              SftpFileOpenMode.write;

    final file = await fs.open(remotePath, mode: sftpMode);
    await file.writeBytes(Uint8List.fromList(bytes));
    await file.close();

    return this;
  }

  @override
  void writeAsBytesSync(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    return writeAsBytes(encoding.encode(contents), mode: mode, flush: flush);
  }

  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    throw UnsupportedError('Sync operations not supported.');
  }

  /// Converts a [FileMode] to the corresponding [SftpFileOpenMode] flags.
  ///
  /// - [FileMode.read] produces read-only access.
  /// - [FileMode.write] and [FileMode.writeOnly] create or truncate then write.
  /// - All other modes (including [FileMode.append]) create or append.
  static SftpFileOpenMode _toSftpMode(FileMode mode) {
    if (mode == FileMode.read) return SftpFileOpenMode.read;
    if (mode == FileMode.write || mode == FileMode.writeOnly) {
      return SftpFileOpenMode.create |
          SftpFileOpenMode.truncate |
          SftpFileOpenMode.write;
    }
    return SftpFileOpenMode.create |
        SftpFileOpenMode.append |
        SftpFileOpenMode.write;
  }

  /// Whether the filesystem is configured as read-only.
  void _ensureWritable() {
    if (fileSystem.config.readOnly) {
      throw FileSystemException('SFTP filesystem is read-only.', path);
    }
  }
}
