// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:axichat/src/common/attachment_import_source.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/email/service/attachment_optimizer.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

final class ComposerAttachmentStagingException implements Exception {
  const ComposerAttachmentStagingException([this.wrapped]);

  final Object? wrapped;
}

final class ComposerAttachmentTooLargeException
    extends ComposerAttachmentStagingException {
  const ComposerAttachmentTooLargeException();
}

final class ComposerStagedAttachment extends Equatable {
  const ComposerStagedAttachment({required this.sessionId, required this.path});

  final String sessionId;
  final String path;

  @override
  List<Object?> get props => [sessionId, path];
}

final class ComposerAttachmentStage {
  const ComposerAttachmentStage({
    required this.attachment,
    required this.staged,
  });

  final Attachment attachment;
  final ComposerStagedAttachment staged;
}

final class ComposerAttachmentCommit {
  const ComposerAttachmentCommit({
    required this.attachment,
    required this.committedDirectoryPath,
    required this.committedPath,
    required this.stagedPath,
  });

  final Attachment attachment;
  final String? committedDirectoryPath;
  final String? committedPath;
  final String? stagedPath;
}

Future<ComposerAttachmentStage> stageComposerAttachment({
  required AttachmentImportSource source,
  required String sessionId,
  required String fallbackId,
  int? maxSizeBytes,
}) async {
  final limit = maxSizeBytes ?? 0;
  final int sourceSizeBytes;
  try {
    sourceSizeBytes = await _sourceSizeBytes(source);
  } on AttachmentImportException catch (error) {
    throw ComposerAttachmentStagingException(error);
  }
  final fileName = _composerAttachmentFileName(
    fileName: source.fileName,
    path: source.path,
    fallback: fallbackId,
  );
  final sourceAttachment = Attachment(
    path: source.path,
    fileName: fileName,
    sizeBytes: sourceSizeBytes,
    mimeType: source.mimeType,
  );
  if (limit > 0 &&
      sourceSizeBytes > limit &&
      !_mayOptimizeBelowLimit(sourceAttachment)) {
    throw const ComposerAttachmentTooLargeException();
  }
  final Directory directory;
  final File destination;
  try {
    directory = await appOwnedTemporaryDirectory(
      composerAttachmentStagingDirectoryName,
      childDirectoryName: sessionId,
    );
    await directory.create(recursive: true);
    destination = await _uniqueAttachmentFile(
      directory: directory,
      fileName: _prefixedComposerAttachmentFileName(
        prefix: fallbackId,
        fileName: fileName,
      ),
    );
  } on FileSystemException catch (error) {
    throw ComposerAttachmentStagingException(error);
  } on MissingPluginException catch (error) {
    throw ComposerAttachmentStagingException(error);
  } on PlatformException catch (error) {
    throw ComposerAttachmentStagingException(error);
  }
  File copiedFile;
  try {
    copiedFile = await source.copyTo(destination);
  } on AttachmentImportException catch (error) {
    await _deleteFileIfChild(file: destination, directory: directory);
    throw ComposerAttachmentStagingException(error);
  }
  if (!appOwnedPathIsChildOf(
    rootPath: directory.path,
    candidatePath: copiedFile.path,
  )) {
    await _deleteFileIfChild(file: destination, directory: directory);
    throw const ComposerAttachmentStagingException();
  }
  try {
    final copiedSizeBytes = await copiedFile.length();
    final mimeType = await resolveMimeTypeFromPath(
      path: copiedFile.path,
      fileName: fileName,
      declaredMimeType: source.mimeType,
    );
    final stagedAttachment = Attachment(
      path: copiedFile.path,
      fileName: fileName,
      sizeBytes: copiedSizeBytes > 0 ? copiedSizeBytes : sourceSizeBytes,
      mimeType: mimeType,
    );
    final optimized = await EmailAttachmentOptimizer.optimize(stagedAttachment);
    final finalized = await _finalizeStagedAttachment(
      directory: directory,
      sourceCopy: copiedFile,
      attachment: optimized,
      fallbackId: fallbackId,
    );
    if (limit > 0 && finalized.sizeBytes > limit) {
      await _deleteFileIfChild(
        file: File(finalized.path),
        directory: directory,
      );
      throw const ComposerAttachmentTooLargeException();
    }
    return ComposerAttachmentStage(
      attachment: finalized,
      staged: ComposerStagedAttachment(
        sessionId: sessionId,
        path: finalized.path,
      ),
    );
  } on FileSystemException catch (error) {
    await _deleteFileIfChild(file: copiedFile, directory: directory);
    throw ComposerAttachmentStagingException(error);
  }
}

Future<ComposerAttachmentCommit> commitComposerStagedAttachment({
  required Attachment attachment,
  required String metadataId,
  required Directory committedDirectory,
}) async {
  final bool isStaged;
  try {
    isStaged = await isComposerStagedAttachmentPath(attachment.path);
  } on FileSystemException catch (error) {
    throw ComposerAttachmentStagingException(error);
  } on MissingPluginException catch (error) {
    throw ComposerAttachmentStagingException(error);
  } on PlatformException catch (error) {
    throw ComposerAttachmentStagingException(error);
  }
  if (!isStaged) {
    return ComposerAttachmentCommit(
      attachment: attachment.copyWith(metadataId: metadataId),
      committedDirectoryPath: null,
      committedPath: null,
      stagedPath: null,
    );
  }
  final directory = committedDirectory;
  final fileName = _composerAttachmentFileName(
    fileName: attachment.fileName,
    path: attachment.path,
    fallback: metadataId,
  );
  final File destination;
  try {
    final attachmentRoot = await appOwnedAttachmentRootDirectory();
    if (!appOwnedPathIsChildOf(
      rootPath: attachmentRoot.path,
      candidatePath: directory.path,
    )) {
      throw const ComposerAttachmentStagingException();
    }
    destination = await _uniqueAttachmentFile(
      directory: directory,
      fileName: _prefixedComposerAttachmentFileName(
        prefix: metadataId,
        fileName: fileName,
      ),
    );
  } on ComposerAttachmentStagingException {
    rethrow;
  } on FileSystemException catch (error) {
    throw ComposerAttachmentStagingException(error);
  } on MissingPluginException catch (error) {
    throw ComposerAttachmentStagingException(error);
  } on PlatformException catch (error) {
    throw ComposerAttachmentStagingException(error);
  }
  final source = File(attachment.path);
  final File committed;
  final int sizeBytes;
  try {
    committed = await _copyFile(source: source, destination: destination);
    sizeBytes = await committed.length();
  } on ComposerAttachmentStagingException {
    await _deleteFileIfChild(file: destination, directory: directory);
    rethrow;
  } on FileSystemException catch (error) {
    await _deleteFileIfChild(file: destination, directory: directory);
    throw ComposerAttachmentStagingException(error);
  }
  return ComposerAttachmentCommit(
    attachment: attachment.copyWith(
      path: committed.path,
      fileName: fileName,
      sizeBytes: sizeBytes > 0 ? sizeBytes : attachment.sizeBytes,
      metadataId: metadataId,
    ),
    committedDirectoryPath: directory.path,
    committedPath: committed.path,
    stagedPath: attachment.path,
  );
}

Future<void> deleteCommittedComposerAttachment(
  ComposerAttachmentCommit commit,
) async {
  final path = commit.committedPath;
  if (path == null || path.trim().isEmpty) {
    return;
  }
  final directoryPath = commit.committedDirectoryPath;
  if (directoryPath == null || directoryPath.trim().isEmpty) {
    return;
  }
  final attachmentRoot = await appOwnedAttachmentRootDirectory();
  if (!appOwnedPathIsChildOf(
    rootPath: attachmentRoot.path,
    candidatePath: directoryPath,
  )) {
    return;
  }
  final directory = Directory(directoryPath);
  await _deleteFileIfChild(file: File(path), directory: directory);
}

Future<void> deleteComposerStagedAttachment(
  ComposerStagedAttachment staged,
) async {
  await deleteComposerStagedAttachmentPath(staged.path);
}

Future<void> deleteComposerStagedAttachmentPath(String path) async {
  try {
    final directory = await appOwnedTemporaryDirectory(
      composerAttachmentStagingDirectoryName,
    );
    await _deleteFileIfChild(file: File(path), directory: directory);
  } on Exception {
    // Best-effort cleanup for app-owned composer staging.
  }
}

Future<bool> isComposerStagedAttachmentPath(String path) async {
  final directory = await appOwnedTemporaryDirectory(
    composerAttachmentStagingDirectoryName,
  );
  return appOwnedPathIsChildOf(rootPath: directory.path, candidatePath: path);
}

bool _mayOptimizeBelowLimit(Attachment attachment) {
  return attachment.isImage && !attachment.isGif;
}

Future<int> _sourceSizeBytes(AttachmentImportSource source) async {
  try {
    return await source.loadSizeBytes();
  } on AttachmentImportException {
    rethrow;
  } on FileSystemException catch (error) {
    throw AttachmentImportException(error);
  }
}

Future<Attachment> _finalizeStagedAttachment({
  required Directory directory,
  required File sourceCopy,
  required Attachment attachment,
  required String fallbackId,
}) async {
  final fileName = _composerAttachmentFileName(
    fileName: attachment.fileName,
    path: attachment.path,
    fallback: fallbackId,
  );
  if (p.equals(sourceCopy.path, attachment.path)) {
    return attachment.copyWith(fileName: fileName);
  }
  final optimizedFile = File(attachment.path);
  final optimizedBytes = await optimizedFile.readAsBytes();
  await sourceCopy.writeAsBytes(optimizedBytes, flush: true);
  await _deleteFileIfChild(file: optimizedFile, directory: directory);
  final sizeBytes = await sourceCopy.length();
  return attachment.copyWith(
    path: sourceCopy.path,
    fileName: fileName,
    sizeBytes: sizeBytes > 0 ? sizeBytes : attachment.sizeBytes,
  );
}

Future<File> _copyFile({
  required File source,
  required File destination,
}) async {
  try {
    await destination.parent.create(recursive: true);
    return source.copy(destination.path);
  } on FileSystemException catch (error) {
    throw ComposerAttachmentStagingException(error);
  }
}

Future<void> _deleteFileIfChild({
  required File file,
  required Directory directory,
}) async {
  if (!appOwnedPathIsChildOf(
    rootPath: directory.path,
    candidatePath: file.path,
  )) {
    return;
  }
  try {
    await deleteAppOwnedFile(file: file, expectedPath: file.path);
  } on FileSystemException {
    // Best-effort cleanup for app-owned staging/commit artifacts.
  }
}

Future<File> _uniqueAttachmentFile({
  required Directory directory,
  required String fileName,
}) async {
  var candidate = File(p.join(directory.path, fileName));
  if (!await candidate.exists()) {
    return candidate;
  }
  final basename = p.basenameWithoutExtension(fileName);
  final extension = p.extension(fileName);
  var suffix = 1;
  while (await candidate.exists()) {
    candidate = File(p.join(directory.path, '$basename-$suffix$extension'));
    suffix += 1;
  }
  return candidate;
}

String _composerAttachmentFileName({
  required String fileName,
  required String path,
  required String fallback,
}) {
  final candidate = fileName.trim().isNotEmpty
      ? fileName.trim()
      : p.basename(path).trim();
  final normalized = tryNormalizeAppOwnedPathSegment(candidate);
  if (normalized != null) {
    return normalized;
  }
  return fallback;
}

String _prefixedComposerAttachmentFileName({
  required String prefix,
  required String fileName,
}) {
  return '${normalizeAppOwnedPathSegment(prefix)}-$fileName';
}
