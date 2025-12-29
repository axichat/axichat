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
const String _dbFileName = '$_dbPrefix$_dbSuffix';
const String _tempDirPrefix = 'axichat-db-';
const String _supportDirName = 'support';
const String _attachmentRoot = 'attachments';
const String _sampleFileName = 'sample.txt';
const String _sampleContents = 'test';
const String _emptyPassphrase = '';
const String _metadataId = 'metadata-id';
const String _messageStanzaId = 'stanza-id';
const String _senderJid = 'sender@axi.im';
const String _chatJid = 'chat@axi.im';
const String _messageBody = 'Hello';
const String _thumbnailType = 'image/png';
const String _thumbnailData = 'thumbnail';
const bool _recursiveCreate = true;
const bool _recursiveDelete = true;

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
    final tempDir = await Directory.systemTemp.createTemp(_tempDirPrefix);
    final supportDir = Directory(p.join(tempDir.path, _supportDirName));
    await supportDir.create(recursive: _recursiveCreate);
    PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir.path);

    try {
      final dbFile = File(p.join(tempDir.path, _dbFileName));
      final database = XmppDrift(
        file: dbFile,
        passphrase: _emptyPassphrase,
        executor: NativeDatabase.memory(),
      );
      final attachmentDir = Directory(
        p.join(supportDir.path, _attachmentRoot, _dbPrefix),
      );
      await attachmentDir.create(recursive: _recursiveCreate);
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
      await tempDir.delete(recursive: _recursiveDelete);
    }
  });

  test('markMessageRetracted removes managed attachment files', () async {
    final originalPlatform = PathProviderPlatform.instance;
    final tempDir = await Directory.systemTemp.createTemp(_tempDirPrefix);
    final supportDir = Directory(p.join(tempDir.path, _supportDirName));
    await supportDir.create(recursive: _recursiveCreate);
    PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir.path);

    try {
      final dbFile = File(p.join(tempDir.path, _dbFileName));
      final database = XmppDrift(
        file: dbFile,
        passphrase: _emptyPassphrase,
        executor: NativeDatabase.memory(),
      );
      final attachmentDir = Directory(
        p.join(supportDir.path, _attachmentRoot, _dbPrefix),
      );
      await attachmentDir.create(recursive: _recursiveCreate);
      final attachmentPath = p.join(attachmentDir.path, _sampleFileName);
      final file = File(attachmentPath);
      await file.writeAsString(_sampleContents, flush: true);
      final metadata = FileMetadataData(
        id: _metadataId,
        filename: _sampleFileName,
        path: attachmentPath,
        thumbnailType: _thumbnailType,
        thumbnailData: _thumbnailData,
      );
      await database.saveFileMetadata(metadata);
      final message = Message(
        stanzaID: _messageStanzaId,
        senderJid: _senderJid,
        chatJid: _chatJid,
        body: _messageBody,
        fileMetadataID: metadata.id,
      );
      await database.saveMessage(message);

      await database.markMessageRetracted(message.stanzaID);

      expect(await file.exists(), isFalse);
      expect(await database.getFileMetadata(metadata.id), isNull);
      await database.close();
    } finally {
      PathProviderPlatform.instance = originalPlatform;
      await tempDir.delete(recursive: _recursiveDelete);
    }
  });

  test('deleteMessage removes managed attachment files', () async {
    final originalPlatform = PathProviderPlatform.instance;
    final tempDir = await Directory.systemTemp.createTemp(_tempDirPrefix);
    final supportDir = Directory(p.join(tempDir.path, _supportDirName));
    await supportDir.create(recursive: _recursiveCreate);
    PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir.path);

    try {
      final dbFile = File(p.join(tempDir.path, _dbFileName));
      final database = XmppDrift(
        file: dbFile,
        passphrase: _emptyPassphrase,
        executor: NativeDatabase.memory(),
      );
      final attachmentDir = Directory(
        p.join(supportDir.path, _attachmentRoot, _dbPrefix),
      );
      await attachmentDir.create(recursive: _recursiveCreate);
      final attachmentPath = p.join(attachmentDir.path, _sampleFileName);
      final file = File(attachmentPath);
      await file.writeAsString(_sampleContents, flush: true);
      final metadata = FileMetadataData(
        id: _metadataId,
        filename: _sampleFileName,
        path: attachmentPath,
        thumbnailType: _thumbnailType,
        thumbnailData: _thumbnailData,
      );
      await database.saveFileMetadata(metadata);
      final message = Message(
        stanzaID: _messageStanzaId,
        senderJid: _senderJid,
        chatJid: _chatJid,
        body: _messageBody,
        fileMetadataID: metadata.id,
      );
      await database.saveMessage(message);

      await database.deleteMessage(message.stanzaID);

      expect(await file.exists(), isFalse);
      expect(await database.getFileMetadata(metadata.id), isNull);
      await database.close();
    } finally {
      PathProviderPlatform.instance = originalPlatform;
      await tempDir.delete(recursive: _recursiveDelete);
    }
  });

  test('deleteFile removes attachment root directories', () async {
    final originalPlatform = PathProviderPlatform.instance;
    final tempDir = await Directory.systemTemp.createTemp(_tempDirPrefix);
    final supportDir = Directory(p.join(tempDir.path, _supportDirName));
    await supportDir.create(recursive: _recursiveCreate);
    PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir.path);

    try {
      final dbFile = File(p.join(tempDir.path, _dbFileName));
      await dbFile.writeAsString(_sampleContents, flush: true);
      final database = XmppDrift(
        file: dbFile,
        passphrase: _emptyPassphrase,
        executor: NativeDatabase.memory(),
      );
      final attachmentDir = Directory(
        p.join(supportDir.path, _attachmentRoot, _dbPrefix),
      );
      await attachmentDir.create(recursive: _recursiveCreate);
      final attachmentPath = p.join(attachmentDir.path, _sampleFileName);
      final file = File(attachmentPath);
      await file.writeAsString(_sampleContents, flush: true);

      await database.deleteAll();
      await database.close();
      await database.deleteFile();

      expect(await dbFile.exists(), isFalse);
      expect(await attachmentDir.exists(), isFalse);
    } finally {
      PathProviderPlatform.instance = originalPlatform;
      await tempDir.delete(recursive: _recursiveDelete);
    }
  });
}
