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
const int _bundleMaxFileCount = 20;
const int _bundleMaxTotalSizeMiB = 50;
const int _bundleMaxFileNameLength = 120;
const int _bundleFileIndexStart = 1;
const int _bundleFileIndexStep = 1;
const int _bundleSubstringStart = 0;
const int _bundleMinFileSizeBytes = 0;
const int _bundleBytesPerKiB = 1024;
const int _bundleBytesPerMiB = _bundleBytesPerKiB * _bundleBytesPerKiB;
const int _bundleMaxTotalBytes = _bundleMaxTotalSizeMiB * _bundleBytesPerMiB;
const String _bundleFallbackFileName = 'attachment';
const String _bundleFileIndexSeparator = '_';
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
    final attachmentList = attachments.toList(growable: false);
    if (attachmentList.isEmpty) {
      throw ArgumentError('Attachment bundle requires at least one file.');
    }
    if (attachmentList.length > _bundleMaxFileCount) {
      throw ArgumentError(
        'Attachment bundle exceeds the maximum number of files.',
      );
    }
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
    var totalBytes = 0;
    var index = _bundleFileIndexStart;
    final files = <Map<String, String>>[];
    for (final attachment in attachmentList) {
      final file = File(attachment.path);
      if (!await file.exists()) {
        throw FileSystemException('Attachment missing', attachment.path);
      }
      final attachmentSize = attachment.sizeBytes;
      final safeSize = attachmentSize < _bundleMinFileSizeBytes
          ? _bundleMinFileSizeBytes
          : attachmentSize;
      totalBytes += safeSize;
      if (totalBytes > _bundleMaxTotalBytes) {
        throw ArgumentError('Attachment bundle exceeds size limits.');
      }
      final sanitizedName = _sanitizeBundleFileName(
        explicitName: attachment.fileName,
        fallbackPath: attachment.path,
        index: index,
      );
      files.add(
        <String, String>{
          _bundleFilePathKey: attachment.path,
          _bundleFileNameKey: sanitizedName,
        },
      );
      index += _bundleFileIndexStep;
    }
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

String _sanitizeBundleFileName({
  required String? explicitName,
  required String fallbackPath,
  required int index,
}) {
  final trimmedName = explicitName?.trim();
  final candidate =
      trimmedName?.isNotEmpty == true ? trimmedName! : p.basename(fallbackPath);
  final normalized = p.basename(candidate).trim();
  final fallbackName =
      '$_bundleFallbackFileName$_bundleFileIndexSeparator$index';
  final resolved = normalized.isEmpty ? fallbackName : normalized;
  return _truncateBundleFileName(resolved);
}

String _truncateBundleFileName(String name) {
  if (name.length <= _bundleMaxFileNameLength) {
    return name;
  }
  final extension = p.extension(name);
  if (extension.isEmpty || extension.length >= _bundleMaxFileNameLength) {
    return name.substring(_bundleSubstringStart, _bundleMaxFileNameLength);
  }
  final maxBaseLength = _bundleMaxFileNameLength - extension.length;
  return '${name.substring(_bundleSubstringStart, maxBaseLength)}$extension';
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
