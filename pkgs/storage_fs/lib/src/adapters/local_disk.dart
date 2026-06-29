import '../contracts/disk.dart';
import '../contracts/filesystem.dart';
import '../config/disk_config.dart';
import 'filesystem_adapter.dart';

/// Typed configuration for a local filesystem disk.
class LocalDisk extends Disk {
  @override
  final String name;

  @override
  final String? root;

  @override
  final bool throwExceptions;

  @override
  final bool readOnly;

  final String? url;

  final String? visibility;

  final bool report;

  final String directorySeparator;

  final String? prefix;

  const LocalDisk({
    required this.name,
    this.root,
    this.url,
    this.visibility,
    this.throwExceptions = false,
    this.report = false,
    this.readOnly = false,
    this.directorySeparator = '/',
    this.prefix,
  });

  @override
  DiskConfig toDiskConfig() {
    return DiskConfig(
      driver: 'local',
      root: root,
      url: url,
      visibility: visibility,
      throw_: throwExceptions,
      report: report,
      readOnly: readOnly,
      directorySeparator: directorySeparator,
      prefix: prefix,
    );
  }

  @override
  Filesystem build() {
    return FilesystemAdapter(toDiskConfig());
  }
}
