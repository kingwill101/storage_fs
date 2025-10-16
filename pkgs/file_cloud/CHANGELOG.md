## 0.1.0 (2025-10-16)

### Features
- **Cloud Filesystem Implementation**: Full `FileSystem` interface implementation for cloud storage
- **MinIO Driver**: Built-in support for MinIO and S3-compatible cloud storage services
- **File Operations**: Complete file CRUD operations (create, read, update, delete)
- **Directory Operations**: Directory listing, creation, and deletion with recursive support
- **Streaming Support**: Efficient large file handling with `Stream<List<int>>` APIs
- **Signed URLs**: Generate temporary access URLs for secure file sharing
- **Metadata Support**: File size, modification time, MIME type detection
- **Path Normalization**: POSIX-style path handling for cross-platform compatibility
- **Async-First Design**: All operations are asynchronous for non-blocking I/O
- **Extensible Architecture**: `CloudStorageDriver` interface for custom cloud providers

### API
- `CloudFileSystem`: Main filesystem implementation
- `CloudFile`: File operations with familiar `File` interface
- `CloudDirectory`: Directory operations with familiar `Directory` interface
- `MinioCloudDriver`: S3-compatible storage driver
- `CloudStorageDriver`: Abstract interface for cloud storage backends

### Supported Cloud Providers
- AWS S3
- MinIO (self-hosted)
- Cloudflare R2
- DigitalOcean Spaces
- Any S3-compatible service

### Examples
- Complete example in `example/file_cloud_example.dart`
- Documentation with code samples for all major features

### Breaking Changes
- None (initial release)

### Dependencies
- `file: ^7.0.1` - Dart filesystem interface
- `minio: ^3.5.8` - MinIO client library
- `path: ^1.9.1` - Path manipulation utilities
- `http: ^1.5.0` - HTTP client
- `meta: ^1.17.0` - Metadata annotations
- `crypto: ^3.0.6` - Cryptographic functions
- `mime: ^2.0.0` - MIME type detection
- `convert: ^3.1.2` - Data conversion utilities
