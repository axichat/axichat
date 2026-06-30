// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

const int defaultExportPickerBytesMaxSize = 256 * 1024 * 1024;

class ExportSaveFileTooLargeException implements Exception {
  const ExportSaveFileTooLargeException({
    required this.byteCount,
    required this.maxBytes,
  });

  final int byteCount;
  final int maxBytes;
}

bool exportSaveShouldWriteBytes(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => false,
  };
}

Future<String?> saveExportFileWithPicker({
  required File file,
  required String filename,
  required TargetPlatform platform,
  FilePicker? filePicker,
  int? maxBytesForBytesSave,
  bool deleteSource = false,
}) async {
  var savedSourceInPlace = false;
  try {
    if (exportSaveShouldWriteBytes(platform)) {
      final byteCount = await file.length();
      if (maxBytesForBytesSave != null && byteCount > maxBytesForBytesSave) {
        throw ExportSaveFileTooLargeException(
          byteCount: byteCount,
          maxBytes: maxBytesForBytesSave,
        );
      }
      final picker = filePicker ?? FilePicker.platform;
      return picker.saveFile(
        fileName: filename,
        bytes: await file.readAsBytes(),
      );
    }

    final picker = filePicker ?? FilePicker.platform;
    final savePath = await picker.saveFile(fileName: filename);
    if (savePath == null || savePath.trim().isEmpty) {
      return savePath;
    }
    final destination = File(savePath);
    savedSourceInPlace = p.equals(destination.path, file.path);
    if (!savedSourceInPlace) {
      await file.copy(destination.path);
    }
    return savePath;
  } finally {
    if (deleteSource && !savedSourceInPlace) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } on Exception {
        // Export temp cleanup is best-effort.
      }
    }
  }
}
