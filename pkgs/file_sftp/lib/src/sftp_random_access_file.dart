import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart' show SftpFileAttrs, SftpFileOpenMode;
import 'package:file/file.dart';

import 'sftp_fs.dart';

/// An SFTP-backed implementation of [RandomAccessFile] that reads and writes
/// to an open remote file using offset-based SFTP operations.
///
/// The SFTP protocol (`SSH_FXP_READ` and `SSH_FXP_WRITE`) supports reading
/// and writing at arbitrary byte offsets without an explicit seek operation.
/// This class translates [RandomAccessFile]'s position-based API (seek, read,
/// write) into offset-based SFTP calls. The current [position] is tracked
/// locally and incremented after each read or write.
///
/// ## Positioning
///
/// [setPosition] updates the local offset immediately. [read] and [writeByte]
/// use the current position as the `offset` parameter to
/// [SftpFsFile.readBytes] and [SftpFsFile.writeBytes]. The position is
/// advanced by the number of bytes actually read or written.
///
/// ## Length and truncation
///
/// [length] issues a remote [SftpFs.stat] call each time it is invoked.
/// [truncate] closes the underlying file handle, calls
/// [SftpFs.setStat] with the new size, then reopens the file. This approach
/// avoids writing padding bytes and relies on the SFTP server to adjust the
/// file size.
///
/// ## Limitations
///
/// - File locking ([lock], [unlock]) throws [UnsupportedError] because SFTP
///   does not support advisory locking.
/// - [flush] is a no-op; SFTP write operations are sent directly to the
///   server without local buffering.
///
/// All synchronous operations throw [UnsupportedError].
class SftpRandomAccessFile implements RandomAccessFile {
  /// Creates a new [SftpRandomAccessFile] backed by the open SFTP file handle
  /// [_file] at the given [path].
  ///
  /// The [fs] parameter is required for [length] and [truncate]; if omitted,
  /// those methods throw [UnsupportedError]. The [remotePath] defaults to
  /// [path] and is used for remote stat and setStat calls.
  SftpRandomAccessFile(this._file, this.path, {SftpFs? fs, String? remotePath})
    : _fs = fs,
      _remotePath = remotePath ?? path;

  /// The underlying SFTP file handle obtained from [SftpFs.open].
  SftpFsFile _file;

  /// The [SftpFs] instance used for stat and setStat calls in [length] and
  /// [truncate]. May be `null` if the caller did not provide it.
  final SftpFs? _fs;

  /// The remote path used for stat and setStat calls.
  final String _remotePath;

  @override
  final String path;

  int _position = 0;
  bool _closed = false;

  void _checkNotClosed() {
    if (_closed) {
      throw FileSystemException('RandomAccessFile is closed', path);
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _file.close();
  }

  @override
  void closeSync() {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<int> length() async {
    _checkNotClosed();
    if (_fs case final fs?) {
      final attrs = await fs.stat(_remotePath);
      return attrs.size ?? 0;
    }
    throw UnsupportedError(
      'Cannot determine length without access to SftpFs.',
    );
  }

  @override
  int lengthSync() {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<int> position() async {
    _checkNotClosed();
    return _position;
  }

  @override
  int positionSync() {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<RandomAccessFile> setPosition(int position) async {
    _checkNotClosed();
    _position = position;
    return this;
  }

  @override
  void setPositionSync(int position) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<Uint8List> read(int bytes) async {
    _checkNotClosed();
    final chunk = await _file.readBytes(length: bytes, offset: _position);
    _position += chunk.length;
    return chunk;
  }

  @override
  Uint8List readSync(int bytes) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<int> readByte() async {
    _checkNotClosed();
    final chunk = await _file.readBytes(length: 1, offset: _position);
    if (chunk.isEmpty) return -1;
    _position += 1;
    return chunk[0];
  }

  @override
  int readByteSync() {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<int> readInto(List<int> buffer, [int start = 0, int? end]) async {
    _checkNotClosed();
    end ??= buffer.length;
    final length = end - start;
    if (length <= 0) return 0;
    final chunk = await _file.readBytes(length: length, offset: _position);
    if (chunk.isEmpty) return 0;
    final bytesToCopy = chunk.length > length ? length : chunk.length;
    buffer.setRange(start, start + bytesToCopy, chunk);
    _position += bytesToCopy;
    return bytesToCopy;
  }

  @override
  int readIntoSync(List<int> buffer, [int start = 0, int? end]) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<RandomAccessFile> truncate(int length) async {
    _checkNotClosed();
    if (_fs case final fs?) {
      await _file.close();

      await fs.setStat(_remotePath, SftpFileAttrs(size: length));

      final reopened = await fs.open(
        _remotePath,
        mode: SftpFileOpenMode.read | SftpFileOpenMode.write,
      );
      _file = reopened;
      _position = 0;

      return this;
    }
    throw UnsupportedError(
      'Truncation not supported without access to SftpFs.',
    );
  }

  @override
  void truncateSync(int length) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<RandomAccessFile> flush() async => this;

  @override
  void flushSync() {}

  @override
  Future<RandomAccessFile> lock([
    FileLock mode = FileLock.shared,
    int start = 0,
    int end = -1,
  ]) async {
    throw UnsupportedError('File locking not supported');
  }

  @override
  void lockSync([FileLock mode = FileLock.shared, int start = 0, int end = -1]) {
    throw UnsupportedError('File locking not supported');
  }

  @override
  Future<RandomAccessFile> unlock([int start = 0, int end = -1]) async {
    throw UnsupportedError('File locking not supported');
  }

  @override
  void unlockSync([int start = 0, int end = -1]) {
    throw UnsupportedError('File locking not supported');
  }

  @override
  Future<RandomAccessFile> writeByte(int value) async {
    _checkNotClosed();
    await _file.writeBytes(Uint8List.fromList([value]), offset: _position);
    _position += 1;
    return this;
  }

  @override
  int writeByteSync(int value) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<RandomAccessFile> writeFrom(List<int> buffer, [int start = 0, int? end]) async {
    _checkNotClosed();
    end ??= buffer.length;
    final data = Uint8List.fromList(buffer.sublist(start, end));
    await _file.writeBytes(data, offset: _position);
    _position += data.length;
    return this;
  }

  @override
  void writeFromSync(List<int> buffer, [int start = 0, int? end]) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<RandomAccessFile> writeString(String string, {Encoding encoding = utf8}) async {
    final bytes = encoding.encode(string);
    return writeFrom(bytes);
  }

  @override
  void writeStringSync(String string, {Encoding encoding = utf8}) {
    throw UnsupportedError('Sync operations not supported.');
  }
}
