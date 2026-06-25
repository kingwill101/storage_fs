import 'package:file_cloud/file_cloud.dart';
import 'package:file_cloud/drivers.dart';

import '../contracts/disk.dart';
import '../contracts/filesystem.dart';
import '../config/disk_config.dart';
import 'cloud_adapter.dart';

/// Typed configuration for an S3-compatible cloud storage disk.
class S3Disk extends Disk {
  @override
  final String name;

  final String endpoint;

  final String bucket;

  final String? accessKey;

  final String? secretKey;

  final String? sessionToken;

  final String? region;

  final bool useSSL;

  @override
  final String? root;

  @override
  final bool throwExceptions;

  @override
  final bool readOnly;

  final String? url;

  final bool autoCreateBucket;

  final bool enforcePathStyle;

  const S3Disk({
    required this.name,
    required this.endpoint,
    required this.bucket,
    this.accessKey,
    this.secretKey,
    this.sessionToken,
    this.region,
    this.useSSL = true,
    this.root,
    this.throwExceptions = false,
    this.readOnly = false,
    this.url,
    this.autoCreateBucket = true,
    this.enforcePathStyle = false,
  });

  @override
  Filesystem build() {
    final endpointParts = endpoint.split(':');
    final host = endpointParts[0];
    final port = endpointParts.length > 1
        ? int.parse(endpointParts[1])
        : (useSSL ? 443 : 9000);

    final minio = Minio(
      endPoint: host,
      port: port,
      accessKey: accessKey ?? '',
      secretKey: secretKey ?? '',
      useSSL: useSSL,
      sessionToken: sessionToken,
      region: region ?? 'us-east-1',
    );

    final driver = MinioCloudDriver(
      client: minio,
      bucket: bucket,
      rootPrefix: root,
      baseUrl: url != null ? Uri.tryParse(url!) : null,
      enforcePathStyle: enforcePathStyle,
      autoCreateBucket: autoCreateBucket,
    );

    final cloudFs = CloudFileSystem(driver: driver);

    return CloudAdapter(
      fileSystem: cloudFs,
      config: DiskConfig(
        driver: 's3',
        root: root,
        url: url,
        throw_: throwExceptions,
        readOnly: readOnly,
        options: {
          'endpoint': endpoint,
          'key': accessKey ?? '',
          'secret': secretKey ?? '',
          'bucket': bucket,
          'region': region ?? 'us-east-1',
          'use_ssl': useSSL,
        },
      ),
      baseUrl: url != null ? Uri.tryParse(url!) : null,
    );
  }
}
