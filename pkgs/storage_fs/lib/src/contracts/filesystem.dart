/// Base contract for filesystem operations.
///
/// All operations are async to support both local and cloud storage backends.
abstract class Filesystem {
  /// The public visibility setting.
  static const String visibilityPublic = 'public';

  /// The private visibility setting.
  static const String visibilityPrivate = 'private';

  /// Determine if a file exists.
  Future<bool> exists(String path);

  /// Determine if a file or directory is missing.
  Future<bool> missing(String path);

  /// Get the contents of a file.
  Future<String?> get(String path);

  /// Get the contents of a file as a stream.
  Stream<List<int>>? readStream(String path);

  /// Write the contents of a file.
  Future<bool> put(
    String path,
    dynamic contents, {
    Map<String, dynamic>? options,
  });

  /// Write a new file using a stream.
  Future<bool> writeStream(
    String path,
    Stream<List<int>> resource, {
    Map<String, dynamic>? options,
  });

  /// Get the visibility for the given path.
  Future<String> getVisibility(String path);

  /// Set the visibility for the given path.
  Future<bool> setVisibility(String path, String visibility);

  /// Prepend to a file.
  Future<bool> prepend(String path, String data, {String separator = '\n'});

  /// Append to a file.
  Future<bool> append(String path, String data, {String separator = '\n'});

  /// Delete the file at a given path.
  Future<bool> delete(dynamic paths);

  /// Copy a file to a new location.
  Future<bool> copy(String from, String to);

  /// Move a file to a new location.
  Future<bool> move(String from, String to);

  /// Get the file size of a given file.
  Future<int> size(String path);

  /// Get the checksum for the given file.
  Future<String?> checksum(String path, {String algorithm = 'md5'});

  /// Determine the mime type for the given file.
  Future<String?> mimeType(String path);

  /// Get the file's last modification time.
  Future<DateTime> lastModified(String path);

  /// Get an array of all files in a directory.
  Future<List<String>> files([String? directory, bool recursive = false]);

  /// Get all of the files from the given directory (recursive).
  Future<List<String>> allFiles([String? directory]);

  /// Get all of the directories within a given directory.
  Future<List<String>> directories([String? directory, bool recursive = false]);

  /// Get all the directories within a given directory (recursive).
  Future<List<String>> allDirectories([String? directory]);

  /// Create a directory.
  Future<bool> makeDirectory(String path);

  /// Recursively delete a directory.
  Future<bool> deleteDirectory(String directory);
}
