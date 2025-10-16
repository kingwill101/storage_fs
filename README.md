# Filesystem

A comprehensive cloud storage solution for Dart, providing both low-level filesystem primitives and high-level storage abstractions for S3-compatible cloud services.

[![pub package](https://img.shields.io/pub/v/storage_fs.svg?label=storage_fs)](https://pub.dev/packages/storage_fs)
[![pub package](https://img.shields.io/pub/v/file_cloud.svg?label=file_cloud)](https://pub.dev/packages/file_cloud)
[![Dart](https://img.shields.io/badge/dart-%3E%3D3.0.0-blue.svg)](https://dart.dev/)
[![License](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-support-yellow.svg)](https://www.buymeacoffee.com/kingwill101)

## Overview

This workspace contains two complementary packages that together provide a complete cloud storage ecosystem for Dart applications:

- **[file_cloud](pkgs/file_cloud/)** - Low-level cloud filesystem backend implementing the `file` package interface
- **[storage_fs](pkgs/storage_fs/)** - High-level storage abstraction with Laravel-inspired API


## Packages

### file_cloud

A low-level cloud filesystem library that provides direct access to S3-compatible object storage services. This package implements a cloud backend for the `file` package, enabling filesystem operations on cloud storage.

**Key Features:**
- 🚀 Low-level API with fine-grained control
- ☁️ File package backend implementation
- 📦 S3-compatible storage support
- 🎯 Familiar File/Directory/FileSystem APIs
- ⚡ Async-first design

**Use when you need:**
- Direct control over cloud storage operations
- Custom cloud storage drivers
- Integration with existing file-based code
- Maximum performance and flexibility

### storage_fs

A high-level storage abstraction library inspired by Laravel's Storage facade. Provides a unified API for working with local filesystems and cloud storage services.

**Key Features:**
- 🎨 Laravel-inspired Storage facade
- 🗂️ Multiple storage drivers (local, cloud)
- 🔐 Signed URLs for secure file access
- 👁️ File visibility controls
- 🧪 Testing support with fake disks
- ⚙️ Configuration-driven setup

**Use when you need:**
- Simple, expressive storage API
- Multiple storage backends
- Laravel-style development experience
- Built-in testing utilities

## Installation

### Individual Packages

Install packages individually as needed:

```bash
# For low-level cloud filesystem access
dart pub add file_cloud

# For high-level storage abstraction
dart pub add storage_fs
```

## Quick Start

### Using file_cloud (Low-level)

```dart
import 'package:file_cloud/file_cloud.dart';
import 'package:minio/minio.dart';

final minio = Minio(
  endPoint: 'localhost',
  port: 9000,
  accessKey: 'minioadmin',
  secretKey: 'minioadmin',
  useSSL: false,
);

final driver = MinioCloudDriver(
  client: minio,
  bucket: 'my-bucket',
  autoCreateBucket: true,
);

final fs = CloudFileSystem(driver: driver);
await fs.driver.ensureReady();

// Use familiar file APIs
await fs.file('hello.txt').writeAsString('Hello, Cloud!');
final content = await fs.file('hello.txt').readAsString();
```

### Using storage (High-level)

```dart
import 'package:storage_fs/storage_fs.dart';

Storage.initialize({
  'default': 'local',
  'disks': {
    'local': {
      'driver': 'local',
      'root': './storage',
    },
    's3': {
      'driver': 's3',
      'options': {
        'endpoint': 'my-endpoint.com',
        'key': 'access-key',
        'secret': 'secret-key',
        'bucket': 'my-bucket',
      },
    },
  },
});

// Simple, expressive API
await Storage.put('hello.txt', 'Hello, World!');
final content = await Storage.get('hello.txt');
await Storage.delete('hello.txt');
```

## Contributing

We welcome contributions! Please see the individual package READMEs for specific contribution guidelines.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by Laravel's Storage facade
- Built on the Dart `file` package ecosystem
- Powered by the MinIO Dart client
- Thanks to the Dart community for excellent packages

---

Made with ❤️ for the Dart ecosystem
