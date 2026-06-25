import 'package:storage_fs/storage_fs.dart' as sf;
import 'sftp_config.dart';
import 'sftp_filesystem_adapter.dart';

/// Typed disk configuration for SFTP/SSH storage.
///
/// ```dart
/// Storage.initialize(
///   disks: [
///     SftpDisk(
///       name: 'remote',
///       host: 'example.com',
///       username: 'deploy',
///       password: 'secret',
///       root: '/var/www',
///     ),
///   ],
/// );
/// ```
class SftpDisk extends sf.Disk {
  @override
  final String name;

  final String host;

  final int port;

  final String username;

  final String? password;

  final String? privateKeyPem;

  final String? privateKeyPassphrase;

  @override
  final String? root;

  @override
  final bool throwExceptions;

  @override
  final bool readOnly;

  const SftpDisk({
    required this.name,
    required this.host,
    required this.username,
    this.port = 22,
    this.password,
    this.privateKeyPem,
    this.privateKeyPassphrase,
    this.root,
    this.throwExceptions = false,
    this.readOnly = false,
  });

  @override
  sf.Filesystem build() {
    return SftpFilesystemAdapter(
      SftpConfig(
        host: host,
        port: port,
        username: username,
        password: password,
        privateKeyPems:
            privateKeyPem != null ? [privateKeyPem!] : null,
        privateKeyPassphrase: privateKeyPassphrase,
        root: root,
        throw_: throwExceptions,
        readOnly: readOnly,
      ),
    );
  }
}
