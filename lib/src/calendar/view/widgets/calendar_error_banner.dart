// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

/// Shared error banner wrapper for calendar surfaces (full calendar + guest)
/// so the ErrorDisplay layout and margin logic stay consistent.
class CalendarErrorBanner extends StatelessWidget {
  const CalendarErrorBanner({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onDismiss,
    this.margin,
  });

  final String error;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.all(context.spacing.m),
      child: ErrorDisplay(error: error, onRetry: onRetry, onDismiss: onDismiss),
    );
  }
}

class ErrorDisplay extends StatelessWidget {
  const ErrorDisplay({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
  });

  final String error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final spacing = context.spacing;
    const double errorBackgroundMix = 0.12;
    const double errorBorderMix = 0.35;
    final Color background =
        Color.lerp(scheme.background, scheme.destructive, errorBackgroundMix) ??
        scheme.background;
    final Color border =
        Color.lerp(scheme.border, scheme.destructive, errorBorderMix) ??
        scheme.border;
    return Container(
      margin: EdgeInsets.all(spacing.m),
      padding: EdgeInsets.all(spacing.m),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: context.radius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: scheme.destructive,
                size: context.sizing.iconButtonIconSize,
              ),
              SizedBox(width: spacing.s),
              Text(
                l10n.calendarErrorTitle,
                style: context.textTheme.small.strong.copyWith(
                  color: scheme.destructive,
                ),
              ),
              const Spacer(),
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close,
                    color: scheme.mutedForeground,
                    size: context.sizing.menuItemIconSize,
                  ),
                ),
            ],
          ),
          SizedBox(height: spacing.s),
          Text(
            _friendlyCalendarErrorMessage(l10n, error),
            style: context.textTheme.small.copyWith(color: scheme.foreground),
          ),
          if (onRetry != null) ...[
            SizedBox(height: spacing.m),
            AxiButton.outline(
              onPressed: onRetry,
              child: Text(l10n.commonRetry),
            ),
          ],
        ],
      ),
    );
  }
}

String _friendlyCalendarErrorMessage(AppLocalizations l10n, String error) {
  if (error.contains('Task not found')) {
    return l10n.calendarErrorTaskNotFound;
  }
  if (error.contains('Validation failed')) {
    if (error.contains('Title cannot be empty')) {
      return l10n.calendarErrorTitleEmpty;
    }
    if (error.contains('Title too long')) {
      return l10n.calendarTaskTitleTooLong(calendarTaskTitleMaxLength);
    }
    if (error.contains('Description too long')) {
      return l10n.calendarErrorDescriptionTooLong;
    }
    return l10n.calendarErrorInputInvalid;
  }
  if (error.contains('Failed to add task')) {
    return l10n.calendarErrorAddFailed;
  }
  if (error.contains('Failed to update task')) {
    return l10n.calendarErrorUpdateFailed;
  }
  if (error.contains('Failed to delete task')) {
    return l10n.calendarErrorDeleteFailed;
  }
  if (error.contains('network') || error.contains('connection')) {
    return l10n.calendarErrorNetwork;
  }
  if (error.contains('storage') || error.contains('database')) {
    return l10n.calendarErrorStorage;
  }
  return l10n.calendarErrorUnknown;
}

class ErrorSnackBar {
  static void show(
    BuildContext context,
    String error, {
    VoidCallback? onRetry,
  }) {
    final scheme = context.colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: scheme.destructiveForeground,
              size: context.sizing.iconButtonIconSize,
            ),
            SizedBox(width: context.spacing.s),
            Expanded(
              child: Text(
                _friendlyCalendarErrorMessage(context.l10n, error),
                style: context.textTheme.small.copyWith(
                  color: scheme.destructiveForeground,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: scheme.destructive,
        action: onRetry != null
            ? SnackBarAction(
                label: context.l10n.commonRetry,
                textColor: scheme.destructiveForeground,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}
