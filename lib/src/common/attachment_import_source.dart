// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

class AttachmentImportException implements Exception {
  const AttachmentImportException([this.wrapped]);

  final Object? wrapped;
}

abstract interface class AttachmentImportSource {
  String get path;
  String get fileName;
  String? get mimeType;

  Future<int> loadSizeBytes();
  Future<File> copyTo(File destination);
}

class LocalFileAttachmentImportSource implements AttachmentImportSource {
  const LocalFileAttachmentImportSource({
    required this.path,
    required this.fileName,
    this.mimeType,
    this.sizeBytes,
  });

  @override
  final String path;

  @override
  final String fileName;

  @override
  final String? mimeType;

  final int? sizeBytes;

  @override
  Future<int> loadSizeBytes() async {
    final declaredSizeBytes = sizeBytes;
    if (declaredSizeBytes != null && declaredSizeBytes > 0) {
      return declaredSizeBytes;
    }
    try {
      return File(path).length();
    } on FileSystemException catch (error) {
      throw AttachmentImportException(error);
    }
  }

  @override
  Future<File> copyTo(File destination) async {
    try {
      await destination.parent.create(recursive: true);
      return await File(path).copy(destination.path);
    } on FileSystemException catch (error) {
      throw AttachmentImportException(error);
    }
  }
}
