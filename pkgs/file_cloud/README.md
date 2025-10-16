# file_cloud

A low-level cloud filesystem library for Dart that provides direct access to S3-compatible object storage services like AWS S3, MinIO, Cloudflare R2, and DigitalOcean Spaces. This package implements a cloud backend for the file package, enabling filesystem operations on cloud storage.

[![Dart](https://img.shields.io/badge/dart-%3E%3D3.0.0-blue.svg)](https://dart.dev/)
[![License](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)

## Overview

`file_cloud` provides the foundational primitives for working with cloud object storage in Dart. Unlike higher-level storage abstractions, this package gives you direct, fine-grained control over cloud filesystem operations.

**Key Characteristics:**
- ☁️ **File Package Backend** - Implements `FileSystem` interface for cloud storage
- 🚀 **Low-level API** - Direct access to cloud storage primitives
- 🔧 **Fine-grained control** - No abstractions, just the filesystem you need
- 📦 **S3-compatible** - Works with any S3-compatible service
- 🎯 **Filesystem interface** - Familiar `File`, `Directory`, and `FileSystem` APIs
- ⚡ **Async-first** - Built for efficient non-blocking I/O

## Features

- **Cloud Filesystem Implementation** - Full `FileSystem` interface for cloud storage
- **S3-Compatible Drivers** - Built-in support for MinIO and S3-compatible services
- **File Operations** - Read, write, copy, move, and delete files
- **Directory Operations** - List, create, and delete directories
- **Streaming Support** - Efficient large file handling with streams
- **Signed URLs** - Generate temporary access URLs
- **Metadata Support** - File size, modification time, MIME types
- **Path Normalization** - POSIX-style path handling

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  file_cloud: ^1.0.0
```

Then run:

```bash
dart pub get
```

## Quick Start

```dart
import 'package:file_cloud/file_cloud.dart';
import 'package:minio/minio.dart';

Future<void> main() async {
  // Create a MinIO client
  final minio = Minio(
    endPoint: 'localhost',
    port: 9000,
    accessKey: 'minioadmin',
    secretKey: 'minioadmin',
    useSSL: false,
  );

  // Create the cloud driver
  final driver = MinioCloudDriver(
    client: minio,
    bucket: 'my-bucket',
    autoCreateBucket: true,
  );

  // Create the filesystem
  final fs = CloudFileSystem(driver: driver);

  // Ensure the backend is ready
  await fs.driver.ensureReady();

  // Write a file
  await fs.file('hello.txt').writeAsString('Hello, Cloud!');

  // Read it back
  final content = await fs.file('hello.txt').readAsString();
  print(content); // Hello, Cloud!

  // Clean up
  await fs.file('hello.txt').delete();
}
```

## Usage

### File Operations

```dart
// Write text files
await fs.file('docs/readme.txt').writeAsString('Documentation content');

// Write binary files
await fs.file('images/logo.png').writeAsBytes(imageBytes);

// Read files
final content = await fs.file('docs/readme.txt').readAsString();
final bytes = await fs.file('images/logo.png').readAsBytes();

// Check if file exists
if (await fs.file('docs/readme.txt').exists()) {
  print('File exists!');
}

// Get file metadata
final size = await fs.file('large-file.zip').length();
final modified = await fs.file('large-file.zip').lastModified();
final mimeType = await fs.file('image.jpg').mimeType;

// Copy and move files
await fs.file('source.txt').copy('destination.txt');
await fs.file('old-name.txt').rename('new-name.txt');

// Delete files
await fs.file('temp.txt').delete();
```

### Directory Operations

```dart
// Create directories
await fs.directory('uploads/images').create(recursive: true);

// List directory contents
final uploads = fs.directory('uploads');
await for (final entity in uploads.list()) {
  if (entity is CloudFile) {
    print('File: ${entity.path}');
  } else if (entity is CloudDirectory) {
    print('Directory: ${entity.path}');
  }
}

// List recursively
await for (final entity in uploads.list(recursive: true)) {
  print(entity.path);
}

// Delete directories
await fs.directory('temp').delete(recursive: true);
```

### Streaming Operations

```dart
// Stream large files for efficient memory usage
final stream = fs.file('large-video.mp4').openRead();
await for (final chunk in stream) {
  // Process chunk
}

// Write streams
final inputStream = File('local-file.mp4').openRead();
await fs.file('uploaded.mp4').writeAsStream(inputStream);
```

### Signed URLs

```dart
// Generate temporary download URLs
final downloadUrl = await fs.driver.presignDownload(
  'private/document.pdf',
  Duration(hours: 1),
);

// Generate temporary upload URLs
final upload = await fs.driver.presignUpload(
  'uploads/file.pdf',
  Duration(minutes: 30),
);

print('Upload to: ${upload.url}');
print('With headers: ${upload.headers}');
```

### Public URLs

```dart
// Get public URLs (depends on bucket configuration)
final publicUrl = fs.driver.publicUrl('public/image.jpg');
if (publicUrl != null) {
  print('Public URL: $publicUrl');
}
```

## API Overview

### Core Classes

- **`CloudFileSystem`** - The main filesystem implementation
- **`CloudFile`** - Represents a file in cloud storage
- **`CloudDirectory`** - Represents a directory in cloud storage
- **`CloudLink`** - Symbolic link support (throws `UnsupportedError`)
- **`MinioCloudDriver`** - S3-compatible storage driver using MinIO

### Driver Interface

- **`CloudStorageDriver`** - Abstract interface for storage backends
- **`CloudStorageStat`** - File/directory metadata
- **`CloudStorageItem`** - Items returned from directory listings
- **`CloudPresignedUpload`** - Pre-signed upload configuration

## Configuration

### MinIO (Local Development)

```dart
final minio = Minio(
  endPoint: 'localhost',
  port: 9000,
  accessKey: 'minioadmin',
  secretKey: 'minioadmin',
  useSSL: false,
);

final driver = MinioCloudDriver(
  client: minio,
  bucket: 'test-bucket',
  autoCreateBucket: true, // Creates bucket if it doesn't exist
);
```

### AWS S3

```dart
final minio = Minio(
  endPoint: 's3.amazonaws.com',
  accessKey: 'AKIA...',
  secretKey: 'your-secret-key',
  useSSL: true,
);

final driver = MinioCloudDriver(
  client: minio,
  bucket: 'my-s3-bucket',
);
```

### Cloudflare R2

```dart
final minio = Minio(
  endPoint: 'your-account-id.r2.cloudflarestorage.com',
  accessKey: 'your-r2-access-key',
  secretKey: 'your-r2-secret-key',
  useSSL: true,
);

final driver = MinioCloudDriver(
  client: minio,
  bucket: 'my-r2-bucket',
);
```

### DigitalOcean Spaces

```dart
final minio = Minio(
  endPoint: 'nyc3.digitaloceanspaces.com',
  accessKey: 'your-spaces-key',
  secretKey: 'your-spaces-secret',
  useSSL: true,
);

final driver = MinioCloudDriver(
  client: minio,
  bucket: 'my-space',
);
```

## Custom Drivers

While `file_cloud` includes a `MinioCloudDriver` for S3-compatible services, you can implement custom drivers for other cloud storage providers by implementing the `CloudStorageDriver` interface.

### Implementing a Custom Driver

```dart
import 'package:file_cloud/file_cloud.dart';

class MyCloudDriver implements CloudStorageDriver {
  // Constructor with your service credentials
  MyCloudDriver({required this.apiKey, required this.bucket});

  final String apiKey;
  final String bucket;

  @override
  String get rootPrefix => ''; // Optional path prefix

  @override
  Future<void> ensureReady() async {
    // Initialize connection, create bucket if needed, etc.
    // Throw exceptions if setup fails
  }

  @override
  Future<CloudStorageStat?> stat(String path) async {
    // Return metadata for the file/directory at path
    // Return null if it doesn't exist
    // For directories, check if any objects exist under the path
  }

  @override
  Stream<CloudStorageItem> list(String prefix, {bool recursive = false}) async* {
    // Yield CloudStorageItem objects for each file/directory
    // Use 'recursive' to control depth
  }

  @override
  Future<void> upload(
    String path,
    Stream<List<int>> data, {
    int? length,
    Map<String, String>? metadata,
  }) async {
    // Upload the data stream to the specified path
    // Handle metadata if supported by your service
  }

  @override
  Future<Stream<List<int>>> download(String path) async {
    // Return a stream of bytes for the file content
  }

  @override
  Future<Stream<List<int>>> downloadRange(
    String path, {
    int? start,
    int? end,
  }) async {
    // Return a stream for a byte range (optional optimization)
    // Fall back to download(path) if not supported
  }

  @override
  Future<void> delete(String path) async {
    // Delete the file at path
  }

  @override
  Future<void> deleteMany(Iterable<String> paths) async {
    // Delete multiple files efficiently (optional)
    // Default implementation calls delete() for each path
  }

  @override
  Future<void> copy(String from, String to) async {
    // Copy file from one path to another
  }

  @override
  Uri? publicUrl(String path) {
    // Return a public URL if your service supports it
    // Return null otherwise
  }

  @override
  bool get supportsTemporaryUrls => true; // or false

  @override
  Future<String?> presignDownload(
    String path,
    Duration expires, {
    Map<String, dynamic>? options,
  }) async {
    // Generate a temporary download URL
    // Return null if not supported
  }

  @override
  Future<CloudPresignedUpload?> presignUpload(
    String path,
    Duration expires, {
    Map<String, dynamic>? options,
  }) async {
    // Generate a temporary upload URL with headers
    // Return null if not supported
  }
}
```

### Using a Custom Driver

```dart
// Create your custom driver
final driver = MyCloudDriver(apiKey: 'your-key', bucket: 'my-bucket');

// Create the filesystem
final fs = CloudFileSystem(driver: driver);

// Use it like any other cloud filesystem
await fs.driver.ensureReady();
await fs.file('test.txt').writeAsString('Hello from custom driver!');
```

### Driver Requirements

- **Async Operations**: All methods must be asynchronous
- **Path Handling**: Use POSIX-style paths (forward slashes)
- **Error Handling**: Throw descriptive exceptions on failure
- **Stream Support**: Handle large files efficiently with streams
- **Optional Features**: Return `null` or `false` for unsupported features


## Limitations

- **No sync operations** - All operations are asynchronous
- **No file watching** - Cloud storage doesn't support real-time notifications
- **No symbolic links** - Most cloud storage doesn't support symlinks
- **No permissions** - Cloud storage has different permission models
- **Eventual consistency** - Some operations may not be immediately visible

## Related Packages

- **[file](https://pub.dev/packages/file)** - Standard Dart filesystem interface that `file_cloud` implements as a cloud backend
- **[storage](https://pub.dev/packages/storage_fs)** - High-level storage abstraction built on top of `file_cloud`
- **[minio](https://pub.dev/packages/minio)** - MinIO Dart client library

## Examples

Check the `example/` directory for complete examples:

- `file_cloud_example.dart` - Basic usage example

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
