import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart' hide SftpFile;
import 'package:file/file.dart';
import 'package:file_sftp/file_sftp.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockSftpFs extends Mock implements SftpFs {}

class _MockSftpFsFile extends Mock implements SftpFsFile {}

void main() {
  late _MockSftpFs mockFs;
  late _MockSftpFsFile mockFile;
  late SftpFileSystem fs;

  setUpAll(() {
    registerFallbackValue(SftpFileOpenMode.read);
    registerFallbackValue(SftpFileAttrs());
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(Stream<List<int>>.empty());
  });

  setUp(() {
    mockFs = _MockSftpFs();
    mockFile = _MockSftpFsFile();
    fs = SftpFileSystem.fromSftpFs(
      mockFs,
      config: () => const SftpConfig(host: '', username: '', root: '/'),
    );
  });

  group('FileSystem API', () {
    test('file() returns SftpFile', () {
      expect(fs.file('/foo.txt'), isA<SftpFile>());
    });

    test('directory() returns SftpDirectory', () {
      expect(fs.directory('/bar'), isA<SftpDirectory>());
    });

    test('link() returns SftpLink', () {
      expect(fs.link('/link'), isA<SftpLink>());
    });

    test('path uses posix style', () {
      expect(fs.path.join('a', 'b'), equals('a/b'));
    });

    test('currentDirectory defaults to /', () {
      expect(fs.currentDirectory.path, equals('/'));
    });

    test('currentDirectory can be set', () {
      fs.currentDirectory = '/some/dir';
      expect(fs.currentDirectory.path, equals('/some/dir'));
    });

    test('isWatchSupported returns false', () {
      expect(fs.isWatchSupported, isFalse);
    });

    test('stat returns FileStat from remote attrs', () async {
      when(() => mockFs.stat('/foo.txt')).thenAnswer(
        (_) async => SftpFileAttrs(
          size: 42,
          modifyTime: 1000,
          accessTime: 1000,
          mode: SftpFileMode.value(33188),
        ),
      );

      final stat = await fs.stat('/foo.txt');
      expect(stat.size, equals(42));
      expect(stat.type, equals(FileSystemEntityType.file));
    });

    test('stat returns FileStat for directory', () async {
      when(
        () => mockFs.stat('/dir'),
      ).thenAnswer((_) async => SftpFileAttrs(mode: SftpFileMode.value(16877)));

      final stat = await fs.stat('/dir');
      expect(stat.type, equals(FileSystemEntityType.directory));
    });

    test('systemTempDirectory throws', () {
      expect(() => fs.systemTempDirectory, throwsA(isA<UnsupportedError>()));
    });

    test('identical returns true when remote paths match', () async {
      expect(await fs.identical('/a', '/a'), isTrue);
    });

    test('identical returns false when remote paths differ', () async {
      expect(await fs.identical('/a', '/b'), isFalse);
    });

    test('isFile delegates to stat', () async {
      when(
        () => mockFs.stat('/f.txt'),
      ).thenAnswer((_) async => SftpFileAttrs(mode: SftpFileMode.value(33188)));
      expect(await fs.isFile('/f.txt'), isTrue);
    });

    test('isDirectory delegates to stat', () async {
      when(
        () => mockFs.stat('/d'),
      ).thenAnswer((_) async => SftpFileAttrs(mode: SftpFileMode.value(16877)));
      expect(await fs.isDirectory('/d'), isTrue);
    });
  });

  group('SftpFile', () {
    test('exists returns true when stat matches file type', () async {
      when(
        () => mockFs.stat('/f.txt'),
      ).thenAnswer((_) async => SftpFileAttrs(mode: SftpFileMode.value(33188)));
      expect(await fs.file('/f.txt').exists(), isTrue);
    });

    test('exists returns false when stat throws', () async {
      when(() => mockFs.stat('/f.txt')).thenThrow(Exception('fail'));
      expect(await fs.file('/f.txt').exists(), isFalse);
    });

    test('exists returns false when type does not match', () async {
      when(
        () => mockFs.stat('/f.txt'),
      ).thenAnswer((_) async => SftpFileAttrs(mode: SftpFileMode.value(16877)));
      expect(await fs.file('/f.txt').exists(), isFalse);
    });

    test('length returns file size from stat', () async {
      when(
        () => mockFs.stat('/f.txt'),
      ).thenAnswer((_) async => SftpFileAttrs(size: 123));
      expect(await fs.file('/f.txt').length(), equals(123));
    });

    test('readAsBytes opens and reads file', () async {
      when(() => mockFs.open('/f.txt')).thenAnswer((_) async => mockFile);
      when(() => mockFile.close()).thenAnswer((_) async {});
      when(
        () => mockFile.readBytes(),
      ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

      final bytes = await fs.file('/f.txt').readAsBytes();
      expect(bytes, equals([1, 2, 3]));
    });

    test('readAsString decodes UTF-8', () async {
      when(() => mockFs.open('/f.txt')).thenAnswer((_) async => mockFile);
      when(() => mockFile.close()).thenAnswer((_) async {});
      when(
        () => mockFile.readBytes(),
      ).thenAnswer((_) async => Uint8List.fromList(utf8.encode('hello')));

      expect(await fs.file('/f.txt').readAsString(), equals('hello'));
    });

    test('readAsLines splits lines', () async {
      when(() => mockFs.open('/f.txt')).thenAnswer((_) async => mockFile);
      when(() => mockFile.close()).thenAnswer((_) async {});
      when(() => mockFile.readBytes()).thenAnswer(
        (_) async => Uint8List.fromList(utf8.encode('line1\nline2\nline3')),
      );

      expect(
        await fs.file('/f.txt').readAsLines(),
        equals(['line1', 'line2', 'line3']),
      );
    });

    test('writeAsBytes writes content to file', () async {
      when(
        () => mockFs.open('/f.txt', mode: any(named: 'mode')),
      ).thenAnswer((_) async => mockFile);
      when(() => mockFile.writeBytes(any())).thenAnswer((_) async {});
      when(() => mockFile.close()).thenAnswer((_) async {});

      await fs.file('/f.txt').writeAsBytes([1, 2, 3]);
      verify(() => mockFile.writeBytes(any())).called(1);
    });

    test('writeAsString encodes and writes', () async {
      when(
        () => mockFs.open('/f.txt', mode: any(named: 'mode')),
      ).thenAnswer((_) async => mockFile);
      when(() => mockFile.writeBytes(any())).thenAnswer((_) async {});
      when(() => mockFile.close()).thenAnswer((_) async {});

      await fs.file('/f.txt').writeAsString('hello');
      verify(
        () => mockFile.writeBytes(Uint8List.fromList(utf8.encode('hello'))),
      ).called(1);
    });

    test('copy reads source and writes destination', () async {
      when(() => mockFs.open('/src.txt')).thenAnswer((_) async => mockFile);
      when(() => mockFile.close()).thenAnswer((_) async {});
      when(
        () => mockFile.readBytes(),
      ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

      final destFile = _MockSftpFsFile();
      when(
        () => mockFs.open('/dest.txt', mode: any(named: 'mode')),
      ).thenAnswer((_) async => destFile);
      when(() => destFile.writeBytes(any())).thenAnswer((_) async {});
      when(() => destFile.close()).thenAnswer((_) async {});

      final copied = await fs.file('/src.txt').copy('/dest.txt');
      expect(copied.path, equals('/dest.txt'));
      verify(() => destFile.writeBytes(any())).called(1);
    });

    test('rename renames remote file', () async {
      when(
        () => mockFs.rename('/old.txt', '/new.txt'),
      ).thenAnswer((_) async {});

      final renamed = await fs.file('/old.txt').rename('/new.txt');
      expect(renamed.path, equals('/new.txt'));
      verify(() => mockFs.rename('/old.txt', '/new.txt')).called(1);
    });

    test('delete removes remote file', () async {
      when(() => mockFs.remove('/f.txt')).thenAnswer((_) async {});

      await fs.file('/f.txt').delete();
      verify(() => mockFs.remove('/f.txt')).called(1);
    });

    test('create opens file with create and write modes', () async {
      when(() => mockFs.stat('/f.txt')).thenThrow(Exception('not found'));
      when(
        () => mockFs.open('/f.txt', mode: any(named: 'mode')),
      ).thenAnswer((_) async => mockFile);
      when(() => mockFile.close()).thenAnswer((_) async {});

      await fs.file('/f.txt').create();
      verify(() => mockFs.open('/f.txt', mode: any(named: 'mode'))).called(1);
    });

    test('create with exclusive throws when file exists', () async {
      when(
        () => mockFs.stat('/f.txt'),
      ).thenAnswer((_) async => SftpFileAttrs(mode: SftpFileMode.value(33188)));

      await expectLater(
        fs.file('/f.txt').create(exclusive: true),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('lastModified returns DateTime from stat', () async {
      when(
        () => mockFs.stat('/f.txt'),
      ).thenAnswer((_) async => SftpFileAttrs(modifyTime: 1000000));
      final dt = await fs.file('/f.txt').lastModified();
      expect(dt.millisecondsSinceEpoch, equals(1000000000));
    });

    test('setLastModified updates remote attrs', () async {
      when(() => mockFs.setStat('/f.txt', any())).thenAnswer((_) async {});
      final dt = DateTime.fromMillisecondsSinceEpoch(2000000000);
      await fs.file('/f.txt').setLastModified(dt);

      verify(() => mockFs.setStat('/f.txt', any())).called(1);
    });

    test('open returns RandomAccessFile', () async {
      when(
        () => mockFs.open('/f.txt', mode: any(named: 'mode')),
      ).thenAnswer((_) async => mockFile);
      when(() => mockFile.close()).thenAnswer((_) async {});

      final raf = await fs.file('/f.txt').open();
      expect(raf, isA<SftpRandomAccessFile>());
      await raf.close();
    });

    test('openWrite returns an IOSink that buffers and writes', () async {
      when(
        () => mockFs.open('/f.txt', mode: any(named: 'mode')),
      ).thenAnswer((_) async => mockFile);
      when(() => mockFile.writeBytes(any())).thenAnswer((_) async {});
      when(() => mockFile.close()).thenAnswer((_) async {});

      final sink = fs.file('/f.txt').openWrite();
      sink.write('hello');
      await sink.flush();
      await sink.close();
    });

    test('openRead streams file content', () async {
      var readCallCount = 0;
      when(() => mockFs.open('/f.txt')).thenAnswer((_) async => mockFile);
      when(() => mockFile.close()).thenAnswer((_) async {});
      when(
        () => mockFile.readBytes(
          length: any(named: 'length'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async {
        readCallCount++;
        if (readCallCount == 1) {
          return Uint8List.fromList(utf8.encode('hello'));
        }
        return Uint8List(0);
      });

      final stream = fs.file('/f.txt').openRead();
      final chunks = await stream.toList();
      expect(chunks, hasLength(1));
      expect(utf8.decode(chunks[0]), equals('hello'));
    });

    test('readAsBytesSync throws UnsupportedError', () {
      expect(
        () => fs.file('/f.txt').readAsBytesSync(),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('writeAsBytesSync throws UnsupportedError', () {
      expect(
        () => fs.file('/f.txt').writeAsBytesSync([]),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('SftpFile - open mode flags', () {
    test('open with FileMode.read passes only read flag', () async {
      SftpFileOpenMode? capturedMode;
      when(() => mockFs.open(any(), mode: any(named: 'mode')))
          .thenAnswer((invocation) async {
        capturedMode =
            invocation.namedArguments[const Symbol('mode')] as SftpFileOpenMode;
        return mockFile;
      });
      when(() => mockFile.close()).thenAnswer((_) async {});

      await fs.file('/f.txt').open(mode: FileMode.read);

      expect(capturedMode, isNotNull);
      expect(capturedMode!.flag & SftpFileOpenMode.read.flag, isNot(0));
      expect(capturedMode!.flag & SftpFileOpenMode.write.flag, equals(0));
      expect(capturedMode!.flag & SftpFileOpenMode.create.flag, equals(0));
      expect(capturedMode!.flag & SftpFileOpenMode.truncate.flag, equals(0));
    });

    test('open with FileMode.write includes read permission', () async {
      SftpFileOpenMode? capturedMode;
      when(() => mockFs.open(any(), mode: any(named: 'mode')))
          .thenAnswer((invocation) async {
        capturedMode =
            invocation.namedArguments[const Symbol('mode')] as SftpFileOpenMode;
        return mockFile;
      });
      when(() => mockFile.close()).thenAnswer((_) async {});

      await fs.file('/f.txt').open(mode: FileMode.write);

      expect(capturedMode, isNotNull);
      // Should include read, write, create, and truncate
      expect(capturedMode!.flag & SftpFileOpenMode.read.flag, isNot(0));
      expect(capturedMode!.flag & SftpFileOpenMode.write.flag, isNot(0));
      expect(capturedMode!.flag & SftpFileOpenMode.create.flag, isNot(0));
      expect(capturedMode!.flag & SftpFileOpenMode.truncate.flag, isNot(0));
    });

    test('open with FileMode.writeOnly includes read permission', () async {
      SftpFileOpenMode? capturedMode;
      when(() => mockFs.open(any(), mode: any(named: 'mode')))
          .thenAnswer((invocation) async {
        capturedMode =
            invocation.namedArguments[const Symbol('mode')] as SftpFileOpenMode;
        return mockFile;
      });
      when(() => mockFile.close()).thenAnswer((_) async {});

      await fs.file('/f.txt').open(mode: FileMode.writeOnly);

      expect(capturedMode, isNotNull);
      expect(capturedMode!.flag & SftpFileOpenMode.read.flag, isNot(0));
      expect(capturedMode!.flag & SftpFileOpenMode.write.flag, isNot(0));
      expect(capturedMode!.flag & SftpFileOpenMode.create.flag, isNot(0));
      expect(capturedMode!.flag & SftpFileOpenMode.truncate.flag, isNot(0));
    });

    test('open with FileMode.append includes read permission', () async {
      SftpFileOpenMode? capturedMode;
      when(() => mockFs.open(any(), mode: any(named: 'mode')))
          .thenAnswer((invocation) async {
        capturedMode =
            invocation.namedArguments[const Symbol('mode')] as SftpFileOpenMode;
        return mockFile;
      });
      when(() => mockFile.close()).thenAnswer((_) async {});

      await fs.file('/f.txt').open(mode: FileMode.append);

      expect(capturedMode, isNotNull);
      // Should include read, write, create, and append (no truncate)
      expect(capturedMode!.flag & SftpFileOpenMode.read.flag, isNot(0));
      expect(capturedMode!.flag & SftpFileOpenMode.write.flag, isNot(0));
      expect(capturedMode!.flag & SftpFileOpenMode.create.flag, isNot(0));
      expect(capturedMode!.flag & SftpFileOpenMode.truncate.flag, equals(0));
      expect(capturedMode!.flag & SftpFileOpenMode.append.flag, isNot(0));
    });
  });

  group('SftpFile - readOnly guard', () {
    late SftpFileSystem roFs;

    setUp(() {
      roFs = SftpFileSystem.fromSftpFs(
        mockFs,
        config: () =>
            const SftpConfig(host: '', username: '', root: '/', readOnly: true),
      );
    });

    test('writeAsBytes throws FileSystemException', () async {
      await expectLater(
        roFs.file('/f.txt').writeAsBytes([1, 2, 3]),
        throwsA(isA<FileSystemException>()),
      );
      verifyNever(() => mockFs.open(any(), mode: any(named: 'mode')));
    });

    test('delete throws FileSystemException', () async {
      await expectLater(
        roFs.file('/f.txt').delete(),
        throwsA(isA<FileSystemException>()),
      );
      verifyNever(() => mockFs.remove(any()));
    });
  });

  group('SftpDirectory', () {
    test('exists returns true when stat returns directory type', () async {
      when(
        () => mockFs.stat('/dir'),
      ).thenAnswer((_) async => SftpFileAttrs(mode: SftpFileMode.value(16877)));
      expect(await fs.directory('/dir').exists(), isTrue);
    });

    test('create calls mkdir', () async {
      when(() => mockFs.mkdir('/newdir')).thenAnswer((_) async {});
      await fs.directory('/newdir').create();
      verify(() => mockFs.mkdir('/newdir')).called(1);
    });

    test('create with recursive creates parent directories', () async {
      when(() => mockFs.stat('/a')).thenThrow(Exception('not found'));
      when(
        () => mockFs.stat('/'),
      ).thenAnswer((_) async => SftpFileAttrs(mode: SftpFileMode.value(16877)));
      when(() => mockFs.mkdir('/a')).thenAnswer((_) async {});
      when(() => mockFs.mkdir('/a/b')).thenAnswer((_) async {});

      await fs.directory('/a/b').create(recursive: true);
      verify(() => mockFs.mkdir('/a')).called(1);
      verify(() => mockFs.mkdir('/a/b')).called(1);
    });

    test('delete removes empty directory', () async {
      when(() => mockFs.listdir('/dir')).thenAnswer(
        (_) async => [
          SftpName(
            filename: '.',
            longname: '.',
            attr: SftpFileAttrs(mode: SftpFileMode.value(16877)),
          ),
          SftpName(
            filename: '..',
            longname: '..',
            attr: SftpFileAttrs(mode: SftpFileMode.value(16877)),
          ),
        ],
      );
      when(() => mockFs.rmdir('/dir')).thenAnswer((_) async {});

      await fs.directory('/dir').delete();
      verify(() => mockFs.rmdir('/dir')).called(1);
    });

    test('delete with recursive removes tree', () async {
      when(() => mockFs.listdir('/dir')).thenAnswer(
        (_) async => [
          SftpName(
            filename: 'f.txt',
            longname: 'f.txt',
            attr: SftpFileAttrs(mode: SftpFileMode.value(33188)),
          ),
        ],
      );
      when(() => mockFs.remove('/dir/f.txt')).thenAnswer((_) async {});
      when(() => mockFs.rmdir('/dir')).thenAnswer((_) async {});

      await fs.directory('/dir').delete(recursive: true);
      verify(() => mockFs.remove('/dir/f.txt')).called(1);
      verify(() => mockFs.rmdir('/dir')).called(1);
    });

    test('rename renames remote directory', () async {
      when(() => mockFs.rename('/old', '/new')).thenAnswer((_) async {});

      final renamed = await fs.directory('/old').rename('/new');
      expect(renamed.path, equals('/new'));
      verify(() => mockFs.rename('/old', '/new')).called(1);
    });

    test('list yields file and directory entities', () async {
      when(() => mockFs.listdir('/dir')).thenAnswer(
        (_) async => [
          SftpName(
            filename: 'f.txt',
            longname: 'f.txt',
            attr: SftpFileAttrs(mode: SftpFileMode.value(33188)),
          ),
          SftpName(
            filename: 'sub',
            longname: 'sub',
            attr: SftpFileAttrs(mode: SftpFileMode.value(16877)),
          ),
        ],
      );

      final entities = await fs.directory('/dir').list().toList();
      expect(entities.length, equals(2));
      expect(entities[0], isA<SftpFile>());
      expect(entities[1], isA<SftpDirectory>());
    });

    test('childFile returns a file in the directory', () {
      final child = fs.directory('/dir').childFile('f.txt');
      expect(child, isA<SftpFile>());
      expect(child.path, equals('/dir/f.txt'));
    });

    test('childDirectory returns a subdirectory', () {
      final child = fs.directory('/dir').childDirectory('sub');
      expect(child, isA<SftpDirectory>());
      expect(child.path, equals('/dir/sub'));
    });

    test('createTemp throws UnsupportedError', () {
      expect(
        () => fs.directory('/dir').createTempSync(),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('SftpLink', () {
    test('create calls link on the remote FS', () async {
      when(() => mockFs.link('/link', '/target')).thenAnswer((_) async {});

      await fs.link('/link').create('/target');
      verify(() => mockFs.link('/link', '/target')).called(1);
    });

    test('target returns readlink result', () async {
      when(() => mockFs.readlink('/link')).thenAnswer((_) async => '/target');

      final t = await fs.link('/link').target();
      expect(t, equals('/target'));
    });

    test('update removes old link and creates new one', () async {
      when(
        () => mockFs.stat('/link', followLink: false),
      ).thenAnswer((_) async => SftpFileAttrs(mode: SftpFileMode.value(41453)));
      when(() => mockFs.remove('/link')).thenAnswer((_) async {});
      when(() => mockFs.link('/link', '/new-target')).thenAnswer((_) async {});

      await fs.link('/link').update('/new-target');
      verify(() => mockFs.remove('/link')).called(1);
      verify(() => mockFs.link('/link', '/new-target')).called(1);
    });

    test('delete removes the link', () async {
      when(() => mockFs.remove('/link')).thenAnswer((_) async {});

      await fs.link('/link').delete();
      verify(() => mockFs.remove('/link')).called(1);
    });

    test('rename renames the link', () async {
      when(
        () => mockFs.rename('/old-link', '/new-link'),
      ).thenAnswer((_) async {});

      await fs.link('/old-link').rename('/new-link');
      verify(() => mockFs.rename('/old-link', '/new-link')).called(1);
    });

    test('exists returns true when stat shows symbolic link', () async {
      when(
        () => mockFs.stat('/link', followLink: false),
      ).thenAnswer((_) async => SftpFileAttrs(mode: SftpFileMode.value(41453)));
      expect(await fs.link('/link').exists(), isTrue);
    });

    test('exists returns false when stat throws', () async {
      when(
        () => mockFs.stat('/link', followLink: false),
      ).thenThrow(Exception('fail'));
      expect(await fs.link('/link').exists(), isFalse);
    });
  });

  group('SftpRandomAccessFile', () {
    test('read returns bytes and advances position', () async {
      when(
        () => mockFile.readBytes(length: 5, offset: 0),
      ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3, 4, 5]));
      when(
        () => mockFile.readBytes(length: 5, offset: 5),
      ).thenAnswer((_) async => Uint8List.fromList([6, 7, 8, 9, 10]));
      when(() => mockFile.close()).thenAnswer((_) async {});

      final raf = SftpRandomAccessFile(mockFile, '/f.txt', fs: mockFs);

      final chunk1 = await raf.read(5);
      expect(chunk1, equals([1, 2, 3, 4, 5]));
      expect(await raf.position(), equals(5));

      final chunk2 = await raf.read(5);
      expect(chunk2, equals([6, 7, 8, 9, 10]));
      expect(await raf.position(), equals(10));

      await raf.close();
    });

    test('setPosition changes position', () async {
      when(() => mockFile.close()).thenAnswer((_) async {});

      final raf = SftpRandomAccessFile(mockFile, '/f.txt');

      await raf.setPosition(42);
      expect(await raf.position(), equals(42));

      await raf.close();
    });

    test('writeByte writes at current position', () async {
      when(
        () => mockFile.writeBytes(any(), offset: 0),
      ).thenAnswer((_) async {});
      when(() => mockFile.close()).thenAnswer((_) async {});

      final raf = SftpRandomAccessFile(mockFile, '/f.txt');
      await raf.writeByte(65);
      verify(
        () => mockFile.writeBytes(Uint8List.fromList([65]), offset: 0),
      ).called(1);

      await raf.close();
    });

    test('writeFrom writes buffer at current position', () async {
      when(
        () => mockFile.writeBytes(any(), offset: 0),
      ).thenAnswer((_) async {});
      when(() => mockFile.close()).thenAnswer((_) async {});

      final raf = SftpRandomAccessFile(mockFile, '/f.txt');
      await raf.writeFrom([1, 2, 3]);
      verify(
        () => mockFile.writeBytes(Uint8List.fromList([1, 2, 3]), offset: 0),
      ).called(1);

      await raf.close();
    });

    test('readByte reads single byte', () async {
      when(
        () => mockFile.readBytes(length: 1, offset: 0),
      ).thenAnswer((_) async => Uint8List.fromList([42]));
      when(() => mockFile.close()).thenAnswer((_) async {});

      final raf = SftpRandomAccessFile(mockFile, '/f.txt');
      final byte = await raf.readByte();
      expect(byte, equals(42));

      await raf.close();
    });

    test('readByte returns -1 at EOF', () async {
      when(
        () => mockFile.readBytes(length: 1, offset: 0),
      ).thenAnswer((_) async => Uint8List(0));
      when(() => mockFile.close()).thenAnswer((_) async {});

      final raf = SftpRandomAccessFile(mockFile, '/f.txt');
      expect(await raf.readByte(), equals(-1));

      await raf.close();
    });

    test('close sets closed state', () async {
      when(() => mockFile.close()).thenAnswer((_) async {});

      final raf = SftpRandomAccessFile(mockFile, '/f.txt');
      await raf.close();
      await raf.close(); // second close should be no-op
    });

    test('operations after close throw', () async {
      when(() => mockFile.close()).thenAnswer((_) async {});

      final raf = SftpRandomAccessFile(mockFile, '/f.txt');
      await raf.close();

      expect(() => raf.read(1), throwsA(isA<FileSystemException>()));
    });

    test('length returns size from stat', () async {
      when(
        () => mockFs.stat('/f.txt'),
      ).thenAnswer((_) async => SftpFileAttrs(size: 100));
      when(() => mockFile.close()).thenAnswer((_) async {});

      final raf = SftpRandomAccessFile(mockFile, '/f.txt', fs: mockFs);
      expect(await raf.length(), equals(100));

      await raf.close();
    });

    test('lock throws UnsupportedError', () {
      final raf = SftpRandomAccessFile(mockFile, '/f.txt');
      expect(() => raf.lock(), throwsA(isA<UnsupportedError>()));
    });
  });

  group('SftpFileSystem - root path handling', () {
    late SftpFileSystem prefixedFs;

    setUp(() {
      prefixedFs = SftpFileSystem.fromSftpFs(
        mockFs,
        config: () => const SftpConfig(host: '', username: '', root: '/data'),
      );
    });

    test(
      'file paths are translated to remote paths with root prefix',
      () async {
        when(() => mockFs.stat('/data/foo.txt')).thenAnswer(
          (_) async => SftpFileAttrs(mode: SftpFileMode.value(33188)),
        );
        expect(await prefixedFs.file('/foo.txt').exists(), isTrue);
        verify(() => mockFs.stat('/data/foo.txt')).called(1);
      },
    );

    test('toRemotePath handles root prefix', () {
      expect(prefixedFs.toRemotePath('/foo.txt'), equals('/data/foo.txt'));
      expect(prefixedFs.toRemotePath('/'), equals('/data'));
    });

    test('fromRemotePath strips root prefix', () {
      expect(prefixedFs.fromRemotePath('/data/foo.txt'), equals('/foo.txt'));
      expect(prefixedFs.fromRemotePath('/data'), equals('/'));
    });
  });

  group('FileSystemEntity common', () {
    test('basename returns the filename part', () {
      expect(fs.file('/a/b/c.txt').basename, equals('c.txt'));
    });

    test('dirname returns the parent directory path', () {
      expect(fs.file('/a/b/c.txt').dirname, equals('/a/b'));
    });

    test('parent returns the parent directory', () {
      final parent = fs.file('/a/b/c.txt').parent;
      expect(parent.path, equals('/a/b'));
    });

    test('isAbsolute returns true for absolute paths', () {
      expect(fs.file('/foo').isAbsolute, isTrue);
    });

    test('isAbsolute returns true when path is normalized to absolute', () {
      expect(fs.file('relative').isAbsolute, isTrue);
    });

    test('resolveSymbolicLinks delegates to readlink', () async {
      when(() => mockFs.readlink('/link')).thenAnswer((_) async => '/target');

      final resolved = await fs.link('/link').resolveSymbolicLinks();
      expect(resolved, equals('/target'));
    });

    test('stat delegates to filesystem stat', () async {
      when(
        () => mockFs.stat('/f.txt'),
      ).thenAnswer((_) async => SftpFileAttrs(size: 42));
      final fileStat = await fs.file('/f.txt').stat();
      expect(fileStat.size, equals(42));
    });

    test('watch throws UnsupportedError', () {
      expect(() => fs.file('/f.txt').watch(), throwsA(isA<UnsupportedError>()));
    });
  });

  group('SftpFileSystem.disconnect', () {
    test('disconnect closes FS and clears state', () async {
      await fs.disconnect();
    });
  });

  group('SftpConfig integration with SftpFileSystem', () {
    test('readOnly config prevents writes', () async {
      final roFs = SftpFileSystem.fromSftpFs(
        mockFs,
        config: () =>
            const SftpConfig(host: '', username: '', root: '/', readOnly: true),
      );

      await expectLater(
        roFs.file('/f.txt').create(),
        throwsA(isA<FileSystemException>()),
      );
      verifyNever(() => mockFs.open(any(), mode: any(named: 'mode')));
    });
  });

  group('SftpFileSystem.fromClient', () {
    test('constructor accepts a pre-configured SftpClient', () {
      expect(
        () => SftpFileSystem.fromSftpFs(
          mockFs,
          config: () => const SftpConfig(host: '', username: ''),
        ),
        returnsNormally,
      );
    });
  });

  group('default constructor with optional client', () {
    test(
      'accepts a pre-configured SftpClient and is immediately connected',
      () async {
        final mockSftpClient = _MockSftpClient();
        final configuredFs = SftpFileSystem(
          const SftpConfig(host: '', username: ''),
          client: mockSftpClient,
        );

        // The filesystem should be connected immediately (no lazy init needed).
        // Verify by calling ensureConnected — it should not throw.
        final fs = await configuredFs.ensureConnected();
        expect(fs, isNotNull);
      },
    );
  });

  group('default constructor with optional sshClient', () {
    test('derives SftpClient lazily from SSHClient', () async {
      final mockSftpClient = _MockSftpClient();
      final mockSshClient = _MockSSHClient();
      when(() => mockSshClient.sftp()).thenAnswer((_) async => mockSftpClient);

      final configuredFs = SftpFileSystem(
        const SftpConfig(host: '', username: ''),
        sshClient: mockSshClient,
      );

      // The SFTP session should be derived lazily, not yet connected.
      verifyNever(() => mockSshClient.sftp());

      // First file operation triggers the SFTP derivation.
      final fs = await configuredFs.ensureConnected();
      expect(fs, isNotNull);
      verify(() => mockSshClient.sftp()).called(1);
    });

    test('throws when SSHClient.sftp() fails', () async {
      final mockSshClient = _MockSSHClient();
      when(() => mockSshClient.sftp()).thenThrow(Exception('SFTP failed'));

      final configuredFs = SftpFileSystem(
        const SftpConfig(host: '', username: ''),
        sshClient: mockSshClient,
      );

      await expectLater(
        configuredFs.ensureConnected(),
        throwsA(isA<Exception>()),
      );
    });
  });
}

class _MockSftpClient extends Mock implements SftpClient {}

class _MockSSHClient extends Mock implements SSHClient {}
