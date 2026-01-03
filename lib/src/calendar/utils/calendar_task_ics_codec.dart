// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/calendar_ics_codec.dart';

const String _emptyCalendarChecksum = '';

class CalendarTaskIcsCodec {
  const CalendarTaskIcsCodec();

  static const CalendarIcsCodec _icsCodec = CalendarIcsCodec();

  String encode(CalendarTask task) {
    final CalendarModel model = _modelFromTask(task);
    return _icsCodec.encode(model);
  }

  CalendarTask? decode(String data) {
    try {
      final CalendarModel model = _icsCodec.decode(data);
      if (model.tasks.isEmpty) {
        return null;
      }
      return model.tasks.values.first;
    } on FormatException {
      return null;
    }
  }

  CalendarModel _modelFromTask(CalendarTask task) {
    final DateTime now = DateTime.now();
    final CalendarModel model = CalendarModel(
      tasks: <String, CalendarTask>{task.id: task},
      lastModified: now,
      checksum: _emptyCalendarChecksum,
    );
    return model.copyWith(checksum: model.calculateChecksum());
  }
}
