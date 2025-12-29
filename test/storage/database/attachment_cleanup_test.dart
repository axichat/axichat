// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

const String _dbPrefix = 'account';
const String _dbSuffix = '.axichat.drift';
const String _attachmentRoot = 'attachments';
const String _sampleFileName = 'sample.txt';
const String _sampleContents = 'test';
const String _metadataId = 'metadata-id';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deleteFileMetadata removes managed attachment files', () async {
    final originalPlatform = PathProviderPlatform.instance;
    final tempDir = await Directory.systemTemp.createTemp('axichat-db-');
    final supportDir = Directory(p.join(tempDir.path, 'support'));
    await supportDir.create(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir.path);

    try {
      final dbFile = File(p.join(tempDir.path, '$_dbPrefix$_dbSuffix'));
      final database = XmppDrift(
        file: dbFile,
        passphrase: '',
        executor: NativeDatabase.memory(),
      );
      final attachmentDir = Directory(
        p.join(supportDir.path, _attachmentRoot, _dbPrefix),
      );
      await attachmentDir.create(recursive: true);
      final attachmentPath = p.join(attachmentDir.path, _sampleFileName);
      final file = File(attachmentPath);
      await file.writeAsString(_sampleContents, flush: true);
      final metadata = FileMetadataData(
        id: _metadataId,
        filename: _sampleFileName,
        path: attachmentPath,
      );
      await database.saveFileMetadata(metadata);

      await database.deleteFileMetadata(metadata.id);

      expect(await file.exists(), isFalse);
      await database.close();
    } finally {
      PathProviderPlatform.instance = originalPlatform;
      await tempDir.delete(recursive: true);
    }
  });
}
