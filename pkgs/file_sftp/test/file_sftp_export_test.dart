import 'package:file_sftp/file_sftp.dart';
import 'package:test/test.dart';

void main() {
  test('barrel export exposes mock interfaces', () {
    expect(SftpFs, isNotNull);
    expect(SftpFsFile, isNotNull);
  });
}
