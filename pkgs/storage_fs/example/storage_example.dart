import 'package:storage_fs/storage_fs.dart';
import 'dart:io';

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

  // Write a file
  await Storage.put('example.txt', 'Hello from Storage!');

  // Read a file
  final content = await Storage.get('example.txt');
  print('File content: $content');

  // Check if file exists
  final exists = await Storage.exists('example.txt');
  print('File exists: $exists');

  // Delete the file
  await Storage.delete('example.txt');
  print('File deleted');
}
