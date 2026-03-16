// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/focus_extensions.dart';
import 'package:flutter/material.dart';

final class AxiSurfaceController extends ChangeNotifier {
  final List<Object> _surfaceOrder = <Object>[];
  final Map<Object, VoidCallback> _dismissCallbacks = <Object, VoidCallback>{};
  FocusScopeNode? _focusScopeNode;

  bool get hasOpenSurface => _surfaceOrder.isNotEmpty;

  void attachFocusScope(FocusScopeNode focusScopeNode) {
    if (identical(_focusScopeNode, focusScopeNode)) {
      return;
    }
    _focusScopeNode = focusScopeNode;
    notifyListeners();
  }

  void detachFocusScope(FocusScopeNode focusScopeNode) {
    if (!identical(_focusScopeNode, focusScopeNode)) {
      return;
    }
    _focusScopeNode = null;
    notifyListeners();
  }

  void registerSurface({
    required Object owner,
    required VoidCallback onDismiss,
  }) {
    final bool alreadyRegistered = _dismissCallbacks.containsKey(owner);
    _dismissCallbacks[owner] = onDismiss;
    if (alreadyRegistered) {
      _surfaceOrder.remove(owner);
    }
    _surfaceOrder.add(owner);
    notifyListeners();
  }

  void unregisterSurface(Object owner) {
    final bool removedCallback = _dismissCallbacks.remove(owner) != null;
    final bool removedOrder = _surfaceOrder.remove(owner);
    if (removedCallback || removedOrder) {
      notifyListeners();
    }
  }

  bool hasFocusedTextInput() {
    if (!FocusManager.instance.isTextInputFocused) {
      return false;
    }
    final FocusNode? focusNode = FocusManager.instance.primaryFocus;
    if (focusNode == null) {
      return false;
    }
    FocusNode? current = focusNode;
    while (current != null) {
      if (identical(current, _focusScopeNode)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  bool dismissActiveTextInput() {
    if (!hasFocusedTextInput()) {
      return false;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    return true;
  }

  bool dismissTopSurface() {
    if (_surfaceOrder.isEmpty) {
      return false;
    }
    final Object owner = _surfaceOrder.last;
    final VoidCallback? dismiss = _dismissCallbacks[owner];
    if (dismiss == null) {
      _surfaceOrder.removeLast();
      notifyListeners();
      return _surfaceOrder.isNotEmpty;
    }
    dismiss();
    return true;
  }
}

class AxiSurfaceScope extends InheritedNotifier<AxiSurfaceController> {
  const AxiSurfaceScope({
    super.key,
    required AxiSurfaceController controller,
    required super.child,
  }) : super(notifier: controller);

  static AxiSurfaceController? maybeControllerOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AxiSurfaceScope>()
        ?.notifier;
  }

  static AxiSurfaceController controllerOf(BuildContext context) {
    final AxiSurfaceController? controller = maybeControllerOf(context);
    assert(controller != null, 'No AxiSurfaceScope found in context');
    return controller!;
  }
}
