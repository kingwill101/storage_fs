import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:file_sftp/src/sftp_config.dart';
import 'package:file_sftp/src/sftp_filesystem_adapter.dart';
import 'package:file_sftp/src/sftp_fs.dart';
import 'package:mocktail/mocktail.dart';
import 'package:storage_fs/storage_fs.dart'
    show
        FilesystemException,
        UnableToReadFileException,
        UnableToWriteFileException,
        UnableToDeleteFileException,
        UnableToCopyFileException,
        UnableToMoveFileException,
        UnableToRetrieveMetadataException,
        UnableToCreateDirectoryException,
        UnableToDeleteDirectoryException;
import 'package:storage_fs/storage_fs.dart' as sf;
import 'package:test/test.dart';

class _MockSftpFs extends Mock implements SftpFs {}

class _MockSftpFsFile extends Mock implements SftpFsFile {}

void main() {
  late _MockSftpFs mockFs;
  late _MockSftpFsFile mockFile;
  late SftpFilesystemAdapter adapter;

  setUpAll(() {
    registerFallbackValue(SftpFileOpenMode.read);
    registerFallbackValue(SftpFileAttrs());
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(Stream<List<int>>.empty());
  });

  setUp(() {
    mockFs = _MockSftpFs();
    mockFile = _MockSftpFsFile();
    adapter = SftpFilesystemAdapter.fromSftpFs(
      mockFs,
      config: () => const SftpConfig(host: '', username: '', root: '/'),
    );
  });

  group('exists / missing', () {
    test('exists returns true when stat succeeds', () async {
      when(
        () => mockFs.stat('/foo.txt'),
      ).thenAnswer((_) async => SftpFileAttrs());
      expect(await adapter.exists('foo.txt'), isTrue);
    });

    test('exists returns false when stat throws', () async {
      when(() => mockFs.stat('/foo.txt')).thenThrow(Exception('fail'));
      expect(await adapter.exists('foo.txt'), isFalse);
    });

    test('missing is the inverse of exists', () async {
      when(() => mockFs.stat('/foo.txt')).thenThrow(Exception('fail'));
      expect(await adapter.missing('foo.txt'), isTrue);
    });
  });

  group('get / readStream', () {
    test('get returns file content as string', () async {
      when(() => mockFs.open('/foo.txt')).thenAnswer((_) async => mockFile);
      when(
        () => mockFile.readBytes(),
      ).thenAnswer((_) async => Uint8List.fromList(utf8.encode('hello')));
      when(() => mockFile.close()).thenAnswer((_) async {});

      expect(await adapter.get('foo.txt'), equals('hello'));
    });

    test('get returns null on error when throwExceptions is false', () async {
      when(() => mockFs.open('/foo.txt')).thenThrow(Exception('fail'));
      expect(await adapter.get('foo.txt'), isNull);
    });

    test(
      'readStream rethrows async open failures when throwExceptions is true',
      () async {
        adapter = SftpFilesystemAdapter.fromSftpFs(
          mockFs,
          config: () =>
              const SftpConfig(host: '', username: '', root: '/', throw_: true),
        );
        when(() => mockFs.open('/foo.txt')).thenThrow(Exception('fail'));

        final stream = adapter.readStream('foo.txt');
        expect(stream, isNotNull);
        await expectLater(
          stream!.toList(),
          throwsA(isA<UnableToReadFileException>()),
        );
      },
    );
  });

  group('put', () {
    test('put writes string content', () async {
      when(
        () => mockFs.open('/foo.txt', mode: any(named: 'mode')),
      ).thenAnswer((_) async => mockFile);
      when(() => mockFile.writeBytes(any())).thenAnswer((_) async {});
      when(() => mockFile.close()).thenAnswer((_) async {});
      when(() => mockFs.stat('/')).thenThrow(Exception('not found'));
      when(() => mockFs.mkdir('/')).thenAnswer((_) async {});

      expect(await adapter.put('foo.txt', 'hello'), isTrue);
      verify(() => mockFile.writeBytes(any())).called(1);
    });

    test('put writes bytes content', () async {
      when(
        () => mockFs.open('/foo.txt', mode: any(named: 'mode')),
      ).thenAnswer((_) async => mockFile);
      when(() => mockFile.writeBytes(any())).thenAnswer((_) async {});
      when(() => mockFile.close()).thenAnswer((_) async {});
      when(() => mockFs.stat('/')).thenThrow(Exception('not found'));
      when(() => mockFs.mkdir('/')).thenAnswer((_) async {});

      expect(await adapter.put('foo.txt', [1, 2, 3]), isTrue);
    });
  });

  group('writeStream', () {
    test('writes stream content', () async {
      when(
        () => mockFs.open('/foo.txt', mode: any(named: 'mode')),
      ).thenAnswer((_) async => mockFile);
      when(() => mockFile.write(any())).thenAnswer((_) async {});
      when(() => mockFile.close()).thenAnswer((_) async {});
      when(() => mockFs.stat('/')).thenThrow(Exception('not found'));
      when(() => mockFs.mkdir('/')).thenAnswer((_) async {});

      final stream = Stream.value([1, 2, 3]);
      expect(await adapter.writeStream('foo.txt', stream), isTrue);
    });
  });

  group('delete', () {
    test('deletes a single file', () async {
      when(() => mockFs.remove('/foo.txt')).thenAnswer((_) async {});
      expect(await adapter.delete('foo.txt'), isTrue);
    });

    test('deletes multiple files', () async {
      when(() => mockFs.remove('/a.txt')).thenAnswer((_) async {});
      when(() => mockFs.remove('/b.txt')).thenAnswer((_) async {});
      expect(await adapter.delete(['a.txt', 'b.txt']), isTrue);
    });

    test(
      'delete returns false on error when throwExceptions is false',
      () async {
        when(() => mockFs.remove('/foo.txt')).thenThrow(Exception('fail'));
        expect(await adapter.delete('foo.txt'), isFalse);
      },
    );
  });

  group('copy', () {
    test('copies a file by reading and writing', () async {
      when(() => mockFs.open('/from.txt')).thenAnswer((_) async => mockFile);
      when(
        () => mockFile.readBytes(),
      ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
      when(() => mockFile.close()).thenAnswer((_) async {});

      when(() => mockFs.stat('/')).thenThrow(Exception('not found'));
      when(() => mockFs.mkdir('/')).thenAnswer((_) async {});

      final toFile = _MockSftpFsFile();
      when(
        () => mockFs.open('/to.txt', mode: any(named: 'mode')),
      ).thenAnswer((_) async => toFile);
      when(() => toFile.writeBytes(any())).thenAnswer((_) async {});
      when(() => toFile.close()).thenAnswer((_) async {});

      expect(await adapter.copy('from.txt', 'to.txt'), isTrue);
      verify(() => toFile.writeBytes(any())).called(1);
    });
  });

  group('move', () {
    test('move renames when possible', () async {
      when(
        () => mockFs.rename('/from.txt', '/to.txt'),
      ).thenAnswer((_) async {});
      expect(await adapter.move('from.txt', 'to.txt'), isTrue);
      verify(() => mockFs.rename('/from.txt', '/to.txt')).called(1);
    });

    test('move falls back to copy+delete when rename fails', () async {
      when(
        () => mockFs.rename('/from.txt', '/to.txt'),
      ).thenThrow(Exception('rename fail'));
      when(() => mockFs.open('/from.txt')).thenAnswer((_) async => mockFile);
      when(
        () => mockFile.readBytes(),
      ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
      when(() => mockFile.close()).thenAnswer((_) async {});

      when(() => mockFs.stat('/')).thenThrow(Exception('not found'));
      when(() => mockFs.mkdir('/')).thenAnswer((_) async {});

      final toFile = _MockSftpFsFile();
      when(
        () => mockFs.open('/to.txt', mode: any(named: 'mode')),
      ).thenAnswer((_) async => toFile);
      when(() => toFile.writeBytes(any())).thenAnswer((_) async {});
      when(() => toFile.close()).thenAnswer((_) async {});

      when(() => mockFs.remove('/from.txt')).thenAnswer((_) async {});

      expect(await adapter.move('from.txt', 'to.txt'), isTrue);
      verify(() => mockFs.remove('/from.txt')).called(1);
    });
  });

  group('size', () {
    test('returns file size from stat', () async {
      when(
        () => mockFs.stat('/foo.txt'),
      ).thenAnswer((_) async => SftpFileAttrs(size: 42));
      expect(await adapter.size('foo.txt'), equals(42));
    });

    test('returns 0 on error when throwExceptions is false', () async {
      when(() => mockFs.stat('/foo.txt')).thenThrow(Exception('fail'));
      expect(await adapter.size('foo.txt'), equals(0));
    });
  });

  group('checksum', () {
    test('returns md5 hex string', () async {
      when(
        () => mockFs.stat('/foo.txt'),
      ).thenAnswer((_) async => SftpFileAttrs());
      when(() => mockFs.open('/foo.txt')).thenAnswer((_) async => mockFile);
      when(
        () => mockFile.readBytes(length: 65536, offset: 0),
      ).thenAnswer((_) async => Uint8List.fromList(utf8.encode('hello')));
      when(
        () => mockFile.readBytes(length: 65536, offset: 5),
      ).thenAnswer((_) async => Uint8List(0));
      when(() => mockFile.close()).thenAnswer((_) async {});

      final result = await adapter.checksum('foo.txt');
      expect(result, isNotNull);
      expect((result as String).length, equals(32));
    });
  });

  group('lastModified', () {
    test('returns DateTime from modifyTime', () async {
      when(
        () => mockFs.stat('/foo.txt'),
      ).thenAnswer((_) async => SftpFileAttrs(modifyTime: 1_000_000));
      final dt = await adapter.lastModified('foo.txt');
      expect(dt.millisecondsSinceEpoch, equals(1_000_000_000));
    });
  });

  group('files / directories', () {
    test('files returns sorted list', () async {
      when(() => mockFs.stat('/')).thenAnswer((_) async => SftpFileAttrs());
      when(() => mockFs.listdir('/')).thenAnswer(
        (_) async => [
          SftpName(
            filename: 'a.txt',
            longname: 'a.txt',
            attr: SftpFileAttrs(mode: SftpFileMode.value(1 << 15)),
          ),
          SftpName(
            filename: 'b.txt',
            longname: 'b.txt',
            attr: SftpFileAttrs(mode: SftpFileMode.value(1 << 15)),
          ),
        ],
      );

      final result = await adapter.files();
      expect(result, equals(['a.txt', 'b.txt']));
    });

    test('files returns empty list when directory does not exist', () async {
      when(() => mockFs.stat('/')).thenThrow(Exception('fail'));
      expect(await adapter.files(), isEmpty);
    });

    test('directories returns sorted list', () async {
      when(() => mockFs.stat('/')).thenAnswer((_) async => SftpFileAttrs());
      when(() => mockFs.listdir('/')).thenAnswer(
        (_) async => [
          SftpName(
            filename: 'subdir',
            longname: 'subdir',
            attr: SftpFileAttrs(mode: SftpFileMode.value(1 << 14)),
          ),
        ],
      );

      final result = await adapter.directories();
      expect(result, equals(['subdir']));
    });
  });

  group('makeDirectory / deleteDirectory', () {
    test('makeDirectory creates directory', () async {
      when(() => mockFs.stat('/')).thenThrow(Exception('not found'));
      when(() => mockFs.mkdir('/')).thenAnswer((_) async {});
      when(() => mockFs.mkdir('/subdir')).thenAnswer((_) async {});
      expect(await adapter.makeDirectory('subdir'), isTrue);
    });

    test('deleteDirectory removes tree', () async {
      when(() => mockFs.listdir('/dir')).thenAnswer((_) async => []);
      when(() => mockFs.rmdir('/dir')).thenAnswer((_) async {});
      expect(await adapter.deleteDirectory('dir'), isTrue);
    });
  });

  group('visibility', () {
    test('getVisibility returns public when otherRead is true', () async {
      when(() => mockFs.stat('/foo.txt')).thenAnswer(
        (_) async => SftpFileAttrs(
          mode: SftpFileMode(userRead: true, groupRead: true, otherRead: true),
        ),
      );
      expect(
        await adapter.getVisibility('foo.txt'),
        equals(sf.Filesystem.visibilityPublic),
      );
    });

    test('getVisibility returns private when otherRead is false', () async {
      when(() => mockFs.stat('/foo.txt')).thenAnswer(
        (_) async => SftpFileAttrs(
          mode: SftpFileMode(userRead: true, groupRead: true, otherRead: false),
        ),
      );
      expect(
        await adapter.getVisibility('foo.txt'),
        equals(sf.Filesystem.visibilityPrivate),
      );
    });

    test('setVisibility sets mode with otherRead', () async {
      when(() => mockFs.setStat('/foo.txt', any())).thenAnswer((_) async {});
      expect(
        await adapter.setVisibility('foo.txt', sf.Filesystem.visibilityPublic),
        isTrue,
      );
      verify(() => mockFs.setStat('/foo.txt', any())).called(1);
    });
  });

  group('prepend / append', () {
    test('prepend adds data before existing content', () async {
      when(
        () => mockFs.stat('/foo.txt'),
      ).thenAnswer((_) async => SftpFileAttrs());
      when(() => mockFs.open('/foo.txt')).thenAnswer((_) async => mockFile);
      when(
        () => mockFile.readBytes(),
      ).thenAnswer((_) async => Uint8List.fromList(utf8.encode('existing')));
      when(() => mockFile.close()).thenAnswer((_) async {});

      when(() => mockFs.stat('/')).thenThrow(Exception('not found'));
      when(() => mockFs.mkdir('/')).thenAnswer((_) async {});

      when(
        () => mockFs.open('/foo.txt', mode: any(named: 'mode')),
      ).thenAnswer((_) async => mockFile);
      when(() => mockFile.writeBytes(any())).thenAnswer((_) async {});
      when(() => mockFile.close()).thenAnswer((_) async {});

      expect(await adapter.prepend('foo.txt', 'new'), isTrue);
      verify(() => mockFile.writeBytes(utf8.encode('new\nexisting')));
    });

    test('append adds data after existing content', () async {
      when(
        () => mockFs.stat('/foo.txt'),
      ).thenAnswer((_) async => SftpFileAttrs());
      when(() => mockFs.open('/foo.txt')).thenAnswer((_) async => mockFile);
      when(
        () => mockFile.readBytes(),
      ).thenAnswer((_) async => Uint8List.fromList(utf8.encode('existing')));
      when(() => mockFile.close()).thenAnswer((_) async {});

      when(() => mockFs.stat('/')).thenThrow(Exception('not found'));
      when(() => mockFs.mkdir('/')).thenAnswer((_) async {});

      when(
        () => mockFs.open('/foo.txt', mode: any(named: 'mode')),
      ).thenAnswer((_) async => mockFile);
      when(() => mockFile.writeBytes(any())).thenAnswer((_) async {});
      when(() => mockFile.close()).thenAnswer((_) async {});

      expect(await adapter.append('foo.txt', 'new'), isTrue);
      verify(() => mockFile.writeBytes(utf8.encode('existing\nnew')));
    });
  });

  group('throwExceptions mode', () {
    setUp(() {
      adapter = SftpFilesystemAdapter.fromSftpFs(
        mockFs,
        config: () =>
            const SftpConfig(host: '', username: '', root: '/', throw_: true),
      );
    });

    test('get throws UnableToReadFileException', () async {
      when(() => mockFs.open('/foo.txt')).thenThrow(Exception('fail'));
      await expectLater(
        adapter.get('foo.txt'),
        throwsA(isA<UnableToReadFileException>()),
      );
    });

    test('put throws UnableToWriteFileException', () async {
      when(
        () => mockFs.open('/foo.txt', mode: any(named: 'mode')),
      ).thenThrow(Exception('fail'));
      await expectLater(
        adapter.put('foo.txt', 'data'),
        throwsA(isA<UnableToWriteFileException>()),
      );
    });

    test('delete throws UnableToDeleteFileException', () async {
      when(() => mockFs.remove('/foo.txt')).thenThrow(Exception('fail'));
      await expectLater(
        adapter.delete('foo.txt'),
        throwsA(isA<UnableToDeleteFileException>()),
      );
    });

    test('copy throws UnableToCopyFileException', () async {
      when(() => mockFs.open('/from.txt')).thenThrow(Exception('fail'));
      await expectLater(
        adapter.copy('from.txt', 'to.txt'),
        throwsA(isA<UnableToCopyFileException>()),
      );
    });

    test('move throws UnableToMoveFileException', () async {
      when(
        () => mockFs.rename('/from.txt', '/to.txt'),
      ).thenThrow(Exception('fail'));
      when(() => mockFs.open('/from.txt')).thenThrow(Exception('fail'));
      await expectLater(
        adapter.move('from.txt', 'to.txt'),
        throwsA(isA<UnableToMoveFileException>()),
      );
    });

    test('size throws UnableToRetrieveMetadataException', () async {
      when(() => mockFs.stat('/foo.txt')).thenThrow(Exception('fail'));
      await expectLater(
        adapter.size('foo.txt'),
        throwsA(isA<UnableToRetrieveMetadataException>()),
      );
    });

    test('makeDirectory throws UnableToCreateDirectoryException', () async {
      when(() => mockFs.mkdir('/dir')).thenThrow(Exception('fail'));
      await expectLater(
        adapter.makeDirectory('dir'),
        throwsA(isA<UnableToCreateDirectoryException>()),
      );
    });

    test('deleteDirectory throws UnableToDeleteDirectoryException', () async {
      when(() => mockFs.listdir('/dir')).thenThrow(Exception('fail'));
      await expectLater(
        adapter.deleteDirectory('dir'),
        throwsA(isA<UnableToDeleteDirectoryException>()),
      );
    });
  });

  group('root path handling', () {
    setUp(() {
      adapter = SftpFilesystemAdapter.fromSftpFs(
        mockFs,
        config: () => const SftpConfig(host: '', username: '', root: '/data'),
      );
    });

    test('prepends root to paths', () async {
      when(
        () => mockFs.stat('/data/foo.txt'),
      ).thenAnswer((_) async => SftpFileAttrs());
      expect(await adapter.exists('foo.txt'), isTrue);
      verify(() => mockFs.stat('/data/foo.txt')).called(1);
    });

    test('files returns paths relative to root', () async {
      when(() => mockFs.stat('/data')).thenAnswer((_) async => SftpFileAttrs());
      when(() => mockFs.listdir('/data')).thenAnswer(
        (_) async => [
          SftpName(
            filename: 'a.txt',
            longname: 'a.txt',
            attr: SftpFileAttrs(mode: SftpFileMode.value(1 << 15)),
          ),
        ],
      );

      final result = await adapter.files();
      expect(result, equals(['a.txt']));
    });
  });

  group('readOnly mode', () {
    setUp(() {
      adapter = SftpFilesystemAdapter.fromSftpFs(
        mockFs,
        config: () =>
            const SftpConfig(host: '', username: '', root: '/', readOnly: true),
      );
    });

    test('put returns false without touching SFTP', () async {
      expect(await adapter.put('foo.txt', 'data'), isFalse);
      verifyNever(() => mockFs.open(any(), mode: any(named: 'mode')));
    });

    test('delete returns false without touching SFTP', () async {
      expect(await adapter.delete('foo.txt'), isFalse);
      verifyNever(() => mockFs.remove(any()));
    });

    test('makeDirectory returns false without touching SFTP', () async {
      expect(await adapter.makeDirectory('dir'), isFalse);
      verifyNever(() => mockFs.mkdir(any()));
    });

    test('mutating operations throw when throwExceptions is true', () async {
      adapter = SftpFilesystemAdapter.fromSftpFs(
        mockFs,
        config: () => const SftpConfig(
          host: '',
          username: '',
          root: '/',
          readOnly: true,
          throw_: true,
        ),
      );

      await expectLater(
        adapter.put('foo.txt', 'data'),
        throwsA(isA<FilesystemException>()),
      );
    });
  });

  group('SftpConfig serialization', () {
    test('toMap/fromMap roundtrip preserves all fields', () {
      const original = SftpConfig(
        host: 'example.com',
        port: 2222,
        username: 'deploy',
        password: 'secret',
        privateKeyPems: ['-----BEGIN KEY-----'],
        privateKeyPassphrase: 'phrase',
        root: '/remote',
        throw_: true,
        readOnly: true,
        directorySeparator: '\\',
        timeout: Duration(seconds: 30),
        connectTimeout: Duration(seconds: 5),
      );

      final restored = SftpConfig.fromMap(original.toMap());

      expect(restored.host, original.host);
      expect(restored.port, original.port);
      expect(restored.username, original.username);
      expect(restored.password, original.password);
      expect(restored.privateKeyPems, original.privateKeyPems);
      expect(restored.privateKeyPassphrase, original.privateKeyPassphrase);
      expect(restored.root, original.root);
      expect(restored.throw_, original.throw_);
      expect(restored.readOnly, original.readOnly);
      expect(restored.directorySeparator, original.directorySeparator);
      expect(restored.timeout, original.timeout);
      expect(restored.connectTimeout, original.connectTimeout);
    });
  });

  group('disk name', () {
    test('name returns null by default', () {
      expect(adapter.name, isNull);
    });

    test('diskName sets and returns the name', () {
      expect(adapter.diskName('mydisk'), same(adapter));
      expect(adapter.name, equals('mydisk'));
    });
  });
}
