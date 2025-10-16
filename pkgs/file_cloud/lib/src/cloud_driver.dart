import 'dart:async';

import 'package:file/file.dart';

/// Metadata returned when querying a remote object.
class CloudStorageStat {
  CloudStorageStat({required this.type, this.size = 0, this.modified});

  final FileSystemEntityType type;
  final int size;
  final DateTime? modified;
}

/// Represents an entry returned when listing remote storage objects.
class CloudStorageItem {
  CloudStorageItem({
    required this.path,
    required this.isDirectory,
    this.size,
    this.modified,
  });

  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? modified;
}

/// Represents a pre-signed upload target.
class CloudPresignedUpload {
  CloudPresignedUpload({
    required this.url,
    this.headers = const {},
    this.fields = const {},
  });

  final String url;
  final Map<String, String> headers;
  final Map<String, String> fields;
}

/// Driver abstraction used by the cloud filesystem backend.
///
/// Implementations should translate calls to the concrete provider
/// (MinIO, S3, Dropbox, etc.) without leaking provider-specific APIs to the
/// filesystem / adapter layers.
abstract class CloudStorageDriver {
  /// Optional prefix applied to all remote paths (for scoped disks).
  String get rootPrefix;

  /// Return `true` once the driver is ready to service requests.
  Future<void> ensureReady();

  /// Retrieve metadata for a remote path.
  ///
  /// Returns `null` when the object does not exist.
  Future<CloudStorageStat?> stat(String path);

  /// List remote entries beneath a prefix.
  Stream<CloudStorageItem> list(String prefix, {bool recursive = false});

  /// Upload new content to a remote path.
  Future<void> upload(
    String path,
    Stream<List<int>> data, {
    int? length,
    Map<String, String>? metadata,
  });

  /// Download the entire object as a stream.
  Future<Stream<List<int>>> download(String path);

  /// Download a byte range from the object.
  Future<Stream<List<int>>> downloadRange(String path, {int? start, int? end});

  /// Remove the object at [path].
  Future<void> delete(String path);

  /// Remove many objects in a single operation when supported.
  Future<void> deleteMany(Iterable<String> paths);

  /// Copy an object from [from] to [to].
  Future<void> copy(String from, String to);

  /// Generate a public URL if the provider supports it.
  ///
  /// Returns `null` when public URLs are not available.
  Uri? publicUrl(String path);

  /// Whether this driver supports generating temporary URLs.
  bool get supportsTemporaryUrls;

  /// Generate a temporary download URL or return `null` when unsupported.
  Future<String?> presignDownload(
    String path,
    Duration expires, {
    Map<String, dynamic>? options,
  });

  /// Generate a temporary upload URL or return `null` when unsupported.
  Future<CloudPresignedUpload?> presignUpload(
    String path,
    Duration expires, {
    Map<String, dynamic>? options,
  });
}
