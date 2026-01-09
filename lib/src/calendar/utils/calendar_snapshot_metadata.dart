// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/sync/calendar_snapshot_codec.dart';
import 'package:axichat/src/storage/models/file_models.dart';

extension CalendarSnapshotMetadata on FileMetadataData {
  bool get isCalendarSnapshot {
    final String? normalizedMimeType = mimeType?.trim().toLowerCase();
    if (normalizedMimeType == CalendarSnapshotCodec.mimeType) {
      return true;
    }
    final String snapshotExtension =
        CalendarSnapshotCodec.fileExtension.toLowerCase();
    if (_matchesSnapshotExtension(filename, snapshotExtension)) {
      return true;
    }
    final List<String>? sources = sourceUrls;
    if (sources == null || sources.isEmpty) {
      return false;
    }
    for (final String source in sources) {
      final String sourcePath = _snapshotSourcePath(source);
      if (_matchesSnapshotExtension(sourcePath, snapshotExtension)) {
        return true;
      }
    }
    return false;
  }
}

bool _matchesSnapshotExtension(String value, String snapshotExtension) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  return trimmed.toLowerCase().endsWith(snapshotExtension);
}

String _snapshotSourcePath(String source) {
  final String trimmed = source.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  final Uri? uri = Uri.tryParse(trimmed);
  return (uri?.path ?? trimmed);
}
