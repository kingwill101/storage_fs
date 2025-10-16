import 'dart:async';
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:file_cloud/src/cloud_driver.dart';
import 'package:minio/minio.dart';
export 'package:minio/minio.dart';


/// Cloud storage driver implementation for MinIO and S3-compatible services.
///
/// This driver provides access to object storage services like MinIO, AWS S3,
/// DigitalOcean Spaces, and Cloudflare R2 using the MinIO Dart client.
class MinioCloudDriver implements CloudStorageDriver {
  MinioCloudDriver({
    required this.client,
    required this.bucket,
    String? rootPrefix,
    this.baseUrl,
    this.enforcePathStyle = false,
    this.autoCreateBucket = false,
  }) : _rootPrefix = _sanitizePrefix(rootPrefix);

  final Minio client;
  final String bucket;
  final Uri? baseUrl;
  final bool enforcePathStyle;
  final bool autoCreateBucket;

  final String _rootPrefix;

  static String _sanitizePrefix(String? prefix) {
    if (prefix == null || prefix.isEmpty) {
      return '';
    }
    return prefix.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/+$'), '');
  }

  String _fullKey(String path) {
    final cleanPath = path.replaceAll(RegExp(r'^/+'), '');
    if (_rootPrefix.isEmpty) {
      return cleanPath;
    }
    if (cleanPath.isEmpty) {
      return _rootPrefix;
    }
    return '$_rootPrefix/$cleanPath';
  }

  String _relativePath(String key) {
    if (_rootPrefix.isEmpty) {
      return key;
    }
    final prefixWithSlash = '$_rootPrefix/';
    if (key == _rootPrefix) {
      return '';
    }
    if (key.startsWith(prefixWithSlash)) {
      return key.substring(prefixWithSlash.length);
    }
    return key;
  }

  @override
  String get rootPrefix => _rootPrefix;

  @override
  Future<void> ensureReady() async {
    if (!autoCreateBucket) {
      return;
    }

    final exists = await client.bucketExists(bucket);
    if (!exists) {
      await client.makeBucket(bucket);
    }
  }

  @override
  Future<CloudStorageStat?> stat(String path) async {
    final key = _fullKey(path);

    try {
      final stream = client.listObjects(bucket, prefix: key, recursive: false);
      await for (final result in stream) {
        for (final obj in result.objects) {
          final objectKey = obj.key ?? '';
          if (objectKey == key) {
            return CloudStorageStat(
              type: FileSystemEntityType.file,
              size: obj.size ?? 0,
              modified: obj.lastModified,
            );
          }
        }
      }
    } catch (_) {
      // Ignore failures and try directory detection below.
    }

    final dirPrefix = key.isEmpty ? '' : (key.endsWith('/') ? key : '$key/');
    try {
      final stream = client.listObjects(
        bucket,
        prefix: dirPrefix,
        recursive: false,
      );
      await for (final result in stream) {
        for (final obj in result.objects) {
          final objectKey = obj.key ?? '';
          if (objectKey != dirPrefix && objectKey.startsWith(dirPrefix)) {
            return CloudStorageStat(
              type: FileSystemEntityType.directory,
              size: 0,
            );
          }
        }
      }
    } catch (_) {
      // Ignore failures.
    }

    return null;
  }

  @override
  Stream<CloudStorageItem> list(
    String prefix, {
    bool recursive = false,
  }) async* {
    final keyPrefix = _fullKey(prefix);
    final relativePrefix = keyPrefix.isEmpty ? '' : _relativePath(keyPrefix);
    final stream = keyPrefix.isEmpty
        ? client.listObjects(bucket, recursive: recursive)
        : client.listObjects(bucket, prefix: keyPrefix, recursive: recursive);

    await for (final result in stream) {
      for (final obj in result.objects) {
        final key = obj.key;
        if (key == null) {
          continue;
        }

        final relative = _relativePath(key);
        if (relative.isEmpty) {
          continue;
        }

        final trimmed = relativePrefix.isEmpty
            ? relative
            : relative.replaceFirst(RegExp('^$relativePrefix'), '');
        final normalized = trimmed.replaceFirst(RegExp('^/+'), '');

        if (normalized.isEmpty) {
          continue;
        }

        final isDirectory = key.endsWith('/');
        yield CloudStorageItem(
          path: normalized,
          isDirectory: isDirectory,
          size: obj.size,
          modified: obj.lastModified,
        );
      }
    }
  }

  @override
  Future<void> upload(
    String path,
    Stream<List<int>> data, {
    int? length,
    Map<String, String>? metadata,
  }) async {
    final key = _fullKey(path);
    await client.putObject(
      bucket,
      key,
      data.map((chunk) => Uint8List.fromList(chunk)),
      size: length,
      metadata: metadata,
    );
  }

  @override
  Future<Stream<List<int>>> download(String path) async {
    final key = _fullKey(path);
    final stream = await client.getObject(bucket, key);
    return stream.map((chunk) => Uint8List.fromList(chunk).toList());
  }

  @override
  Future<Stream<List<int>>> downloadRange(
    String path, {
    int? start,
    int? end,
  }) async {
    final key = _fullKey(path);
    if (start == null) {
      return download(path);
    }

    final length = end != null ? end - start : null;
    final stream = await client.getPartialObject(bucket, key, start, length);
    return stream.map((chunk) => Uint8List.fromList(chunk).toList());
  }

  @override
  Future<void> delete(String path) async {
    final key = _fullKey(path);
    await client.removeObject(bucket, key);
  }

  @override
  Future<void> deleteMany(Iterable<String> paths) async {
    for (final path in paths) {
      await delete(path);
    }
  }

  @override
  Future<void> copy(String from, String to) async {
    final sourceKey = _fullKey(from);
    final destinationKey = _fullKey(to);
    await client.copyObject(bucket, destinationKey, '$bucket/$sourceKey');
  }

  @override
  Uri? publicUrl(String path) {
    final key = _fullKey(path);
    if (baseUrl != null) {
      final base = baseUrl.toString().replaceAll(RegExp(r'/+$'), '');
      final suffix = key.isEmpty ? '' : '/$key';
      return Uri.parse('$base$suffix');
    }

    final scheme = client.useSSL ? 'https' : 'http';
    final endpoint = client.endPoint;
    final port = client.port;
    final authorityPort = (port != 80 && port != 443) ? ':$port' : '';

    final host = enforcePathStyle ? endpoint : '$bucket.$endpoint';
    final pathSegment = enforcePathStyle ? '/$bucket/$key' : '/$key';

    return Uri.parse('$scheme://$host$authorityPort$pathSegment');
  }

  @override
  bool get supportsTemporaryUrls => true;

  @override
  Future<String?> presignDownload(
    String path,
    Duration expires, {
    Map<String, dynamic>? options,
  }) async {
    final key = _fullKey(path);
    final expiresInSeconds = expires.inSeconds;
    return client.presignedGetObject(bucket, key, expires: expiresInSeconds);
  }

  @override
  Future<CloudPresignedUpload?> presignUpload(
    String path,
    Duration expires, {
    Map<String, dynamic>? options,
  }) async {
    final key = _fullKey(path);
    final expiresInSeconds = expires.inSeconds;
    final url = await client.presignedPutObject(
      bucket,
      key,
      expires: expiresInSeconds,
    );

    return CloudPresignedUpload(url: url, headers: const {});
  }
}
