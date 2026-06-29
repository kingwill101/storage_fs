# Changelog

## 0.2.1 (2026-06-29)

### Fixed
- **`SftpFile._toSftpMode` now includes read permission** for `FileMode.write`,
  `FileMode.writeOnly`, and `FileMode.append` modes. Previously these modes
  opened SFTP handles without read access, making it impossible to read from a
  `RandomAccessFile` opened for writing. This matches `dart:io`'s semantics
  where any writable handle also supports reads.
- Added unit tests verifying the open-mode flags include `SftpFileOpenMode.read`
  for all writable modes.

## 0.2.0 (2026-06-29)

### Features
- **package:file FileSystem implementation**: New `SftpFileSystem` implementing the standard `package:file` `FileSystem` interface
- **SftpFile**: Remote file operations (read, write, copy, rename, delete)
- **SftpDirectory**: Remote directory operations (create, list, rename, delete, recursive tree removal)
- **SftpLink**: Remote symbolic link operations (create, update, resolve, rename, delete)
- **SftpRandomAccessFile**: Offset-based random access read/write over SFTP
- **Connection flexibility**: Default constructor accepts optional `SftpClient` (immediate) or `SSHClient` (lazy SFTP derivation) from `dartssh2`

### API
- `SftpFileSystem`: `FileSystem` implementation with three constructors (config, fromClient, fromSftpFs)
- `SftpFileSystemEntity`: Abstract base for file/directory/link entities
- `SftpFile`: `File` implementation for remote files
- `SftpDirectory`: `Directory` implementation for remote directories
- `SftpLink`: `Link` implementation for remote symbolic links
- `SftpRandomAccessFile`: `RandomAccessFile` implementation with offset-based positioning
- `SftpFileSystem(config, client:)`: Pass an existing `SftpClient` to the default constructor
- `SftpFileSystem(config, sshClient:)`: Pass an existing `SSHClient` for lazy SFTP session derivation

### Constraints
- Async-only: All `*Sync()` methods throw `UnsupportedError`
- Read-only guard: All write operations check `SftpConfig.readOnly`
- Error handling: All failures throw `FileSystemException` (no `throw_` toggle)
- File watching not supported
- File locking not supported
- Temporary directories not supported

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
