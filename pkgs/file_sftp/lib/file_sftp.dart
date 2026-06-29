/// SFTP/SSH filesystem adapter for [storage_fs] and [package:file].
///
/// This library provides two sets of SFTP-backed filesystem abstractions:
///
/// ## Legacy adapter ([SftpFilesystemAdapter], [SftpDisk])
///
/// Bridges the [storage_fs] package's [Disk] and [Filesystem] interfaces to
/// SFTP. These classes predate the [package:file] implementation and are
/// maintained for backward compatibility.
///
/// ## Package:file implementation ([SftpFileSystem] and entity types)
///
/// A direct implementation of [package:file]'s [FileSystem] interface that
/// enables remote SFTP file operations through the standard Dart filesystem
/// API. The following types are provided:
///
/// - [SftpFileSystem] — the root [FileSystem] implementation
/// - [SftpFile] — a remote file ([File])
/// - [SftpDirectory] — a remote directory ([Directory])
/// - [SftpLink] — a remote symbolic link ([Link])
/// - [SftpRandomAccessFile] — random-access read/write ([RandomAccessFile])
/// - [SftpConfig] — connection and behavior configuration
///
/// All I/O operations are asynchronous; synchronous variants throw
/// [UnsupportedError].
///
/// ## Usage
///
/// ```dart
/// import 'package:file_sftp/file_sftp.dart';
///
/// final fs = SftpFileSystem(SftpConfig(
///   host: 'example.com',
///   username: 'user',
///   password: 'pass',
///   root: '/var/data',
/// ));
///
/// final file = fs.file('config.json');
/// final contents = await file.readAsString();
/// print(contents);
///
/// await fs.disconnect();
/// ```
library;

export 'src/sftp_config.dart';
export 'src/sftp_fs.dart';
export 'src/sftp_filesystem_adapter.dart';
export 'src/sftp_disk.dart';
export 'src/sftp_file_system.dart';
export 'src/sftp_file_system_entity.dart';
export 'src/sftp_file.dart';
export 'src/sftp_directory.dart';
export 'src/sftp_link.dart';
export 'src/sftp_random_access_file.dart';
