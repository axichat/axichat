// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/common/attachment_import_source.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class DroppedAttachmentSourceResult {
  const DroppedAttachmentSourceResult({
    required this.sources,
    required this.skippedCount,
  });

  final List<AttachmentImportSource> sources;
  final int skippedCount;

  bool get hasSkippedItems => skippedCount > 0;
}

DroppedAttachmentSourceResult droppedAttachmentSourcesFromItems(
  Iterable<DropItem> items,
) {
  final sources = <AttachmentImportSource>[];
  var skippedCount = 0;
  for (final item in items) {
    if (item is! DropItemFile) {
      skippedCount += 1;
      continue;
    }
    final path = item.path;
    if (path.trim().isEmpty) {
      skippedCount += 1;
      continue;
    }
    final fileName = _dropItemFileName(item, path);
    if (fileName == null) {
      skippedCount += 1;
      continue;
    }
    sources.add(
      DroppedFileAttachmentImportSource(
        item: item,
        path: path,
        fileName: fileName,
        mimeType: _normalizedMimeType(item.mimeType),
      ),
    );
  }
  return DroppedAttachmentSourceResult(
    sources: List<AttachmentImportSource>.unmodifiable(sources),
    skippedCount: skippedCount,
  );
}

final class DroppedFileAttachmentImportSource
    extends LocalFileAttachmentImportSource {
  const DroppedFileAttachmentImportSource({
    required this.item,
    required super.path,
    required super.fileName,
    super.mimeType,
  });

  final DropItemFile item;

  @override
  Future<int> loadSizeBytes() {
    return _withSecurityScopedAccess(item.length);
  }

  @override
  Future<File> copyTo(File destination) async {
    return _withSecurityScopedAccess(() => super.copyTo(destination));
  }

  Future<T> _withSecurityScopedAccess<T>(Future<T> Function() operation) async {
    final bookmark = item.extraAppleBookmark;
    if (bookmark == null || bookmark.isEmpty) {
      return operation();
    }
    final bool accessStarted;
    try {
      accessStarted = await DesktopDrop.instance
          .startAccessingSecurityScopedResource(bookmark: bookmark);
    } on PlatformException catch (error) {
      throw AttachmentImportException(error);
    }
    try {
      return await operation();
    } finally {
      if (accessStarted) {
        try {
          await DesktopDrop.instance.stopAccessingSecurityScopedResource(
            bookmark: bookmark,
          );
        } on PlatformException {
          // The copy is complete; release failures are not composer state.
        }
      }
    }
  }
}

String? _dropItemFileName(DropItemFile item, String path) {
  final itemName = p.basename(item.name.trim()).trim();
  final pathName = p.basename(path).trim();
  final fileName = itemName.isNotEmpty ? itemName : pathName;
  final trimmed = fileName.trim();
  if (trimmed.isEmpty || trimmed == '.' || trimmed == '..') {
    return null;
  }
  return trimmed;
}

String? _normalizedMimeType(String? mimeType) {
  final String? trimmed = mimeType?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
