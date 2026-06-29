import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart' show AccumulatorSink;
import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:storage_fs/storage_fs.dart' as sf;
import 'package:storage_fs/storage_fs.dart'
    show
        FilesystemException,
        UnableToReadFileException,
        UnableToWriteFileException,
        UnableToDeleteFileException,
        UnableToCopyFileException,
        UnableToMoveFileException,
        UnableToCreateDirectoryException,
        UnableToDeleteDirectoryException,
        UnableToRetrieveMetadataException,
        UnableToProvideChecksumException;

import 'sftp_config.dart';
import 'sftp_fs.dart';
import 'sftp_fs_client.dart';

class SftpFilesystemAdapter implements sf.Filesystem {
  final SftpConfig config;

  SSHClient? _sshClient;
  SftpFs? _fs;
  String? _diskName;
  bool _connected = false;

  SftpFilesystemAdapter(this.config);

  SftpFilesystemAdapter.fromClient(
    SftpClient sftp, {
    SftpConfig Function()? config,
  }) : _fs = SftpFsClient(sftp),
       _connected = true,
       config =
           config?.call() ??
           const SftpConfig(host: '', username: '', root: '/');

  SftpFilesystemAdapter.fromSftpFs(SftpFs fs, {SftpConfig Function()? config})
    : _fs = fs,
      _connected = true,
      config =
          config?.call() ?? const SftpConfig(host: '', username: '', root: '/');

  Future<SftpFs> _ensureConnected() async {
    if (_connected && _fs != null) return _fs!;

    final socket = await SSHSocket.connect(
      config.host,
      config.port,
      timeout: config.connectTimeout,
    );

    _sshClient = SSHClient(
      socket,
      username: config.username,
      onPasswordRequest: config.password != null
          ? () => config.password!
          : null,
      identities:
          config.privateKeyPems
              ?.expand(
                (pem) => SSHKeyPair.fromPem(pem, config.privateKeyPassphrase),
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

  Future<void> disconnect() async {
    _fs?.close();
    _sshClient?.close();
    _fs = null;
    _sshClient = null;
    _connected = false;
  }

  String _getFullPath(String path) {
    final root = config.root;
    if (root == null || root.isEmpty) return path;
    if (path.isEmpty) return root;
    final normalized = path.replaceAll(RegExp(r'^/+'), '');
    final sep = root.endsWith('/') ? '' : '/';
    return '$root$sep$normalized';
  }

  String _relativePath(String fullPath) {
    final root = config.root;
    if (root == null || root.isEmpty) return fullPath;
    if (fullPath == root) return '';
    final prefix = root.endsWith('/') ? root : '$root/';
    if (fullPath.startsWith(prefix)) {
      return fullPath.substring(prefix.length);
    }
    return fullPath;
  }

  bool _throwsExceptions() => config.throw_;

  bool _ensureWritable() {
    if (!config.readOnly) return true;
    if (_throwsExceptions()) {
      throw FilesystemException('Disk is read-only.');
    }
    return false;
  }

  String? get name => _diskName;

  SftpFilesystemAdapter diskName(String name) {
    _diskName = name;
    return this;
  }

  Future<void> _ensureParentDir(String path) async {
    final parent = p.dirname(path);
    if (parent == path || parent == '.') return;
    try {
      final fs = await _ensureConnected();
      await fs.stat(parent);
    } catch (_) {
      await _ensureParentDir(parent);
      try {
        final fs = await _ensureConnected();
        await fs.mkdir(parent);
      } catch (_) {}
    }
  }

  Future<void> _deleteTree(String path) async {
    final fs = await _ensureConnected();
    final entries = await fs.listdir(path);
    for (final entry in entries) {
      if (entry.filename == '.' || entry.filename == '..') continue;
      final childPath = '$path/${entry.filename}';
      final isDir = entry.attr.isDirectory;
      if (isDir) {
        await _deleteTree(childPath);
      } else {
        await fs.remove(childPath);
      }
    }
    await fs.rmdir(path);
  }

  Future<List<String>> _collectFiles(
    String path,
    bool recursive, {
    required bool collectFiles,
  }) async {
    final fs = await _ensureConnected();
    final result = <String>[];
    final entries = await fs.listdir(path);
    for (final entry in entries) {
      if (entry.filename == '.' || entry.filename == '..') continue;
      final childPath = p.join(path, entry.filename);
      final isDir = entry.attr.isDirectory;
      if (isDir && collectFiles) continue;
      if (!isDir && !collectFiles) continue;
      if (isDir && recursive) {
        result.addAll(
          await _collectFiles(childPath, true, collectFiles: collectFiles),
        );
      }
      if (!isDir || !collectFiles) {
        final relative = _relativePath(childPath);
        if (relative.isNotEmpty) {
          result.add(relative);
        }
      }
    }
    result.sort();
    return result;
  }

  @override
  Future<bool> exists(String path) async {
    try {
      final fs = await _ensureConnected();
      await fs.stat(_getFullPath(path));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> missing(String path) async => !(await exists(path));

  @override
  Future<String?> get(String path) async {
    try {
      final fs = await _ensureConnected();
      final file = await fs.open(_getFullPath(path));
      final bytes = await file.readBytes();
      await file.close();
      return utf8.decode(bytes);
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToReadFileException(path, cause: e);
      }
      return null;
    }
  }

  @override
  Stream<List<int>>? readStream(String path) {
    late Stream<List<int>> stream;
    try {
      stream = _readStream(path).asStream().asyncExpand((s) => s);
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToReadFileException(path, cause: e);
      }
      return null;
    }

    return stream.handleError((Object e, StackTrace stack) {
      if (_throwsExceptions()) {
        Error.throwWithStackTrace(
          UnableToReadFileException(path, cause: e),
          stack,
        );
      }
    });
  }

  Future<Stream<List<int>>> _readStream(String path) async {
    final fs = await _ensureConnected();
    final file = await fs.open(_getFullPath(path));
    return _readChunked(file);
  }

  Stream<List<int>> _readChunked(SftpFsFile file) async* {
    try {
      const chunkSize = 65536;
      int offset = 0;
      while (true) {
        final chunk = await file.readBytes(length: chunkSize, offset: offset);
        if (chunk.isEmpty) break;
        yield chunk.toList();
        offset += chunk.length;
      }
    } finally {
      await file.close();
    }
  }

  @override
  Future<bool> put(
    String path,
    dynamic contents, {
    Map<String, dynamic>? options,
  }) async {
    if (!_ensureWritable()) return false;

    try {
      final fs = await _ensureConnected();
      final fullPath = _getFullPath(path);
      await _ensureParentDir(fullPath);

      final file = await fs.open(
        fullPath,
        mode:
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.write,
      );

      if (contents is String) {
        await file.writeBytes(Uint8List.fromList(utf8.encode(contents)));
      } else if (contents is List<int>) {
        await file.writeBytes(Uint8List.fromList(contents));
      } else if (contents is Stream<List<int>>) {
        await file.write(contents);
      } else {
        await file.close();
        throw ArgumentError(
          'Unsupported content type: ${contents.runtimeType}',
        );
      }

      await file.close();

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
    if (!_ensureWritable()) return false;

    try {
      final fs = await _ensureConnected();
      final fullPath = _getFullPath(path);
      await _ensureParentDir(fullPath);

      final file = await fs.open(
        fullPath,
        mode:
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.write,
      );

      await file.write(resource);
      await file.close();

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
      final fs = await _ensureConnected();
      final attrs = await fs.stat(_getFullPath(path));
      final mode = attrs.mode;
      if (mode != null && mode.otherRead) {
        return sf.Filesystem.visibilityPublic;
      }
      return sf.Filesystem.visibilityPrivate;
    } catch (_) {
      return sf.Filesystem.visibilityPrivate;
    }
  }

  @override
  Future<bool> setVisibility(String path, String visibility) async {
    if (!_ensureWritable()) return false;

    try {
      final fs = await _ensureConnected();
      final fullPath = _getFullPath(path);
      final isPublic = visibility == sf.Filesystem.visibilityPublic;

      await fs.setStat(
        fullPath,
        SftpFileAttrs(
          mode: SftpFileMode(
            userRead: true,
            userWrite: true,
            groupRead: isPublic,
            otherRead: isPublic,
          ),
        ),
      );
      return true;
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToWriteFileException(path, cause: e);
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
    if (await exists(path)) {
      final existing = await get(path) ?? '';
      return put(path, '$data$separator$existing');
    }
    return put(path, data);
  }

  @override
  Future<bool> append(
    String path,
    String data, {
    String separator = '\n',
  }) async {
    if (await exists(path)) {
      final existing = await get(path) ?? '';
      return put(path, '$existing$separator$data');
    }
    return put(path, data);
  }

  @override
  Future<bool> delete(dynamic paths) async {
    if (!_ensureWritable()) return false;

    final pathList = paths is List ? paths : [paths];
    var success = true;

    for (final path in pathList) {
      try {
        final fs = await _ensureConnected();
        await fs.remove(_getFullPath(path as String));
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
    if (!_ensureWritable()) return false;

    try {
      final fs = await _ensureConnected();
      final fullFrom = _getFullPath(from);
      final fullTo = _getFullPath(to);
      await _ensureParentDir(fullTo);

      final sourceFile = await fs.open(fullFrom);
      final bytes = await sourceFile.readBytes();
      await sourceFile.close();

      final destFile = await fs.open(
        fullTo,
        mode:
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.write,
      );
      await destFile.writeBytes(bytes);
      await destFile.close();

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
    if (!_ensureWritable()) return false;

    try {
      final fs = await _ensureConnected();
      final fullFrom = _getFullPath(from);
      final fullTo = _getFullPath(to);
      await _ensureParentDir(fullTo);
      await fs.rename(fullFrom, fullTo);
      return true;
    } catch (e) {
      try {
        if (await copy(from, to)) {
          return await delete(from);
        }
        return false;
      } catch (e2) {
        if (_throwsExceptions()) {
          throw UnableToMoveFileException(from, to, cause: e2);
        }
        return false;
      }
    }
  }

  @override
  Future<int> size(String path) async {
    try {
      final fs = await _ensureConnected();
      final attrs = await fs.stat(_getFullPath(path));
      return attrs.size ?? 0;
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToRetrieveMetadataException(path, cause: e);
      }
      return 0;
    }
  }

  @override
  Future<String?> checksum(String path, {String algorithm = 'md5'}) async {
    try {
      final fs = await _ensureConnected();
      final fullPath = _getFullPath(path);

      try {
        await fs.stat(fullPath);
      } catch (_) {
        return null;
      }

      final hash = _hashForAlgorithm(algorithm);
      final sink = AccumulatorSink<Digest>();
      final hasher = hash.startChunkedConversion(sink);
      final file = await fs.open(fullPath);
      const chunkSize = 65536;
      int offset = 0;

      while (true) {
        final chunk = await file.readBytes(length: chunkSize, offset: offset);
        if (chunk.isEmpty) break;
        hasher.add(chunk.toList());
        offset += chunk.length;
      }

      await file.close();
      hasher.close();

      return sink.events.single.toString();
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToProvideChecksumException(path, cause: e);
      }
      return null;
    }
  }

  @override
  Future<String?> mimeType(String path) async {
    try {
      final fs = await _ensureConnected();
      final fullPath = _getFullPath(path);

      try {
        await fs.stat(fullPath);
      } catch (_) {
        return null;
      }

      final file = await fs.open(fullPath);
      final header = await file.readBytes(length: 256);
      await file.close();

      return lookupMimeType(path, headerBytes: header.toList());
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
      final fs = await _ensureConnected();
      final attrs = await fs.stat(_getFullPath(path));
      if (attrs.modifyTime != null) {
        return DateTime.fromMillisecondsSinceEpoch(attrs.modifyTime! * 1000);
      }
      return DateTime.now();
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
    try {
      final fs = await _ensureConnected();
      final dirPath = _getFullPath(directory ?? '');
      try {
        await fs.stat(dirPath);
      } catch (_) {
        return [];
      }
      return await _collectFiles(dirPath, recursive, collectFiles: true);
    } catch (e) {
      if (_throwsExceptions()) {
        throw FilesystemException(
          'Unable to list files in [$directory].',
          cause: e,
        );
      }
      return [];
    }
  }

  @override
  Future<List<String>> allFiles([String? directory]) async {
    return files(directory, true);
  }

  @override
  Future<List<String>> directories([
    String? directory,
    bool recursive = false,
  ]) async {
    try {
      final fs = await _ensureConnected();
      final dirPath = _getFullPath(directory ?? '');
      try {
        await fs.stat(dirPath);
      } catch (_) {
        return [];
      }
      return await _collectFiles(dirPath, recursive, collectFiles: false);
    } catch (e) {
      if (_throwsExceptions()) {
        throw FilesystemException(
          'Unable to list directories in [$directory].',
          cause: e,
        );
      }
      return [];
    }
  }

  @override
  Future<List<String>> allDirectories([String? directory]) async {
    return directories(directory, true);
  }

  @override
  Future<bool> makeDirectory(String path) async {
    if (!_ensureWritable()) return false;

    try {
      final fs = await _ensureConnected();
      final fullPath = _getFullPath(path);
      await _ensureParentDir(fullPath);
      await fs.mkdir(fullPath);
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
    if (!_ensureWritable()) return false;

    try {
      final fullPath = _getFullPath(directory);
      await _deleteTree(fullPath);
      return true;
    } catch (e) {
      if (_throwsExceptions()) {
        throw UnableToDeleteDirectoryException(directory, cause: e);
      }
      return false;
    }
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
}
