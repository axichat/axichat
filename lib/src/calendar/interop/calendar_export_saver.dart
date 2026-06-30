// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/common/export_file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

Future<String?> saveCalendarExport({required File file}) {
  return saveExportFileWithPicker(
    file: file,
    filename: p.basename(file.path),
    platform: defaultTargetPlatform,
    deleteSource: true,
  );
}
