import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file/file.dart';

import 'cloud_file_system_entity.dart';

/// A file in a cloud filesystem.
///
/// This class provides file operations like reading, writing, copying, and
/// deleting files stored in cloud object storage.
class CloudFile extends CloudFileSystemEntity implements File {
  const CloudFile(super.fileSystem, super.path);

  @override
  CloudFile get absolute =>
      CloudFile(fileSystem, fileSystem.path.absolute(path));

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
    if (exclusive && await exists()) {
      throw FileSystemException('File already exists', path);
    }

    await fileSystem.driver.upload(remotePath, Stream<List<int>>.empty());

    return this;
  }

  @override
  void createSync({bool recursive = false, bool exclusive = false}) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<File> copy(String newPath) async {
    final destination = fileSystem.toRemotePath(fileSystem.getPath(newPath));
    await fileSystem.driver.copy(remotePath, destination);
    return CloudFile(fileSystem, newPath);
  }

  @override
  File copySync(String newPath) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<File> rename(String newPath) async {
    await copy(newPath);
    await delete();
    return CloudFile(fileSystem, newPath);
  }

  @override
  File renameSync(String newPath) {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<File> delete({bool recursive = false}) async {
    await fileSystem.driver.delete(remotePath);
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
  Future<DateTime> lastAccessed() async => lastModified();

  @override
  DateTime lastAccessedSync() {
    throw UnsupportedError('Sync operations not supported.');
  }

  @override
  Future<File> setLastModified(DateTime time) async => this;

  @override
  void setLastModifiedSync(DateTime time) {
    throw UnsupportedError('Setting modification time not supported.');
  }

  @override
  Future<File> setLastAccessed(DateTime time) async => this;

  @override
  void setLastAccessedSync(DateTime time) {
    throw UnsupportedError('Setting access time not supported.');
  }

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async {
    throw UnsupportedError(
      'RandomAccessFile not supported. Use openRead/openWrite.',
    );
  }

  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) {
    throw UnsupportedError(
      'RandomAccessFile not supported. Use openRead/openWrite.',
    );
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) async* {
    final stream = await fileSystem.driver.downloadRange(
      remotePath,
      start: start,
      end: end,
    );
    yield* stream;
  }

  @override
  IOSink openWrite({FileMode mode = FileMode.write, Encoding encoding = utf8}) {
    final controller = StreamController<List<int>>();
    final sink = IOSink(controller.sink, encoding: encoding);

    controller.stream
        .fold<List<int>>(
          <int>[],
          (previous, element) => previous..addAll(element),
        )
        .then((bytes) async {
          await fileSystem.driver.upload(
            remotePath,
            Stream<List<int>>.value(bytes),
          );
        })
        .catchError((error) {
          throw FileSystemException('Failed to write file', path, error);
        });

    return sink;
  }

  @override
  Future<Uint8List> readAsBytes() async {
    final stream = await fileSystem.driver.download(remotePath);
    final chunks = await stream.toList();
    final totalLength = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final buffer = Uint8List(totalLength);
    var offset = 0;
    for (final chunk in chunks) {
      buffer.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return buffer;
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
    await fileSystem.driver.upload(remotePath, Stream<List<int>>.value(bytes));
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
}
