// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/storage/models.dart';

Stream<List<Message>> exportHistoryPages({
  required String jid,
  required Future<int> Function(String jid) countHistory,
  required Future<List<Message>> Function({
    required String jid,
    required int offset,
    required int limit,
  })
  loadHistoryPage,
  int pageSize = 200,
}) async* {
  final total = await countHistory(jid);
  var remaining = total;
  while (remaining > 0) {
    final offset = remaining > pageSize ? remaining - pageSize : 0;
    final limit = remaining - offset;
    final page = await loadHistoryPage(jid: jid, offset: offset, limit: limit);
    if (page.isEmpty) {
      break;
    }
    yield page.reversed.toList(growable: false);
    remaining = offset;
  }
}

Future<void> writeExportWarningsFile({
  required File file,
  required String header,
  required List<String> warnings,
}) async {
  final sink = file.openWrite();
  try {
    sink.writeln(header);
    sink.writeln();
    for (final warning in warnings) {
      sink.writeln('- $warning');
    }
  } finally {
    await sink.flush();
    await sink.close();
  }
}
