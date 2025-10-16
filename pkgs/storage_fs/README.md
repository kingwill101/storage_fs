# Storagefs

A powerful and flexible filesystem abstraction library for Dart, inspired by Laravel's Storage facade. Provides a unified API for working with local filesystems and cloud storage services.

[![Dart](https://img.shields.io/badge/dart-%3E%3D3.0.0-blue.svg)](https://dart.dev/)
[![License](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)

## Features

- 🗂️ **Unified API** - Same interface for local and cloud storage
- ☁️ **Cloud Storage** - Full support for S3-compatible services (AWS S3, Cloudflare R2, MinIO, etc.)
- 🔐 **Signed URLs** - Generate secure temporary URLs for cloud storage
- 👁️ **File Visibility** - Control public/private access with ACL support
- ⚡ **Async-First** - Built for efficient non-blocking I/O operations
- 🔧 **Type-Safe** - Strongly typed configuration and APIs
- 🧪 **Testing Support** - Built-in fake disks for easy testing
- 📦 **Laravel-Inspired** - Familiar API for PHP/Laravel developers
- 🎯 **Multiple Disks** - Configure and switch between multiple storage backends

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  storage_fs: ^0.1.0
```

Then run:

```bash
dart pub get
```

## MinIO (Local) Testing

Run a local S3-compatible MinIO server for cloud tests:

```bash
# Start MinIO with Docker
docker-compose up -d

# Or use the helper script (creates .env and starts services)
./setup-minio.sh
```

Set environment (or copy `.env.example` to `.env`):

```bash
cp .env.example .env
# defaults:
# MINIO_ENDPOINT=localhost:9000
# MINIO_ACCESS_KEY=minioadmin
# MINIO_SECRET_KEY=minioadmin
# MINIO_BUCKET=test-bucket
# MINIO_USE_SSL=false
```

Run cloud tests:

```bash
make test-cloud
# or
dart test test/cloud_test.dart
```

See MINIO_TESTING.md and QUICKSTART.md for a full walkthrough.

## Quick Start

```dart
import 'package:storage_fs/storage_fs.dart';

void main() async {
  // Initialize the storage system
  Storage.initialize({
    'default': 'local',
    'disks': {
      'local': {
        'driver': 'local',
        'root': './storage',
      },
    },
  });

  // Write a file
  await Storage.put('hello.txt', 'Hello, World!');

  // Read a file
  final content = await Storage.get('hello.txt');
  print(content); // Hello, World!

  // Check if file exists
  if (await Storage.exists('hello.txt')) {
    print('File exists!');
  }

  // Delete a file
  await Storage.delete('hello.txt');
}
```

## Configuration

### Local Filesystem

```dart
Storage.initialize({
  'default': 'local',
  'disks': {
    'local': {
      'driver': 'local',
      'root': './storage',
      'throw': false, // Whether to throw exceptions or return false
    },
  },
});
```

### Cloud Storage (S3-Compatible)

```dart
Storage.initialize({
  'default': 's3',
  'cloud': 's3',
  'disks': {
    's3': {
      'driver': 's3',
      'options': {
        'endpoint': 'your-endpoint.r2.cloudflarestorage.com',
        'key': 'your-access-key-id',
        'secret': 'your-secret-access-key',
        'bucket': 'your-bucket-name',
        'use_ssl': true,
        'region': 'auto', // Optional
      },
    },
  },
});
```

### Multiple Disks

```dart
Storage.initialize({
  'default': 'local',
  'cloud': 's3',
  'disks': {
    'local': {
      'driver': 'local',
      'root': './storage',
    },
    'public': {
      'driver': 'local',
      'root': './public',
    },
    's3': {
      'driver': 's3',
      'options': {
        'endpoint': 's3.amazonaws.com',
        'key': 'your-key',
        'secret': 'your-secret',
        'bucket': 'my-bucket',
        'use_ssl': true,
      },
    },
  },
});
```

## Usage

### Basic File Operations

```dart
// Write files
await Storage.put('file.txt', 'Hello World');
await Storage.put('data.bin', <int>[1, 2, 3, 4]);

// Read files
final content = await Storage.get('file.txt');
print(content);

// Read as stream (for large files)
final stream = Storage.readStream('large-file.bin');
await for (final chunk in stream!) {
  // Process chunk
}

// Check if file exists
if (await Storage.exists('file.txt')) {
  print('File exists!');
}

// Check if file is missing
if (await Storage.missing('file.txt')) {
  print('File not found');
}

// Delete files
await Storage.delete('file.txt');
await Storage.delete(['file1.txt', 'file2.txt', 'file3.txt']);
```

### File Metadata

```dart
// Get file size
final size = await Storage.size('file.txt');
print('Size: $size bytes');

// Get last modified time
final modified = await Storage.lastModified('file.txt');
print('Modified: $modified');

// Get MIME type
final mimeType = await Storage.mimeType('image.jpg');
print('MIME type: $mimeType'); // image/jpeg

// Get checksum
final checksum = await Storage.checksum('file.txt', algorithm: 'md5');
print('MD5: $checksum');
```

### Copy and Move Operations

```dart
// Copy a file
await Storage.copy('original.txt', 'copy.txt');

// Move/rename a file
await Storage.move('old-name.txt', 'new-name.txt');

// Upload local file
final path = await Storage.putFile('uploads', File('/tmp/photo.jpg'));
print('Uploaded to: $path'); // uploads/photo.jpg

// Upload with custom name
final customPath = await Storage.putFileAs(
  'uploads',
  File('/tmp/photo.jpg'),
  'avatar.jpg',
);
print('Uploaded to: $customPath'); // uploads/avatar.jpg
```

### Append and Prepend

```dart
// Append to file
await Storage.put('log.txt', 'Initial log entry');
await Storage.append('log.txt', 'Another log entry', separator: '\n');

// Prepend to file
await Storage.prepend('log.txt', 'First entry', separator: '\n');
```

### Directory Operations

```dart
// Create a directory
await Storage.makeDirectory('uploads/images');

// List files in directory
final files = await Storage.files('uploads');
for (final file in files) {
  print(file);
}

// List files recursively
final allFiles = await Storage.allFiles('uploads');

// List directories
final dirs = await Storage.directories('uploads');

// List directories recursively
final allDirs = await Storage.allDirectories('uploads');

// Delete directory
await Storage.deleteDirectory('temp');
```

### Working with Multiple Disks

```dart
// Use default disk
await Storage.put('file.txt', 'content');

// Use specific disk
final s3 = Storage.disk('s3');
await s3.put('file.txt', 'cloud content');

final local = Storage.disk('local');
await local.put('file.txt', 'local content');

// Use cloud disk directly
final cloud = Storage.cloud();
await cloud.put('file.txt', 'cloud content');
```

### Cloud Storage - Signed URLs

Generate secure, time-limited URLs for accessing private files:

```dart
// Check if disk supports temporary URLs
if (Storage.providesTemporaryUrls()) {

  // Generate temporary download URL (expires in 1 hour)
  final downloadUrl = await Storage.getTemporaryUrl(
    'private/document.pdf',
    DateTime.now().add(Duration(hours: 1)),
  );
  print('Download URL: $downloadUrl');

  // Generate temporary upload URL (expires in 30 minutes)
  final uploadData = await Storage.getTemporaryUploadUrl(
    'uploads/new-file.jpg',
    DateTime.now().add(Duration(minutes: 30)),
  );

  final url = uploadData['url'] as String;
  final headers = uploadData['headers'] as Map<String, String>;

  print('Upload to: $url');
  print('With headers: $headers');
}
```

### File Visibility (ACL)

Control whether files are publicly accessible:

```dart
// Set file as public
await Storage.setVisibility('public-file.jpg', 'public');

// Set file as private
await Storage.setVisibility('private-data.pdf', 'private');

// Get current visibility
final visibility = await Storage.getVisibility('file.txt');
print(visibility); // 'public' or 'private'

// Get public URL
final url = Storage.url('public-file.jpg');
print(url);
```

### Streaming Operations

For large files, use streaming to avoid memory issues:

```dart
// Write using stream
final inputStream = File('large-file.bin').openRead();
await Storage.writeStream('uploads/large-file.bin', inputStream);

// Read as stream
final outputStream = Storage.readStream('uploads/large-file.bin');
final file = File('downloaded.bin').openWrite();
await for (final chunk in outputStream!) {
  file.add(chunk);
}
await file.close();
```

## Testing

The storage library provides built-in support for testing:

```dart
import 'package:storage_fs/storage_fs.dart';
import 'package:test/test.dart';

void main() {
  test('file operations work correctly', () async {
    // Create a fake disk for testing
    Storage.fake();

    // All operations now use the fake disk
    await Storage.put('test.txt', 'test content');

    // Make assertions
    await Storage.assertExists('test.txt');
    await Storage.assertExists('test.txt', content: 'test content');
    await Storage.assertMissing('nonexistent.txt');

    // Assert file count
    await Storage.put('file1.txt', 'content');
    await Storage.put('file2.txt', 'content');
    await Storage.assertCount('.', 3); // test.txt, file1.txt, file2.txt

    // Assert directory is empty
    await Storage.makeDirectory('empty');
    await Storage.assertDirectoryEmpty('empty');
  });

  test('persistent fake disk', () async {
    // Use persistent fake to keep data between tests
    Storage.persistentFake();

    await Storage.put('persistent.txt', 'data');
    // Data persists in temp directory
  });
}
```

## Advanced Features

### Custom Temporary URL Builders

Customize how temporary URLs are generated:

```dart
Storage.buildTemporaryUrlsUsing((path, expiration, options) async {
  // Your custom logic here
  return 'https://custom.url/$path?expires=${expiration.millisecondsSinceEpoch}';
});

// Generate URL using custom builder
final url = await Storage.getTemporaryUrl('file.txt', DateTime.now().add(Duration(hours: 1)));
```

### Reading JSON Files

```dart
// Read and parse JSON file
final data = await Storage.json('config.json');
print(data['version']);
```

### Error Handling

```dart
try {
  await Storage.put('file.txt', 'content');
} catch (e) {
  print('Error: $e');
}

// Or configure to return false instead of throwing
Storage.initialize({
  'default': 'local',
  'disks': {
    'local': {
      'driver': 'local',
      'root': './storage',
      'throw': false, // Returns false on error instead of throwing
    },
  },
});

final success = await Storage.put('file.txt', 'content');
if (!success) {
  print('Failed to write file');
}
```

## Supported Storage Backends

### Local Filesystem

Uses Dart's native `file` package for local filesystem operations.

**Features:**
- Full read/write access
- Directory operations
- Metadata support
- Fast and efficient

### S3-Compatible Cloud Storage

Works with any S3-compatible storage service:

**Supported Services:**
- Amazon S3
- Cloudflare R2
- MinIO
- DigitalOcean Spaces
- Wasabi
- Backblaze B2 (S3-compatible API)

**Features:**
- Signed URLs (presigned URLs)
- Public/private ACL
- Metadata support
- Streaming uploads/downloads

## API Reference

### Storage Facade Methods

#### Initialization
- `Storage.initialize(config)` - Initialize with configuration
- `Storage.disk([name])` - Get filesystem instance
- `Storage.cloud()` - Get cloud filesystem instance

#### File Operations
- `Storage.get(path)` - Read file content
- `Storage.put(path, contents)` - Write file content
- `Storage.exists(path)` - Check if file exists
- `Storage.missing(path)` - Check if file is missing
- `Storage.delete(paths)` - Delete file(s)
- `Storage.copy(from, to)` - Copy file
- `Storage.move(from, to)` - Move/rename file

#### File Metadata
- `Storage.size(path)` - Get file size
- `Storage.lastModified(path)` - Get last modified time
- `Storage.mimeType(path)` - Get MIME type
- `Storage.checksum(path)` - Get file checksum

#### Directory Operations
- `Storage.files(directory)` - List files
- `Storage.allFiles(directory)` - List files recursively
- `Storage.directories(directory)` - List directories
- `Storage.allDirectories(directory)` - List directories recursively
- `Storage.makeDirectory(path)` - Create directory
- `Storage.deleteDirectory(path)` - Delete directory

#### Cloud Storage
- `Storage.url(path)` - Get public URL
- `Storage.getTemporaryUrl(path, expiration)` - Get signed URL
- `Storage.getTemporaryUploadUrl(path, expiration)` - Get upload URL
- `Storage.providesTemporaryUrls()` - Check if supported
- `Storage.getVisibility(path)` - Get visibility
- `Storage.setVisibility(path, visibility)` - Set visibility

#### Testing
- `Storage.fake([disk, config])` - Create fake disk
- `Storage.persistentFake([disk, config])` - Create persistent fake
- `Storage.assertExists(path)` - Assert file exists
- `Storage.assertMissing(path)` - Assert file missing
- `Storage.assertCount(path, count)` - Assert file count
- `Storage.assertDirectoryEmpty(path)` - Assert directory empty

## Examples

Check the `example/` directory for complete examples:

- `example.dart` - Basic usage examples
- `s3_example.dart` - Cloud storage with S3
- `comprehensive_example.dart` - Advanced features
- `config_example.dart` - Configuration patterns

## Testing

Run all tests:

```bash
dart test
```

Run specific test suites:

```bash
# Local filesystem tests
dart test test/storage_test.dart

# Cloud storage tests
dart test test/cloud_comprehensive_test.dart

# Configuration tests
dart test test/config_test.dart
```

## Performance Considerations

- Use streaming operations for large files (`readStream`, `writeStream`)
- Enable compression for cloud uploads when appropriate
- Use signed URLs for direct client uploads to reduce server load
- Consider using multiple disks for different types of content
- Cache file metadata when making multiple checks

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by [Laravel's Storage facade](https://laravel.com/docs/filesystem)
- Built on top of the [file](https://pub.dev/packages/file) package
- Uses [minio](https://pub.dev/packages/minio) for S3-compatible storage

## Support

- 📖 [API Documentation](https://pub.dev/documentation/storage/latest/)
- 🐛 [Issue Tracker](https://github.com/yourusername/storage/issues)
- 💬 [Discussions](https://github.com/yourusername/storage/discussions)

## Roadmap

- [ ] Azure Blob Storage support
- [ ] Google Cloud Storage support
- [ ] FTP/SFTP support
- [ ] Encryption at rest
- [ ] File versioning
- [ ] Webhook support for cloud events
- [ ] CDN integration helpers

---

Made with ❤️ for the Dart community
