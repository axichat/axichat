// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/view/shell/feedback_system.dart';
import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const String _syncedReminderNoticeId =
    'calendar-synced-reminder-notifications-disabled';

class CalendarSyncWarningFeedback {
  CalendarSyncWarningFeedback._();

  static bool _syncedReminderNoticeShownThisSession = false;

  static void dismissSyncedReminderNotice() {
    FeedbackSystem.dismissPersistent(_syncedReminderNoticeId);
    _syncedReminderNoticeShownThisSession = false;
  }

  static void show(
    BuildContext context, {
    required CalendarSyncWarning warning,
  }) {
    if (warning.type == CalendarSyncWarningType.reminderNotificationsDisabled) {
      _showSyncedReminderNotice(context);
      return;
    }

    final l10n = context.l10n;
    final (String title, String message) = switch (warning.type) {
      CalendarSyncWarningType.snapshotUnavailable => (
        l10n.calendarSyncWarningSnapshotTitle,
        l10n.calendarSyncWarningSnapshotMessage,
      ),
      CalendarSyncWarningType.archiveIncomplete => (
        l10n.calendarSyncWarningArchiveTitle,
        l10n.calendarSyncWarningArchiveMessage,
      ),
      CalendarSyncWarningType.snapshotPublishPending => (
        l10n.calendarSyncWarningArchiveTitle,
        l10n.calendarSyncWarningArchiveMessage,
      ),
      CalendarSyncWarningType.snapshotPublishBlocked => (
        l10n.calendarSyncWarningSnapshotTitle,
        l10n.calendarSyncWarningSnapshotMessage,
      ),
      CalendarSyncWarningType.reminderNotificationsDisabled => (
        l10n.calendarSyncedReminderNoticeTitle,
        l10n.calendarSyncedReminderNoticeMessage,
      ),
    };
    FeedbackSystem.showWarning(context, message, title: title);
  }

  static void _showSyncedReminderNotice(BuildContext context) {
    if (_syncedReminderNoticeShownThisSession) {
      return;
    }
    final l10n = context.l10n;
    final reminderController = context.read<CalendarReminderController>();
    _syncedReminderNoticeShownThisSession = true;
    FeedbackSystem.showPersistentError(
      context,
      l10n.calendarSyncedReminderNoticeMessage,
      id: _syncedReminderNoticeId,
      title: l10n.calendarSyncedReminderNoticeTitle,
      actionLabel: l10n.calendarSyncedReminderEnableAction,
      onAction: () => fireAndForget(
        reminderController.requestSyncedReminderPermissions,
        operationName:
            'CalendarReminderController.requestSyncedReminderPermissions',
      ),
    );
  }
}
