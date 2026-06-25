/// SFTP/SSH filesystem adapter for [storage_fs].
///
/// Provides [Disk] and [Filesystem] implementations backed by the `dartssh2`
/// package, enabling file operations over SSH/SFTP.
library;

export 'src/sftp_config.dart';
export 'src/sftp_filesystem_adapter.dart';
export 'src/sftp_disk.dart';
