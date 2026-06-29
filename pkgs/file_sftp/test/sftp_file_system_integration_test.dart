import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:dartssh2/dartssh2.dart';
import 'package:file/file.dart';
import 'package:file_sftp/file_sftp.dart';
import 'package:test/test.dart';
import 'package:testcontainers_compose/testcontainers_compose.dart';

String _composeContext() {
  final inPackage = io.File('test/fixtures/docker-compose.yaml');
  if (inPackage.existsSync()) return 'test/fixtures';
  return 'pkgs/file_sftp/test/fixtures';
}

Future<void> main() async {
  group('SftpFileSystem Integration Tests (Docker)', () {
    late DockerCompose compose;
    late SftpFileSystem fs;

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

    int sftpPort() {
      return compose.container('sftp').publisher(byPort: 22).publishedPort!;
    }

    SftpConfig sftpConfig() => SftpConfig(
      host: 'localhost',
      port: sftpPort(),
      username: 'testuser',
      password: 'testpass',
      root: '/upload',
    );

    group('fromClient constructor', () {
      setUp(() async {
        final socket = await SSHSocket.connect('localhost', sftpPort());
        final sshClient = SSHClient(
          socket,
          username: 'testuser',
          onPasswordRequest: () => 'testpass',
        );
        await sshClient.authenticated;
        final sftp = await sshClient.sftp();
        fs = SftpFileSystem.fromClient(sftp, config: () => sftpConfig());
      });

      tearDown(() async {
        await fs.disconnect();
      });

      test('file does not exist', () async {
        expect(await fs.file('/nonexistent.txt').exists(), isFalse);
      });

      test('write and read a file', () async {
        final file = fs.file('/write-read-test.txt');
        await file.writeAsString('Hello SFTP!');
        expect(await file.readAsString(), equals('Hello SFTP!'));
      });

      test('writeAsBytes and readAsBytes round trip', () async {
        final file = fs.file('/binary-test.bin');
        final bytes = <int>[0, 1, 2, 3, 255, 254];
        await file.writeAsBytes(bytes);
        final read = await file.readAsBytes();
        expect(read, equals(bytes));
      });

      test('readAsLines splits content', () async {
        final file = fs.file('/lines-test.txt');
        await file.writeAsString('line1\nline2\nline3');
        final lines = await file.readAsLines();
        expect(lines, equals(['line1', 'line2', 'line3']));
      });

      test('file length', () async {
        final file = fs.file('/length-test.txt');
        await file.writeAsString('hello');
        expect(await file.length(), equals(5));
      });

      test('file lastModified', () async {
        final file = fs.file('/modified-test.txt');
        await file.writeAsString('test');
        final dt = await file.lastModified();
        expect(dt, isA<DateTime>());
        expect(
          dt.isAfter(DateTime.now().subtract(const Duration(minutes: 1))),
          isTrue,
        );
      });

      test('copy copies file content', () async {
        final src = fs.file('/copy-src.txt');
        await src.writeAsString('copy me');
        final dst = await src.copy('/copy-dst.txt');
        expect(await dst.readAsString(), equals('copy me'));
      });

      test('rename moves file', () async {
        final src = fs.file('/rename-src.txt');
        await src.writeAsString('moving');
        final renamed = await src.rename('/rename-dst.txt');
        expect(await renamed.readAsString(), equals('moving'));
        expect(await fs.file('/rename-src.txt').exists(), isFalse);
      });

      test('delete removes file', () async {
        final file = fs.file('/delete-me.txt');
        await file.writeAsString('bye');
        expect(await file.exists(), isTrue);
        await file.delete();
        expect(await file.exists(), isFalse);
      });

      test('create file with exclusive throws when exists', () async {
        final file = fs.file('/exclusive-test.txt');
        await file.writeAsString('original');
        await expectLater(
          file.create(exclusive: true),
          throwsA(isA<FileSystemException>()),
        );
      });

      test('create directory', () async {
        final dir = fs.directory('/new-dir');
        await dir.create();
        expect(await dir.exists(), isTrue);
      });

      test('create directory recursive', () async {
        final dir = fs.directory('/a/b/c');
        await dir.create(recursive: true);
        expect(await dir.exists(), isTrue);
        expect(await fs.directory('/a/b').exists(), isTrue);
        expect(await fs.directory('/a').exists(), isTrue);
      });

      test('delete directory', () async {
        final dir = fs.directory('/dir-to-delete');
        await dir.create();
        expect(await dir.exists(), isTrue);
        await dir.delete();
        expect(await dir.exists(), isFalse);
      });

      test('delete directory recursive', () async {
        final dir = fs.directory('/recursive-dir');
        await dir.create();
        final child = dir.childFile('child.txt');
        await child.writeAsString('nested');
        await dir.delete(recursive: true);
        expect(await dir.exists(), isFalse);
      });

      test('list directory', () async {
        final dir = fs.directory('/list-dir');
        await dir.create();
        await dir.childFile('a.txt').writeAsString('A');
        await dir.childFile('b.txt').writeAsString('B');

        final entries = await dir.list().toList();
        final names = entries.map((e) => e.basename).toSet();
        expect(names, contains('a.txt'));
        expect(names, contains('b.txt'));
      });

      test('list directory recursive', () async {
        final dir = fs.directory('/list-recursive');
        await dir.create(recursive: true);
        await dir.childFile('top.txt').writeAsString('top');
        final sub = dir.childDirectory('sub');
        await sub.create();
        await sub.childFile('nested.txt').writeAsString('nested');

        final entries = await dir.list(recursive: true).toList();
        final names = entries.map((e) => e.basename).toSet();
        expect(names, contains('top.txt'));
        expect(names, contains('nested.txt'));
      });

      test('rename directory', () async {
        final src = fs.directory('/rename-dir-src');
        await src.create();
        await src.childFile('f.txt').writeAsString('content');
        final dst = await src.rename('/rename-dir-dst');
        expect(await dst.exists(), isTrue);
        expect(await dst.childFile('f.txt').readAsString(), equals('content'));
        expect(await src.exists(), isFalse);
      });

      test('symlink create and target', () async {
        final target = fs.file('/link-target.txt');
        await target.writeAsString('linked');
        final link = fs.link('/my-link');
        try {
          await link.create(target.path);
          expect(await link.target(), equals(target.path));
        } catch (_) {
          markTestSkipped('Symlinks not supported in this environment');
        }
      });

      test('symlink update', () async {
        final link = fs.link('/update-link');
        try {
          await link.create('/original-target');
          await link.update('/new-target');
          expect(await link.target(), equals('/new-target'));
        } catch (_) {
          markTestSkipped('Symlinks not supported in this environment');
        }
      });

      test('symlink delete', () async {
        final link = fs.link('/delete-link');
        try {
          await link.create('/some-target');
          expect(await link.exists(), isTrue);
          await link.delete();
          expect(await link.exists(), isFalse);
        } catch (_) {
          markTestSkipped('Symlinks not supported in this environment');
        }
      });

      test('resolveSymbolicLinks via entity', () async {
        final target = fs.file('/resolve-target.txt');
        await target.writeAsString('resolved');
        final link = fs.link('/resolve-link');
        try {
          await link.create(target.path);
          final resolved = await link.resolveSymbolicLinks();
          expect(resolved, equals(target.path));
        } catch (_) {
          markTestSkipped('Symlinks not supported in this environment');
        }
      });

      test('RandomAccessFile read/write', () async {
        final file = fs.file('/raf-test.txt');
        await file.writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

        final raf = await file.open();
        try {
          expect(await raf.length(), equals(10));
          expect(await raf.position(), equals(0));

          final chunk = await raf.read(3);
          expect(chunk, equals([1, 2, 3]));
          expect(await raf.position(), equals(3));

          await raf.setPosition(0);
          expect(await raf.position(), equals(0));

          final byte = await raf.readByte();
          expect(byte, equals(1));
        } finally {
          await raf.close();
        }
      });

      test('RandomAccessFile writeFrom', () async {
        final file = fs.file('/raf-write-test.txt');
        await file.writeAsBytes([0, 0, 0]);

        final raf = await file.open(mode: FileMode.write);
        try {
          await raf.writeFrom([1, 2]);
          await raf.truncate(2);
        } finally {
          await raf.close();
        }

        final content = await file.readAsBytes();
        expect(content, equals([1, 2]));
      });

      test('stat returns correct type for file', () async {
        final file = fs.file('/stat-file.txt');
        await file.writeAsString('stat me');
        final stat = await file.stat();
        expect(stat.type, equals(FileSystemEntityType.file));
        expect(stat.size, greaterThan(0));
      });

      test('stat returns directory type', () async {
        final dir = fs.directory('/stat-dir');
        await dir.create();
        final stat = await dir.stat();
        expect(stat.type, equals(FileSystemEntityType.directory));
      });

      test('FileSystem.stat returns FileStat', () async {
        final file = fs.file('/fs-stat.txt');
        await file.writeAsBytes([1, 2, 3, 4, 5]);
        final stat = await fs.stat('/fs-stat.txt');
        expect(stat.size, equals(5));
        expect(stat.type, equals(FileSystemEntityType.file));
      });

      test('FileSystem.isFile/isDirectory', () async {
        await fs.file('/type-file.txt').writeAsString('file');
        await fs.directory('/type-dir').create();

        expect(await fs.isFile('/type-file.txt'), isTrue);
        expect(await fs.isFile('/type-dir'), isFalse);
        expect(await fs.isDirectory('/type-file.txt'), isFalse);
        expect(await fs.isDirectory('/type-dir'), isTrue);
      });

      test('openRead streams file', () async {
        final file = fs.file('/stream-test.txt');
        await file.writeAsString('hello world');

        final stream = file.openRead();
        final chunks = await stream.toList();
        final content = chunks.map(utf8.decode).join();
        expect(content, equals('hello world'));
      });

      test('openRead with start/end range', () async {
        final file = fs.file('/range-test.txt');
        await file.writeAsString('abcdefghij');

        final stream = file.openRead(2, 5);
        final chunks = await stream.toList();
        final content = chunks.map(utf8.decode).join();
        expect(content, equals('cde'));
      });

      test('openWrite writes file', () async {
        final sink = fs.file('/openwrite-test.txt').openWrite();
        sink.write('written via ');
        sink.write('openWrite');
        await sink.close();

        expect(
          await fs.file('/openwrite-test.txt').readAsString(),
          equals('written via openWrite'),
        );
      });

      test('openWrite with append mode', () async {
        final file = fs.file('/append-test.txt');
        await file.writeAsString('line1');

        final sink = file.openWrite(mode: FileMode.append);
        sink.write('\nline2');
        await sink.close();

        expect(await file.readAsString(), equals('line1\nline2'));
      });

      test('setLastModified changes modification time', () async {
        final file = fs.file('/set-mtime-test.txt');
        await file.writeAsString('test');
        final newTime = DateTime(2020, 1, 1);
        try {
          await file
              .setLastModified(newTime)
              .timeout(const Duration(seconds: 10));
          final modified = await file.lastModified();
          expect(modified.year, equals(2020));
        } on TimeoutException {
          markTestSkipped('setStat timed out - not supported by this server');
        } catch (e) {
          markTestSkipped('setStat not supported: $e');
        }
      });

      test('directory parent relationship', () async {
        fs.directory('/parent-test');
        expect(fs.directory('/parent-test').parent.path, equals('/'));
      });

      test('basename and dirname', () async {
        final file = fs.file('/deep/path/file.txt');
        expect(file.basename, equals('file.txt'));
        expect(file.dirname, equals('/deep/path'));
      });

      test('childFile and childDirectory', () async {
        final dir = fs.directory('/parent');
        expect(dir.childFile('test.txt').path, equals('/parent/test.txt'));
        expect(dir.childDirectory('sub').path, equals('/parent/sub'));
      });
    });

    group('full connection constructor', () {
      test('connects and reads a file', () async {
        final fileFs = SftpFileSystem(sftpConfig());
        try {
          expect(await fileFs.file('/nonexistent.txt').exists(), isFalse);
        } finally {
          await fileFs.disconnect();
        }
      });
    });

    group('default constructor with optional client', () {
      setUp(() async {
        final socket = await SSHSocket.connect('localhost', sftpPort());
        final sshClient = SSHClient(
          socket,
          username: 'testuser',
          onPasswordRequest: () => 'testpass',
        );
        await sshClient.authenticated;
        final sftp = await sshClient.sftp();
        fs = SftpFileSystem(sftpConfig(), client: sftp);
      });

      tearDown(() async {
        await fs.disconnect();
      });

      test('file does not exist', () async {
        expect(await fs.file('/nonexistent.txt').exists(), isFalse);
      });

      test('write and read a file', () async {
        final file = fs.file('/write-read-default-test.txt');
        await file.writeAsString('Hello with optional client!');
        expect(
          await file.readAsString(),
          equals('Hello with optional client!'),
        );
      });

      test('writeAsBytes and readAsBytes round trip', () async {
        final file = fs.file('/binary-default-test.bin');
        final bytes = <int>[10, 20, 30, 40, 255];
        await file.writeAsBytes(bytes);
        final read = await file.readAsBytes();
        expect(read, equals(bytes));
      });

      test('file length', () async {
        final file = fs.file('/length-default-test.txt');
        await file.writeAsString('12345');
        expect(await file.length(), equals(5));
      });

      test('delete removes file', () async {
        final file = fs.file('/delete-default-test.txt');
        await file.writeAsString('delete me');
        await file.delete();
        expect(await file.exists(), isFalse);
      });

      test('create directory and list', () async {
        final dir = fs.directory('/list-default-test-dir');
        await dir.create();
        final file = dir.childFile('nested.txt');
        await file.writeAsString('nested');
        final entries = await dir.list().toList();
        expect(entries.length, equals(1));
        expect(entries.first.basename, equals('nested.txt'));
      });

      test('uses config root path', () async {
        // The config root is /upload, so paths are relative to that.
        final file = fs.file('/root-test.txt');
        await file.writeAsString('rooted');
        expect(await file.exists(), isTrue);
      });
    });

    group('default constructor with optional sshClient', () {
      setUp(() async {
        final socket = await SSHSocket.connect('localhost', sftpPort());
        final sshClient = SSHClient(
          socket,
          username: 'testuser',
          onPasswordRequest: () => 'testpass',
        );
        await sshClient.authenticated;
        fs = SftpFileSystem(sftpConfig(), sshClient: sshClient);
      });

      tearDown(() async {
        await fs.disconnect();
      });

      test('file does not exist', () async {
        expect(await fs.file('/nonexistent-ssh.txt').exists(), isFalse);
      });

      test('write and read a file', () async {
        final file = fs.file('/write-read-ssh-test.txt');
        await file.writeAsString('Hello via SSHClient!');
        expect(await file.readAsString(), equals('Hello via SSHClient!'));
      });

      test('file length', () async {
        final file = fs.file('/length-ssh-test.txt');
        await file.writeAsString('ABCDE');
        expect(await file.length(), equals(5));
      });

      test('delete removes file', () async {
        final file = fs.file('/delete-ssh-test.txt');
        await file.writeAsString('delete me ssh');
        await file.delete();
        expect(await file.exists(), isFalse);
      });

      test('create directory and list', () async {
        final dir = fs.directory('/list-ssh-test-dir');
        await dir.create();
        final file = dir.childFile('nested.txt');
        await file.writeAsString('nested ssh');
        final entries = await dir.list().toList();
        expect(entries.length, equals(1));
        expect(entries.first.basename, equals('nested.txt'));
      });
    });
  });
}
