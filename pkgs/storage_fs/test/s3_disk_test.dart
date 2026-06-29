import 'package:storage_fs/storage_fs.dart';
import 'package:test/test.dart';

void main() {
  group('S3Disk endpoint parsing', () {
    test('parses bare host:port endpoint', () {
      final disk = S3Disk(
        name: 's3',
        endpoint: '127.0.0.1:9000',
        bucket: 'bucket',
        useSSL: false,
      );

      final config = disk.toDiskConfig();

      expect(config.s3Endpoint, equals('127.0.0.1:9000'));
      expect(disk.build(), isA<CloudAdapter>());
    });

    test('parses full URL endpoint without crashing', () {
      final disk = S3Disk(
        name: 's3',
        endpoint: 'https://minio.example.com:9000',
        bucket: 'bucket',
      );

      expect(
        () => disk.build(),
        returnsNormally,
        reason: 'URL-style endpoints should not throw FormatException',
      );
    });

    test('toDiskConfig preserves backend options', () {
      final disk = S3Disk(
        name: 'cloud',
        endpoint: 'https://minio.example.com:9000',
        bucket: 'my-bucket',
        accessKey: 'key',
        secretKey: 'secret',
        region: 'eu-west-1',
        readOnly: true,
      );

      final config = disk.toDiskConfig();

      expect(config.driver, equals('s3'));
      expect(config.readOnly, isTrue);
      expect(config.s3Endpoint, equals('https://minio.example.com:9000'));
      expect(config.s3AccessKey, equals('key'));
      expect(config.s3SecretKey, equals('secret'));
      expect(config.s3Bucket, equals('my-bucket'));
      expect(config.s3Region, equals('eu-west-1'));
    });
  });
}
