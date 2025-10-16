import 'dart:io';
import 'package:test/test.dart';
import 'package:file_cloud/file_cloud.dart';
import 'package:file_cloud/drivers.dart';

import 'minio_config.dart';

/// Direct CloudFileSystem tests using R2
void main() {
  final enableCloud = () {
    final v = Platform.environment['ENABLE_CLOUD_TESTS']?.toLowerCase() ?? '';
    return v == '1' || v == 'true' || v == 'yes' || v == 'on';
  }();
  group(
    'CloudFileSystem Direct Tests',
    () {
      late CloudFileSystem fs;
      final testPrefix = 'direct-test-${DateTime.now().millisecondsSinceEpoch}';

      setUpAll(() async {
        final env = MinioConfig.fromEnvironment();
        final minio = Minio(
          endPoint: env.endpoint,
          port: env.useSsl
              ? 443
              : (env.endpoint.contains(':')
                    ? int.parse(env.endpoint.split(':')[1])
                    : 9000),
          accessKey: env.accessKey,
          secretKey: env.secretKey,
          useSSL: env.useSsl,
        );
        final driver = MinioCloudDriver(
          client: minio,
          bucket: env.bucket,
          autoCreateBucket: true,
        );
        fs = CloudFileSystem(driver: driver);
        await fs.driver.ensureReady();
      });

      tearDownAll(() async {
        // Clean up test files
        try {
          final dir = fs.directory(testPrefix);
          await dir.delete(recursive: true);
        } catch (e) {
          print('Cleanup error: $e');
        }
      });

      test('can write and read a file', () async {
        final file = fs.file('$testPrefix/test-file.txt');
        final content = 'Hello from Cloudflare R2!';

        await file.writeAsString(content);
        final retrieved = await file.readAsString();

        expect(retrieved, equals(content));
        await file.delete();
      });

      test('file exists check works', () async {
        final file = fs.file('$testPrefix/exists-test.txt');

        expect(await file.exists(), isFalse);

        await file.writeAsString('test content');
        expect(await file.exists(), isTrue);

        await file.delete();
        expect(await file.exists(), isFalse);
      });

      test('can get file size', () async {
        final file = fs.file('$testPrefix/size-test.txt');
        final content = 'Hello World!';

        await file.writeAsString(content);
        final size = await file.length();

        expect(size, equals(content.length));
        await file.delete();
      });

      test('can copy a file', () async {
        final source = fs.file('$testPrefix/source.txt');
        final dest = fs.file('$testPrefix/dest.txt');

        await source.writeAsString('content to copy');
        await source.copy(dest.path);

        expect(await dest.exists(), isTrue);
        expect(await dest.readAsString(), equals('content to copy'));

        await source.delete();
        await dest.delete();
      });

      test('can list files in directory', () async {
        final dir = fs.directory('$testPrefix/list-test');

        // Create some files
        await fs.file('${dir.path}/file1.txt').writeAsString('content1');
        await fs.file('${dir.path}/file2.txt').writeAsString('content2');
        await fs.file('${dir.path}/file3.txt').writeAsString('content3');

        // List them
        final files = await dir.list().toList();
        expect(files.length, greaterThanOrEqualTo(3));

        // Clean up
        await dir.delete(recursive: true);
      });

      test('can handle binary data', () async {
        final file = fs.file('$testPrefix/binary-test.bin');
        final data = List.generate(256, (i) => i);

        await file.writeAsBytes(data);
        final retrieved = await file.readAsBytes();

        expect(retrieved, equals(data));
        await file.delete();
      });

      test('can create and delete directories', () async {
        final dir = fs.directory('$testPrefix/new-directory');

        await dir.create();
        expect(await dir.exists(), isTrue);

        await dir.delete();
      });

      test('works with nested paths', () async {
        final file = fs.file('$testPrefix/level1/level2/level3/deep.txt');

        await file.writeAsString('deep content');
        expect(await file.exists(), isTrue);
        expect(await file.readAsString(), equals('deep content'));

        // Clean up the whole tree
        await fs.directory('$testPrefix/level1').delete(recursive: true);
      });

      test('multiple concurrent operations', () async {
        final files = List.generate(
          10,
          (i) => fs.file('$testPrefix/concurrent/file$i.txt'),
        );

        // Write concurrently
        await Future.wait(
          files.map((f) => f.writeAsString('Content ${files.indexOf(f)}')),
        );

        // Verify all exist
        for (final file in files) {
          expect(await file.exists(), isTrue);
        }

        // Clean up
        await fs.directory('$testPrefix/concurrent').delete(recursive: true);
      });

      test('direct CloudFileSystem creation works', () async {
        final endpoint =
            Platform.environment['MINIO_ENDPOINT'] ?? 'localhost:9000';
        final accessKey =
            Platform.environment['MINIO_ACCESS_KEY'] ?? 'minioadmin';
        final secretKey =
            Platform.environment['MINIO_SECRET_KEY'] ?? 'minioadmin';
        final bucket = Platform.environment['MINIO_BUCKET'] ?? 'test-bucket';
        final useSsl =
            (Platform.environment['MINIO_USE_SSL'] ?? 'false').toLowerCase() ==
            'true';

        final minio = Minio(
          endPoint: endpoint,
          port: useSsl
              ? 443
              : (endpoint.contains(':')
                    ? int.parse(endpoint.split(':')[1])
                    : 9000),
          accessKey: accessKey,
          secretKey: secretKey,
          useSSL: useSsl,
        );
        final driver = MinioCloudDriver(
          client: minio,
          bucket: bucket,
          autoCreateBucket: true,
        );
        final directFs = CloudFileSystem(driver: driver);
        await directFs.driver.ensureReady();

        final file = directFs.file('$testPrefix/direct-test.txt');

        await file.writeAsString('Directly created FS');
        expect(await file.exists(), isTrue);

        await file.delete();
      });
    },
    skip: enableCloud
        ? false
        : 'Set ENABLE_CLOUD_TESTS=1 to run cloud integration tests',
  );
}
