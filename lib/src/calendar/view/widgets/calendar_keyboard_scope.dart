import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CalendarKeyboardScope extends StatelessWidget {
  const CalendarKeyboardScope({
    super.key,
    required this.child,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    this.autofocus = false,
    this.onNavigatePrevious,
    this.onNavigateNext,
    this.onJumpToToday,
    this.onCancelDrag,
  });

  final Widget child;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool autofocus;
  final VoidCallback? onNavigatePrevious;
  final VoidCallback? onNavigateNext;
  final VoidCallback? onJumpToToday;
  final VoidCallback? onCancelDrag;

  Map<ShortcutActivator, Intent> get _shortcuts {
    final Map<ShortcutActivator, Intent> shortcuts =
        Map<ShortcutActivator, Intent>.from(_undoRedoShortcuts);
    if (onNavigatePrevious != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.arrowLeft)] =
          const CalendarNavigatePreviousIntent();
      shortcuts[const SingleActivator(LogicalKeyboardKey.arrowUp)] =
          const CalendarNavigatePreviousIntent();
      shortcuts[const SingleActivator(LogicalKeyboardKey.pageUp)] =
          const CalendarNavigatePreviousIntent();
    }
    if (onNavigateNext != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.arrowRight)] =
          const CalendarNavigateNextIntent();
      shortcuts[const SingleActivator(LogicalKeyboardKey.arrowDown)] =
          const CalendarNavigateNextIntent();
      shortcuts[const SingleActivator(LogicalKeyboardKey.pageDown)] =
          const CalendarNavigateNextIntent();
    }
    if (onJumpToToday != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.home)] =
          const CalendarNavigateTodayIntent();
      shortcuts[const SingleActivator(LogicalKeyboardKey.keyT, control: true)] =
          const CalendarNavigateTodayIntent();
      shortcuts[const SingleActivator(LogicalKeyboardKey.keyT, meta: true)] =
          const CalendarNavigateTodayIntent();
    }
    if (onCancelDrag != null) {
      shortcuts.addAll(_cancelShortcuts);
    }
    return shortcuts;
  }

  static const Map<ShortcutActivator, Intent> _undoRedoShortcuts = {
    SingleActivator(LogicalKeyboardKey.keyZ, control: true):
        CalendarUndoIntent(),
    SingleActivator(LogicalKeyboardKey.keyZ, meta: true): CalendarUndoIntent(),
    SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
        CalendarRedoIntent(),
    SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
        CalendarRedoIntent(),
    SingleActivator(LogicalKeyboardKey.keyY, control: true):
        CalendarRedoIntent(),
    SingleActivator(LogicalKeyboardKey.keyY, meta: true): CalendarRedoIntent(),
  };

  static const Map<ShortcutActivator, Intent> _cancelShortcuts =
      <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.space): CalendarCancelDragIntent(),
    SingleActivator(LogicalKeyboardKey.enter): CalendarCancelDragIntent(),
    SingleActivator(LogicalKeyboardKey.escape): CalendarCancelDragIntent(),
  };

  static bool _isEditableFocused() {
    final focusNode = FocusManager.instance.primaryFocus;
    if (focusNode == null) {
      return false;
    }
    final context = focusNode.context;
    if (context == null) {
      return false;
    }
    if (context.widget is EditableText) {
      return true;
    }
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: {
          CalendarUndoIntent: CallbackAction<CalendarUndoIntent>(
            onInvoke: (_) {
              if (!canUndo || _isEditableFocused()) {
                return null;
              }
              onUndo();
              return null;
            },
          ),
          CalendarRedoIntent: CallbackAction<CalendarRedoIntent>(
            onInvoke: (_) {
              if (!canRedo || _isEditableFocused()) {
                return null;
              }
              onRedo();
              return null;
            },
          ),
          CalendarNavigatePreviousIntent:
              CallbackAction<CalendarNavigatePreviousIntent>(
            onInvoke: (_) {
              if (onNavigatePrevious == null || _isEditableFocused()) {
                return null;
              }
              onNavigatePrevious!.call();
              return null;
            },
          ),
          CalendarNavigateNextIntent:
              CallbackAction<CalendarNavigateNextIntent>(
            onInvoke: (_) {
              if (onNavigateNext == null || _isEditableFocused()) {
                return null;
              }
              onNavigateNext!.call();
              return null;
            },
          ),
          CalendarNavigateTodayIntent:
              CallbackAction<CalendarNavigateTodayIntent>(
            onInvoke: (_) {
              if (onJumpToToday == null || _isEditableFocused()) {
                return null;
              }
              onJumpToToday!.call();
              return null;
            },
          ),
          CalendarCancelDragIntent: CallbackAction<CalendarCancelDragIntent>(
            onInvoke: (_) {
              if (onCancelDrag == null || _isEditableFocused()) {
                return null;
              }
              onCancelDrag!.call();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: autofocus,
          child: child,
        ),
      ),
    );
  }
}

class CalendarUndoIntent extends Intent {
  const CalendarUndoIntent();
}

class CalendarRedoIntent extends Intent {
  const CalendarRedoIntent();
}

class CalendarNavigatePreviousIntent extends Intent {
  const CalendarNavigatePreviousIntent();
}

class CalendarNavigateNextIntent extends Intent {
  const CalendarNavigateNextIntent();
}

class CalendarNavigateTodayIntent extends Intent {
  const CalendarNavigateTodayIntent();
}

class CalendarCancelDragIntent extends Intent {
  const CalendarCancelDragIntent();
}
