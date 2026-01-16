// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:axichat/src/localization/app_localizations.dart';

class TimeFormatter {
  /// Format DateTime to HH:mm format
  static String formatDateTime(DateTime time) {
    return DateFormat.Hm().format(time);
  }

  /// Format TimeOfDay using Flutter's built-in format
  static String formatTimeOfDay(BuildContext context, TimeOfDay time) {
    return time.format(context);
  }

  /// Format relative sync time (e.g., "Just now", "5m ago")
  static String formatSyncTime(AppLocalizations l10n, DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return l10n.commonTimeJustNow;
    if (diff.inMinutes < 60) {
      return l10n.commonTimeMinutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return l10n.commonTimeHoursAgo(diff.inHours);
    }
    return l10n.commonTimeDaysAgo(diff.inDays);
  }

  /// Format time to 12-hour format (e.g., "2:00 PM")
  static String formatTime(DateTime time) {
    return DateFormat.jm().format(time);
  }

  /// Format date to short format (e.g., "Jan 15")
  static String formatShortDate(DateTime date) {
    return DateFormat.MMMd().format(date);
  }

  /// Format duration to human-readable format
  static String formatDuration(AppLocalizations l10n, Duration duration) {
    if (duration.inMinutes < 60) {
      return l10n.commonDurationMinutes(duration.inMinutes);
    }
    final hours = duration.inHours;
    return l10n.commonDurationHours(hours);
  }

  /// Format short duration for compact display
  static String formatDurationShort(
    AppLocalizations l10n,
    Duration duration,
  ) {
    if (duration.inMinutes < 60) {
      return l10n.commonDurationMinutesShort(duration.inMinutes);
    }
    return l10n.commonDurationHoursShort(duration.inHours);
  }

  /// Format date to a readable string (e.g., "Aug 21, 2025").
  static String formatFriendlyDate(DateTime date) {
    return DateFormat.yMMMd().format(date);
  }

  /// Format date and time together (e.g., "Aug 21, 2025 · 5:00 PM").
  static String formatFriendlyDateTime(
    AppLocalizations l10n,
    DateTime dateTime,
  ) {
    final String dateLabel = formatFriendlyDate(dateTime);
    final String timeLabel = formatTime(dateTime);
    return l10n.commonDateTimeLabel(dateLabel, timeLabel);
  }
}
