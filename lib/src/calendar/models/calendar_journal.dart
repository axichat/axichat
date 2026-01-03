// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

import 'calendar_date_time.dart';
import 'calendar_ics_meta.dart';
import 'calendar_item.dart';

part 'calendar_journal.freezed.dart';
part 'calendar_journal.g.dart';

const int _calendarJournalTypeId = 80;
const int _calendarJournalIdField = 0;
const int _calendarJournalTitleField = 1;
const int _calendarJournalEntryDateField = 2;
const int _calendarJournalDescriptionField = 3;
const int _calendarJournalCreatedAtField = 4;
const int _calendarJournalModifiedAtField = 5;
const int _calendarJournalIcsMetaField = 6;

@freezed
@HiveType(typeId: _calendarJournalTypeId)
class CalendarJournal with _$CalendarJournal implements CalendarItemBase {
  const factory CalendarJournal({
    @HiveField(_calendarJournalIdField) required String id,
    @HiveField(_calendarJournalTitleField) required String title,
    @HiveField(_calendarJournalEntryDateField)
    required CalendarDateTime entryDate,
    @HiveField(_calendarJournalDescriptionField) String? description,
    @HiveField(_calendarJournalCreatedAtField) required DateTime createdAt,
    @HiveField(_calendarJournalModifiedAtField) required DateTime modifiedAt,
    @HiveField(_calendarJournalIcsMetaField) CalendarIcsMeta? icsMeta,
  }) = _CalendarJournal;

  const CalendarJournal._();

  @override
  CalendarItemType get itemType => CalendarItemType.journal;

  factory CalendarJournal.fromJson(Map<String, dynamic> json) =>
      _$CalendarJournalFromJson(json);
}
