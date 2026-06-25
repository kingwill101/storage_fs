import 'filesystem.dart';

/// Typed configuration for a storage disk.
///
/// Each storage backend provides a concrete subclass with typed fields.
/// Instances are passed to [Storage.initialize] or [FilesystemManager.addDisks].
abstract class Disk {
  const Disk();
  /// The disk name used to reference it via [Storage.disk] or [FilesystemManager.disk].
  String get name;

  /// Optional root path prefix applied to all operations.
  String? get root;

  /// Whether to throw exceptions on errors instead of returning `false`/`null`.
  bool get throwExceptions;

  /// Whether the disk is read-only.
  bool get readOnly;

  /// Build the [Filesystem] instance from this typed configuration.
  Filesystem build();
}
