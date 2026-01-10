// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Outcome of attempting to share a calendar export.
enum CalendarShareOutcome {
  shared,
  openedDirectory,
  copiedPath,
}

const Duration _calendarExportCleanupDelay = Duration(hours: 1);

Future<CalendarShareOutcome> shareCalendarExport({
  required File file,
  required String subject,
  required String text,
}) async {
  if (Platform.isLinux) {
    if (await _openDirectory(file.parent)) {
      _scheduleExportCleanup(file);
      return CalendarShareOutcome.openedDirectory;
    }
    await Clipboard.setData(ClipboardData(text: file.path));
    _scheduleExportCleanup(file);
    return CalendarShareOutcome.copiedPath;
  }

  await Share.shareXFiles(
    <XFile>[XFile(file.path)],
    subject: subject,
    text: text,
  );
  _scheduleExportCleanup(file);
  return CalendarShareOutcome.shared;
}

String calendarShareSuccessMessage({
  required CalendarShareOutcome outcome,
  required String filePath,
  required String sharedText,
}) {
  switch (outcome) {
    case CalendarShareOutcome.shared:
      return sharedText;
    case CalendarShareOutcome.openedDirectory:
      return 'Export saved to $filePath. Opening the containing folder because system share is unavailable on Linux.';
    case CalendarShareOutcome.copiedPath:
      return 'Export saved to $filePath. Path copied so you can share it manually.';
  }
}

Future<bool> _openDirectory(Directory directory) async {
  try {
    final ProcessResult result = await Process.run(
      'xdg-open',
      <String>[directory.path],
    );
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

void _scheduleExportCleanup(File file) {
  unawaited(
    Future<void>.delayed(_calendarExportCleanupDelay, () async {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } on Exception {
        return;
      }
    }),
  );
}
