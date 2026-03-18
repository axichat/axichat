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
    bool notify = true,
  }) {
    final bool alreadyRegistered = _dismissCallbacks.containsKey(owner);
    final bool alreadyTop =
        _surfaceOrder.isNotEmpty && identical(_surfaceOrder.last, owner);
    _dismissCallbacks[owner] = onDismiss;
    if (alreadyRegistered && alreadyTop) {
      return;
    }
    if (alreadyRegistered) {
      _surfaceOrder.remove(owner);
    }
    _surfaceOrder.add(owner);
    if (notify) {
      notifyListeners();
    }
  }

  void unregisterSurface(Object owner, {bool notify = true}) {
    final bool removedCallback = _dismissCallbacks.remove(owner) != null;
    final bool removedOrder = _surfaceOrder.remove(owner);
    if (notify && (removedCallback || removedOrder)) {
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

class AxiSurfaceScope extends InheritedWidget {
  const AxiSurfaceScope({
    super.key,
    required AxiSurfaceController controller,
    required super.child,
  }) : _controller = controller;

  final AxiSurfaceController _controller;

  static AxiSurfaceController? maybeControllerOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AxiSurfaceScope>()
        ?._controller;
  }

  static AxiSurfaceController controllerOf(BuildContext context) {
    final AxiSurfaceController? controller = maybeControllerOf(context);
    assert(controller != null, 'No AxiSurfaceScope found in context');
    return controller!;
  }

  @override
  bool updateShouldNotify(AxiSurfaceScope oldWidget) {
    return !identical(_controller, oldWidget._controller);
  }
}

mixin AxiSurfaceRegistration<T extends StatefulWidget> on State<T> {
  final Object axiSurfaceOwner = Object();
  AxiSurfaceController? _registeredAxiSurfaceController;

  bool get isAxiSurfaceOpen;

  VoidCallback? get onAxiSurfaceDismiss;

  @protected
  void syncAxiSurfaceRegistration({bool notify = true}) {
    final AxiSurfaceController? surfaceController =
        AxiSurfaceScope.maybeControllerOf(context);
    if (_registeredAxiSurfaceController != null &&
        _registeredAxiSurfaceController != surfaceController) {
      unregisterAxiSurfaceRegistration(notify: false);
    }
    final VoidCallback? dismiss = onAxiSurfaceDismiss;
    if (!isAxiSurfaceOpen || dismiss == null || surfaceController == null) {
      unregisterAxiSurfaceRegistration(notify: notify);
      return;
    }
    surfaceController.registerSurface(
      owner: axiSurfaceOwner,
      onDismiss: dismiss,
      notify: notify,
    );
    _registeredAxiSurfaceController = surfaceController;
  }

  @protected
  void unregisterAxiSurfaceRegistration({required bool notify}) {
    _registeredAxiSurfaceController?.unregisterSurface(
      axiSurfaceOwner,
      notify: notify,
    );
    _registeredAxiSurfaceController = null;
  }

  @override
  void activate() {
    super.activate();
    syncAxiSurfaceRegistration(notify: false);
  }

  @override
  void deactivate() {
    unregisterAxiSurfaceRegistration(notify: false);
    super.deactivate();
  }

  @override
  void dispose() {
    unregisterAxiSurfaceRegistration(notify: false);
    super.dispose();
  }
}
