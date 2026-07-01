// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/axi_surface_scope.dart';
import 'package:axichat/src/common/ui/focus_extensions.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class KeyboardPopScope extends StatelessWidget {
  const KeyboardPopScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    final bool isPopupRoute = route is PopupRoute<dynamic>;
    if (AxiSurfaceScope.maybeControllerOf(context) != null && !isPopupRoute) {
      return child;
    }
    return ListenableBuilder(
      listenable: FocusManager.instance,
      builder: (context, _) {
        final hasTextInputFocus = FocusManager.instance.isTextInputFocused;
        final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
        final shouldBlockPop = hasTextInputFocus || keyboardVisible;
        return PopScope(
          canPop: !shouldBlockPop,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              return;
            }
            if (shouldBlockPop) {
              FocusManager.instance.primaryFocus?.unfocus();
            }
          },
          child: child,
        );
      },
    );
  }
}

class KeyboardDismissScope extends StatefulWidget {
  const KeyboardDismissScope({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardDismissScope> createState() => _KeyboardDismissScopeState();
}

class _KeyboardDismissScopeState extends State<KeyboardDismissScope> {
  final GlobalKey _scopeKey = GlobalKey();
  int? _tapCandidatePointer;
  Offset? _tapCandidateStart;

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: _scopeKey,
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    _clearTapCandidate();
    if (!FocusManager.instance.isTextInputFocused) {
      return;
    }
    if (!_isPrimaryPointerContact(event)) {
      return;
    }
    if (_hitInteractiveTarget(event)) {
      return;
    }
    _tapCandidatePointer = event.pointer;
    _tapCandidateStart = event.position;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_tapCandidatePointer != event.pointer) {
      return;
    }
    if (_pointerMovedBeyondTapSlop(event.position)) {
      _clearTapCandidate();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_tapCandidatePointer != event.pointer) {
      return;
    }
    if (!_pointerMovedBeyondTapSlop(event.position) &&
        FocusManager.instance.isTextInputFocused) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    _clearTapCandidate();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_tapCandidatePointer == event.pointer) {
      _clearTapCandidate();
    }
  }

  bool _pointerMovedBeyondTapSlop(Offset position) {
    final start = _tapCandidateStart;
    if (start == null) {
      return true;
    }
    return (position - start).distance >
        (MediaQuery.maybeOf(context)?.gestureSettings.touchSlop ?? kTouchSlop);
  }

  void _clearTapCandidate() {
    _tapCandidatePointer = null;
    _tapCandidateStart = null;
  }

  bool _isPrimaryPointerContact(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      return true;
    }
    if (event.kind == PointerDeviceKind.mouse ||
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      return event.buttons == kPrimaryButton;
    }
    return false;
  }

  bool _hitInteractiveTarget(PointerDownEvent event) {
    final RenderObject? scope = _scopeKey.currentContext?.findRenderObject();
    if (scope == null) {
      return true;
    }
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (identical(target, scope)) {
        return false;
      }
      if (_isInteractiveHitTarget(target)) {
        return true;
      }
    }
    return true;
  }

  bool _isInteractiveHitTarget(HitTestTarget target) {
    if (target is RenderEditable) {
      return true;
    }
    if (target is RenderTapRegion && target.enabled) {
      return true;
    }
    if (target is RenderSemanticsGestureHandler &&
        _handlesSemanticGesture(target)) {
      return true;
    }
    return false;
  }

  bool _handlesSemanticGesture(RenderSemanticsGestureHandler handler) {
    return handler.onTap != null || handler.onLongPress != null;
  }
}

Future<void> closeSheetWithKeyboardDismiss(
  BuildContext context,
  VoidCallback onClose,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  if (!context.mounted) return;
  onClose();
  if (!context.mounted) return;
  final route = ModalRoute.of(context);
  if (route is! PopupRoute<dynamic> || !route.isCurrent) {
    return;
  }
  final navigator = Navigator.maybeOf(context);
  if (navigator == null || !navigator.canPop()) {
    return;
  }
  navigator.pop();
}
