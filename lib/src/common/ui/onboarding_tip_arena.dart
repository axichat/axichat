// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:showcaseview/showcaseview.dart';

enum OnboardingTipKind { emailWebView, calendarTaskDrag }

@immutable
class OnboardingTipOrder implements Comparable<OnboardingTipOrder> {
  const OnboardingTipOrder({required this.path, required this.tieBreaker});

  final List<int> path;
  final String tieBreaker;

  @override
  int compareTo(OnboardingTipOrder other) {
    final length = math.min(path.length, other.path.length);
    for (var index = 0; index < length; index += 1) {
      final comparison = path[index].compareTo(other.path[index]);
      if (comparison != 0) {
        return comparison;
      }
    }
    final lengthComparison = path.length.compareTo(other.path.length);
    if (lengthComparison != 0) {
      return lengthComparison;
    }
    return tieBreaker.compareTo(other.tieBreaker);
  }
}

class OnboardingTipCandidateNotification extends Notification {
  const OnboardingTipCandidateNotification({
    required this.kind,
    required this.candidateId,
    required this.order,
    required this.showcaseKey,
    required this.viable,
    this.targetStable = true,
    this.targetRect,
  });

  final OnboardingTipKind kind;
  final Object candidateId;
  final OnboardingTipOrder order;
  final GlobalKey showcaseKey;
  final bool viable;
  final bool targetStable;
  final Rect? targetRect;
}

class OnboardingTipCompletedNotification extends Notification {
  const OnboardingTipCompletedNotification({required this.kind});

  final OnboardingTipKind kind;
}

class OnboardingTipArena extends StatefulWidget {
  const OnboardingTipArena({
    super.key,
    required this.kind,
    required this.enabled,
    required this.identity,
    this.candidateIdentity,
    required this.lowMotion,
    required this.onCompleted,
    required this.child,
  });

  final OnboardingTipKind kind;
  final bool enabled;
  final Object? identity;
  final Object? candidateIdentity;
  final bool lowMotion;
  final VoidCallback onCompleted;
  final Widget child;

  @override
  State<OnboardingTipArena> createState() => _OnboardingTipArenaState();
}

class OnboardingTipTarget extends StatefulWidget {
  const OnboardingTipTarget({
    super.key,
    required this.kind,
    required this.candidateId,
    required this.order,
    required this.title,
    required this.description,
    required this.child,
    this.enabled = true,
    this.onTargetTap,
    this.disableDefaultTargetGestures = false,
  });

  final OnboardingTipKind kind;
  final Object candidateId;
  final OnboardingTipOrder order;
  final String title;
  final String description;
  final Widget child;
  final bool enabled;
  final VoidCallback? onTargetTap;
  final bool disableDefaultTargetGestures;

  @override
  State<OnboardingTipTarget> createState() => _OnboardingTipTargetState();
}

class _OnboardingTipCandidateEntry {
  const _OnboardingTipCandidateEntry({
    required this.id,
    required this.order,
    required this.showcaseKey,
    required this.targetStable,
    required this.targetRect,
  });

  final Object id;
  final OnboardingTipOrder order;
  final GlobalKey showcaseKey;
  final bool targetStable;
  final Rect targetRect;
}

class _OnboardingTipArenaState extends State<OnboardingTipArena> {
  late final String _showcaseScope =
      'onboarding-tip-${widget.kind.name}-${UniqueKey()}';
  late final ShowcaseView _showcaseView;
  final Map<Object, _OnboardingTipCandidateEntry> _candidates =
      <Object, _OnboardingTipCandidateEntry>{};
  bool _completed = false;
  bool _startScheduled = false;
  bool _transientDismissPending = false;
  Object? _startedCandidateId;

  bool get _active => widget.enabled && !_completed;

  @override
  void initState() {
    super.initState();
    _showcaseView = ShowcaseView.register(
      scope: _showcaseScope,
      onDismiss: _handleDismiss,
      enableAutoScroll: false,
      skipIfTargetNotPresent: true,
      disableBarrierInteraction: false,
      scrollDuration: baseAnimationDuration,
      disableMovingAnimation: widget.lowMotion,
      disableScaleAnimation: widget.lowMotion,
    );
  }

  @override
  void didUpdateWidget(covariant OnboardingTipArena oldWidget) {
    super.didUpdateWidget(oldWidget);
    _showcaseView
      ..disableMovingAnimation = widget.lowMotion
      ..disableScaleAnimation = widget.lowMotion;
    if (oldWidget.kind != widget.kind ||
        oldWidget.identity != widget.identity) {
      _dismissTransient();
      _clearCandidates();
      _completed = false;
    } else if (oldWidget.candidateIdentity != widget.candidateIdentity ||
        (oldWidget.enabled && !widget.enabled)) {
      _dismissTransient();
      _clearCandidates();
    }
    _scheduleStart();
  }

  @override
  void dispose() {
    _dismissTransient();
    _showcaseView.unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<OnboardingTipCompletedNotification>(
      onNotification: _handleCompletedNotification,
      child: NotificationListener<OnboardingTipCandidateNotification>(
        onNotification: _handleCandidateNotification,
        child: _OnboardingTipArenaScope(
          kind: widget.kind,
          enabled: _active,
          showcaseScope: _showcaseScope,
          lowMotion: widget.lowMotion,
          complete: _complete,
          child: widget.child,
        ),
      ),
    );
  }

  bool _handleCandidateNotification(
    OnboardingTipCandidateNotification notification,
  ) {
    if (notification.kind != widget.kind) {
      return false;
    }
    if (!_active || !notification.viable || notification.targetRect == null) {
      _candidates.remove(notification.candidateId);
    } else {
      final previous = _candidates[notification.candidateId];
      _candidates[notification.candidateId] = _OnboardingTipCandidateEntry(
        id: notification.candidateId,
        order: notification.order,
        showcaseKey: notification.showcaseKey,
        targetStable: notification.targetStable,
        targetRect: notification.targetRect!,
      );
      if (_startedCandidateId == notification.candidateId &&
          _showcaseView.isShowcaseRunning &&
          !_sameOnboardingTipRect(
            previous?.targetRect,
            notification.targetRect,
          )) {
        _showcaseView.updateOverlay();
      }
    }
    if (!_active || _candidates.isEmpty) {
      _dismissTransient();
      return true;
    }
    _scheduleStart();
    return true;
  }

  bool _handleCompletedNotification(
    OnboardingTipCompletedNotification notification,
  ) {
    if (notification.kind != widget.kind) {
      return false;
    }
    _complete();
    return true;
  }

  void _scheduleStart() {
    if (_startScheduled) {
      return;
    }
    _startScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScheduled = false;
      if (!mounted) {
        return;
      }
      _startWinner();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _startWinner() {
    if (!_active) {
      _dismissTransient();
      return;
    }
    final winner = _winner();
    if (winner == null) {
      if (_showcaseView.isShowcaseRunning &&
          _startedCandidateId != null &&
          _candidates.containsKey(_startedCandidateId)) {
        _showcaseView.updateOverlay();
        return;
      }
      _dismissTransient();
      return;
    }
    if (!_showcaseView.isTargetRendered(winner.showcaseKey)) {
      return;
    }
    if (_startedCandidateId == winner.id && _showcaseView.isShowcaseRunning) {
      return;
    }
    if (_showcaseView.isShowcaseRunning) {
      _dismissTransient();
      _scheduleStart();
      return;
    }
    _showcaseView.startShowCase(<GlobalKey>[winner.showcaseKey]);
    _startedCandidateId = winner.id;
    _scheduleOverlayUpdate();
  }

  _OnboardingTipCandidateEntry? _winner() {
    _OnboardingTipCandidateEntry? winner;
    for (final candidate in _candidates.values) {
      if (!candidate.targetStable) {
        continue;
      }
      if (winner == null || candidate.order.compareTo(winner.order) < 0) {
        winner = candidate;
      }
    }
    return winner;
  }

  void _complete() {
    if (_completed) {
      return;
    }
    setState(() {
      _completed = true;
      _clearCandidates();
    });
    _dismissTransient();
    widget.onCompleted();
  }

  void _clearCandidates() {
    _startedCandidateId = null;
    _candidates.clear();
  }

  void _dismissTransient() {
    if (!_showcaseView.isShowcaseRunning) {
      return;
    }
    _transientDismissPending = true;
    _showcaseView.dismiss();
  }

  void _scheduleOverlayUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showcaseView.isShowcaseRunning) {
        return;
      }
      _showcaseView.updateOverlay();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _handleDismiss(GlobalKey? key) {
    if (_transientDismissPending || _completed || !_active) {
      _transientDismissPending = false;
      return;
    }
    _transientDismissPending = false;
    _complete();
  }
}

class _OnboardingTipArenaScope extends InheritedWidget {
  const _OnboardingTipArenaScope({
    required this.kind,
    required this.enabled,
    required this.showcaseScope,
    required this.lowMotion,
    required this.complete,
    required super.child,
  });

  final OnboardingTipKind kind;
  final bool enabled;
  final String showcaseScope;
  final bool lowMotion;
  final VoidCallback complete;

  static _OnboardingTipArenaScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_OnboardingTipArenaScope>();
  }

  @override
  bool updateShouldNotify(covariant _OnboardingTipArenaScope oldWidget) {
    return oldWidget.kind != kind ||
        oldWidget.enabled != enabled ||
        oldWidget.showcaseScope != showcaseScope ||
        oldWidget.lowMotion != lowMotion ||
        oldWidget.complete != complete;
  }
}

class _OnboardingTipTargetState extends State<OnboardingTipTarget> {
  final GlobalKey _measureKey = GlobalKey();
  final GlobalKey _showcaseKey = GlobalKey();
  List<ScrollableState> _scrollables = <ScrollableState>[];
  Set<ScrollPosition> _scrollPositions = <ScrollPosition>{};
  Rect? _lastReportedRect;
  Rect? _visibleLocalRect;
  bool _reportScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleReport();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncScrollable();
    _scheduleReport();
  }

  @override
  void didUpdateWidget(covariant OnboardingTipTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.candidateId != widget.candidateId ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.order.compareTo(widget.order) != 0) {
      _dispatchCandidate(
        kind: oldWidget.kind,
        candidateId: oldWidget.candidateId,
        order: oldWidget.order,
        viable: false,
      );
    }
    _scheduleReport();
  }

  @override
  void deactivate() {
    _dispatchViability(viable: false);
    super.deactivate();
  }

  @override
  void dispose() {
    for (final position in _scrollPositions) {
      position.removeListener(_scheduleReport);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final measuredChild = NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _scheduleReport();
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: KeyedSubtree(key: _measureKey, child: widget.child),
      ),
    );
    final scope = _OnboardingTipArenaScope.maybeOf(context);
    if (scope == null || !scope.enabled || scope.kind != widget.kind) {
      return measuredChild;
    }
    final visibleLocalRect = _visibleLocalRect;
    if (visibleLocalRect == null) {
      return measuredChild;
    }
    final targetPadding = EdgeInsets.all(context.spacing.xs);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        measuredChild,
        Positioned(
          left: visibleLocalRect.left,
          top: visibleLocalRect.top,
          width: visibleLocalRect.width,
          height: visibleLocalRect.height,
          child: _OnboardingTipShowcase(
            showcaseKey: _showcaseKey,
            showcaseScope: scope.showcaseScope,
            title: widget.title,
            description: widget.description,
            targetPadding: targetPadding,
            lowMotion: scope.lowMotion,
            disableDefaultTargetGestures: widget.disableDefaultTargetGestures,
            onBarrierTap: scope.complete,
            onTargetTap: widget.onTargetTap == null
                ? null
                : () {
                    OnboardingTipCompletedNotification(
                      kind: widget.kind,
                    ).dispatch(context);
                    widget.onTargetTap?.call();
                  },
            child: const IgnorePointer(child: SizedBox.expand()),
          ),
        ),
      ],
    );
  }

  void _syncScrollable() {
    final nextScrollables = _ancestorScrollablesOf(context);
    final nextPositions = _scrollPositionsOf(nextScrollables);
    if (setEquals(_scrollPositions, nextPositions)) {
      _scrollables = nextScrollables;
      return;
    }
    for (final position in _scrollPositions.difference(nextPositions)) {
      position.removeListener(_scheduleReport);
    }
    for (final position in nextPositions.difference(_scrollPositions)) {
      position.addListener(_scheduleReport);
    }
    _scrollables = nextScrollables;
    _scrollPositions = nextPositions;
  }

  void _scheduleReport() {
    if (_reportScheduled) {
      return;
    }
    _reportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (!mounted) {
        return;
      }
      _reportCandidate();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _reportCandidate() {
    final scope = _OnboardingTipArenaScope.maybeOf(context);
    final active =
        widget.enabled &&
        scope != null &&
        scope.enabled &&
        scope.kind == widget.kind;
    final geometry = active ? _targetGeometry() : null;
    final localRectChanged = _syncVisibleLocalRect(geometry?.localRect);
    final targetRect = geometry?.targetRect;
    final targetStable = _sameOnboardingTipRect(_lastReportedRect, targetRect);
    _lastReportedRect = targetRect;
    _dispatchViability(
      viable: targetRect != null,
      targetStable: targetStable,
      targetRect: targetRect,
    );
    if (active && targetRect != null && (!targetStable || localRectChanged)) {
      _scheduleReport();
    }
  }

  bool _syncVisibleLocalRect(Rect? localRect) {
    if (_sameOnboardingTipRect(_visibleLocalRect, localRect)) {
      return false;
    }
    setState(() {
      _visibleLocalRect = localRect;
    });
    return true;
  }

  void _dispatchViability({
    required bool viable,
    bool targetStable = false,
    Rect? targetRect,
  }) {
    _dispatchCandidate(
      kind: widget.kind,
      candidateId: widget.candidateId,
      order: widget.order,
      viable: viable,
      targetStable: targetStable,
      targetRect: targetRect,
    );
  }

  void _dispatchCandidate({
    required OnboardingTipKind kind,
    required Object candidateId,
    required OnboardingTipOrder order,
    required bool viable,
    bool targetStable = false,
    Rect? targetRect,
  }) {
    OnboardingTipCandidateNotification(
      kind: kind,
      candidateId: candidateId,
      order: order,
      showcaseKey: _showcaseKey,
      viable: viable,
      targetStable: targetStable,
      targetRect: targetRect,
    ).dispatch(context);
  }

  ({Rect targetRect, Rect localRect})? _targetGeometry() {
    final renderObject = _measureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize ||
        !_renderObjectCanPaint(renderObject)) {
      return null;
    }
    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    if (rect.width <= 0 || rect.height <= 0) {
      return null;
    }
    final viewport = _viewportRect();
    final targetRect = _targetProxyRect(
      target: rect,
      viewport: viewport,
      targetPadding: EdgeInsets.all(context.spacing.xs),
    );
    if (targetRect == null) {
      return null;
    }
    return (targetRect: targetRect, localRect: targetRect.shift(-rect.topLeft));
  }

  Rect _viewportRect() {
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    return _intersectViewportRects(
      screen,
      _scrollables.map(_scrollableViewportRect),
    );
  }
}

class _OnboardingTipShowcase extends StatelessWidget {
  const _OnboardingTipShowcase({
    required this.showcaseKey,
    required this.showcaseScope,
    required this.title,
    required this.description,
    required this.targetPadding,
    required this.lowMotion,
    required this.disableDefaultTargetGestures,
    required this.onBarrierTap,
    required this.onTargetTap,
    required this.child,
  });

  final GlobalKey showcaseKey;
  final String showcaseScope;
  final String title;
  final String description;
  final EdgeInsets targetPadding;
  final bool lowMotion;
  final bool disableDefaultTargetGestures;
  final VoidCallback onBarrierTap;
  final VoidCallback? onTargetTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    return Showcase(
      key: showcaseKey,
      scope: showcaseScope,
      title: title,
      description: description,
      targetShapeBorder: RoundedSuperellipseBorder(
        borderRadius: context.radius,
      ),
      targetBorderRadius: context.radius,
      targetPadding: targetPadding,
      tooltipPadding: EdgeInsets.all(context.spacing.s),
      tooltipBorderRadius: context.radius,
      tooltipBackgroundColor: context.colorScheme.card,
      textColor: context.colorScheme.foreground,
      titleTextStyle: context.textTheme.small,
      descTextStyle: context.textTheme.muted,
      overlayColor: context.colorScheme.foreground,
      overlayOpacity: motion.tapFocusAlpha + motion.tapHoverAlpha,
      scrollLoadingWidget: const AxiProgressIndicator(),
      disableMovingAnimation: lowMotion,
      disableScaleAnimation: lowMotion,
      disposeOnTap: onTargetTap == null ? null : true,
      disableDefaultTargetGestures: disableDefaultTargetGestures,
      enableAutoScroll: false,
      onBarrierClick: onBarrierTap,
      onTargetClick: onTargetTap,
      child: child,
    );
  }
}

bool _renderObjectCanPaint(RenderObject renderObject) {
  RenderObject? current = renderObject;
  while (current != null) {
    if (current is RenderOffstage && current.offstage) {
      return false;
    }
    current = current.parent;
  }
  return true;
}

@visibleForTesting
bool onboardingTipTargetMeetsViewportPolicyForTesting({
  required Rect target,
  required Rect viewport,
}) => _targetMeetsViewportPolicy(target, viewport);

@visibleForTesting
Rect? onboardingTipTargetProxyRectForTesting({
  required Rect target,
  required Rect viewport,
  required EdgeInsets targetPadding,
}) => _targetProxyRect(
  target: target,
  viewport: viewport,
  targetPadding: targetPadding,
);

@visibleForTesting
Rect onboardingTipIntersectViewportRectsForTesting({
  required Rect viewport,
  required List<Rect?> scrollViewports,
}) => _intersectViewportRects(viewport, scrollViewports);

Set<ScrollPosition> _scrollPositionsOf(Iterable<ScrollableState> scrollables) {
  return <ScrollPosition>{
    for (final scrollable in scrollables) scrollable.position,
  };
}

List<ScrollableState> _ancestorScrollablesOf(BuildContext context) {
  final scrollables = <ScrollableState>[];
  var searchContext = context;
  while (true) {
    final scrollable = Scrollable.maybeOf(searchContext);
    if (scrollable == null || scrollables.contains(scrollable)) {
      return scrollables;
    }
    scrollables.add(scrollable);
    searchContext = scrollable.context;
  }
}

Rect? _scrollableViewportRect(ScrollableState scrollable) {
  final renderObject = scrollable.context.findRenderObject();
  if (renderObject is! RenderBox ||
      !renderObject.attached ||
      !renderObject.hasSize ||
      !_renderObjectCanPaint(renderObject)) {
    return null;
  }
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}

Rect _intersectViewportRects(Rect viewport, Iterable<Rect?> clips) {
  var clipped = viewport;
  for (final clip in clips) {
    if (clip == null) {
      continue;
    }
    clipped = clipped.intersect(clip);
  }
  return clipped;
}

bool _targetMeetsViewportPolicy(Rect target, Rect viewport) {
  if (viewport.width <= 0 || viewport.height <= 0) {
    return false;
  }
  final fitsHorizontally = target.width <= viewport.width;
  final fitsVertically = target.height <= viewport.height;
  final horizontallyVisible = fitsHorizontally
      ? target.left >= viewport.left && target.right <= viewport.right
      : target.left >= viewport.left && target.left < viewport.right;
  final verticallyVisible = fitsVertically
      ? target.top >= viewport.top && target.bottom <= viewport.bottom
      : target.top >= viewport.top && target.top < viewport.bottom;
  return horizontallyVisible && verticallyVisible;
}

Rect? _targetProxyRect({
  required Rect target,
  required Rect viewport,
  required EdgeInsets targetPadding,
}) {
  if (!_targetMeetsViewportPolicy(target, viewport)) {
    return null;
  }
  final cutoutRect = _inflateRect(target, targetPadding).intersect(viewport);
  if (cutoutRect.width <= 0 || cutoutRect.height <= 0) {
    return null;
  }
  final proxyRect = _deflateRect(cutoutRect, targetPadding);
  if (proxyRect.width <= 0 || proxyRect.height <= 0) {
    return null;
  }
  return proxyRect;
}

Rect _inflateRect(Rect rect, EdgeInsets insets) {
  return Rect.fromLTRB(
    rect.left - insets.left,
    rect.top - insets.top,
    rect.right + insets.right,
    rect.bottom + insets.bottom,
  );
}

Rect _deflateRect(Rect rect, EdgeInsets insets) {
  return Rect.fromLTRB(
    rect.left + insets.left,
    rect.top + insets.top,
    rect.right - insets.right,
    rect.bottom - insets.bottom,
  );
}

bool _sameOnboardingTipRect(Rect? first, Rect? second) {
  if (first == null || second == null) {
    return first == second;
  }
  return _closeEnoughForOnboardingTip(first.left, second.left) &&
      _closeEnoughForOnboardingTip(first.top, second.top) &&
      _closeEnoughForOnboardingTip(first.right, second.right) &&
      _closeEnoughForOnboardingTip(first.bottom, second.bottom);
}

bool _closeEnoughForOnboardingTip(double first, double second) {
  return (first - second).abs() <= 0.5;
}
