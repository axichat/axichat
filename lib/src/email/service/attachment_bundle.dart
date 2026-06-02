// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:axichat/src/common/file_name_safety.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:path/path.dart' as p;

const String emailAttachmentBundleDirName = emailAttachmentTempDirectoryName;
const String emailAttachmentBundleNamePrefix = 'attachments_';
const String emailAttachmentBundleExtension = '.zip';
const String emailAttachmentBundleMimeType = 'application/zip';
const int _bundleMaxFileCount = 20;
const int _bundleMaxTotalSizeMiB = 50;
const int _bundleMaxFileNameLength = 120;
const int _bundleFileIndexStart = 1;
const int _bundleFileIndexStep = 1;
const int _bundleBytesPerKiB = 1024;
const int _bundleBytesPerMiB = _bundleBytesPerKiB * _bundleBytesPerKiB;
const int _bundleMaxTotalBytes = _bundleMaxTotalSizeMiB * _bundleBytesPerMiB;
const Duration _bundleCleanupDelay = Duration(hours: 1);
const String _bundleFallbackFileName = 'attachment';
const String _bundleFileIndexSeparator = '_';
const String _bundlePayloadPathKey = 'path';
const String _bundlePayloadFilesKey = 'files';
const String _bundleFilePathKey = 'file_path';
const String _bundleFileNameKey = 'file_name';
const String _bundleFileSizeKey = 'file_size';

sealed class EmailAttachmentBundleException implements Exception {
  const EmailAttachmentBundleException({this.path});

  final String? path;

  @override
  String toString() =>
      path == null ? runtimeType.toString() : '$runtimeType(path: $path)';
}

final class EmailAttachmentBundleEmptySelectionException
    extends EmailAttachmentBundleException {
  const EmailAttachmentBundleEmptySelectionException();
}

final class EmailAttachmentBundleTooManyFilesException
    extends EmailAttachmentBundleException {
  const EmailAttachmentBundleTooManyFilesException();
}

final class EmailAttachmentBundleTooLargeException
    extends EmailAttachmentBundleException {
  const EmailAttachmentBundleTooLargeException();
}

final class EmailAttachmentBundleMissingFileException
    extends EmailAttachmentBundleException {
  const EmailAttachmentBundleMissingFileException({super.path});
}

final class EmailAttachmentBundleInvalidEntityTypeException
    extends EmailAttachmentBundleException {
  const EmailAttachmentBundleInvalidEntityTypeException({super.path});
}

final class EmailAttachmentBundleSymlinkNotAllowedException
    extends EmailAttachmentBundleException {
  const EmailAttachmentBundleSymlinkNotAllowedException({super.path});
}

final class EmailAttachmentBundleInvalidPayloadException
    extends EmailAttachmentBundleException {
  const EmailAttachmentBundleInvalidPayloadException();
}

final class EmailAttachmentBundleInvalidArchiveException
    extends EmailAttachmentBundleException {
  const EmailAttachmentBundleInvalidArchiveException({super.path});
}

final class EmailAttachmentBundler {
  const EmailAttachmentBundler();

  static Future<EmailAttachment> bundle({
    required Iterable<EmailAttachment> attachments,
    required String? caption,
  }) async {
    final attachmentList = attachments.toList(growable: false);
    if (attachmentList.isEmpty) {
      throw const EmailAttachmentBundleEmptySelectionException();
    }
    if (attachmentList.length > _bundleMaxFileCount) {
      throw const EmailAttachmentBundleTooManyFilesException();
    }
    final bundleDir = await appOwnedTemporaryDirectory(
      emailAttachmentBundleDirName,
    );
    if (!await bundleDir.exists()) {
      await bundleDir.create(recursive: true);
    }
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final zipName =
        '$emailAttachmentBundleNamePrefix$timestamp$emailAttachmentBundleExtension';
    final zipPath = p.join(bundleDir.path, zipName);
    var totalBytes = 0;
    var index = _bundleFileIndexStart;
    final usedEntryNames = <String>{};
    final files = <Map<String, Object>>[];
    for (final attachment in attachmentList) {
      final entityType = await FileSystemEntity.type(
        attachment.path,
        followLinks: false,
      );
      if (entityType == FileSystemEntityType.link) {
        throw EmailAttachmentBundleSymlinkNotAllowedException(
          path: attachment.path,
        );
      }
      if (entityType != FileSystemEntityType.file) {
        throw EmailAttachmentBundleInvalidEntityTypeException(
          path: attachment.path,
        );
      }
      final file = File(attachment.path);
      if (!await file.exists()) {
        throw EmailAttachmentBundleMissingFileException(path: attachment.path);
      }
      final attachmentSize = await file.length();
      totalBytes += attachmentSize;
      if (totalBytes > _bundleMaxTotalBytes) {
        throw const EmailAttachmentBundleTooLargeException();
      }
      final sanitizedName = _uniqueBundleFileName(
        sanitizedName: _sanitizeBundleFileName(
          explicitName: attachment.fileName,
          fallbackPath: attachment.path,
          index: index,
        ),
        index: index,
        usedNames: usedEntryNames,
      );
      files.add(<String, Object>{
        _bundleFilePathKey: attachment.path,
        _bundleFileNameKey: sanitizedName,
        _bundleFileSizeKey: attachmentSize,
      });
      index += _bundleFileIndexStep;
    }
    final payload = <String, Object?>{
      _bundlePayloadPathKey: zipPath,
      _bundlePayloadFilesKey: files,
    };
    await Isolate.run(() => _writeBundle(payload));
    final zipFile = File(zipPath);
    final sizeBytes = await zipFile.length();
    final attachment = EmailAttachment(
      path: zipFile.path,
      fileName: zipName,
      sizeBytes: sizeBytes,
      mimeType: emailAttachmentBundleMimeType,
      caption: caption,
    );
    return attachment;
  }

  static void scheduleCleanup(EmailAttachment attachment) {
    final String path = attachment.path.trim();
    if (path.isEmpty) {
      return;
    }
    final File file = File(path);
    if (!_isBundledAttachmentFile(file)) {
      return;
    }
    _scheduleBundleCleanup(file);
  }
}

String _sanitizeBundleFileName({
  required String? explicitName,
  required String fallbackPath,
  required int index,
}) {
  final fallbackName = _resolveBundleFallbackName(
    fallbackPath: fallbackPath,
    index: index,
  );
  return sanitizeAttachmentFileName(
    rawName: explicitName,
    fallbackName: fallbackName,
    maxLength: _bundleMaxFileNameLength,
  );
}

String _resolveBundleFallbackName({
  required String fallbackPath,
  required int index,
}) {
  final trimmedPath = fallbackPath.trim();
  if (trimmedPath.isNotEmpty) {
    return trimmedPath;
  }
  return _buildBundleFallbackName(index);
}

String _buildBundleFallbackName(int index) =>
    '$_bundleFallbackFileName$_bundleFileIndexSeparator$index';

String _uniqueBundleFileName({
  required String sanitizedName,
  required int index,
  required Set<String> usedNames,
}) {
  var candidate = sanitizedName;
  var collisionIndex = index;
  while (!usedNames.add(candidate.toLowerCase())) {
    final extension = p.extension(sanitizedName);
    final baseName = extension.isEmpty
        ? sanitizedName
        : sanitizedName.substring(0, sanitizedName.length - extension.length);
    final suffix = '$_bundleFileIndexSeparator$collisionIndex';
    final extensionForUniqueName =
        _bundleMaxFileNameLength - extension.length - suffix.length > 0
        ? extension
        : '';
    final maxBaseLength =
        _bundleMaxFileNameLength -
        extensionForUniqueName.length -
        suffix.length;
    final sourceBaseName = baseName.isEmpty
        ? _bundleFallbackFileName
        : baseName;
    final uniqueBaseName = sourceBaseName.length > maxBaseLength
        ? sourceBaseName.substring(0, maxBaseLength)
        : sourceBaseName;
    candidate = sanitizeAttachmentFileName(
      rawName: '$uniqueBaseName$suffix$extensionForUniqueName',
      fallbackName: _buildBundleFallbackName(collisionIndex),
      maxLength: _bundleMaxFileNameLength,
    );
    collisionIndex += _bundleFileIndexStep;
  }
  return candidate;
}

Future<void> _writeBundle(Map<String, Object?> payload) async {
  final rawPath = payload[_bundlePayloadPathKey];
  if (rawPath is! String || rawPath.trim().isEmpty) {
    throw const EmailAttachmentBundleInvalidPayloadException();
  }
  final rawFiles = payload[_bundlePayloadFilesKey];
  if (rawFiles is! List) {
    throw const EmailAttachmentBundleInvalidPayloadException();
  }
  final encoder = ZipFileEncoder()..create(rawPath);
  try {
    for (final entry in rawFiles) {
      final bundleEntry = _parseBundlePayloadEntry(entry);
      final filePath = bundleEntry.path;
      final fileName = bundleEntry.name;
      final entityType = FileSystemEntity.typeSync(
        filePath,
        followLinks: false,
      );
      if (entityType == FileSystemEntityType.link) {
        throw EmailAttachmentBundleSymlinkNotAllowedException(path: filePath);
      }
      if (entityType != FileSystemEntityType.file) {
        throw EmailAttachmentBundleInvalidEntityTypeException(path: filePath);
      }
      final file = File(filePath);
      if (!file.existsSync()) {
        throw EmailAttachmentBundleMissingFileException(path: filePath);
      }
      if (file.lengthSync() != bundleEntry.size) {
        throw EmailAttachmentBundleInvalidArchiveException(path: filePath);
      }
      await encoder.addFile(file, fileName);
    }
  } finally {
    await encoder.close();
  }
  _validateBundle(rawPath, rawFiles);
}

_BundlePayloadEntry _parseBundlePayloadEntry(Object? entry) {
  if (entry is! Map) {
    throw const EmailAttachmentBundleInvalidPayloadException();
  }
  final filePath = entry[_bundleFilePathKey];
  final fileName = entry[_bundleFileNameKey];
  final fileSize = entry[_bundleFileSizeKey];
  if (filePath is! String || filePath.trim().isEmpty) {
    throw const EmailAttachmentBundleInvalidPayloadException();
  }
  if (fileName is! String || fileName.trim().isEmpty) {
    throw const EmailAttachmentBundleInvalidPayloadException();
  }
  if (fileSize is! int || fileSize < 0) {
    throw const EmailAttachmentBundleInvalidPayloadException();
  }
  return _BundlePayloadEntry(path: filePath, name: fileName, size: fileSize);
}

void _validateBundle(String zipPath, List<Object?> rawFiles) {
  if (rawFiles.isEmpty) {
    throw EmailAttachmentBundleInvalidArchiveException(path: zipPath);
  }
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
  } on Exception {
    throw EmailAttachmentBundleInvalidArchiveException(path: zipPath);
  }
  final archiveFiles = archive.files
      .where((entry) => entry.isFile)
      .toList(growable: false);
  if (archiveFiles.length != rawFiles.length) {
    throw EmailAttachmentBundleInvalidArchiveException(path: zipPath);
  }
  final filesByName = <String, ArchiveFile>{
    for (final entry in archiveFiles) entry.name: entry,
  };
  if (filesByName.length != rawFiles.length) {
    throw EmailAttachmentBundleInvalidArchiveException(path: zipPath);
  }
  for (final rawEntry in rawFiles) {
    final expectedEntry = _parseBundlePayloadEntry(rawEntry);
    final archiveEntry = filesByName[expectedEntry.name];
    if (archiveEntry == null || archiveEntry.size != expectedEntry.size) {
      throw EmailAttachmentBundleInvalidArchiveException(path: zipPath);
    }
    final sourceBytes = File(expectedEntry.path).readAsBytesSync();
    final archivedBytes = archiveEntry.content;
    if (!_bytesEqual(sourceBytes, archivedBytes)) {
      throw EmailAttachmentBundleInvalidArchiveException(path: zipPath);
    }
  }
}

bool _bytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

final class _BundlePayloadEntry {
  const _BundlePayloadEntry({
    required this.path,
    required this.name,
    required this.size,
  });

  final String path;
  final String name;
  final int size;
}

bool _isBundledAttachmentFile(File file) {
  final String baseName = p.basename(file.path);
  if (!baseName.startsWith(emailAttachmentBundleNamePrefix)) {
    return false;
  }
  final String parentName = p.basename(p.dirname(file.path));
  return parentName == emailAttachmentBundleDirName;
}

void _scheduleBundleCleanup(File file) {
  Timer(_bundleCleanupDelay, () async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on Exception {
      return;
    }
  });
}
