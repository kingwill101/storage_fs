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
    final port = useSSL
        ? 443
        : (endpoint.contains(':') ? int.parse(endpoint.split(':')[1]) : 9000);

    final minio = Minio(
      endPoint: endpoint,
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
