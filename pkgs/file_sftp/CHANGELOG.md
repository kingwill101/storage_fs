# Changelog

## 0.1.1 (2026-06-25)

### Notes
- Patch release to align dependency on `storage_fs: ^0.2.0`

## 0.1.0 (2026-06-25)

### Features
- **SFTP Filesystem Adapter**: Full `Filesystem` implementation over SFTP via dartssh2
- **Typed Disk Support**: `SftpDisk` extends `Disk` for integration with `Storage.initialize()`
- **Connection Flexibility**: Accepts pre-connected `SftpClient` or connection params (host, port, username, password)
- **Built-in Driver Registration**: `SftpFilesystemAdapter.register()` registers as a storage driver
- **Abstraction Layer**: `SftpFs`/`SftpFsFile` interfaces for testability
- **Mock Testing**: mocktail-based unit tests via `SftpFs` abstraction
- **Integration Tests**: Docker-based SFTP integration tests using testcontainers_compose

### API
- `SftpConfig`: Connection and behavior configuration
- `SftpDisk`: Typed disk configuration for `Storage.initialize()`
- `SftpFilesystemAdapter`: Main adapter implementing the `Filesystem` interface
- `SftpFs` / `SftpFsFile`: Abstract interfaces decoupled from dartssh2
- `SftpFsClient` / `SftpFsFileHandle`: Dartssh2-backed implementations

### Operations Supported
- File: `get`, `put`, `delete`, `exists`, `missing`, `copy`, `move`
- Streams: `readStream`, `writeStream`
- Directories: `makeDirectory`, `deleteDirectory`, `files`, `directories`
- Metadata: `size`, `mimeType`, `checksum`, `lastModified`
- Visibility: `getVisibility`, `setVisibility`
- Advanced: `prepend`, `append`

### Dependencies
- `storage_fs: ^0.2.0`
- `dartssh2: ^2.18.0`
- `path: ^1.9.1`
- `convert: ^3.1.2`
- `crypto: ^3.0.6`
- `mime: ^2.0.0`
- `meta: ^1.17.0`
