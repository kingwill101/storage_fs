import 'dart:async';
import 'dart:io';

import 'package:storage_fs/storage_fs.dart';
import 'package:test/test.dart';
import 'helpers/minio_config.dart';

/// Comprehensive cloud storage test with signed URLs and advanced features
void main() {
  final enableCloud = () {
    final v = Platform.environment['ENABLE_CLOUD_TESTS']?.toLowerCase() ?? '';
    return v == '1' || v == 'true' || v == 'yes' || v == 'on';
  }();
  group(
    'Cloud Storage with Signed URLs',
    () {
      late String testPrefix;

      setUpAll(() {
        testPrefix = 'signed-url-test-${DateTime.now().millisecondsSinceEpoch}';

        // Initialize storage with env-based S3 configuration
        final env = MinioConfig.fromEnvironment();
        Storage.initialize(env.toStorageInitConfig());
      });

      tearDownAll(() async {
        // // Clean up test files
        // try {
        //   await Storage.deleteDirectory(testPrefix);
        // } catch (e) {
        //   print('Cleanup error: $e');
        // }
      });

      test('Can write and read files via Storage facade', () async {
        final path = '$testPrefix/facade-test.txt';
        final content = 'Hello from Storage facade!';

        await Storage.put(path, content);
        final retrieved = await Storage.get(path);

        expect(retrieved, equals(content));
        await Storage.delete(path);
      });

      test('File existence checks work', () async {
        final path = '$testPrefix/exists-test.txt';

        expect(await Storage.exists(path), isFalse);

        await Storage.put(path, 'test content');
        expect(await Storage.exists(path), isTrue);

        await Storage.delete(path);
        expect(await Storage.exists(path), isFalse);
      });

      test('Can get file size and last modified', () async {
        final path = '$testPrefix/metadata-test.txt';
        final content = 'Test content for metadata';

        await Storage.put(path, content);

        final size = await Storage.size(path);
        expect(size, equals(content.length));

        final lastMod = await Storage.lastModified(path);
        expect(lastMod.isBefore(DateTime.now()), isTrue);

        await Storage.delete(path);
      });

      test('Can copy and move files', () async {
        final source = '$testPrefix/source.txt';
        final dest1 = '$testPrefix/copy-dest.txt';
        final dest2 = '$testPrefix/move-dest.txt';

        await Storage.put(source, 'content to copy');

        // Test copy
        await Storage.copy(source, dest1);
        expect(await Storage.exists(dest1), isTrue);
        expect(await Storage.get(dest1), equals('content to copy'));

        // Test move
        await Storage.move(source, dest2);
        expect(await Storage.exists(source), isFalse);
        expect(await Storage.exists(dest2), isTrue);

        await Storage.delete([dest1, dest2]);
      });

      test('Can list files and directories', () async {
        final dir = '$testPrefix/list-test';

        // Create some files
        await Storage.put('$dir/file1.txt', 'content1');
        await Storage.put('$dir/file2.txt', 'content2');
        await Storage.put('$dir/subdir/file3.txt', 'content3');

        // List files non-recursively
        final files = await Storage.files(dir);
        expect(files.length, greaterThanOrEqualTo(2));

        // List all files recursively
        final allFiles = await Storage.allFiles(dir);
        expect(allFiles.length, greaterThanOrEqualTo(3));

        await Storage.deleteDirectory(dir);
      });

      test('Can generate URLs', () {
        final path = '$testPrefix/url-test.txt';
        final url = Storage.url(path);

        expect(url, isNotEmpty);
        expect(url, contains(path));
      });

      test('Supports temporary URLs', () {
        expect(Storage.providesTemporaryUrls(), isTrue);
      });

      test('Can generate temporary signed URLs', () async {
        final path = '$testPrefix/signed-url-test.txt';
        await Storage.put(path, 'Content for signed URL test');

        final expiration = DateTime.now().add(Duration(hours: 1));
        final signedUrl = await Storage.getTemporaryUrl(path, expiration);

        expect(signedUrl, isNotEmpty);
        expect(signedUrl, contains(path));
        // Signed URLs should contain query parameters or authentication
        expect(signedUrl.contains('?') || signedUrl.contains('X-Amz'), isTrue);

        print('Generated signed URL: $signedUrl');

        await Storage.delete(path);
      });

      test('Can generate temporary upload URLs', () async {
        final path = '$testPrefix/upload-url-test.txt';
        final expiration = DateTime.now().add(Duration(hours: 1));

        final uploadData = await Storage.getTemporaryUploadUrl(
          path,
          expiration,
        );

        expect(uploadData['url'], isNotEmpty);
        expect(uploadData['url'], contains(path));
        expect(uploadData['headers'], isA<Map<String, String>>());

        print('Generated upload URL: ${uploadData['url']}');
      });

      test('Can append and prepend to files', () async {
        final path = '$testPrefix/append-test.txt';

        await Storage.put(path, 'middle');
        await Storage.prepend(path, 'start');
        await Storage.append(path, 'end');

        final content = await Storage.get(path);
        expect(content, contains('start'));
        expect(content, contains('middle'));
        expect(content, contains('end'));

        await Storage.delete(path);
      });

      test('Can create and delete directories', () async {
        final dir = '$testPrefix/new-directory';

        // In S3, makeDirectory just marks the directory as created in cache
        // Directories are virtual and exist when files are created within them
        await Storage.makeDirectory(dir);

        // Put a file in the directory to verify it works
        await Storage.put('$dir/test.txt', 'test content');
        expect(await Storage.exists('$dir/test.txt'), isTrue);

        // Delete the directory and verify file is gone
        await Storage.deleteDirectory(dir);
        expect(await Storage.exists('$dir/test.txt'), isFalse);
      });

      test('Can handle binary data', () async {
        final path = '$testPrefix/binary-test.bin';
        final data = List.generate(256, (i) => i);

        // Write binary data
        await Storage.put(path, data);

        // For binary data, we should use readStream instead of get()
        // since get() returns a string which doesn't work well with binary
        final exists = await Storage.exists(path);
        expect(exists, isTrue);

        // Verify file size matches
        final size = await Storage.size(path);
        expect(size, equals(256));

        await Storage.delete(path);
      });

      test('Visibility methods work (even if not fully supported)', () async {
        final path = '$testPrefix/visibility-test.txt';
        await Storage.put(path, 'test');

        final visibility = await Storage.getVisibility(path);
        expect(visibility, isNotNull);

        final result = await Storage.setVisibility(path, 'public');
        expect(result, isTrue);

        await Storage.delete(path);
      });

      test('Can use cloud() method to get cloud disk', () {
        final cloud = Storage.cloud();
        expect(cloud, isNotNull);
      });

      test('Can access disk by name', () {
        final s3Disk = Storage.disk('s3');
        expect(s3Disk, isNotNull);
      });

      test('Multiple concurrent operations work', () async {
        final files = List.generate(
          5,
          (i) => '$testPrefix/concurrent/file$i.txt',
        );

        // Write concurrently
        await Future.wait(
          files.map((path) => Storage.put(path, 'Content $path')),
        );

        // Verify all exist
        for (final file in files) {
          expect(await Storage.exists(file), isTrue);
        }

        // Clean up
        await Storage.deleteDirectory('$testPrefix/concurrent');
      });
    },
    skip: enableCloud
        ? false
        : 'Set ENABLE_CLOUD_TESTS=1 to run cloud integration tests',
  );

  group('Local Filesystem Tests', () {
    setUp(() {
      Storage.initialize({
        'default': 'local',
        'disks': {
          'local': {
            'driver': 'local',
            'root': '${Directory.systemTemp.path}/storage_local_test',
          },
        },
      });
    });

    tearDown(() async {
      try {
        final dir = Directory(
          '${Directory.systemTemp.path}/storage_local_test',
        );
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      } catch (e) {
        print('Local cleanup error: $e');
      }
    });

    test('Local filesystem works', () async {
      await Storage.put('test.txt', 'Local content');
      final content = await Storage.get('test.txt');
      expect(content, equals('Local content'));
    });

    test('Local filesystem URL generation works', () {
      final url = Storage.url('test.txt');
      expect(url, contains('test.txt'));
    });
  });
}
