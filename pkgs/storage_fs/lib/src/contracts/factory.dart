import 'filesystem.dart';
import 'cloud.dart';

/// Contract for filesystem manager factory.
abstract class Factory {
  /// Get a filesystem instance.
  Filesystem disk([String? name]);

  /// Get a default cloud filesystem instance.
  Cloud cloud();
}
