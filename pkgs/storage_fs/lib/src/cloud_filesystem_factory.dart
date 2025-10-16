import 'package:file_cloud/file_cloud.dart';
import 'package:file_cloud/drivers.dart';

/// Factory for creating cloud filesystem instances.
class CloudFileSystemFactory {
  /// Create a CloudFileSystem for MinIO (self-hosted S3-compatible).
  static CloudFileSystem minio({
    required String endpoint,
    required String accessKey,
    required String secretKey,
    required String bucket,
    bool useSSL = false,
    String region = 'us-east-1',
  }) {
    // Parse endpoint and port
    final endpointParts = endpoint.split(':');
    final host = endpointParts[0];
    final port = endpointParts.length > 1
        ? int.parse(endpointParts[1])
        : (useSSL ? 443 : 9000);

    final minio = Minio(
      endPoint: host,
      port: port,
      accessKey: accessKey,
      secretKey: secretKey,
      useSSL: useSSL,
    );

    final driver = MinioCloudDriver(
      client: minio,
      bucket: bucket,
      autoCreateBucket: true,
    );

    return CloudFileSystem(driver: driver);
  }
}
