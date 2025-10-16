## 0.1.0 (2025-10-16)

### Features
- **Laravel-Inspired Storage Facade**: High-level storage abstraction with familiar Laravel-style API
- **Multiple Storage Drivers**: Support for local filesystem and cloud storage backends
- **Cloud Storage Integration**: Seamless integration with S3-compatible services via `file_cloud`
- **Configuration-Driven Setup**: Flexible disk configuration with multiple backends
- **Signed URLs**: Generate secure temporary URLs for cloud storage access
- **File Visibility Controls**: Public/private access control for cloud files
- **Directory Operations**: Comprehensive directory management with recursive support
- **File Metadata**: Size, MIME type, checksum, and modification time support
- **Streaming Operations**: Efficient large file handling with stream APIs
- **Testing Support**: Built-in fake disks for easy unit testing
- **Scoped Disks**: Path-prefixed storage areas for multi-tenant applications
- **Custom Drivers**: Extensible architecture for custom storage backends

### API
- `Storage`: Static facade for storage operations
- `FilesystemManager`: Manages multiple storage disks and drivers
- `FilesystemAdapter`: Local filesystem implementation
- `CloudAdapter`: Cloud storage implementation using `file_cloud`
- `DiskConfig`: Configuration for storage disks
- `StorageConfig`: Global storage configuration

### Storage Operations
- **File Operations**: `get()`, `put()`, `delete()`, `exists()`, `copy()`, `move()`
- **Directory Operations**: `files()`, `directories()`, `makeDirectory()`, `deleteDirectory()`
- **Cloud Features**: `temporaryUrl()`, `temporaryUploadUrl()`, `getVisibility()`, `setVisibility()`
- **Utility Methods**: `size()`, `mimeType()`, `checksum()`, `lastModified()`
- **Batch Operations**: `putFile()`, `putFileAs()`, `delete()` with multiple paths

### Supported Storage Backends
- **Local Filesystem**: Full local file operations with visibility controls
- **Cloud Storage**: S3-compatible services (AWS S3, MinIO, Cloudflare R2, DigitalOcean Spaces)
- **Scoped Storage**: Path-prefixed areas within existing disks
- **Custom Drivers**: Extensible driver system for additional backends

### Configuration
- **Disk Configuration**: Multiple named disks with different drivers
- **Driver Options**: Flexible configuration for each storage backend
- **Default Disk**: Configurable default storage disk
- **Cloud Disk**: Designated cloud storage disk for advanced features

### Testing Features
- **Fake Disks**: In-memory testing disks that persist across tests
- **Persistent Fakes**: Fake disks that maintain state between test runs
- **Assertion Methods**: `assertExists()`, `assertMissing()`, `assertCount()`, `assertDirectoryEmpty()`
- **Cleanup**: Automatic test isolation and cleanup

### Examples
- Complete configuration examples for local and cloud storage
- Usage examples for all major features
- Testing examples with fake disks

### Breaking Changes
- None (initial release)

### Dependencies
- `file: ^7.0.1` - Dart filesystem interface
- `minio: ^3.5.8` - MinIO client library
- `path: ^1.9.1` - Path manipulation utilities
- `meta: ^1.17.0` - Metadata annotations
- `crypto: ^3.0.6` - Cryptographic functions
- `mime: ^2.0.0` - MIME type detection
- `convert: ^3.1.2` - Data conversion utilities
- `file_cloud` - Cloud filesystem backend (workspace dependency)
