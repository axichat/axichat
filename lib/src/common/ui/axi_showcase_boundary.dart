// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:showcaseview/showcaseview.dart';

enum AxiShowcaseDismissReason { user, transient }

typedef AxiShowcaseDismissed =
    void Function(GlobalKey? key, AxiShowcaseDismissReason reason);

class AxiShowcaseBoundary extends StatefulWidget {
  const AxiShowcaseBoundary({
    super.key,
    required this.active,
    required this.identity,
    required this.lowMotion,
    required this.child,
    this.scope,
    this.onComplete,
    this.onDismiss,
    this.onTargetInteraction,
    this.enableAutoScroll = true,
    this.disableBarrierInteraction = false,
  });

  final bool active;
  final Object? identity;
  final bool lowMotion;
  final Widget child;
  final String? scope;
  final OnShowcaseCallback? onComplete;
  final AxiShowcaseDismissed? onDismiss;
  final VoidCallback? onTargetInteraction;
  final bool enableAutoScroll;
  final bool disableBarrierInteraction;

  @override
  State<AxiShowcaseBoundary> createState() => _AxiShowcaseBoundaryState();
}

class AxiShowcaseController {
  AxiShowcaseController._(this._state);

  final _AxiShowcaseBoundaryState _state;

  String get scope => _state._scope;

  bool get active => _state.widget.active;

  bool get isRunning => _state._showcaseView.isShowcaseRunning;

  GlobalKey? get activeKey => _state._showcaseView.getActiveShowcaseKey;

  bool isTargetRendered(GlobalKey key) =>
      _state._showcaseView.isTargetRendered(key);

  bool start(List<GlobalKey> keys, {Duration delay = Duration.zero}) {
    return _state._start(keys, delay: delay);
  }

  void dismissTransient() {
    _state._dismissTransient();
  }

  void dismissUser() {
    _state._dismissUser();
  }

  void notifyTargetInteraction() {
    _state.widget.onTargetInteraction?.call();
  }

  static AxiShowcaseController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_AxiShowcaseBoundaryScope>()
        ?.controller;
  }
}

class _AxiShowcaseBoundaryState extends State<AxiShowcaseBoundary> {
  late final String _scope = widget.scope ?? 'axi-showcase-${UniqueKey()}';
  late final AxiShowcaseController _controller = AxiShowcaseController._(this);
  late final ShowcaseView _showcaseView;
  bool _transientDismissPending = false;

  @override
  void initState() {
    super.initState();
    _showcaseView = ShowcaseView.register(
      scope: _scope,
      onComplete: widget.onComplete,
      onDismiss: _handleDismiss,
      enableAutoScroll: widget.enableAutoScroll,
      skipIfTargetNotPresent: true,
      disableBarrierInteraction: widget.disableBarrierInteraction,
      scrollDuration: baseAnimationDuration,
      disableMovingAnimation: widget.lowMotion,
      disableScaleAnimation: widget.lowMotion,
    );
  }

  @override
  void didUpdateWidget(covariant AxiShowcaseBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    _showcaseView
      ..disableMovingAnimation = widget.lowMotion
      ..disableScaleAnimation = widget.lowMotion
      ..enableAutoScroll = widget.enableAutoScroll
      ..disableBarrierInteraction = widget.disableBarrierInteraction;
    if (!widget.active ||
        oldWidget.active != widget.active ||
        oldWidget.identity != widget.identity) {
      _dismissTransient();
    }
  }

  @override
  void dispose() {
    _dismissTransient();
    _showcaseView.unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AxiShowcaseBoundaryScope(
      controller: _controller,
      child: widget.child,
    );
  }

  bool _start(List<GlobalKey> keys, {required Duration delay}) {
    if (!widget.active || keys.isEmpty) {
      _dismissTransient();
      return false;
    }
    final availableKeys = keys
        .where(_showcaseView.isTargetRendered)
        .toList(growable: false);
    if (availableKeys.isEmpty) {
      _dismissTransient();
      return false;
    }
    _showcaseView.startShowCase(availableKeys, delay: delay);
    return true;
  }

  void _dismissTransient() {
    if (!_showcaseView.isShowcaseRunning) {
      return;
    }
    _transientDismissPending = true;
    _showcaseView.dismiss();
  }

  void _dismissUser() {
    if (!_showcaseView.isShowcaseRunning) {
      return;
    }
    _showcaseView.dismiss();
  }

  void _handleDismiss(GlobalKey? key) {
    final reason = _transientDismissPending
        ? AxiShowcaseDismissReason.transient
        : AxiShowcaseDismissReason.user;
    _transientDismissPending = false;
    widget.onDismiss?.call(key, reason);
  }
}

class _AxiShowcaseBoundaryScope extends InheritedWidget {
  const _AxiShowcaseBoundaryScope({
    required this.controller,
    required super.child,
  });

  final AxiShowcaseController controller;

  @override
  bool updateShouldNotify(covariant _AxiShowcaseBoundaryScope oldWidget) {
    return oldWidget.controller != controller;
  }
}
