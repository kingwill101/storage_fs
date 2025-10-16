import 'dart:io';

/// Minimal environment-based loader for MinIO/S3-compatible configuration.
/// This intentionally avoids external packages and fancy features.
/// It just reads a few well-known environment variables and provides a
/// simple way to initialize the Storage package in tests.
///
/// Supported environment variables (with defaults):
/// - MINIO_ENDPOINT   (default: "localhost:9000")
/// - MINIO_ACCESS_KEY (default: "minioadmin")
/// - MINIO_SECRET_KEY (default: "minioadmin")
/// - MINIO_BUCKET     (default: "test-bucket")
/// - MINIO_REGION     (default: "us-east-1")
/// - MINIO_USE_SSL    (default: "false", accepts: true/1/yes/on)
class MinioConfig {
  final String endpoint;
  final String accessKey;
  final String secretKey;
  final String bucket;
  final String region;
  final bool useSsl;

  const MinioConfig({
    required this.endpoint,
    required this.accessKey,
    required this.secretKey,
    required this.bucket,
    this.region = 'us-east-1',
    this.useSsl = false,
  });

  /// Load configuration from environment variables with sensible defaults.
  factory MinioConfig.fromEnvironment() {
    String env(String key, String fallback) =>
        (Platform.environment[key] ?? '').trim().isNotEmpty
        ? Platform.environment[key]!.trim()
        : fallback;

    bool boolEnv(String key, bool fallback) {
      final raw = (Platform.environment[key] ?? '').trim().toLowerCase();
      if (raw.isEmpty) return fallback;
      return raw == 'true' || raw == '1' || raw == 'yes' || raw == 'on';
    }

    return MinioConfig(
      endpoint: env('MINIO_ENDPOINT', 'localhost:9000'),
      accessKey: env('MINIO_ACCESS_KEY', 'minioadmin'),
      secretKey: env('MINIO_SECRET_KEY', 'minioadmin'),
      bucket: env('MINIO_BUCKET', 'test-bucket'),
      region: env('MINIO_REGION', 'us-east-1'),
      useSsl: boolEnv('MINIO_USE_SSL', false),
    );
  }

  /// Convert to a minimal disk config map understood by the Storage package.
  Map<String, dynamic> toStorageConfig() {
    return {
      'driver': 's3',
      'options': {
        'endpoint': endpoint,
        'key': accessKey,
        'secret': secretKey,
        'bucket': bucket,
        'region': region,
        'use_ssl': useSsl,
      },
    };
  }

  /// Convenience method to produce the full initialization map for Storage.
  Map<String, dynamic> toStorageInitConfig({
    String diskName = 's3',
    bool setAsDefault = true,
    bool setAsCloud = true,
  }) {
    return {
      if (setAsDefault) 'default': diskName,
      if (setAsCloud) 'cloud': diskName,
      'disks': {diskName: toStorageConfig()},
    };
  }

  /// Print a simple, masked summary to help with debugging CI runs.
  void printInfo() {
    print('MinIO/S3 Config:');
    print('  Endpoint:   $endpoint');
    print('  AccessKey:  $accessKey');
    print('  SecretKey:  ${_mask(secretKey)}');
    print('  Bucket:     $bucket');
    print('  Region:     $region');
    print('  Use SSL:    $useSsl');
  }

  @override
  String toString() {
    return 'MinioConfig('
        'endpoint: $endpoint, '
        'accessKey: $accessKey, '
        'secretKey: ${_mask(secretKey)}, '
        'bucket: $bucket, '
        'region: $region, '
        'useSsl: $useSsl'
        ')';
  }

  String _mask(String value) {
    if (value.length <= 8) return '***';
    return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
  }
}
