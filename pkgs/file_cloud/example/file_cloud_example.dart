import 'package:file_cloud/file_cloud.dart';
import 'package:file_cloud/drivers.dart';
import 'package:minio/minio.dart';

void main() async {
  // Create a Minio client
  final minio = Minio(
    endPoint: 'localhost',
    port: 9000,
    accessKey: 'minioadmin',
    secretKey: 'minioadmin',
    useSSL: false,
  );

  // Create the cloud driver
  final driver = MinioCloudDriver(
    client: minio,
    bucket: 'test-bucket',
    autoCreateBucket: true,
  );

  // Create the filesystem
  final fs = CloudFileSystem(driver: driver);

  // Ensure the backend is ready
  await fs.driver.ensureReady();

  // Write a file
  await fs.file('example.txt').writeAsString('Hello from file_cloud!');

  // Read it back
  final content = await fs.file('example.txt').readAsString();
  print(content);

  // Clean up
  await fs.file('example.txt').delete();
}
