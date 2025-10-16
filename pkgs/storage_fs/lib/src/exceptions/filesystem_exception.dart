/// Base exception for filesystem operations.
class FilesystemException implements Exception {
  final String message;
  final String? path;
  final Object? cause;

  FilesystemException(this.message, {this.path, this.cause});

  @override
  String toString() {
    final buffer = StringBuffer('FilesystemException: $message');
    if (path != null) buffer.write(' (path: $path)');
    if (cause != null) buffer.write('\nCaused by: $cause');
    return buffer.toString();
  }
}

/// Exception thrown when unable to read a file.
class UnableToReadFileException extends FilesystemException {
  UnableToReadFileException(String path, {Object? cause})
    : super('Unable to read file', path: path, cause: cause);
}

/// Exception thrown when unable to write a file.
class UnableToWriteFileException extends FilesystemException {
  UnableToWriteFileException(String path, {Object? cause})
    : super('Unable to write file', path: path, cause: cause);
}

/// Exception thrown when unable to delete a file.
class UnableToDeleteFileException extends FilesystemException {
  UnableToDeleteFileException(String path, {Object? cause})
    : super('Unable to delete file', path: path, cause: cause);
}

/// Exception thrown when unable to copy a file.
class UnableToCopyFileException extends FilesystemException {
  UnableToCopyFileException(String from, String to, {Object? cause})
    : super('Unable to copy file from $from to $to', cause: cause);
}

/// Exception thrown when unable to move a file.
class UnableToMoveFileException extends FilesystemException {
  UnableToMoveFileException(String from, String to, {Object? cause})
    : super('Unable to move file from $from to $to', cause: cause);
}

/// Exception thrown when unable to create a directory.
class UnableToCreateDirectoryException extends FilesystemException {
  UnableToCreateDirectoryException(String path, {Object? cause})
    : super('Unable to create directory', path: path, cause: cause);
}

/// Exception thrown when unable to delete a directory.
class UnableToDeleteDirectoryException extends FilesystemException {
  UnableToDeleteDirectoryException(String path, {Object? cause})
    : super('Unable to delete directory', path: path, cause: cause);
}

/// Exception thrown when unable to set visibility.
class UnableToSetVisibilityException extends FilesystemException {
  UnableToSetVisibilityException(String path, {Object? cause})
    : super('Unable to set visibility', path: path, cause: cause);
}

/// Exception thrown when unable to retrieve metadata.
class UnableToRetrieveMetadataException extends FilesystemException {
  UnableToRetrieveMetadataException(String path, {Object? cause})
    : super('Unable to retrieve metadata', path: path, cause: cause);
}

/// Exception thrown when unable to provide checksum.
class UnableToProvideChecksumException extends FilesystemException {
  UnableToProvideChecksumException(String path, {Object? cause})
    : super('Unable to provide checksum', path: path, cause: cause);
}
