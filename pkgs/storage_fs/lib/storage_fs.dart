/// A filesystem abstraction library for Dart, inspired by Laravel's Storage facade.
///
/// This library provides a unified API for working with different storage backends
/// including local filesystem and cloud storage (S3-compatible services like AWS S3,
/// Cloudflare R2, MinIO, and others).
///
/// ## Features
///
/// * **Multiple storage drivers**: Local filesystem, S3-compatible cloud storage
/// * **Unified API**: Same interface for all storage backends
/// * **Laravel-inspired**: Familiar API for PHP/Laravel developers
/// * **Signed URLs**: Generate temporary URLs for cloud storage
/// * **Configurable**: Easy configuration with multiple disk support
///
/// ## Getting Started
///
/// First, initialize the storage system with your configuration:
///
/// ```dart
/// import 'package:storage_fs/storage_fs.dart';
///
/// void main() {
///   Storage.initialize({
///     'default': 'local',
///     'disks': {
///       'local': {
///         'driver': 'local',
///         'root': '/path/to/storage',
///       },
///       's3': {
///         'driver': 's3',
///         'options': {
///           'endpoint': 'your-endpoint.com',
///           'key': 'your-access-key',
///           'secret': 'your-secret-key',
///           'bucket': 'your-bucket',
///         },
///       },
///     },
///   });
/// }
/// ```
///
/// ## Basic Usage
///
/// Once initialized, use the [Storage] facade to interact with files:
///
/// ```dart
/// // Write a file
/// await Storage.put('hello.txt', 'Hello, World!');
///
/// // Read a file
/// final content = await Storage.get('hello.txt');
///
/// // Check if a file exists
/// if (await Storage.exists('hello.txt')) {
///   print('File exists!');
/// }
///
/// // Delete a file
/// await Storage.delete('hello.txt');
/// ```
///
/// ## Working with Different Disks
///
/// You can work with specific storage disks:
///
/// ```dart
/// // Use the default disk
/// await Storage.put('file.txt', 'content');
///
/// // Use a specific disk
/// await Storage.disk('s3').put('file.txt', 'content');
///
/// // Use the cloud disk
/// await Storage.cloud().put('file.txt', 'content');
/// ```
///
/// ## Cloud Storage Features
///
/// Generate temporary signed URLs for secure file access:
///
/// ```dart
/// final url = await Storage.getTemporaryUrl(
///   'private-file.pdf',
///   DateTime.now().add(Duration(hours: 1)),
/// );
/// print('Download URL (valid for 1 hour): $url');
/// ```
///
/// ## Directory Operations
///
/// ```dart
/// // List files in a directory
/// final files = await Storage.files('documents');
///
/// // List all files recursively
/// final allFiles = await Storage.allFiles('documents');
///
/// // Create a directory
/// await Storage.makeDirectory('uploads');
///
/// // Delete a directory
/// await Storage.deleteDirectory('uploads');
/// ```
///
/// See also:
///
/// * [Storage] - The main facade for interacting with storage
/// * [Filesystem] - The filesystem contract interface
/// * [Cloud] - The cloud storage contract interface
library;

export 'src/storage.dart';
export 'src/filesystem_manager.dart';
export 'src/config/disk_config.dart';
export 'src/config/storage_config.dart';
export 'src/contracts/filesystem.dart';
export 'src/contracts/cloud.dart';
export 'src/contracts/factory.dart';
export 'src/adapters/filesystem_adapter.dart';
export 'src/adapters/cloud_adapter.dart';
export 'src/exceptions/filesystem_exception.dart';
