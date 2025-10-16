import 'dart:async';
import 'dart:io';

import 'package:storage_fs/storage_fs.dart';
import 'package:test/test.dart';

/// Comprehensive local storage test with advanced features
void main() {
  group('Local Storage Comprehensive Tests', () {
    late String testRoot;
    late String testPrefix;

    setUpAll(() {
      testRoot = '${Directory.systemTemp.path}/storage_test';
      testPrefix = 'local-test-${DateTime.now().millisecondsSinceEpoch}';

      Storage.initialize({
        'default': 'local',
        'disks': {
          'local': {'driver': 'local', 'root': testRoot},
        },
      });
    });

    tearDownAll(() {
      // Clean up test directory
      try {
        final dir = Directory(testRoot);
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      } catch (e) {
        print('Cleanup error: $e');
      }
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

    test('Local driver does not support temporary URLs', () {
      expect(Storage.providesTemporaryUrls(), isFalse);
    });

    test('Can append and prepend to files', () async {
      final path = '$testPrefix/append-test.txt';

      await Storage.put(path, 'middle');
      await Storage.prepend(path, 'start\n');
      await Storage.append(path, '\nend');

      final content = await Storage.get(path);
      expect(content, contains('start'));
      expect(content, contains('middle'));
      expect(content, contains('end'));

      await Storage.delete(path);
    });

    test('Can create and delete directories', () async {
      final dir = '$testPrefix/new-directory';

      await Storage.makeDirectory(dir);
      await Storage.put('$dir/test.txt', 'test');

      expect(await Storage.exists('$dir/test.txt'), isTrue);

      await Storage.deleteDirectory(dir);
      expect(await Storage.exists('$dir/test.txt'), isFalse);
    });

    test('Can handle binary data', () async {
      final path = '$testPrefix/binary-test.bin';
      final data = List.generate(256, (i) => i);

      // Write binary data
      await Storage.put(path, data);

      // Verify file exists
      final exists = await Storage.exists(path);
      expect(exists, isTrue);

      // Verify file size matches
      final size = await Storage.size(path);
      expect(size, equals(256));

      await Storage.delete(path);
    });

    test('Visibility methods work for local driver', () async {
      final path = '$testPrefix/visibility-test.txt';
      await Storage.put(path, 'test');

      final visibility = await Storage.getVisibility(path);
      expect(visibility, isNotNull);

      final result = await Storage.setVisibility(path, 'public');
      expect(result, isTrue);

      await Storage.delete(path);
    });

    test('Can access disk by name', () {
      final localDisk = Storage.disk('local');
      expect(localDisk, isNotNull);
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

    test('Can handle nested directory structures', () async {
      final deepPath = '$testPrefix/level1/level2/level3/file.txt';

      await Storage.put(deepPath, 'deep content');
      expect(await Storage.exists(deepPath), isTrue);

      final content = await Storage.get(deepPath);
      expect(content, equals('deep content'));

      await Storage.deleteDirectory('$testPrefix/level1');
      expect(await Storage.exists(deepPath), isFalse);
    });

    test('Can delete multiple files at once', () async {
      final files = [
        '$testPrefix/multi-delete/file1.txt',
        '$testPrefix/multi-delete/file2.txt',
        '$testPrefix/multi-delete/file3.txt',
      ];

      // Create files
      for (final file in files) {
        await Storage.put(file, 'content');
      }

      // Verify all exist
      for (final file in files) {
        expect(await Storage.exists(file), isTrue);
      }

      // Delete all at once
      await Storage.delete(files);

      // Verify all deleted
      for (final file in files) {
        expect(await Storage.exists(file), isFalse);
      }
    });

    test('Can list directories', () async {
      final baseDir = '$testPrefix/dir-listing';

      // Create directory structure
      await Storage.put('$baseDir/dir1/file.txt', 'content');
      await Storage.put('$baseDir/dir2/file.txt', 'content');
      await Storage.put('$baseDir/dir3/file.txt', 'content');

      final dirs = await Storage.directories(baseDir);
      expect(dirs.length, greaterThanOrEqualTo(3));

      await Storage.deleteDirectory(baseDir);
    });

    test('Can list all directories recursively', () async {
      final baseDir = '$testPrefix/all-dirs';

      // Create nested structure
      await Storage.put('$baseDir/dir1/subdir1/file.txt', 'content');
      await Storage.put('$baseDir/dir2/subdir2/file.txt', 'content');

      final allDirs = await Storage.allDirectories(baseDir);
      expect(
        allDirs.length,
        greaterThanOrEqualTo(4),
      ); // dir1, dir2, subdir1, subdir2

      await Storage.deleteDirectory(baseDir);
    });

    test('Can handle empty files', () async {
      final path = '$testPrefix/empty.txt';

      await Storage.put(path, '');
      expect(await Storage.exists(path), isTrue);

      final size = await Storage.size(path);
      expect(size, equals(0));

      final content = await Storage.get(path);
      expect(content, isEmpty);

      await Storage.delete(path);
    });

    test('Can handle large text content', () async {
      final path = '$testPrefix/large.txt';
      final largeContent = 'A' * 10000; // 10KB of text

      await Storage.put(path, largeContent);
      final retrieved = await Storage.get(path);

      expect(retrieved?.length, equals(largeContent.length));
      expect(retrieved, equals(largeContent));

      await Storage.delete(path);
    });

    test('Handles missing files gracefully', () async {
      final path = '$testPrefix/nonexistent.txt';

      expect(await Storage.exists(path), isFalse);

      // Getting a non-existent file returns null for local driver
      final content = await Storage.get(path);
      expect(content, isNull);
    });

    test('Can overwrite existing files', () async {
      final path = '$testPrefix/overwrite.txt';

      await Storage.put(path, 'original content');
      final first = await Storage.get(path);
      expect(first, equals('original content'));

      await Storage.put(path, 'new content');
      final second = await Storage.get(path);
      expect(second, equals('new content'));

      await Storage.delete(path);
    });

    test('Can handle files with special characters in names', () async {
      final path = '$testPrefix/special-chars-test_file (1).txt';

      await Storage.put(path, 'special content');
      expect(await Storage.exists(path), isTrue);

      final content = await Storage.get(path);
      expect(content, equals('special content'));

      await Storage.delete(path);
    });

    test('Directory operations handle trailing slashes', () async {
      final dir1 = '$testPrefix/trailing-test';
      final dir2 = '$testPrefix/trailing-test/';

      await Storage.makeDirectory(dir1);
      await Storage.put('$dir2/file.txt', 'content');

      expect(await Storage.exists('$dir1/file.txt'), isTrue);

      await Storage.deleteDirectory(dir2);
      expect(await Storage.exists('$dir1/file.txt'), isFalse);
    });

    test('Can check MIME type of files', () async {
      final path = '$testPrefix/mime-test.txt';
      await Storage.put(path, 'text content');

      final mimeType = await Storage.mimeType(path);
      expect(mimeType, contains('text'));

      await Storage.delete(path);
    });

    test('Missing method throws when file does not exist', () async {
      final path = '$testPrefix/missing-test.txt';

      expect(await Storage.missing(path), isTrue);

      await Storage.put(path, 'content');
      expect(await Storage.missing(path), isFalse);

      await Storage.delete(path);
      expect(await Storage.missing(path), isTrue);
    });

    test('Can handle rapid sequential operations', () async {
      final path = '$testPrefix/rapid-ops.txt';

      for (var i = 0; i < 10; i++) {
        await Storage.put(path, 'iteration $i');
        final content = await Storage.get(path);
        expect(content, equals('iteration $i'));
      }

      await Storage.delete(path);
    });

    test('Can work with different file extensions', () async {
      final extensions = ['txt', 'json', 'xml', 'md', 'log'];

      for (final ext in extensions) {
        final path = '$testPrefix/extension-test.$ext';
        await Storage.put(path, 'content for $ext');
        expect(await Storage.exists(path), isTrue);
        await Storage.delete(path);
      }
    });
  });
}
