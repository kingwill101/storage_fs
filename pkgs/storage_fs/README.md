# Storagefs

A powerful and flexible filesystem abstraction library for Dart, inspired by Laravel's Storage facade. Provides a unified API for working with local filesystems and cloud storage services.

[![pub package](https://img.shields.io/pub/v/storage_fs.svg)](https://pub.dev/packages/storage_fs)
[![Dart](https://img.shields.io/badge/dart-%3E%3D3.0.0-blue.svg)](https://dart.dev/)
[![License](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-support-yellow.svg)](https://www.buymeacoffee.com/kingwill101)

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

## Examples

Check the `example/` directory for complete examples:


## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by [Laravel's Storage facade](https://laravel.com/docs/filesystem)
- Built on top of the [file](https://pub.dev/packages/file) package
- Uses [minio](https://pub.dev/packages/minio) for S3-compatible storage

## Support

- 📖 [API Documentation](https://pub.dev/documentation/storage_fs/latest/)
- 🐛 [Issue Tracker](https://github.com/kingwill101/storage_fs/issues)
- 💬 [Discussions](https://github.com/kingwill101/storage_fs/discussions)



---

Made with ❤️ for the Dart community
