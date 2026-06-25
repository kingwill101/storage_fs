/// Connection configuration for SFTP/SSH access.
class SftpConfig {
  /// The remote SSH host.
  final String host;

  /// The remote SSH port (default 22).
  final int port;

  /// The SSH username.
  final String username;

  /// Optional password for password-based authentication.
  final String? password;

  /// Optional PEM-encoded private keys for key-based authentication.
  ///
  /// Each entry is a full PEM string (including headers).
  final List<String>? privateKeyPems;

  /// Passphrase for encrypted private keys.
  final String? privateKeyPassphrase;

  /// Optional root path prefix on the remote filesystem.
  final String? root;

  /// Whether to throw exceptions on errors.
  final bool throw_;

  /// Whether the disk is read-only.
  final bool readOnly;

  /// Directory separator (default: '/').
  final String directorySeparator;

  /// Connection timeout duration.
  final Duration? timeout;

  /// Socket connect timeout.
  final Duration? connectTimeout;

  const SftpConfig({
    required this.host,
    required this.username,
    this.port = 22,
    this.password,
    this.privateKeyPems,
    this.privateKeyPassphrase,
    this.root,
    this.throw_ = false,
    this.readOnly = false,
    this.directorySeparator = '/',
    this.timeout,
    this.connectTimeout,
  });

  /// Create from a map (for backward compatibility with disk config).
  factory SftpConfig.fromMap(Map<String, dynamic> map) {
    return SftpConfig(
      host: map['host'] as String,
      port: map['port'] as int? ?? 22,
      username: map['username'] as String,
      password: map['password'] as String?,
      privateKeyPems: map['private_key'] != null
          ? [map['private_key'] as String]
          : null,
      root: map['root'] as String?,
      throw_: map['throw'] as bool? ?? false,
      readOnly: map['read-only'] as bool? ?? false,
    );
  }

  /// Convert to a map.
  Map<String, dynamic> toMap() {
    return {
      'host': host,
      'port': port,
      'username': username,
      if (password != null) 'password': password,
      if (privateKeyPems != null) 'private_key': privateKeyPems!.first,
      if (root != null) 'root': root,
      'throw': throw_,
      'read-only': readOnly,
    };
  }

  /// Create a copy with updated values.
  SftpConfig copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    List<String>? privateKeyPems,
    String? privateKeyPassphrase,
    String? root,
    bool? throw_,
    bool? readOnly,
    String? directorySeparator,
    Duration? timeout,
    Duration? connectTimeout,
  }) {
    return SftpConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKeyPems: privateKeyPems ?? this.privateKeyPems,
      privateKeyPassphrase:
          privateKeyPassphrase ?? this.privateKeyPassphrase,
      root: root ?? this.root,
      throw_: throw_ ?? this.throw_,
      readOnly: readOnly ?? this.readOnly,
      directorySeparator: directorySeparator ?? this.directorySeparator,
      timeout: timeout ?? this.timeout,
      connectTimeout: connectTimeout ?? this.connectTimeout,
    );
  }
}
