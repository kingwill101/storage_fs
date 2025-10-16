import 'package:meta/meta.dart';

/// Configuration for a filesystem disk.
@immutable
class DiskConfig {
  /// The driver type (e.g., 'local', 's3', 'gcs')
  final String driver;

  /// The root path for the disk
  final String? root;

  /// The public URL for the disk
  final String? url;

  /// Default visibility for files
  final String? visibility;

  /// Whether to throw exceptions on errors
  final bool throw_;

  /// Whether to report exceptions
  final bool report;

  /// Directory separator character
  final String directorySeparator;

  /// Path prefix for scoped disks
  final String? prefix;

  /// Whether the disk is read-only
  final bool readOnly;

  /// Additional driver-specific options
  final Map<String, dynamic> options;

  /// Creates a new disk configuration.
  ///
  /// The [driver] specifies the storage backend type (e.g., 'local', 's3').
  /// The [root] is the base path for local disks.
  /// The [url] is the public URL base for cloud disks.
  /// The [visibility] sets the default file visibility ('public' or 'private').
  /// The [throw_] determines whether to throw exceptions on errors.
  /// The [report] enables error reporting.
  /// The [directorySeparator] sets the path separator (default: '/').
  /// The [prefix] sets a path prefix for scoped disks.
  /// The [readOnly] makes the disk read-only when true.
  /// The [options] contains driver-specific configuration.
  const DiskConfig({
    required this.driver,
    this.root,
    this.url,
    this.visibility,
    this.throw_ = false,
    this.report = false,
    this.directorySeparator = '/',
    this.prefix,
    this.readOnly = false,
    this.options = const {},
  });

  /// Create a DiskConfig from a map
  factory DiskConfig.fromMap(Map<String, dynamic> map) {
    return DiskConfig(
      driver: map['driver'] as String? ?? 'local',
      root: map['root'] as String?,
      url: map['url'] as String?,
      visibility: map['visibility'] as String?,
      throw_: map['throw'] as bool? ?? false,
      report: map['report'] as bool? ?? false,
      directorySeparator: map['directory_separator'] as String? ?? '/',
      prefix: map['prefix'] as String?,
      readOnly: map['read-only'] as bool? ?? map['readOnly'] as bool? ?? false,
      options: Map<String, dynamic>.from(map['options'] as Map? ?? {}),
    );
  }

  /// Convert to a map
  Map<String, dynamic> toMap() {
    return {
      'driver': driver,
      if (root != null) 'root': root,
      if (url != null) 'url': url,
      if (visibility != null) 'visibility': visibility,
      'throw': throw_,
      'report': report,
      'directory_separator': directorySeparator,
      if (prefix != null) 'prefix': prefix,
      'read-only': readOnly,
      if (options.isNotEmpty) 'options': options,
    };
  }

  // S3-specific configuration helpers

  /// Get S3 endpoint from options
  String? get s3Endpoint => options['endpoint'] as String?;

  /// Get S3 access key from options
  String? get s3AccessKey =>
      options['key'] as String? ?? options['access_key'] as String?;

  /// Get S3 secret key from options
  String? get s3SecretKey =>
      options['secret'] as String? ?? options['secret_key'] as String?;

  /// Get S3 bucket from options
  String? get s3Bucket => options['bucket'] as String?;

  /// Get S3 region from options
  String? get s3Region => options['region'] as String?;

  /// Get S3 use SSL setting
  bool get s3UseSSL =>
      options['use_ssl'] as bool? ?? options['useSSL'] as bool? ?? true;

  /// Get S3 port
  int? get s3Port => options['port'] as int?;

  /// Get S3 session token (for temporary credentials)
  String? get s3SessionToken =>
      options['token'] as String? ?? options['session_token'] as String?;

  /// Check if this is an S3-compatible driver
  bool get isS3 =>
      driver == 's3' ||
      driver == 'minio' ||
      driver == 'spaces' ||
      driver == 'r2';

  /// Create a copy with updated values
  DiskConfig copyWith({
    String? driver,
    String? root,
    String? url,
    String? visibility,
    bool? throw_,
    bool? report,
    String? directorySeparator,
    String? prefix,
    bool? readOnly,
    Map<String, dynamic>? options,
  }) {
    return DiskConfig(
      driver: driver ?? this.driver,
      root: root ?? this.root,
      url: url ?? this.url,
      visibility: visibility ?? this.visibility,
      throw_: throw_ ?? this.throw_,
      report: report ?? this.report,
      directorySeparator: directorySeparator ?? this.directorySeparator,
      prefix: prefix ?? this.prefix,
      readOnly: readOnly ?? this.readOnly,
      options: options ?? this.options,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiskConfig &&
          runtimeType == other.runtimeType &&
          driver == other.driver &&
          root == other.root &&
          url == other.url &&
          visibility == other.visibility &&
          throw_ == other.throw_ &&
          report == other.report &&
          directorySeparator == other.directorySeparator &&
          prefix == other.prefix &&
          readOnly == other.readOnly;

  @override
  int get hashCode =>
      driver.hashCode ^
      root.hashCode ^
      url.hashCode ^
      visibility.hashCode ^
      throw_.hashCode ^
      report.hashCode ^
      directorySeparator.hashCode ^
      prefix.hashCode ^
      readOnly.hashCode;

  @override
  String toString() => 'DiskConfig(driver: $driver, root: $root)';
}
