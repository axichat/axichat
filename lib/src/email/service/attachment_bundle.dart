import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const String emailAttachmentBundleDirName = 'email_attachments';
const String emailAttachmentBundleNamePrefix = 'attachments_';
const String emailAttachmentBundleExtension = '.zip';
const String emailAttachmentBundleMimeType = 'application/zip';
const String _bundlePayloadPathKey = 'path';
const String _bundlePayloadFilesKey = 'files';
const String _bundleFilePathKey = 'file_path';
const String _bundleFileNameKey = 'file_name';

final class EmailAttachmentBundler {
  const EmailAttachmentBundler();

  static Future<EmailAttachment> bundle({
    required Iterable<EmailAttachment> attachments,
    required String? caption,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final bundleDir =
        Directory(p.join(tempDir.path, emailAttachmentBundleDirName));
    if (!await bundleDir.exists()) {
      await bundleDir.create(recursive: true);
    }
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final zipName =
        '$emailAttachmentBundleNamePrefix$timestamp$emailAttachmentBundleExtension';
    final zipPath = p.join(bundleDir.path, zipName);
    final files = attachments
        .map(
          (attachment) => <String, String>{
            _bundleFilePathKey: attachment.path,
            _bundleFileNameKey: attachment.fileName.isNotEmpty
                ? attachment.fileName
                : p.basename(attachment.path),
          },
        )
        .toList(growable: false);
    final payload = <String, Object?>{
      _bundlePayloadPathKey: zipPath,
      _bundlePayloadFilesKey: files,
    };
    await Isolate.run(() => _writeBundle(payload));
    final zipFile = File(zipPath);
    final sizeBytes = await zipFile.length();
    return EmailAttachment(
      path: zipFile.path,
      fileName: zipName,
      sizeBytes: sizeBytes,
      mimeType: emailAttachmentBundleMimeType,
      caption: caption,
    );
  }
}

void _writeBundle(Map<String, Object?> payload) {
  final rawPath = payload[_bundlePayloadPathKey];
  if (rawPath is! String || rawPath.trim().isEmpty) {
    throw const FileSystemException('Attachment bundle path missing');
  }
  final rawFiles = payload[_bundlePayloadFilesKey];
  if (rawFiles is! List) {
    throw const FileSystemException('Attachment bundle file list missing');
  }
  final encoder = ZipFileEncoder()..create(rawPath);
  try {
    for (final entry in rawFiles) {
      if (entry is! Map) {
        throw const FileSystemException('Attachment bundle entry invalid');
      }
      final filePath = entry[_bundleFilePathKey];
      final fileName = entry[_bundleFileNameKey];
      if (filePath is! String || filePath.trim().isEmpty) {
        throw const FileSystemException('Attachment bundle path missing');
      }
      if (fileName is! String || fileName.trim().isEmpty) {
        throw const FileSystemException('Attachment bundle name missing');
      }
      final file = File(filePath);
      if (!file.existsSync()) {
        throw FileSystemException('Attachment missing', filePath);
      }
      encoder.addFile(file, fileName);
    }
  } finally {
    encoder.close();
  }
}
