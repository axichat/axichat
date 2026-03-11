// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const String emailAttachmentTempDirectoryName = 'email_attachments';
const String attachmentShareTempDirectoryName = 'attachment_shares';
const String chatHistoryExportTempDirectoryName = 'chat_history_exports';
const String contactExportTempDirectoryName = 'contact_exports';

Future<Directory> appOwnedTemporaryDirectory(String directoryName) async {
  final normalizedName = _normalizeDirectoryName(directoryName);
  final tempDirectory = await getTemporaryDirectory();
  return Directory(p.join(tempDirectory.path, normalizedName));
}

bool appOwnedPathsMatch({
  required String expectedPath,
  required String actualPath,
}) {
  final normalizedExpected = _normalizeAbsolutePath(expectedPath);
  final normalizedActual = _normalizeAbsolutePath(actualPath);
  if (normalizedExpected == null || normalizedActual == null) {
    return false;
  }
  return p.equals(normalizedExpected, normalizedActual);
}

bool appOwnedPathIsChildOf({
  required String rootPath,
  required String candidatePath,
}) {
  final normalizedRoot = _normalizeAbsolutePath(rootPath);
  final normalizedCandidate = _normalizeAbsolutePath(candidatePath);
  if (normalizedRoot == null || normalizedCandidate == null) {
    return false;
  }
  return p.isWithin(normalizedRoot, normalizedCandidate);
}

Future<bool> deleteAppOwnedDirectoryTree({
  required Directory directory,
  required String expectedPath,
}) async {
  if (!appOwnedPathsMatch(
    expectedPath: expectedPath,
    actualPath: directory.path,
  )) {
    return false;
  }
  final normalizedPath = _normalizeAbsolutePath(expectedPath);
  if (normalizedPath == null) {
    return false;
  }
  final entityType = await FileSystemEntity.type(
    normalizedPath,
    followLinks: false,
  );
  if (entityType == FileSystemEntityType.notFound) {
    return true;
  }
  if (entityType != FileSystemEntityType.directory) {
    return false;
  }
  final rootDirectory = Directory(normalizedPath);
  await _deleteAppOwnedDirectoryContents(
    directory: rootDirectory,
    rootPath: normalizedPath,
  );
  await rootDirectory.delete();
  return true;
}

Future<bool> deleteAppOwnedFile({
  required File file,
  required String expectedPath,
}) async {
  if (!appOwnedPathsMatch(expectedPath: expectedPath, actualPath: file.path)) {
    return false;
  }
  final normalizedPath = _normalizeAbsolutePath(expectedPath);
  if (normalizedPath == null) {
    return false;
  }
  final entityType = await FileSystemEntity.type(
    normalizedPath,
    followLinks: false,
  );
  switch (entityType) {
    case FileSystemEntityType.notFound:
      return true;
    case FileSystemEntityType.file:
      await File(normalizedPath).delete();
      return true;
    case FileSystemEntityType.link:
      await Link(normalizedPath).delete();
      return true;
    case FileSystemEntityType.directory:
      return false;
  }
  return false;
}

Future<void> _deleteAppOwnedDirectoryContents({
  required Directory directory,
  required String rootPath,
}) async {
  await for (final entity in directory.list(followLinks: false)) {
    final entityPath = _normalizeAbsolutePath(entity.path);
    if (entityPath == null ||
        !appOwnedPathIsChildOf(rootPath: rootPath, candidatePath: entityPath)) {
      throw StateError('Refusing to delete unexpected path: ${entity.path}');
    }
    final entityType = await FileSystemEntity.type(
      entityPath,
      followLinks: false,
    );
    switch (entityType) {
      case FileSystemEntityType.notFound:
        continue;
      case FileSystemEntityType.file:
        await File(entityPath).delete();
      case FileSystemEntityType.link:
        await Link(entityPath).delete();
      case FileSystemEntityType.directory:
        final childDirectory = Directory(entityPath);
        await _deleteAppOwnedDirectoryContents(
          directory: childDirectory,
          rootPath: rootPath,
        );
        await childDirectory.delete();
    }
  }
}

String _normalizeDirectoryName(String directoryName) {
  final trimmed = directoryName.trim();
  if (trimmed.isEmpty ||
      trimmed == '.' ||
      trimmed == '..' ||
      p.basename(trimmed) != trimmed) {
    throw ArgumentError.value(
      directoryName,
      'directoryName',
      'Expected a single directory name.',
    );
  }
  return trimmed;
}

String? _normalizeAbsolutePath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty || !p.isAbsolute(trimmed)) {
    return null;
  }
  return p.normalize(trimmed);
}
