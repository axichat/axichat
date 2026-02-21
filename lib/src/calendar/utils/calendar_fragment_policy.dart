// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/models/calendar_acl.dart';
import 'package:axichat/src/calendar/utils/calendar_acl_utils.dart';
import 'package:axichat/src/calendar/utils/task_share_formatter.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/storage/models/chat_models.dart';

const int _fragmentChecklistPreviewLimit = 4;

class CalendarFragmentShareDecision {
  const CalendarFragmentShareDecision({required this.canWrite});

  final bool canWrite;
}

class CalendarFragmentPolicy {
  const CalendarFragmentPolicy();

  CalendarFragmentShareDecision decisionForChat({
    required Chat? chat,
    RoomState? roomState,
  }) {
    if (chat == null || !chat.supportsChatCalendar) {
      return const CalendarFragmentShareDecision(canWrite: false);
    }
    if (chat.type != ChatType.groupChat) {
      return const CalendarFragmentShareDecision(canWrite: true);
    }
    if (roomState == null) {
      return const CalendarFragmentShareDecision(canWrite: false);
    }
    final CalendarChatRole role = roomState.myRole.calendarChatRole;
    final CalendarChatAcl acl = chat.type.calendarDefaultAcl;
    final bool canWrite = role.allows(acl.write);
    return CalendarFragmentShareDecision(canWrite: canWrite);
  }
}

extension ChatCalendarSupportX on Chat {
  bool get supportsChatCalendar => defaultTransport.isXmpp;
}

class CalendarFragmentFormatter {
  const CalendarFragmentFormatter(this.l10n);

  final AppLocalizations l10n;

  String describe(CalendarFragment fragment) {
    return fragment.when(
      task: (task) => task.toShareText(l10n),
      checklist: (taskId, checklist) => _formatChecklist(checklist),
      reminder: (taskId, reminders) => _formatReminders(reminders),
      dayEvent: (event) => _formatDayEvent(event),
      criticalPath: (path, tasks) => _formatCriticalPath(path, tasks),
      freeBusy: (interval) => _formatFreeBusy(interval),
      availability: (window) => _formatAvailability(window),
    );
  }

  String _formatChecklist(List<TaskChecklistItem> checklist) {
    if (checklist.isEmpty) {
      return l10n.calendarFragmentChecklistLabel;
    }
    final labels = checklist
        .map((item) => item.label.trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);
    if (labels.isEmpty) {
      return l10n.calendarFragmentChecklistLabel;
    }
    final visibleLabels = labels.length <= _fragmentChecklistPreviewLimit
        ? labels
        : labels.sublist(0, _fragmentChecklistPreviewLimit);
    final summary = visibleLabels.join(l10n.calendarFragmentChecklistSeparator);
    if (labels.length <= _fragmentChecklistPreviewLimit) {
      return l10n.calendarFragmentChecklistSummary(summary);
    }
    final remaining = labels.length - _fragmentChecklistPreviewLimit;
    return l10n.calendarFragmentChecklistSummaryMore(summary, remaining);
  }

  String _formatReminders(ReminderPreferences reminders) {
    if (!reminders.isEnabled) {
      return l10n.calendarFragmentRemindersLabel;
    }
    final startOffsets = _formatOffsets(reminders.startOffsets);
    final deadlineOffsets = _formatOffsets(reminders.deadlineOffsets);
    final parts = <String>[];
    if (startOffsets.isNotEmpty) {
      parts.add(l10n.calendarFragmentReminderStartSummary(startOffsets));
    }
    if (deadlineOffsets.isNotEmpty) {
      parts.add(l10n.calendarFragmentReminderDeadlineSummary(deadlineOffsets));
    }
    if (parts.isEmpty) {
      return l10n.calendarFragmentRemindersLabel;
    }
    return l10n.calendarFragmentRemindersSummary(
      parts.join(l10n.calendarFragmentReminderSeparator),
    );
  }

  String _formatOffsets(List<Duration> offsets) {
    if (offsets.isEmpty) {
      return '';
    }
    final labels = offsets
        .map((offset) => TimeFormatter.formatDuration(l10n, offset))
        .toList(growable: false);
    return labels.join(l10n.calendarFragmentReminderSeparator);
  }

  String _formatDayEvent(DayEvent event) {
    final String title = event.title.trim().isNotEmpty
        ? event.title.trim()
        : l10n.calendarFragmentEventTitleFallback;
    final String range = _formatDateRange(
      start: event.startDate,
      end: event.endDate,
    );
    return l10n.calendarFragmentDayEventSummary(title, range);
  }

  String _formatFreeBusy(CalendarFreeBusyInterval interval) {
    final range = _formatDateTimeRange(
      start: interval.start.value,
      end: interval.end.value,
    );
    return l10n.calendarFragmentFreeBusySummary(
      interval.type.label(l10n),
      range,
    );
  }

  String _formatCriticalPath(
    CalendarCriticalPath path,
    List<CalendarTask> tasks,
  ) {
    final String name = path.name.trim().isNotEmpty
        ? path.name.trim()
        : l10n.calendarFragmentCriticalPathLabel;
    if (tasks.isEmpty) {
      return l10n.calendarFragmentCriticalPathSummary(name);
    }
    final int completed = tasks.where((task) => task.isCompleted).length;
    final String progress = l10n.calendarFragmentCriticalPathProgress(
      completed,
      tasks.length,
    );
    return l10n.calendarFragmentCriticalPathDetail(name, progress);
  }

  String _formatAvailability(CalendarAvailabilityWindow window) {
    final range = _formatDateTimeRange(
      start: window.start.value,
      end: window.end.value,
    );
    final summary = window.summary?.trim();
    if (summary?.isNotEmpty == true) {
      return l10n.calendarFragmentAvailabilitySummary(summary!, range);
    }
    return l10n.calendarFragmentAvailabilityFallback(range);
  }

  String _formatDateRange({required DateTime start, DateTime? end}) {
    final startLabel = TimeFormatter.formatFriendlyDate(start);
    final endLabel = end == null ? null : TimeFormatter.formatFriendlyDate(end);
    if (endLabel == null || endLabel == startLabel) {
      return startLabel;
    }
    return l10n.commonRangeLabel(startLabel, endLabel);
  }

  String _formatDateTimeRange({
    required DateTime start,
    required DateTime end,
  }) {
    final startLabel = TimeFormatter.formatFriendlyDateTime(l10n, start);
    final endLabel = TimeFormatter.formatFriendlyDateTime(l10n, end);
    if (startLabel == endLabel) {
      return startLabel;
    }
    return l10n.commonRangeLabel(startLabel, endLabel);
  }
}
