import 'package:file_sftp/file_sftp.dart';
import 'package:test/test.dart';

void main() {
  test('barrel export exposes core types', () {
    expect(SftpFs, isNotNull);
    expect(SftpFsFile, isNotNull);
    expect(SftpFileSystem, isNotNull);
    expect(SftpConfig, isNotNull);
  });
}
