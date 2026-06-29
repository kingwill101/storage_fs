import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

abstract class SftpFs {
  Future<SftpFileAttrs> stat(String path, {bool followLink = true});
  Future<void> setStat(String path, SftpFileAttrs attrs);
  Future<SftpFsFile> open(
    String path, {
    SftpFileOpenMode mode = SftpFileOpenMode.read,
  });
  Future<List<SftpName>> listdir(String path);
  Future<void> remove(String path);
  Future<void> mkdir(String path, [SftpFileAttrs? attrs]);
  Future<void> rmdir(String path);
  Future<void> rename(String oldPath, String newPath);
  void close();
}

abstract class SftpFsFile {
  Future<Uint8List> readBytes({int? length, int offset = 0});
  Future<void> writeBytes(Uint8List data, {int offset = 0});
  Future<void> write(Stream<List<int>> stream);
  Future<void> close();
}
