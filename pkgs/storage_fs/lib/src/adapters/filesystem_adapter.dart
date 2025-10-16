import 'dart:convert';
import 'dart:io' as io;
import 'package:convert/convert.dart' show AccumulatorSink;
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';
import '../contracts/filesystem.dart' as contracts;
import '../exceptions/filesystem_exception.dart';
import '../config/disk_config.dart';

/// Base filesystem adapter providing common functionality using the file package.
class FilesystemAdapter implements contracts.Filesystem {
  /// The filesystem instance from the file package
  final FileSystem fileSystem;

  /// The filesystem configuration.
  final DiskConfig config;

  /// The disk name.
  String? _diskName;

  FilesystemAdapter(this.config, {FileSystem? fileSystem})
    : fileSystem = fileSystem ?? const LocalFileSystem();

  /// Create from a map configuration (legacy support)
  factory FilesystemAdapter.fromMap(
    Map<String, dynamic> configMap, {
    FileSystem? fileSystem,
  }) {
    return FilesystemAdapter(
      DiskConfig.fromMap(configMap),
      fileSystem: fileSystem,
    );
  }

  /// Set the disk name.
  FilesystemAdapter diskName(String name) {
    _diskName = name;
    return this;
  }

  /// Get the disk name.
  String? get name => _diskName;

  /// Get the root path
  String get root => config.root ?? '';

  @override
  Future<bool> exists(String path) async {
    final fullPath = _getFullPath(path);
    return await fileSystem.file(fullPath).exists() ||
        await fileSystem.directory(fullPath).exists();
  }

  @override
  Future<bool> missing(String path) async => !(await exists(path));

  /// Determine if a file exists.
  Future<bool> fileExists(String path) async {
    return await fileSystem.file(_getFullPath(path)).exists();
  }

  /// Determine if a file is missing.
  Future<bool> fileMissing(String path) async => !(await fileExists(path));

  /// Determine if a directory exists.
  Future<bool> directoryExists(String path) async {
    return await fileSystem.directory(_getFullPath(path)).exists();
  }

  /// Determine if a directory is missing.
  Future<bool> directoryMissing(String path) async =>
      !(await directoryExists(path));

  /// Get the full path to the file.
  String path(String path) => _getFullPath(path);

  @override
  Future<String?> get(String path) async {
    try {
      return await fileSystem.file(_getFullPath(path)).readAsString();
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToReadFileException(path, cause: e);
      }
      return null;
    }
  }

  /// Get the contents of a file as decoded JSON.
  Future<Map<String, dynamic>?> json(String path) async {
    final content = await get(path);
    if (content == null) return null;

    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (_throwsExceptions()) {
        throw FilesystemException('JSON content at [$path] is not an object.');
      }
      return null;
    } catch (e) {
      if (_throwsExceptions()) {
        throw FilesystemException(
          'Unable to decode JSON from [$path].',
          cause: e,
        );
      }
      return null;
    }
  }

  @override
  Stream<List<int>>? readStream(String path) {
    try {
      return fileSystem.file(_getFullPath(path)).openRead();
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToReadFileException(path, cause: e);
      }
      return null;
    }
  }

  @override
  Future<bool> put(
    String path,
    dynamic contents, {
    Map<String, dynamic>? options,
  }) async {
    try {
      final file = fileSystem.file(_getFullPath(path));

      // Create parent directories if they don't exist
      final parent = file.parent;
      if (!(await parent.exists())) {
        await parent.create(recursive: true);
      }

      if (contents is String) {
        await file.writeAsString(contents);
      } else if (contents is List<int>) {
        await file.writeAsBytes(contents);
      } else if (contents is Stream<List<int>>) {
        return await writeStream(path, contents, options: options);
      } else {
        throw ArgumentError('Unsupported content type');
      }

      if (options != null && options.containsKey('visibility')) {
        await setVisibility(path, options['visibility'] as String);
      }

      return true;
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToWriteFileException(path, cause: e);
      }
      return false;
    }
  }

  @override
  Future<bool> writeStream(
    String path,
    Stream<List<int>> resource, {
    Map<String, dynamic>? options,
  }) async {
    try {
      final file = fileSystem.file(_getFullPath(path));

      // Create parent directories
      if (!(await file.parent.exists())) {
        await file.parent.create(recursive: true);
      }

      final sink = file.openWrite();

      await resource.forEach(sink.add);
      await sink.close();

      return true;
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToWriteFileException(path, cause: e);
      }
      return false;
    }
  }

  @override
  Future<String> getVisibility(String path) async {
    try {
      final stat = await fileSystem.file(_getFullPath(path)).stat();
      final mode = stat.mode;
      final isPublic = (mode & 0x004) != 0;

      return isPublic
          ? contracts.Filesystem.visibilityPublic
          : contracts.Filesystem.visibilityPrivate;
    } catch (e) {
      return contracts.Filesystem.visibilityPrivate;
    }
  }

  @override
  Future<bool> setVisibility(String path, String visibility) async {
    try {
      final fullPath = _getFullPath(path);
      final isPublic = visibility == contracts.Filesystem.visibilityPublic;

      if (io.Platform.isWindows) {
        return true;
      }

      final mode = isPublic ? '644' : '600';
      await io.Process.run('chmod', [mode, fullPath]);

      return true;
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToSetVisibilityException(path, cause: e);
      }
      return false;
    }
  }

  @override
  Future<bool> prepend(
    String path,
    String data, {
    String separator = '\n',
  }) async {
    if (await fileExists(path)) {
      final existing = await get(path) ?? '';
      return await put(path, '$data$separator$existing');
    }
    return await put(path, data);
  }

  @override
  Future<bool> append(
    String path,
    String data, {
    String separator = '\n',
  }) async {
    if (await fileExists(path)) {
      final existing = await get(path) ?? '';
      return await put(path, '$existing$separator$data');
    }
    return await put(path, data);
  }

  @override
  Future<bool> delete(dynamic paths) async {
    final pathList = paths is List ? paths : [paths];
    var success = true;

    for (final path in pathList) {
      try {
        await fileSystem.file(_getFullPath(path as String)).delete();
      } catch (e) {
        if (_throwsExceptions()) {
          throw UnableToDeleteFileException(path, cause: e);
        }
        success = false;
      }
    }

    return success;
  }

  @override
  Future<bool> copy(String from, String to) async {
    try {
      final source = fileSystem.file(_getFullPath(from));
      final dest = fileSystem.file(_getFullPath(to));

      if (!(await dest.parent.exists())) {
        await dest.parent.create(recursive: true);
      }

      await source.copy(dest.path);
      return true;
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToCopyFileException(from, to, cause: e);
      }
      return false;
    }
  }

  @override
  Future<bool> move(String from, String to) async {
    try {
      final source = fileSystem.file(_getFullPath(from));
      final dest = fileSystem.file(_getFullPath(to));

      if (!(await dest.parent.exists())) {
        await dest.parent.create(recursive: true);
      }

      await source.rename(dest.path);
      return true;
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToMoveFileException(from, to, cause: e);
      }
      return false;
    }
  }

  @override
  Future<int> size(String path) async {
    try {
      return await fileSystem.file(_getFullPath(path)).length();
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToRetrieveMetadataException(path, cause: e);
      }
      return 0;
    }
  }

  /// Get the checksum for a file.
  @override
  Future<String?> checksum(String path, {String algorithm = 'md5'}) async {
    try {
      final file = fileSystem.file(_getFullPath(path));
      if (!await file.exists()) {
        return null;
      }

      final hash = _hashForAlgorithm(algorithm);
      final sink = AccumulatorSink<Digest>();
      final hasher = hash.startChunkedConversion(sink);

      await for (final chunk in file.openRead()) {
        hasher.add(chunk);
      }

      hasher.close();

      return sink.events.single.toString();
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToProvideChecksumException(path, cause: e);
      }
      return null;
    }
  }

  /// Get the mime-type of a given file.
  @override
  Future<String?> mimeType(String path) async {
    try {
      final file = fileSystem.file(_getFullPath(path));
      if (!await file.exists()) {
        return null;
      }

      final headerBytes = <int>[];
      final stream = file.openRead(0, 256);
      await for (final chunk in stream) {
        headerBytes.addAll(chunk);
        if (headerBytes.length >= 256) {
          break;
        }
      }

      return lookupMimeType(file.path, headerBytes: headerBytes);
    } catch (e) {
      if (_throwsExceptions()) {
        throw FilesystemException(
          'Unable to determine mime type for [$path].',
          cause: e,
        );
      }
      return null;
    }
  }

  @override
  Future<DateTime> lastModified(String path) async {
    try {
      return await fileSystem.file(_getFullPath(path)).lastModified();
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToRetrieveMetadataException(path, cause: e);
      }
      return DateTime.now();
    }
  }

  @override
  Future<List<String>> files([
    String? directory,
    bool recursive = false,
  ]) async {
    final dir = fileSystem.directory(_getFullPath(directory ?? ''));
    if (!(await dir.exists())) return [];

    final files = <String>[];
    final entities = await dir.list(recursive: recursive).toList();

    for (final entity in entities) {
      if (entity is File) {
        final relativePath = entity.path.substring(root.length);
        files.add(
          relativePath.startsWith('/')
              ? relativePath.substring(1)
              : relativePath,
        );
      }
    }

    files.sort();
    return files;
  }

  @override
  Future<List<String>> allFiles([String? directory]) async {
    return await files(directory, true);
  }

  @override
  Future<List<String>> directories([
    String? directory,
    bool recursive = false,
  ]) async {
    final dir = fileSystem.directory(_getFullPath(directory ?? ''));
    if (!(await dir.exists())) return [];

    final directories = <String>[];
    final entities = await dir.list(recursive: recursive).toList();

    for (final entity in entities) {
      if (entity is Directory) {
        final relativePath = entity.path.substring(root.length);
        directories.add(
          relativePath.startsWith('/')
              ? relativePath.substring(1)
              : relativePath,
        );
      }
    }

    directories.sort();
    return directories;
  }

  @override
  Future<List<String>> allDirectories([String? directory]) async {
    return await directories(directory, true);
  }

  @override
  Future<bool> makeDirectory(String path) async {
    try {
      await fileSystem.directory(_getFullPath(path)).create(recursive: true);
      return true;
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToCreateDirectoryException(path, cause: e);
      }
      return false;
    }
  }

  @override
  Future<bool> deleteDirectory(String directory) async {
    try {
      await fileSystem
          .directory(_getFullPath(directory))
          .delete(recursive: true);
      return true;
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToDeleteDirectoryException(directory, cause: e);
      }
      return false;
    }
  }

  /// Get the URL for the file at the given path.
  String url(String path) {
    if (config.url != null) {
      return _concatPathToUrl(config.url!, path);
    }

    return '/storage/$path';
  }

  /// Concatenate a path to a URL.
  String _concatPathToUrl(String url, String path) {
    return '${url.replaceAll(RegExp(r'/$'), '')}/${path.replaceAll(RegExp(r'^/'), '')}';
  }

  /// Get the full path.
  String _getFullPath(String path) {
    if (root.isEmpty) return path;
    return '$root/$path'.replaceAll('//', '/');
  }

  /// Determine if exceptions should be thrown.
  bool _throwsExceptions() {
    return config.throw_;
  }

  Hash _hashForAlgorithm(String algorithm) {
    switch (algorithm.toLowerCase()) {
      case 'md5':
        return md5;
      case 'sha1':
        return sha1;
      case 'sha256':
        return sha256;
      default:
        throw ArgumentError('Unsupported checksum algorithm [$algorithm].');
    }
  }

  /// Get the configuration.
  DiskConfig getConfig() => config;

  /// Assert that the given file or directory exists.
  Future<FilesystemAdapter> assertExists(
    dynamic path, {
    String? content,
  }) async {
    final paths = path is List ? path : [path];

    for (final p in paths) {
      if (!(await exists(p as String))) {
        throw FilesystemException(
          'Unable to find a file or directory at path [$p].',
        );
      }

      if (content != null) {
        final actual = await get(p);
        if (actual != content) {
          throw FilesystemException(
            'File or directory [$p] was found, but content [$actual] does not match [$content].',
          );
        }
      }
    }

    return this;
  }

  /// Assert that the number of files in path equals the expected count.
  Future<FilesystemAdapter> assertCount(
    String path,
    int count, {
    bool recursive = false,
  }) async {
    final actual = (await files(path, recursive)).length;

    if (actual != count) {
      throw FilesystemException(
        'Expected [$count] files at [$path], but found [$actual].',
      );
    }

    return this;
  }

  /// Assert that the given file or directory does not exist.
  Future<FilesystemAdapter> assertMissing(dynamic path) async {
    final paths = path is List ? path : [path];

    for (final p in paths) {
      if (await exists(p as String)) {
        throw FilesystemException(
          'Found unexpected file or directory at path [$p].',
        );
      }
    }

    return this;
  }

  /// Assert that the given directory is empty.
  Future<FilesystemAdapter> assertDirectoryEmpty(String path) async {
    final filesList = await allFiles(path);
    if (filesList.isNotEmpty) {
      throw FilesystemException('Directory [$path] is not empty.');
    }

    return this;
  }
}
