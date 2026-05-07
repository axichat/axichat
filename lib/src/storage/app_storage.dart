// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory>? _preparedAppStorageDirectory;
final Map<String, Future<Directory>> _preparedAppStorageSubdirectories = {};

const _legacyRootBoxFiles = <String>{
  'guest_calendar_state.hive',
  'guest_calendar_state.lock',
  'hydrated_box.hive',
  'hydrated_box.lock',
};

Future<Directory> prepareAppStorageDirectory() {
  return _preparedAppStorageDirectory ??= _prepareAppStorageDirectory();
}

Future<Directory> prepareAppStorageSubdirectory(String subdirectory) {
  final normalizedSubdirectory = normalizeAppOwnedPathSegment(subdirectory);
  return _preparedAppStorageSubdirectories.putIfAbsent(
    normalizedSubdirectory,
    () => _prepareAppStorageSubdirectory(normalizedSubdirectory),
  );
}

Future<Directory> _prepareAppStorageDirectory() async {
  final targetDirectory = await getApplicationSupportDirectory();
  await targetDirectory.create(recursive: true);

  if (kIsWeb) {
    return targetDirectory;
  }

  final legacyDirectory = await getApplicationDocumentsDirectory();
  if (p.equals(legacyDirectory.path, targetDirectory.path)) {
    return targetDirectory;
  }

  await _migrateLegacyRootStorage(
    legacyDirectory: legacyDirectory,
    targetDirectory: targetDirectory,
  );
  return targetDirectory;
}

Future<Directory> _prepareAppStorageSubdirectory(String subdirectory) async {
  final rootDirectory = await prepareAppStorageDirectory();
  final targetDirectory = Directory(p.join(rootDirectory.path, subdirectory));
  await targetDirectory.create(recursive: true);

  if (kIsWeb) {
    return targetDirectory;
  }

  final legacyRootDirectory = await getApplicationDocumentsDirectory();
  if (p.equals(legacyRootDirectory.path, rootDirectory.path)) {
    return targetDirectory;
  }

  final legacyDirectory = Directory(
    p.join(legacyRootDirectory.path, subdirectory),
  );
  await _mergeDirectoryContents(
    sourceDirectory: legacyDirectory,
    targetDirectory: targetDirectory,
  );
  return targetDirectory;
}

Future<void> _migrateLegacyRootStorage({
  required Directory legacyDirectory,
  required Directory targetDirectory,
}) async {
  if (!await legacyDirectory.exists()) {
    return;
  }

  await for (final entity in legacyDirectory.list(
    recursive: false,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }
    final fileName = p.basename(entity.path);
    if (!_isLegacyRootStorageFile(fileName)) {
      continue;
    }
    await _moveFileIfMissing(
      sourceFile: entity,
      targetFile: File(p.join(targetDirectory.path, fileName)),
    );
  }
}

bool _isLegacyRootStorageFile(String fileName) {
  return _legacyRootBoxFiles.contains(fileName) ||
      fileName.endsWith('.axichat.drift') ||
      fileName.endsWith('.axichat.drift-journal') ||
      fileName.endsWith('.axichat.drift-shm') ||
      fileName.endsWith('.axichat.drift-wal');
}

Future<void> _mergeDirectoryContents({
  required Directory sourceDirectory,
  required Directory targetDirectory,
}) async {
  if (!await sourceDirectory.exists()) {
    return;
  }

  if (!await targetDirectory.exists()) {
    try {
      await sourceDirectory.rename(targetDirectory.path);
      return;
    } on FileSystemException {
      await targetDirectory.create(recursive: true);
    }
  }

  await for (final entity in sourceDirectory.list(
    recursive: false,
    followLinks: false,
  )) {
    final entityName = p.basename(entity.path);
    final targetPath = p.join(targetDirectory.path, entityName);
    if (entity is Directory) {
      await _mergeDirectoryContents(
        sourceDirectory: entity,
        targetDirectory: Directory(targetPath),
      );
      continue;
    }
    if (entity is File) {
      await _moveFileIfMissing(
        sourceFile: entity,
        targetFile: File(targetPath),
      );
    }
  }

  try {
    if (!await sourceDirectory.list(followLinks: false).isEmpty) {
      return;
    }
    await sourceDirectory.delete();
  } on FileSystemException {
    // Best-effort cleanup only.
  }
}

Future<void> _moveFileIfMissing({
  required File sourceFile,
  required File targetFile,
}) async {
  if (!await sourceFile.exists() || await targetFile.exists()) {
    return;
  }

  await targetFile.parent.create(recursive: true);
  try {
    await sourceFile.rename(targetFile.path);
    return;
  } on FileSystemException {
    await sourceFile.copy(targetFile.path);
    try {
      await sourceFile.delete();
    } on FileSystemException {
      // Best-effort cleanup only.
    }
  }
}
