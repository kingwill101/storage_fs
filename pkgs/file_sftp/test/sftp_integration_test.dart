import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:file_sftp/src/sftp_config.dart';
import 'package:file_sftp/src/sftp_filesystem_adapter.dart';
import 'package:storage_fs/storage_fs.dart';
import 'package:test/test.dart';
import 'package:testcontainers_compose/testcontainers_compose.dart';

String _composeContext() {
  final inPackage = File('test/fixtures/docker-compose.yaml');
  if (inPackage.existsSync()) return 'test/fixtures';
  return 'pkgs/file_sftp/test/fixtures';
}

Future<void> main() async {
  group('SFTP Integration Tests (Docker)', () {
    late DockerCompose compose;

    setUpAll(() async {
      compose = DockerCompose(
        context: _composeContext(),
        composeFileName: ['docker-compose.yaml'],
        wait: true,
      );
      await compose.start();
      await Future<void>.delayed(const Duration(seconds: 5));
      addTearDown(() => compose.stop(down: true));
    });

    SftpConfig sftpConfig(int port) => SftpConfig(
      host: 'localhost',
      port: port,
      username: 'testuser',
      password: 'testpass',
      root: '/upload',
    );

    int sftpPort() {
      return compose
          .container('sftp')
          .publisher(byPort: 22)
          .publishedPort!;
    }

    test('connects and checks file existence', () async {
      final adapter = SftpFilesystemAdapter(sftpConfig(sftpPort()));
      try {
        expect(await adapter.exists('nonexistent.txt'), isFalse);
        expect(await adapter.missing('nonexistent.txt'), isTrue);
      } finally {
        await adapter.disconnect();
      }
    });

    test('writes and reads a file', () async {
      final adapter = SftpFilesystemAdapter(sftpConfig(sftpPort()));
      try {
        final result = await adapter.put('greeting.txt', 'Hello SFTP!');
        expect(result, isTrue);
        final content = await adapter.get('greeting.txt');
        expect(content, equals('Hello SFTP!'));
      } finally {
        await adapter.disconnect();
      }
    });

    test('writes bytes to file', () async {
      final adapter = SftpFilesystemAdapter(sftpConfig(sftpPort()));
      try {
        final bytes = <int>[0, 1, 2, 3, 255, 254];
        final result = await adapter.put('binary.bin', bytes);
        expect(result, isTrue);
        final size = await adapter.size('binary.bin');
        expect(size, equals(bytes.length));
        final checksum = await adapter.checksum('binary.bin', algorithm: 'md5');
        expect(checksum, isNotNull);
      } finally {
        await adapter.disconnect();
      }
    });

    test('deletes a file', () async {
      final adapter = SftpFilesystemAdapter(sftpConfig(sftpPort()));
      try {
        await adapter.put('to-delete.txt', 'bye');
        expect(await adapter.exists('to-delete.txt'), isTrue);
        final result = await adapter.delete('to-delete.txt');
        expect(result, isTrue);
        expect(await adapter.exists('to-delete.txt'), isFalse);
      } finally {
        await adapter.disconnect();
      }
    });

    test('copies a file', () async {
      final adapter = SftpFilesystemAdapter(sftpConfig(sftpPort()));
      try {
        await adapter.put('source.txt', 'copy me');
        final result = await adapter.copy('source.txt', 'dest.txt');
        expect(result, isTrue);
        expect(await adapter.get('dest.txt'), equals('copy me'));
      } finally {
        await adapter.disconnect();
      }
    });

    test('moves a file', () async {
      final adapter = SftpFilesystemAdapter(sftpConfig(sftpPort()));
      try {
        await adapter.put('original.txt', 'moving');
        final result = await adapter.move('original.txt', 'moved.txt');
        expect(result, isTrue);
        expect(await adapter.exists('original.txt'), isFalse);
        expect(await adapter.exists('moved.txt'), isTrue);
        expect(await adapter.get('moved.txt'), equals('moving'));
      } finally {
        await adapter.disconnect();
      }
    });

    test('creates and deletes a directory', () async {
      final adapter = SftpFilesystemAdapter(sftpConfig(sftpPort()));
      try {
        final result = await adapter.makeDirectory('new-dir');
        expect(result, isTrue);
        final result2 = await adapter.deleteDirectory('new-dir');
        expect(result2, isTrue);
      } finally {
        await adapter.disconnect();
      }
    });

    test('lists files in root directory', () async {
      final adapter = SftpFilesystemAdapter(sftpConfig(sftpPort()));
      try {
        await adapter.put('a.txt', 'alpha');
        await adapter.put('b.txt', 'beta');
        final files = await adapter.files();
        expect(files, contains('a.txt'));
        expect(files, contains('b.txt'));
      } finally {
        await adapter.disconnect();
      }
    });

    test('gets file size', () async {
      final adapter = SftpFilesystemAdapter(sftpConfig(sftpPort()));
      try {
        await adapter.put('sized.txt', 'hello world');
        final size = await adapter.size('sized.txt');
        expect(size, equals(11));
      } finally {
        await adapter.disconnect();
      }
    });

    test('gets last modified time', () async {
      final adapter = SftpFilesystemAdapter(sftpConfig(sftpPort()));
      try {
        await adapter.put('timestamped.txt', 'time');
        final modified = await adapter.lastModified('timestamped.txt');
        expect(modified, isA<DateTime>());
        expect(
          modified.isAfter(DateTime.now().subtract(const Duration(minutes: 1))),
          isTrue,
        );
      } finally {
        await adapter.disconnect();
      }
    });

    test('gets mime type', () async {
      final adapter = SftpFilesystemAdapter(sftpConfig(sftpPort()));
      try {
        await adapter.put('mime.txt', 'text content');
        final mimeType = await adapter.mimeType('mime.txt');
        expect(mimeType, equals('text/plain'));
      } finally {
        await adapter.disconnect();
      }
    });

    test('computes md5 checksum', () async {
      final adapter = SftpFilesystemAdapter(sftpConfig(sftpPort()));
      try {
        await adapter.put('checksum.txt', 'hello checksum');
        final checksum = await adapter.checksum('checksum.txt', algorithm: 'md5');
        expect(checksum, isNotNull);
        expect(checksum!.length, equals(32));
      } finally {
        await adapter.disconnect();
      }
    });

    test('appends to file', () async {
      final adapter = SftpFilesystemAdapter(sftpConfig(sftpPort()));
      try {
        await adapter.put('append.txt', 'line1');
        final result = await adapter.append('append.txt', 'line2', separator: '\n');
        expect(result, isTrue);
        final content = await adapter.get('append.txt');
        expect(content, equals('line1\nline2'));
      } finally {
        await adapter.disconnect();
      }
    });

    test('prepends to file', () async {
      final adapter = SftpFilesystemAdapter(sftpConfig(sftpPort()));
      try {
        await adapter.put('prepend.txt', 'line2');
        final result = await adapter.prepend('prepend.txt', 'line1', separator: '\n');
        expect(result, isTrue);
        final content = await adapter.get('prepend.txt');
        expect(content, equals('line1\nline2'));
      } finally {
        await adapter.disconnect();
      }
    });

    test('sets and gets visibility', () async {
      final adapter = SftpFilesystemAdapter(sftpConfig(sftpPort()));
      try {
        await adapter.put('vis.txt', 'visible');
        final vis = await adapter.getVisibility('vis.txt');
        expect(vis, isNotNull);
      } finally {
        await adapter.disconnect();
      }
    });

    test('supports stream read and write', () async {
      final adapter = SftpFilesystemAdapter(sftpConfig(sftpPort()));
      try {
        final input = Stream.fromIterable([
          [1, 2, 3],
          [4, 5, 6],
        ]);
        final result = await adapter.writeStream('stream.bin', input);
        expect(result, isTrue);

        final readStream = adapter.readStream('stream.bin');
        expect(readStream, isNotNull);
        final chunks = await readStream!.toList();
        expect(chunks, isNotEmpty);
        final expanded = <int>[];
        for (final chunk in chunks) {
          expanded.addAll(chunk);
        }
        expect(expanded, equals([1, 2, 3, 4, 5, 6]));
      } finally {
        await adapter.disconnect();
      }
    });

    test('throwExceptions mode rethrows errors', () async {
      final strictAdapter = SftpFilesystemAdapter(
        sftpConfig(sftpPort()).copyWith(throw_: true),
      );
      try {
        expect(
          () => strictAdapter.get('nonexistent.txt'),
          throwsA(isA<UnableToReadFileException>()),
        );
      } finally {
        await strictAdapter.disconnect();
      }
    });

    test('connects with password via fromClient', () async {
      final socket = await SSHSocket.connect('localhost', sftpPort());
      final sshClient = SSHClient(
        socket,
        username: 'testuser',
        onPasswordRequest: () => 'testpass',
      );

      await sshClient.authenticated;
      final sftp = await sshClient.sftp();

      final adapter = SftpFilesystemAdapter.fromClient(
        sftp,
        config: () => sftpConfig(sftpPort()),
      );
      try {
        expect(await adapter.exists('nonexistent.txt'), isFalse);
      } finally {
        await adapter.disconnect();
        sshClient.close();
      }
    });
  });
}
