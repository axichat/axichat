// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

import 'calendar_attachment.dart';
import 'calendar_date_time.dart';

part 'calendar_alarm.freezed.dart';
part 'calendar_alarm.g.dart';

const int _calendarAlarmActionTypeId = 54;
const int _calendarAlarmActionAudioField = 0;
const int _calendarAlarmActionDisplayField = 1;
const int _calendarAlarmActionEmailField = 2;
const int _calendarAlarmActionProcedureField = 3;

const int _calendarAlarmTriggerTypeTypeId = 55;
const int _calendarAlarmTriggerTypeAbsoluteField = 0;
const int _calendarAlarmTriggerTypeRelativeField = 1;

const int _calendarAlarmRelativeToTypeId = 56;
const int _calendarAlarmRelativeToStartField = 0;
const int _calendarAlarmRelativeToEndField = 1;

const int _calendarAlarmOffsetDirectionTypeId = 57;
const int _calendarAlarmOffsetDirectionBeforeField = 0;
const int _calendarAlarmOffsetDirectionAfterField = 1;

const int _calendarAlarmTriggerTypeId = 58;
const int _calendarAlarmTriggerKindField = 0;
const int _calendarAlarmTriggerAbsoluteField = 1;
const int _calendarAlarmTriggerOffsetField = 2;
const int _calendarAlarmTriggerRelativeToField = 3;
const int _calendarAlarmTriggerOffsetDirectionField = 4;

const int _calendarAlarmRecipientTypeId = 59;
const int _calendarAlarmRecipientAddressField = 0;
const int _calendarAlarmRecipientCommonNameField = 1;

const int _calendarAlarmTypeId = 60;
const int _calendarAlarmActionField = 0;
const int _calendarAlarmTriggerField = 1;
const int _calendarAlarmRepeatField = 2;
const int _calendarAlarmDurationField = 3;
const int _calendarAlarmDescriptionField = 4;
const int _calendarAlarmSummaryField = 5;
const int _calendarAlarmAttachmentsField = 6;
const int _calendarAlarmAcknowledgedField = 7;
const int _calendarAlarmRecipientsField = 8;

const List<CalendarAttachment> _emptyCalendarAttachments =
    <CalendarAttachment>[];
const List<CalendarAlarmRecipient> _emptyCalendarAlarmRecipients =
    <CalendarAlarmRecipient>[];

const String _calendarAlarmActionAudioIcs = 'AUDIO';
const String _calendarAlarmActionDisplayIcs = 'DISPLAY';
const String _calendarAlarmActionEmailIcs = 'EMAIL';
const String _calendarAlarmActionProcedureIcs = 'PROCEDURE';

const String _calendarAlarmTriggerTypeAbsoluteIcs = 'ABSOLUTE';
const String _calendarAlarmTriggerTypeRelativeIcs = 'RELATIVE';

const String _calendarAlarmRelativeToStartIcs = 'START';
const String _calendarAlarmRelativeToEndIcs = 'END';

const String _calendarAlarmOffsetDirectionBeforeIcs = 'BEFORE';
const String _calendarAlarmOffsetDirectionAfterIcs = 'AFTER';

@HiveType(typeId: _calendarAlarmActionTypeId)
enum CalendarAlarmAction {
  @HiveField(_calendarAlarmActionAudioField)
  audio,
  @HiveField(_calendarAlarmActionDisplayField)
  display,
  @HiveField(_calendarAlarmActionEmailField)
  email,
  @HiveField(_calendarAlarmActionProcedureField)
  procedure;

  bool get isAudio => this == CalendarAlarmAction.audio;
  bool get isDisplay => this == CalendarAlarmAction.display;
  bool get isEmail => this == CalendarAlarmAction.email;
  bool get isProcedure => this == CalendarAlarmAction.procedure;

  String get icsValue => switch (this) {
        CalendarAlarmAction.audio => _calendarAlarmActionAudioIcs,
        CalendarAlarmAction.display => _calendarAlarmActionDisplayIcs,
        CalendarAlarmAction.email => _calendarAlarmActionEmailIcs,
        CalendarAlarmAction.procedure => _calendarAlarmActionProcedureIcs,
      };

  static CalendarAlarmAction? fromIcsValue(String? value) => switch (value) {
        _calendarAlarmActionAudioIcs => CalendarAlarmAction.audio,
        _calendarAlarmActionDisplayIcs => CalendarAlarmAction.display,
        _calendarAlarmActionEmailIcs => CalendarAlarmAction.email,
        _calendarAlarmActionProcedureIcs => CalendarAlarmAction.procedure,
        _ => null,
      };
}

@HiveType(typeId: _calendarAlarmTriggerTypeTypeId)
enum CalendarAlarmTriggerType {
  @HiveField(_calendarAlarmTriggerTypeAbsoluteField)
  absolute,
  @HiveField(_calendarAlarmTriggerTypeRelativeField)
  relative;

  bool get isAbsolute => this == CalendarAlarmTriggerType.absolute;
  bool get isRelative => this == CalendarAlarmTriggerType.relative;

  String get icsValue => switch (this) {
        CalendarAlarmTriggerType.absolute =>
          _calendarAlarmTriggerTypeAbsoluteIcs,
        CalendarAlarmTriggerType.relative =>
          _calendarAlarmTriggerTypeRelativeIcs,
      };

  static CalendarAlarmTriggerType? fromIcsValue(String? value) =>
      switch (value) {
        _calendarAlarmTriggerTypeAbsoluteIcs =>
          CalendarAlarmTriggerType.absolute,
        _calendarAlarmTriggerTypeRelativeIcs =>
          CalendarAlarmTriggerType.relative,
        _ => null,
      };
}

@HiveType(typeId: _calendarAlarmRelativeToTypeId)
enum CalendarAlarmRelativeTo {
  @HiveField(_calendarAlarmRelativeToStartField)
  start,
  @HiveField(_calendarAlarmRelativeToEndField)
  end;

  bool get isStart => this == CalendarAlarmRelativeTo.start;
  bool get isEnd => this == CalendarAlarmRelativeTo.end;

  String get icsValue => switch (this) {
        CalendarAlarmRelativeTo.start => _calendarAlarmRelativeToStartIcs,
        CalendarAlarmRelativeTo.end => _calendarAlarmRelativeToEndIcs,
      };

  static CalendarAlarmRelativeTo? fromIcsValue(String? value) =>
      switch (value) {
        _calendarAlarmRelativeToStartIcs => CalendarAlarmRelativeTo.start,
        _calendarAlarmRelativeToEndIcs => CalendarAlarmRelativeTo.end,
        _ => null,
      };
}

@HiveType(typeId: _calendarAlarmOffsetDirectionTypeId)
enum CalendarAlarmOffsetDirection {
  @HiveField(_calendarAlarmOffsetDirectionBeforeField)
  before,
  @HiveField(_calendarAlarmOffsetDirectionAfterField)
  after;

  bool get isBefore => this == CalendarAlarmOffsetDirection.before;
  bool get isAfter => this == CalendarAlarmOffsetDirection.after;

  String get icsValue => switch (this) {
        CalendarAlarmOffsetDirection.before =>
          _calendarAlarmOffsetDirectionBeforeIcs,
        CalendarAlarmOffsetDirection.after =>
          _calendarAlarmOffsetDirectionAfterIcs,
      };

  static CalendarAlarmOffsetDirection? fromIcsValue(String? value) =>
      switch (value) {
        _calendarAlarmOffsetDirectionBeforeIcs =>
          CalendarAlarmOffsetDirection.before,
        _calendarAlarmOffsetDirectionAfterIcs =>
          CalendarAlarmOffsetDirection.after,
        _ => null,
      };
}

@freezed
@HiveType(typeId: _calendarAlarmTriggerTypeId)
class CalendarAlarmTrigger with _$CalendarAlarmTrigger {
  const factory CalendarAlarmTrigger({
    @HiveField(_calendarAlarmTriggerKindField)
    required CalendarAlarmTriggerType type,
    @HiveField(_calendarAlarmTriggerAbsoluteField) CalendarDateTime? absolute,
    @HiveField(_calendarAlarmTriggerOffsetField) Duration? offset,
    @HiveField(_calendarAlarmTriggerRelativeToField)
    CalendarAlarmRelativeTo? relativeTo,
    @HiveField(_calendarAlarmTriggerOffsetDirectionField)
    CalendarAlarmOffsetDirection? offsetDirection,
  }) = _CalendarAlarmTrigger;

  factory CalendarAlarmTrigger.fromJson(Map<String, dynamic> json) =>
      _$CalendarAlarmTriggerFromJson(json);
}

@freezed
@HiveType(typeId: _calendarAlarmRecipientTypeId)
class CalendarAlarmRecipient with _$CalendarAlarmRecipient {
  const factory CalendarAlarmRecipient({
    @HiveField(_calendarAlarmRecipientAddressField) required String address,
    @HiveField(_calendarAlarmRecipientCommonNameField) String? commonName,
  }) = _CalendarAlarmRecipient;

  factory CalendarAlarmRecipient.fromJson(Map<String, dynamic> json) =>
      _$CalendarAlarmRecipientFromJson(json);
}

@freezed
@HiveType(typeId: _calendarAlarmTypeId)
class CalendarAlarm with _$CalendarAlarm {
  const factory CalendarAlarm({
    @HiveField(_calendarAlarmActionField) required CalendarAlarmAction action,
    @HiveField(_calendarAlarmTriggerField)
    required CalendarAlarmTrigger trigger,
    @HiveField(_calendarAlarmRepeatField) int? repeat,
    @HiveField(_calendarAlarmDurationField) Duration? duration,
    @HiveField(_calendarAlarmDescriptionField) String? description,
    @HiveField(_calendarAlarmSummaryField) String? summary,
    @HiveField(_calendarAlarmAttachmentsField)
    @Default(_emptyCalendarAttachments)
    List<CalendarAttachment> attachments,
    @HiveField(_calendarAlarmAcknowledgedField) DateTime? acknowledged,
    @HiveField(_calendarAlarmRecipientsField)
    @Default(_emptyCalendarAlarmRecipients)
    List<CalendarAlarmRecipient> recipients,
  }) = _CalendarAlarm;

  factory CalendarAlarm.fromJson(Map<String, dynamic> json) =>
      _$CalendarAlarmFromJson(json);
}
