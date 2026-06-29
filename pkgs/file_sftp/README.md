# file_sftp

SFTP/SSH filesystem adapter for [`storage_fs`](https://pub.dev/packages/storage_fs). Enables file operations over SSH/SFTP using the `dartssh2` package.

[![pub package](https://img.shields.io/pub/v/file_sftp.svg)](https://pub.dev/packages/file_sftp)
[![Dart](https://img.shields.io/badge/dart-%3E%3D3.0.0-blue.svg)](https://dart.dev/)
[![License](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)

## Features

- Full filesystem operations over SSH/SFTP
- Same `Filesystem` interface as other `storage_fs` adapters
- Password and private key authentication
- Non-blocking I/O for all operations
- Strongly typed `SftpConfig` and `SftpDisk` classes
- `SftpFs`/`SftpFsFile` abstraction layer enables easy mocking
- Register as a named disk via `SftpDisk`

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  file_sftp: ^0.1.0
```

## Quick Start

```dart
import 'package:storage_fs/storage_fs.dart';
import 'package:file_sftp/file_sftp.dart';

Future<void> main() async {
  final disk = SftpDisk(
    driver: 'sftp',
    config: SftpConfig(
      host: 'your-server.com',
      port: 22,
      username: 'user',
      password: 'password',
      root: '/remote/path',
    ),
  );

  Storage.extend('sftp', () => SftpFilesystemAdapter(disk.config));

  Storage.initialize(
    defaultDisk: 'sftp',
    disks: [disk],
  );

  await Storage.put('hello.txt', 'Hello, World!');

  final content = await Storage.get('hello.txt');
  print(content);

  await Storage.delete('hello.txt');
}
```

## Configuration

### Basic SFTP Disk

```dart
final disk = SftpDisk(
  driver: 'sftp',
  config: const SftpConfig(
    host: 'your-server.com',
    port: 22,
    username: 'user',
    password: 'password',
    root: '/remote/path',
    throw_: false,
  ),
);
```

### SSH Key Authentication

```dart
final disk = SftpDisk(
  driver: 'sftp',
  config: SftpConfig(
    host: 'your-server.com',
    port: 22,
    username: 'user',
    privateKeyPems: [
      '''
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
''',
    ],
    privateKeyPassphrase: 'passphrase',
    root: '/remote/path',
  ),
);
```

### Multiple Disks

```dart
Storage.initialize(
  defaultDisk: 'sftp',
  disks: [
    SftpDisk(
      driver: 'sftp',
      config: SftpConfig(
        host: 'prod-server.com',
        username: 'user',
        password: 'password',
        root: '/var/www',
      ),
    ),
  ],
);
```

### Configuration Options

| Option              | Type             | Description                                   |
|---------------------|------------------|-----------------------------------------------|
| `host`              | `String`         | Remote SSH host address                       |
| `port`              | `int`            | SSH port (default: `22`)                      |
| `username`          | `String`         | SSH username                                  |
| `password`          | `String?`        | Password for authentication                   |
| `privateKeyPems`    | `List<String>?`  | PEM-encoded private keys                      |
| `privateKeyPassphrase` | `String?`     | Passphrase for encrypted private keys         |
| `root`              | `String?`        | Remote root path prefix                       |
| `throw`             | `bool`           | Throw exceptions on errors (default: `false`) |
| `readOnly`          | `bool`           | Mount as read-only (default: `false`)         |
| `connectTimeout`    | `Duration?`      | Socket connect timeout                        |

## Usage

### Basic File Operations

```dart
await Storage.put('file.txt', 'Hello World');
await Storage.put('data.bin', <int>[1, 2, 3, 4]);

final content = await Storage.get('file.txt');

if (await Storage.exists('file.txt')) {
  print('File exists!');
}

await Storage.delete('file.txt');
await Storage.delete(['file1.txt', 'file2.txt']);
```

### File Metadata

```dart
final size = await Storage.size('file.txt');
final modified = await Storage.lastModified('file.txt');
final mimeType = await Storage.mimeType('image.jpg');
```

### Directory Operations

```dart
await Storage.makeDirectory('uploads/images');

final files = await Storage.files('uploads');
final allFiles = await Storage.allFiles('uploads');
final dirs = await Storage.directories('uploads');

await Storage.deleteDirectory('temp');
```

### Copy and Move

```dart
await Storage.copy('original.txt', 'copy.txt');
await Storage.move('old-name.txt', 'new-name.txt');
```

### Append and Prepend

```dart
await Storage.put('log.txt', 'Initial log entry');
await Storage.append('log.txt', 'Another entry', separator: '\n');
await Storage.prepend('log.txt', 'First entry', separator: '\n');
```

### File Visibility

```dart
await Storage.setVisibility('public-file.jpg', 'public');
await Storage.setVisibility('private-data.pdf', 'private');

final visibility = await Storage.getVisibility('file.txt');
```

### Direct Adapter Usage

```dart
import 'package:file_sftp/file_sftp.dart';

final adapter = SftpFilesystemAdapter(
  SftpConfig(
    host: 'server.com',
    username: 'user',
    password: 'password',
  ),
);

await adapter.put('remote/path/file.txt', 'hello');
await adapter.disconnect();
```

## Architecture

```
file_sftp
└── lib
    └── src
        ├── sftp_config.dart              # SftpConfig (connection parameters)
        ├── sftp_disk.dart                # SftpDisk (typed Disk implementation)
        ├── sftp_fs.dart                  # SftpFs / SftpFsFile (abstraction interfaces)
        ├── sftp_fs_client.dart           # SftpFsClient / SftpFsFileHandle (dartssh2 wrappers)
        ├── sftp_filesystem_adapter.dart  # SftpFilesystemAdapter (Filesystem implementation)
        └── file_sftp.dart                # Barrel export (public API)
```

The `SftpFs` and `SftpFsFile` abstract interfaces decouple the adapter from `dartssh2`, enabling mock-based unit testing and future transport implementations.

## Testing

### Unit Tests (Mocking)

Use the `SftpFs` abstraction to mock SFTP operations:

```dart
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:file_sftp/file_sftp.dart';

class MockSftpFs extends Mock implements SftpFs {}

void main() {
  setUpAll(() {
    registerFallbackValue(SftpFileOpenMode.read);
    registerFallbackValue(SftpFileAttrs());
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(Stream<List<int>>.empty());
  });

  test('exists returns true when stat succeeds', () async {
    final mockFs = MockSftpFs();
    when(() => mockFs.stat('/foo.txt'))
        .thenAnswer((_) async => SftpFileAttrs());

    final adapter = SftpFilesystemAdapter.fromSftpFs(
      mockFs,
      config: () => const SftpConfig(host: '', username: '', root: '/'),
    );

    expect(await adapter.exists('/foo.txt'), isTrue);
  });
}
```

### Integration Tests (Docker)

Set up a real SFTP server using Docker:

```yaml
# test/fixtures/docker-compose.yaml
services:
  sftp:
    image: atmoz/sftp:latest
    ports:
      - "2222:22"
    command: testuser:testpass:1001:1000:upload
```

```dart
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:file_sftp/file_sftp.dart';
import 'package:test/test.dart';

void main() {
  test('integration: write and read via real SFTP', () async {
    await Process.run('docker', [
      'compose', '-f', 'test/fixtures/docker-compose.yaml', 'up', '-d',
    ]);
    await Future.delayed(const Duration(seconds: 5));

    final port = 2222;

    final adapter = SftpFilesystemAdapter(SftpConfig(
      host: 'localhost',
      port: port,
      username: 'testuser',
      password: 'testpass',
      root: '/upload',
    ));

    try {
      await adapter.put('test.txt', 'hello from sftp');
      expect(await adapter.exists('test.txt'), isTrue);
      expect(await adapter.get('test.txt'), equals('hello from sftp'));
      await adapter.delete('test.txt');
    } finally {
      await adapter.disconnect();
    }
  });
}
```

## Supported Storage Backends

- `LocalDisk` — Local filesystem (via `storage_fs`)
- `S3Disk` — S3-compatible cloud storage (via `storage_fs`)
- `SftpDisk` — SFTP/SSH remote filesystem (via `file_sftp`)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
