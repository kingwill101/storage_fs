import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import 'sftp_fs.dart';

class SftpFsClient implements SftpFs {
  final SftpClient _client;

  SftpFsClient(this._client);

  @override
  Future<SftpFileAttrs> stat(String path, {bool followLink = true}) =>
      _client.stat(path, followLink: followLink);

  @override
  Future<void> setStat(String path, SftpFileAttrs attrs) =>
      _client.setStat(path, attrs);

  @override
  Future<SftpFsFile> open(
    String path, {
    SftpFileOpenMode mode = SftpFileOpenMode.read,
  }) async {
    final file = await _client.open(path, mode: mode);
    return SftpFsFileHandle(file);
  }

  @override
  Future<List<SftpName>> listdir(String path) => _client.listdir(path);

  @override
  Future<void> remove(String path) => _client.remove(path);

  @override
  Future<void> mkdir(String path, [SftpFileAttrs? attrs]) =>
      _client.mkdir(path, attrs);

  @override
  Future<void> rmdir(String path) => _client.rmdir(path);

  @override
  Future<void> rename(String oldPath, String newPath) =>
      _client.rename(oldPath, newPath);

  @override
  Future<String> readlink(String path) => _client.readlink(path);

  @override
  Future<void> link(String linkPath, String targetPath) =>
      _client.link(linkPath, targetPath);

  @override
  void close() => _client.close();
}

class SftpFsFileHandle implements SftpFsFile {
  final SftpFile _file;

  SftpFsFileHandle(this._file);

  @override
  Future<Uint8List> readBytes({int? length, int offset = 0}) =>
      _file.readBytes(length: length, offset: offset);

  @override
  Future<void> writeBytes(Uint8List data, {int offset = 0}) =>
      _file.writeBytes(data, offset: offset);

  @override
  Future<void> write(Stream<List<int>> stream) async {
    await _file.write(stream.map((c) => Uint8List.fromList(c)));
  }

  @override
  Future<void> close() => _file.close();
}
