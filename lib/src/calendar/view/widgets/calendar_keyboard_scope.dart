// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:axichat/src/calendar/view/calendar_grid.dart';

const String _keyboardScopeFocusLabel = 'CalendarKeyboardScope';

class _CalendarShortcutManager extends ShortcutManager {
  _CalendarShortcutManager({
    required super.shortcuts,
    required bool Function() shouldHandleShortcuts,
  }) : _shouldHandleShortcuts = shouldHandleShortcuts;

  final bool Function() _shouldHandleShortcuts;

  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) {
    if (!_shouldHandleShortcuts()) {
      return KeyEventResult.ignored;
    }
    return super.handleKeypress(context, event);
  }
}

class CalendarKeyboardScope extends StatefulWidget {
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
  State<CalendarKeyboardScope> createState() => _CalendarKeyboardScopeState();
}

class _CalendarKeyboardScopeState extends State<CalendarKeyboardScope> {
  late final FocusNode _focusNode =
      FocusNode(debugLabel: _keyboardScopeFocusLabel);

  Map<ShortcutActivator, Intent> get _shortcuts {
    final Map<ShortcutActivator, Intent> shortcuts =
        Map<ShortcutActivator, Intent>.from(_undoRedoShortcuts);
    if (widget.onNavigatePrevious != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.arrowLeft)] =
          const CalendarNavigatePreviousIntent();
      shortcuts[const SingleActivator(LogicalKeyboardKey.arrowUp)] =
          const CalendarNavigatePreviousIntent();
      shortcuts[const SingleActivator(LogicalKeyboardKey.pageUp)] =
          const CalendarNavigatePreviousIntent();
    }
    if (widget.onNavigateNext != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.arrowRight)] =
          const CalendarNavigateNextIntent();
      shortcuts[const SingleActivator(LogicalKeyboardKey.arrowDown)] =
          const CalendarNavigateNextIntent();
      shortcuts[const SingleActivator(LogicalKeyboardKey.pageDown)] =
          const CalendarNavigateNextIntent();
    }
    if (widget.onJumpToToday != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.home)] =
          const CalendarNavigateTodayIntent();
      shortcuts[const SingleActivator(LogicalKeyboardKey.keyT, control: true)] =
          const CalendarNavigateTodayIntent();
      shortcuts[const SingleActivator(LogicalKeyboardKey.keyT, meta: true)] =
          const CalendarNavigateTodayIntent();
    }
    if (widget.onCancelDrag != null) {
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

  bool _shouldHandleShortcuts() {
    final focusNode = FocusManager.instance.primaryFocus;
    if (focusNode == null || focusNode == _focusNode) {
      return true;
    }
    final focusContext = focusNode.context;
    if (focusContext == null) {
      return false;
    }
    if (CalendarKeyboardScope._isEditableFocused()) {
      return false;
    }
    final bool isGridFocus = focusContext.widget is FocusableActionDetector &&
        focusContext.findAncestorWidgetOfExactType<CalendarGrid>() != null;
    return isGridFocus;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts.manager(
      manager: _CalendarShortcutManager(
        shortcuts: _shortcuts,
        shouldHandleShortcuts: _shouldHandleShortcuts,
      ),
      child: Actions(
        actions: {
          CalendarUndoIntent: CallbackAction<CalendarUndoIntent>(
            onInvoke: (_) {
              if (!widget.canUndo ||
                  CalendarKeyboardScope._isEditableFocused()) {
                return null;
              }
              widget.onUndo();
              return null;
            },
          ),
          CalendarRedoIntent: CallbackAction<CalendarRedoIntent>(
            onInvoke: (_) {
              if (!widget.canRedo ||
                  CalendarKeyboardScope._isEditableFocused()) {
                return null;
              }
              widget.onRedo();
              return null;
            },
          ),
          CalendarNavigatePreviousIntent:
              CallbackAction<CalendarNavigatePreviousIntent>(
            onInvoke: (_) {
              if (widget.onNavigatePrevious == null ||
                  CalendarKeyboardScope._isEditableFocused()) {
                return null;
              }
              widget.onNavigatePrevious!.call();
              return null;
            },
          ),
          CalendarNavigateNextIntent:
              CallbackAction<CalendarNavigateNextIntent>(
            onInvoke: (_) {
              if (widget.onNavigateNext == null ||
                  CalendarKeyboardScope._isEditableFocused()) {
                return null;
              }
              widget.onNavigateNext!.call();
              return null;
            },
          ),
          CalendarNavigateTodayIntent:
              CallbackAction<CalendarNavigateTodayIntent>(
            onInvoke: (_) {
              if (widget.onJumpToToday == null ||
                  CalendarKeyboardScope._isEditableFocused()) {
                return null;
              }
              widget.onJumpToToday!.call();
              return null;
            },
          ),
          CalendarCancelDragIntent: CallbackAction<CalendarCancelDragIntent>(
            onInvoke: (_) {
              if (widget.onCancelDrag == null ||
                  CalendarKeyboardScope._isEditableFocused()) {
                return null;
              }
              widget.onCancelDrag!.call();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: widget.autofocus,
          focusNode: _focusNode,
          child: widget.child,
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
