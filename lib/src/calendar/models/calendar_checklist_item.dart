// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'calendar_checklist_item.freezed.dart';
part 'calendar_checklist_item.g.dart';

const int _taskChecklistItemTypeId = 38;
const int _taskChecklistItemIdField = 0;
const int _taskChecklistItemLabelField = 1;
const int _taskChecklistItemIsCompletedField = 2;
const bool _taskChecklistItemDefaultCompleted = false;

@freezed
@HiveType(typeId: _taskChecklistItemTypeId)
class TaskChecklistItem with _$TaskChecklistItem {
  const factory TaskChecklistItem({
    @HiveField(_taskChecklistItemIdField) required String id,
    @HiveField(_taskChecklistItemLabelField) required String label,
    @HiveField(_taskChecklistItemIsCompletedField)
    @Default(_taskChecklistItemDefaultCompleted)
    bool isCompleted,
  }) = _TaskChecklistItem;

  factory TaskChecklistItem.fromJson(Map<String, dynamic> json) =>
      _$TaskChecklistItemFromJson(json);
}
