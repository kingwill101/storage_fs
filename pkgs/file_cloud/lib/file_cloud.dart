/// Cloud filesystem primitives and helpers for S3‑compatible object storage.
///
/// This library exposes the cloud filesystem types that let you work directly
/// with S3‑compatible providers such as AWS S3, MinIO, DigitalOcean Spaces,
/// and Cloudflare R2. Use these types when you want fine‑grained control
/// over cloud operations without the higher‑level [Storage] facade.
///
///
/// Getting started
///
/// The most direct way to create a cloud filesystem is by creating a MinIO client,
/// a cloud driver, and then the filesystem. Provide your S3 endpoint, credentials,
/// and bucket. Then use the returned [CloudFileSystem] to read and write files.
///
/// ```dart
/// import 'package:file_cloud/file_cloud.dart';
/// import 'package:minio/minio.dart';
///
/// Future<void> main() async {
///   // Create a MinIO client for a local MinIO instance.
///   final minio = Minio(
///     endPoint: '127.0.0.1',
///     port: 9000,
///     accessKey: 'minio',
///     secretKey: 'minio123',
///     useSSL: false,
///   );
///
///   // Create the cloud driver
///   final driver = MinioCloudDriver(
///     client: minio,
///     bucket: 'test-bucket',
///     autoCreateBucket: true,
///   );
///
///   // Create the filesystem
///   final fs = CloudFileSystem(driver: driver);
///
///   // Optional: Prepare the backend (e.g., ensure bucket exists if the driver supports it).
///   await fs.driver.ensureReady();
///
///   // Write a text file.
///   await fs.file('docs/hello.txt').writeAsString('Hello from cloud!');
///
///   // Read the file back.
///   final content = await fs.file('docs/hello.txt').readAsString();
///   print(content);
/// }
/// ```
///
///
/// Provider examples
///
/// For common providers, configure the MinIO client with the appropriate endpoint:
///
/// ```dart
/// import 'package:file_cloud/file_cloud.dart';
/// import 'package:minio/minio.dart';
///
/// Future<void> main() async {
///   // AWS S3
///   final minioS3 = Minio(
///     endPoint: 's3.amazonaws.com',
///     accessKey: 'AKIA...',
///     secretKey: 'secret...',
///     useSSL: true,
///   );
///   final driverS3 = MinioCloudDriver(client: minioS3, bucket: 'my-bucket');
///   final s3 = CloudFileSystem(driver: driverS3);
///
///   // DigitalOcean Spaces (region is part of the endpoint)
///   final minioSpaces = Minio(
///     endPoint: 'nyc3.digitaloceanspaces.com',
///     accessKey: 'DO000...',
///     secretKey: 'secret...',
///     useSSL: true,
///   );
///   final driverSpaces = MinioCloudDriver(client: minioSpaces, bucket: 'my-space');
///   final spaces = CloudFileSystem(driver: driverSpaces);
///
///   // Cloudflare R2
///   final minioR2 = Minio(
///     endPoint: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.r2.cloudflarestorage.com',
///     accessKey: 'r2-access',
///     secretKey: 'r2-secret',
///     useSSL: true,
///   );
///   final driverR2 = MinioCloudDriver(client: minioR2, bucket: 'assets');
///   final r2 = CloudFileSystem(driver: driverR2);
///
///   // MinIO (self‑hosted)
///   final minioLocal = Minio(
///     endPoint: '127.0.0.1',
///     port: 9000,
///     accessKey: 'minio',
///     secretKey: 'minio123',
///     useSSL: false,
///   );
///   final driverLocal = MinioCloudDriver(
///     client: minioLocal,
///     bucket: 'test-bucket',
///     autoCreateBucket: true,
///   );
///   final minioFs = CloudFileSystem(driver: driverLocal);
///
///   // Use them like any CloudFileSystem:
///   await s3.file('readme.txt').writeAsString('Hello S3');
///   await spaces.file('note.txt').writeAsString('Hello Spaces');
///   await r2.file('hello.txt').writeAsString('Hello R2');
///   await minioFs.file('ping.txt').writeAsString('Hello MinIO');
/// }
/// ```
///
///
/// Working with files and directories
///
/// [CloudFileSystem] provides [CloudFile] and [CloudDirectory] for common I/O.
///
/// ```dart
/// import 'package:file_cloud/file_cloud.dart';
/// import 'package:minio/minio.dart';
///
/// Future<void> main() async {
///   final minio = Minio(
///     endPoint: '127.0.0.1',
///     port: 9000,
///     accessKey: 'minio',
///     secretKey: 'minio123',
///     useSSL: false,
///   );
///   final driver = MinioCloudDriver(
///     client: minio,
///     bucket: 'test-bucket',
///     autoCreateBucket: true,
///   );
///   final fs = CloudFileSystem(driver: driver);
///   await fs.driver.ensureReady();
///
///   // Write strings and bytes.
///   await fs.file('docs/info.txt').writeAsString('Docs are here.');
///   await fs.file('bin/blob.bin').writeAsBytes([0, 1, 2, 3]);
///
///   // Copy and delete.
///   await fs.file('docs/info.txt').copy('docs/info-copy.txt');
///   await fs.file('bin/blob.bin').delete();
///
///   // List directory contents.
///   final docs = fs.directory('docs');
///   await for (final entity in docs.list()) {
///     print('${entity.isDirectory ? "DIR " : "FILE"} ${entity.path}');
///   }
///
///   // Remove a whole subtree.
///   await fs.directory('docs').delete(recursive: true);
/// }
/// ```
///
///
/// Public and signed URLs
///
/// The underlying cloud driver can generate public and temporary URLs. Public
/// URLs depend on your bucket’s exposure and configuration. Signed URLs are
/// time‑limited and do not require the object to be public.
///
/// ```dart
/// import 'package:file_cloud/file_cloud.dart';
/// import 'package:minio/minio.dart';
///
/// Future<void> main() async {
///   final minio = Minio(
///     endPoint: '127.0.0.1',
///     port: 9000,
///     accessKey: 'minio',
///     secretKey: 'minio123',
///     useSSL: false,
///   );
///   final driver = MinioCloudDriver(
///     client: minio,
///     bucket: 'test-bucket',
///     autoCreateBucket: true,
///   );
///   final fs = CloudFileSystem(driver: driver);
///   await fs.driver.ensureReady();
///
///   // Public URL (depends on driver configuration and bucket policy).
///   final public = fs.driver.publicUrl('images/logo.png');
///   print('Public URL: $public');
///
///   // Time‑limited download URL (presigned GET).
///   final download = await fs.driver.presignDownload(
///     'images/logo.png',
///     Duration(minutes: 15),
///   );
///   print('Signed download: $download');
///
///   // Time‑limited upload URL (presigned PUT).
///   final upload = await fs.driver.presignUpload(
///     'uploads/new.png',
///     Duration(minutes: 10),
///   );
///   print('Upload to: ${upload?.url}');
///   print('Required headers: ${upload?.headers}');
/// }
/// ```
///
library;

export 'src/cloud.dart';
