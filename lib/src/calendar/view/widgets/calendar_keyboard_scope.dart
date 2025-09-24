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
  });

  final Widget child;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool autofocus;

  static const Map<ShortcutActivator, Intent> _shortcuts = {
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
