// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'calendar_attachment.freezed.dart';
part 'calendar_attachment.g.dart';

const int _calendarAttachmentTypeId = 49;
const int _calendarAttachmentValueField = 0;
const int _calendarAttachmentFormatTypeField = 1;
const int _calendarAttachmentEncodingField = 2;
const int _calendarAttachmentLabelField = 3;

@freezed
@HiveType(typeId: _calendarAttachmentTypeId)
class CalendarAttachment with _$CalendarAttachment {
  const factory CalendarAttachment({
    @HiveField(_calendarAttachmentValueField) required String value,
    @HiveField(_calendarAttachmentFormatTypeField) String? formatType,
    @HiveField(_calendarAttachmentEncodingField) String? encoding,
    @HiveField(_calendarAttachmentLabelField) String? label,
  }) = _CalendarAttachment;

  factory CalendarAttachment.fromJson(Map<String, dynamic> json) =>
      _$CalendarAttachmentFromJson(json);
}
