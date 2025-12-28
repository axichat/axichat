import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/task_share_formatter.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/storage/models/chat_models.dart';

const String _fallbackEventTitle = 'Untitled event';

const String _fragmentLabelChecklist = 'Checklist';
const String _fragmentLabelDayEvent = 'Day event';
const String _fragmentLabelAvailability = 'Availability';
const String _fragmentLabelCriticalPath = 'Critical path';

const String _fragmentRangeSeparator = ' - ';
const String _fragmentChecklistSeparator = ', ';
const String _fragmentChecklistMorePrefix = 'and ';
const String _fragmentChecklistMoreSuffix = ' more';
const String _fragmentReminderLabel = 'Reminders';
const String _fragmentReminderStartLabel = 'Start';
const String _fragmentReminderDeadlineLabel = 'Deadline';
const String _fragmentReminderSeparator = ', ';
const String _fragmentInfoSeparator = ': ';
const String _fragmentDetailOpen = ' (';
const String _fragmentDetailClose = ')';
const String _fragmentFreeBusyLabel = 'Window';
const String _fragmentFreeBusyLabelFree = 'Free';
const String _fragmentFreeBusyLabelBusy = 'Busy';
const String _fragmentFreeBusyLabelBusyUnavailable = 'Busy (unavailable)';
const String _fragmentFreeBusyLabelBusyTentative = 'Busy (tentative)';
const String _emptyText = '';
const String _fragmentCriticalPathProgressSeparator = '/';
const String _fragmentCriticalPathProgressSuffix = ' done';

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
    return const CalendarFragmentShareDecision(canWrite: true);
  }
}

extension ChatCalendarSupportX on Chat {
  bool get supportsChatCalendar => defaultTransport.isXmpp;
}

extension CalendarFreeBusyTypeLabelX on CalendarFreeBusyType {
  String get label => switch (this) {
        CalendarFreeBusyType.free => _fragmentFreeBusyLabelFree,
        CalendarFreeBusyType.busy => _fragmentFreeBusyLabelBusy,
        CalendarFreeBusyType.busyUnavailable =>
          _fragmentFreeBusyLabelBusyUnavailable,
        CalendarFreeBusyType.busyTentative =>
          _fragmentFreeBusyLabelBusyTentative,
      };
}

class CalendarFragmentFormatter {
  const CalendarFragmentFormatter();

  String describe(CalendarFragment fragment) {
    return fragment.when(
      task: (task) => task.toShareText(),
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
      return _fragmentLabelChecklist;
    }
    final labels = checklist
        .map((item) => item.label.trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);
    if (labels.isEmpty) {
      return _fragmentLabelChecklist;
    }
    final visibleLabels = labels.length <= _fragmentChecklistPreviewLimit
        ? labels
        : labels.sublist(0, _fragmentChecklistPreviewLimit);
    final summary = visibleLabels.join(_fragmentChecklistSeparator);
    if (labels.length <= _fragmentChecklistPreviewLimit) {
      return '$_fragmentLabelChecklist$_fragmentInfoSeparator$summary';
    }
    final remaining = labels.length - _fragmentChecklistPreviewLimit;
    return '$_fragmentLabelChecklist$_fragmentInfoSeparator$summary '
        '$_fragmentChecklistMorePrefix$remaining$_fragmentChecklistMoreSuffix';
  }

  String _formatReminders(ReminderPreferences reminders) {
    if (!reminders.isEnabled) {
      return _fragmentReminderLabel;
    }
    final startOffsets = _formatOffsets(reminders.startOffsets);
    final deadlineOffsets = _formatOffsets(reminders.deadlineOffsets);
    final parts = <String>[];
    if (startOffsets.isNotEmpty) {
      parts.add(
        '$_fragmentReminderStartLabel$_fragmentInfoSeparator$startOffsets',
      );
    }
    if (deadlineOffsets.isNotEmpty) {
      parts.add(
        '$_fragmentReminderDeadlineLabel$_fragmentInfoSeparator$deadlineOffsets',
      );
    }
    if (parts.isEmpty) {
      return _fragmentReminderLabel;
    }
    return '$_fragmentReminderLabel$_fragmentInfoSeparator'
        '${parts.join(_fragmentReminderSeparator)}';
  }

  String _formatOffsets(List<Duration> offsets) {
    if (offsets.isEmpty) {
      return _emptyText;
    }
    final labels =
        offsets.map(TimeFormatter.formatDuration).toList(growable: false);
    return labels.join(_fragmentReminderSeparator);
  }

  String _formatDayEvent(DayEvent event) {
    final String title = event.title.trim().isNotEmpty
        ? event.title.trim()
        : _fallbackEventTitle;
    final String range = _formatDateRange(
      start: event.startDate,
      end: event.endDate,
    );
    return '$title$_fragmentDetailOpen'
        '$_fragmentLabelDayEvent$_fragmentInfoSeparator$range'
        '$_fragmentDetailClose';
  }

  String _formatFreeBusy(CalendarFreeBusyInterval interval) {
    final range = _formatDateTimeRange(
      start: interval.start.value,
      end: interval.end.value,
    );
    return '${interval.type.label}$_fragmentDetailOpen'
        '$_fragmentFreeBusyLabel$_fragmentInfoSeparator$range'
        '$_fragmentDetailClose';
  }

  String _formatCriticalPath(
    CalendarCriticalPath path,
    List<CalendarTask> tasks,
  ) {
    final String name = path.name.trim().isNotEmpty
        ? path.name.trim()
        : _fragmentLabelCriticalPath;
    if (tasks.isEmpty) {
      return '$_fragmentLabelCriticalPath$_fragmentInfoSeparator$name';
    }
    final int completed = tasks.where((task) => task.isCompleted).length;
    final String progress = '$completed$_fragmentCriticalPathProgressSeparator'
        '${tasks.length}$_fragmentCriticalPathProgressSuffix';
    return '$name$_fragmentDetailOpen'
        '$_fragmentLabelCriticalPath$_fragmentInfoSeparator$progress'
        '$_fragmentDetailClose';
  }

  String _formatAvailability(CalendarAvailabilityWindow window) {
    final range = _formatDateTimeRange(
      start: window.start.value,
      end: window.end.value,
    );
    final summary = window.summary?.trim();
    if (summary?.isNotEmpty == true) {
      return '$summary$_fragmentDetailOpen'
          '$_fragmentLabelAvailability$_fragmentInfoSeparator$range'
          '$_fragmentDetailClose';
    }
    return '$_fragmentLabelAvailability$_fragmentInfoSeparator$range';
  }

  String _formatDateRange({
    required DateTime start,
    DateTime? end,
  }) {
    final startLabel = TimeFormatter.formatFriendlyDate(start);
    final endLabel = end == null ? null : TimeFormatter.formatFriendlyDate(end);
    if (endLabel == null || endLabel == startLabel) {
      return startLabel;
    }
    return '$startLabel$_fragmentRangeSeparator$endLabel';
  }

  String _formatDateTimeRange({
    required DateTime start,
    required DateTime end,
  }) {
    final startLabel = TimeFormatter.formatFriendlyDateTime(start);
    final endLabel = TimeFormatter.formatFriendlyDateTime(end);
    if (startLabel == endLabel) {
      return startLabel;
    }
    return '$startLabel$_fragmentRangeSeparator$endLabel';
  }
}
