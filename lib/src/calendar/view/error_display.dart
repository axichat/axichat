import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/constants.dart';

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
                'Error',
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
            _getFriendlyErrorMessage(context, error),
            style: TextStyle(
              color: Colors.red.shade800,
              fontSize: 14,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: calendarGutterMd),
            ShadButton.outline(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }

  static String _getFriendlyErrorMessage(
    BuildContext context,
    String error,
  ) {
    // Convert technical errors to user-friendly messages
    if (error.contains('Task not found')) {
      return 'Task not found';
    }
    if (error.contains('Validation failed')) {
      if (error.contains('Title cannot be empty')) {
        return 'Title cannot be empty';
      }
      if (error.contains('Title too long')) {
        return calendarTaskTitleFriendlyError;
      }
      if (error.contains('Description too long')) {
        return 'Description too long';
      }
      return 'Input invalid';
    }
    if (error.contains('Failed to add task')) {
      return 'Failed to add task';
    }
    if (error.contains('Failed to update task')) {
      return 'Failed to update task';
    }
    if (error.contains('Failed to delete task')) {
      return 'Failed to delete task';
    }
    if (error.contains('network') || error.contains('connection')) {
      return 'Network error';
    }
    if (error.contains('storage') || error.contains('database')) {
      return 'Storage error';
    }

    // Generic fallback
    return 'Unknown error';
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
                ErrorDisplay._getFriendlyErrorMessage(context, error),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}
