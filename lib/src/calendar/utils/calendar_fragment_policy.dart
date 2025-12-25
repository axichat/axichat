import 'package:axichat/src/calendar/models/calendar_acl.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/task_share_formatter.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/storage/models/chat_models.dart';

const CalendarChatAcl _defaultCalendarChatAcl = CalendarChatAcl(
  read: CalendarChatRole.visitor,
  write: CalendarChatRole.participant,
  manage: CalendarChatRole.moderator,
  delete: CalendarChatRole.moderator,
);

const CalendarFragmentVisibility _defaultFragmentVisibility =
    CalendarFragmentVisibility.full;
const CalendarFragmentVisibility _redactedFragmentVisibility =
    CalendarFragmentVisibility.redacted;

const CalendarChatRole _calendarChatRoleFallback = CalendarChatRole.none;

const int _calendarChatRolePriorityNone = 0;
const int _calendarChatRolePriorityVisitor = 1;
const int _calendarChatRolePriorityParticipant = 2;
const int _calendarChatRolePriorityModerator = 3;

const String _redactedTaskTitle = 'Private task';
const String _redactedEventTitle = 'Private event';
const String _redactedChecklistItemLabel = 'Private item';
const String _redactedChecklistItemIdPrefix = 'redacted-';

const String _fragmentLabelChecklist = 'Checklist';
const String _fragmentLabelDayEvent = 'Day event';
const String _fragmentLabelAvailability = 'Availability';

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

const int _fragmentChecklistPreviewLimit = 4;

const List<TaskChecklistItem> _emptyTaskChecklistItems = <TaskChecklistItem>[];
const Map<String, TaskOccurrenceOverride> _emptyTaskOverrides =
    <String, TaskOccurrenceOverride>{};
const ReminderPreferences _disabledReminders = ReminderPreferences(
  enabled: false,
  startOffsets: <Duration>[],
  deadlineOffsets: <Duration>[],
);

enum CalendarFragmentVisibility {
  full,
  redacted;
}

extension CalendarFragmentVisibilityX on CalendarFragmentVisibility {
  bool get isFull => this == CalendarFragmentVisibility.full;
  bool get isRedacted => this == CalendarFragmentVisibility.redacted;
}

extension CalendarChatRoleX on CalendarChatRole {
  int get priority => switch (this) {
        CalendarChatRole.none => _calendarChatRolePriorityNone,
        CalendarChatRole.visitor => _calendarChatRolePriorityVisitor,
        CalendarChatRole.participant => _calendarChatRolePriorityParticipant,
        CalendarChatRole.moderator => _calendarChatRolePriorityModerator,
      };

  bool allows(CalendarChatRole required) => priority >= required.priority;
}

extension OccupantRoleCalendarX on OccupantRole {
  CalendarChatRole get calendarRole => switch (this) {
        OccupantRole.visitor => CalendarChatRole.visitor,
        OccupantRole.participant => CalendarChatRole.participant,
        OccupantRole.moderator => CalendarChatRole.moderator,
        OccupantRole.none => CalendarChatRole.none,
      };
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

class CalendarFragmentShareDecision {
  const CalendarFragmentShareDecision({
    required this.canWrite,
    required this.visibility,
  });

  final bool canWrite;
  final CalendarFragmentVisibility visibility;
}

class CalendarFragmentPolicy {
  const CalendarFragmentPolicy({
    this.groupAcl = _defaultCalendarChatAcl,
  });

  final CalendarChatAcl groupAcl;

  CalendarFragmentShareDecision decisionForChat({
    required Chat? chat,
    RoomState? roomState,
  }) {
    if (chat == null || chat.type != ChatType.groupChat) {
      return const CalendarFragmentShareDecision(
        canWrite: true,
        visibility: _defaultFragmentVisibility,
      );
    }
    final CalendarChatRole role = _roleForRoom(roomState);
    final bool canWrite = role.allows(groupAcl.write);
    final CalendarFragmentVisibility visibility = role.allows(groupAcl.manage)
        ? _defaultFragmentVisibility
        : _redactedFragmentVisibility;
    return CalendarFragmentShareDecision(
      canWrite: canWrite,
      visibility: visibility,
    );
  }

  CalendarFragmentVisibility visibilityForChat({
    required Chat? chat,
    RoomState? roomState,
  }) {
    final decision = decisionForChat(chat: chat, roomState: roomState);
    return decision.visibility;
  }

  CalendarAvailabilityOverlay redactOverlay(
    CalendarAvailabilityOverlay overlay,
    CalendarFragmentVisibility visibility,
  ) {
    if (visibility.isFull) {
      return overlay;
    }
    return overlay.copyWith(isRedacted: true);
  }

  CalendarFragment redactFragment(
    CalendarFragment fragment,
    CalendarFragmentVisibility visibility,
  ) {
    return fragment.map(
      task: (value) => CalendarFragment.task(
        task: _sanitizeTask(value.task, visibility),
      ),
      checklist: (value) => CalendarFragment.checklist(
        taskId: value.taskId,
        checklist: _sanitizeChecklist(value.checklist, visibility),
      ),
      reminder: (value) => CalendarFragment.reminder(
        taskId: value.taskId,
        reminders: _sanitizeReminders(value.reminders, visibility),
      ),
      dayEvent: (value) => CalendarFragment.dayEvent(
        event: _sanitizeDayEvent(value.event, visibility),
      ),
      freeBusy: (value) => CalendarFragment.freeBusy(
        interval: value.interval,
      ),
      availability: (value) => CalendarFragment.availability(
        window: _sanitizeAvailability(value.window, visibility),
      ),
    );
  }

  CalendarTask _sanitizeTask(
    CalendarTask task,
    CalendarFragmentVisibility visibility,
  ) {
    final CalendarTask base = task.copyWith(
      icsMeta: null,
      occurrenceOverrides: _emptyTaskOverrides,
    );
    if (visibility.isFull) {
      return base;
    }
    return base.copyWith(
      title: _redactedTaskTitle,
      description: null,
      location: null,
      priority: null,
      recurrence: null,
      reminders: _disabledReminders,
      checklist: _emptyTaskChecklistItems,
    );
  }

  DayEvent _sanitizeDayEvent(
    DayEvent event,
    CalendarFragmentVisibility visibility,
  ) {
    final DayEvent base = event.copyWith(icsMeta: null);
    if (visibility.isFull) {
      return base;
    }
    return base.copyWith(
      title: _redactedEventTitle,
      description: null,
      reminders: _disabledReminders,
    );
  }

  List<TaskChecklistItem> _sanitizeChecklist(
    List<TaskChecklistItem> checklist,
    CalendarFragmentVisibility visibility,
  ) {
    if (visibility.isFull) {
      return checklist;
    }
    if (checklist.isEmpty) {
      return _emptyTaskChecklistItems;
    }
    return List<TaskChecklistItem>.generate(
      checklist.length,
      (index) => TaskChecklistItem(
        id: '$_redactedChecklistItemIdPrefix$index',
        label: _redactedChecklistItemLabel,
      ),
      growable: false,
    );
  }

  ReminderPreferences _sanitizeReminders(
    ReminderPreferences reminders,
    CalendarFragmentVisibility visibility,
  ) {
    if (visibility.isFull) {
      return reminders;
    }
    return _disabledReminders;
  }

  CalendarAvailabilityWindow _sanitizeAvailability(
    CalendarAvailabilityWindow window,
    CalendarFragmentVisibility visibility,
  ) {
    if (visibility.isFull) {
      return window;
    }
    return window.copyWith(
      summary: null,
      description: null,
    );
  }

  CalendarChatRole _roleForRoom(RoomState? roomState) {
    return roomState?.myRole.calendarRole ?? _calendarChatRoleFallback;
  }
}

class CalendarFragmentFormatter {
  const CalendarFragmentFormatter();

  String describe(CalendarFragment fragment) {
    return fragment.when(
      task: (task) => task.toShareText(),
      checklist: (taskId, checklist) => _formatChecklist(checklist),
      reminder: (taskId, reminders) => _formatReminders(reminders),
      dayEvent: (event) => _formatDayEvent(event),
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
        : _redactedEventTitle;
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
