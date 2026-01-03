// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:hive/hive.dart';

import 'calendar_ics_meta.dart';

part 'calendar_item.g.dart';

const int _calendarItemTypeTypeId = 79;
const int _calendarItemTypeEventField = 0;
const int _calendarItemTypeTaskField = 1;
const int _calendarItemTypeJournalField = 2;

@HiveType(typeId: _calendarItemTypeTypeId)
enum CalendarItemType {
  @HiveField(_calendarItemTypeEventField)
  event,
  @HiveField(_calendarItemTypeTaskField)
  task,
  @HiveField(_calendarItemTypeJournalField)
  journal;

  bool get isEvent => this == CalendarItemType.event;
  bool get isTask => this == CalendarItemType.task;
  bool get isJournal => this == CalendarItemType.journal;
}

mixin CalendarItemBase {
  String get id;
  String get title;
  String? get description;
  CalendarIcsMeta? get icsMeta;
  CalendarItemType get itemType;
}
