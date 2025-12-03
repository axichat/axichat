import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

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
    return Container(
      margin: calendarPaddingXl,
      padding: calendarPaddingXl,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade700,
                size: 20,
              ),
              const SizedBox(width: calendarGutterSm),
              Text(
                l10n.calendarErrorTitle,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close,
                    color: Colors.red.shade700,
                    size: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: calendarGutterSm),
          Text(
            _getFriendlyErrorMessage(l10n, error),
            style: TextStyle(
              color: Colors.red.shade800,
              fontSize: 14,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: calendarGutterMd),
            ShadButton.outline(
              onPressed: onRetry,
              child: Text(l10n.commonRetry),
            ),
          ],
        ],
      ),
    );
  }

  static String _getFriendlyErrorMessage(
    AppLocalizations l10n,
    String error,
  ) {
    // Convert technical errors to user-friendly messages
    if (error.contains('Task not found')) {
      return l10n.calendarErrorTaskNotFound;
    }
    if (error.contains('Validation failed')) {
      if (error.contains('Title cannot be empty')) {
        return l10n.calendarErrorTitleEmpty;
      }
      if (error.contains('Title too long')) {
        return calendarTaskTitleFriendlyError;
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

    // Generic fallback
    return l10n.calendarErrorUnknown;
  }
}

class ErrorSnackBar {
  static void show(BuildContext context, String error,
      {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: calendarGutterSm),
            Expanded(
              child: Text(
                ErrorDisplay._getFriendlyErrorMessage(context.l10n, error),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        action: onRetry != null
            ? SnackBarAction(
                label: context.l10n.commonRetry,
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}
