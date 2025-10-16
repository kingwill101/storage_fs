import 'package:storage_fs/storage_fs.dart';
import 'dart:io';

/// Example demonstrating the storage_fs package usage.
///
/// This example shows how to:
/// - Initialize the storage system
/// - Perform basic file operations (write, read, delete)
/// - Check file existence
/// - Work with directories
void main() async {
  // Initialize storage with configuration
  Storage.initialize({
    'default': 'local',
    'disks': {
      'local': {
        'driver': 'local',
        'root': '${Directory.systemTemp.path}/storage_example',
      },
    },
  });

  print('=== Storage Example ===\n');

  // Write a file
  print('1. Writing file...');
  await Storage.put('example.txt', 'Hello from Storage!');

  // Read a file
  print('2. Reading file...');
  final content = await Storage.get('example.txt');
  print('   Content: $content');

  // Check if file exists
  print('3. Checking file existence...');
  final exists = await Storage.exists('example.txt');
  print('   File exists: $exists');

  // Get file size
  print('4. Getting file size...');
  final size = await Storage.size('example.txt');
  print('   Size: $size bytes');

  // Create a directory
  print('5. Creating directory...');
  await Storage.makeDirectory('uploads/images');
  print('   Directory created');

  // Write file to directory
  print('6. Writing file to directory...');
  await Storage.put('uploads/images/photo.txt', 'Sample image data');

  // List files
  print('7. Listing files...');
  final files = await Storage.allFiles('uploads');
  print('   Files: $files');

  // Copy file
  print('8. Copying file...');
  await Storage.copy('example.txt', 'example_copy.txt');
  print('   File copied');

  // Delete files
  print('9. Cleaning up...');
  await Storage.delete('example.txt');
  await Storage.delete('example_copy.txt');
  await Storage.deleteDirectory('uploads');
  print('   Cleanup complete');

  print('\n=== Example Complete ===');
}
