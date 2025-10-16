import 'filesystem.dart';

/// Contract for cloud filesystem operations.
abstract class Cloud extends Filesystem {
  /// Get the URL for the file at the given path.
  String url(String path);

  /// Determine if temporary URLs can be generated.
  bool providesTemporaryUrls();

  /// Get a temporary URL for the file at the given path.
  String temporaryUrl(
    String path,
    DateTime expiration, {
    Map<String, dynamic>? options,
  });
}
