// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:showcaseview/showcaseview.dart';

enum CalendarTaskDragTipSource { grid, sidebar }

class CalendarTaskDragTipHost extends StatefulWidget {
  const CalendarTaskDragTipHost({
    super.key,
    required this.accountJid,
    required this.enabled,
    required this.visibleSources,
    required this.rescanIdentity,
    required this.dragActive,
    required this.child,
  });

  final String? accountJid;
  final bool enabled;
  final Set<CalendarTaskDragTipSource> visibleSources;
  final Object? rescanIdentity;
  final bool dragActive;
  final Widget child;

  @override
  State<CalendarTaskDragTipHost> createState() =>
      _CalendarTaskDragTipHostState();
}

class CalendarTaskDragTipCandidate extends StatefulWidget {
  const CalendarTaskDragTipCandidate({
    super.key,
    required this.source,
    required this.taskId,
    this.enabled = true,
    required this.child,
  });

  final CalendarTaskDragTipSource source;
  final String taskId;
  final bool enabled;
  final Widget child;

  @override
  State<CalendarTaskDragTipCandidate> createState() =>
      _CalendarTaskDragTipCandidateState();
}

@visibleForTesting
String? calendarTaskDragTipFirstVisibleCandidateForTesting({
  required Rect viewport,
  required Map<String, Rect> candidates,
}) {
  final visible = <({String id, Rect rect})>[];
  for (final entry in candidates.entries) {
    final rect = entry.value;
    if (!_rectFullyInside(viewport, rect) ||
        rect.width <= 0 ||
        rect.height <= 0) {
      continue;
    }
    visible.add((id: entry.key, rect: rect));
  }
  visible.sort((a, b) {
    final top = a.rect.top.compareTo(b.rect.top);
    if (top != 0) {
      return top;
    }
    final left = a.rect.left.compareTo(b.rect.left);
    if (left != 0) {
      return left;
    }
    return a.id.compareTo(b.id);
  });
  return visible.isEmpty ? null : visible.first.id;
}

@visibleForTesting
String? calendarTaskDragTipFirstVisibleSourceCandidateForTesting({
  required Rect viewport,
  required Set<CalendarTaskDragTipSource> visibleSources,
  required Map<String, ({CalendarTaskDragTipSource source, Rect rect})>
  candidates,
}) {
  return calendarTaskDragTipFirstVisibleCandidateForTesting(
    viewport: viewport,
    candidates: <String, Rect>{
      for (final entry in candidates.entries)
        if (visibleSources.contains(entry.value.source))
          entry.key: entry.value.rect,
    },
  );
}

void notifyCalendarTaskDragTipTaskPickedUp(BuildContext context) {
  final scope = _CalendarTaskDragTipScope.find(context);
  scope?.state.handleTaskPickedUp();
}

class _CalendarTaskDragTipHostState extends State<CalendarTaskDragTipHost> {
  final GlobalKey _hostKey = GlobalKey(debugLabel: 'calendarTaskDragTipHost');
  final GlobalKey _showcaseKey = GlobalKey(debugLabel: 'calendarTaskDragTip');
  final String _showcaseScope = 'calendar-task-drag-tip-${UniqueKey()}';
  final Set<_CalendarTaskDragTipCandidateState> _candidateStates =
      <_CalendarTaskDragTipCandidateState>{};
  bool _tipShown = true;
  bool _tipStateLoaded = false;
  bool _tipMarkedThisSession = false;
  bool _selectionScheduled = false;
  String? _activeCandidateId;
  String? _loadedAccountJid;

  bool get _accountAvailable => widget.accountJid?.trim().isNotEmpty == true;

  bool get _showEveryTimeForTesting => false;

  bool get _initialTipPending =>
      widget.enabled && _accountAvailable && _tipStateLoaded && !_tipShown;

  bool get _candidateModeActive => _initialTipPending && !widget.dragActive;

  @override
  void initState() {
    super.initState();
    _loadTipState();
  }

  @override
  void didUpdateWidget(covariant CalendarTaskDragTipHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountJid != widget.accountJid ||
        oldWidget.enabled != widget.enabled) {
      _clearCandidateSelection();
      _tipShown = true;
      _tipStateLoaded = false;
      _tipMarkedThisSession = false;
      _loadedAccountJid = null;
      _loadTipState();
      return;
    }
    if (!setEquals(oldWidget.visibleSources, widget.visibleSources) ||
        oldWidget.rescanIdentity != widget.rescanIdentity) {
      _clearCandidateSelection();
      _scheduleCandidateSelection();
    }
    if (!oldWidget.dragActive && widget.dragActive && _initialTipPending) {
      _completeInitialTipFromDragStart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showcaseActive = _candidateModeActive && _activeCandidateId != null;
    return AxiShowcaseBoundary(
      active: showcaseActive,
      identity: '${widget.rescanIdentity}|${_activeCandidateId ?? ''}',
      lowMotion: context.watch<SettingsCubit>().state.lowMotion,
      scope: _showcaseScope,
      onDismiss: _handleShowcaseDismissed,
      enableAutoScroll: false,
      disableBarrierInteraction: true,
      child: _CalendarTaskDragTipShowcaseStarter(
        active: showcaseActive,
        targetId: _activeCandidateId,
        showcaseKey: _showcaseKey,
        child: _CalendarTaskDragTipScope(
          candidateModeActive: _candidateModeActive,
          activeCandidateId: _activeCandidateId,
          showcaseKey: _showcaseKey,
          showcaseScope: _showcaseScope,
          state: this,
          child: KeyedSubtree(key: _hostKey, child: widget.child),
        ),
      ),
    );
  }

  void registerCandidate(_CalendarTaskDragTipCandidateState candidate) {
    if (!_candidateStates.add(candidate)) {
      return;
    }
    _scheduleCandidateSelection();
  }

  void unregisterCandidate(_CalendarTaskDragTipCandidateState candidate) {
    if (!_candidateStates.remove(candidate)) {
      return;
    }
    if (_activeCandidateId == candidate.candidateId) {
      if (mounted) {
        setState(_clearCandidateSelection);
      } else {
        _clearCandidateSelection();
      }
    }
    _scheduleCandidateSelection();
  }

  void handleTaskPickedUp() {
    if (!_initialTipPending) {
      return;
    }
    _completeInitialTipFromDragStart();
  }

  void _loadTipState() {
    final accountJid = widget.accountJid;
    if (!widget.enabled || accountJid == null || accountJid.trim().isEmpty) {
      _loadedAccountJid = null;
      _tipShown = true;
      _tipStateLoaded = true;
      _tipMarkedThisSession = false;
      _clearCandidateSelection();
      return;
    }
    _loadedAccountJid = accountJid;
    final settingsCubit = context.read<SettingsCubit>();
    unawaited(
      settingsCubit.calendarTaskDragTipShownFor(accountJid).then((shown) {
        if (!mounted || _loadedAccountJid != accountJid) {
          return;
        }
        if (_tipMarkedThisSession) {
          setState(() {
            _tipStateLoaded = true;
          });
          return;
        }
        setState(() {
          _tipShown = _showEveryTimeForTesting ? false : shown;
          _tipStateLoaded = true;
        });
        if (widget.dragActive && _initialTipPending) {
          _completeInitialTipFromDragStart();
          return;
        }
        _scheduleCandidateSelection();
      }),
    );
  }

  void _scheduleCandidateSelection() {
    if (!_candidateModeActive) {
      _clearCandidateSelection();
      return;
    }
    if (_selectionScheduled) {
      return;
    }
    _selectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionScheduled = false;
      if (!mounted) {
        return;
      }
      _selectCandidateAfterLayout();
    });
  }

  void _selectCandidateAfterLayout() {
    final candidateId = _measureNextCandidateId();
    if (_activeCandidateId == candidateId) {
      return;
    }
    setState(() {
      _activeCandidateId = candidateId;
    });
  }

  String? _measureNextCandidateId() {
    if (!_candidateModeActive) {
      return null;
    }
    final hostRect = _hostRect();
    if (hostRect == null) {
      return null;
    }
    final candidates =
        <String, ({CalendarTaskDragTipSource source, Rect rect})>{
          for (final candidate in _candidateStates)
            if (candidate.isTipCandidateActive &&
                widget.visibleSources.contains(candidate.source))
              if (candidate.selectableGlobalRectWithin(hostRect)
                  case final rect?)
                candidate.candidateId: (source: candidate.source, rect: rect),
        };
    return calendarTaskDragTipFirstVisibleSourceCandidateForTesting(
      viewport: hostRect,
      visibleSources: widget.visibleSources,
      candidates: candidates,
    );
  }

  Rect? _hostRect() {
    final context = _hostKey.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize ||
        !_renderObjectCanPaint(renderObject)) {
      return null;
    }
    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & renderObject.size;
  }

  void _completeInitialTipFromDragStart() {
    if (!_initialTipPending) {
      return;
    }
    _markInitialTipShown();
  }

  void _dismissInitialTipForSession() {
    if (!mounted || _tipShown) {
      return;
    }
    setState(() {
      _tipShown = true;
      _tipStateLoaded = true;
      _clearCandidateSelection();
    });
  }

  void _handleShowcaseDismissed(
    GlobalKey? key,
    AxiShowcaseDismissReason reason,
  ) {
    if (key != _showcaseKey || reason != AxiShowcaseDismissReason.user) {
      return;
    }
    _dismissInitialTipForSession();
  }

  void _markInitialTipShown() {
    if (!mounted || _tipShown) {
      return;
    }
    setState(() {
      _tipShown = true;
      _tipStateLoaded = true;
      _tipMarkedThisSession = true;
      _clearCandidateSelection();
    });
    unawaited(
      context.read<SettingsCubit>().markCalendarTaskDragTipShownFor(
        widget.accountJid,
      ),
    );
  }

  void _clearCandidateSelection() {
    _activeCandidateId = null;
  }
}

class _CalendarTaskDragTipShowcaseStarter extends StatefulWidget {
  const _CalendarTaskDragTipShowcaseStarter({
    required this.active,
    required this.targetId,
    required this.showcaseKey,
    required this.child,
  });

  final bool active;
  final String? targetId;
  final GlobalKey showcaseKey;
  final Widget child;

  @override
  State<_CalendarTaskDragTipShowcaseStarter> createState() =>
      _CalendarTaskDragTipShowcaseStarterState();
}

class _CalendarTaskDragTipShowcaseStarterState
    extends State<_CalendarTaskDragTipShowcaseStarter> {
  bool _startScheduled = false;
  int _attempt = 0;
  String? _startedTargetId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleStart();
  }

  @override
  void didUpdateWidget(
    covariant _CalendarTaskDragTipShowcaseStarter oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetId != widget.targetId || !widget.active) {
      _startedTargetId = null;
      _attempt = 0;
    }
    _scheduleStart();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _scheduleStart() {
    if (!widget.active ||
        widget.targetId == null ||
        _startedTargetId == widget.targetId ||
        _startScheduled ||
        _attempt > 1) {
      return;
    }
    _startScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScheduled = false;
      if (!mounted || !widget.active || widget.targetId == null) {
        return;
      }
      final controller = AxiShowcaseController.maybeOf(context);
      if (controller == null) {
        return;
      }
      if (controller.start([widget.showcaseKey])) {
        _startedTargetId = widget.targetId;
        _attempt = 0;
        return;
      }
      _attempt++;
      _scheduleStart();
    });
  }
}

bool _rectFullyInside(Rect outer, Rect inner) {
  return inner.left >= outer.left &&
      inner.top >= outer.top &&
      inner.right <= outer.right &&
      inner.bottom <= outer.bottom;
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

class _CalendarTaskDragTipScope extends InheritedWidget {
  const _CalendarTaskDragTipScope({
    required this.candidateModeActive,
    required this.activeCandidateId,
    required this.showcaseKey,
    required this.showcaseScope,
    required this.state,
    required super.child,
  });

  final bool candidateModeActive;
  final String? activeCandidateId;
  final GlobalKey showcaseKey;
  final String showcaseScope;
  final _CalendarTaskDragTipHostState state;

  static _CalendarTaskDragTipScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_CalendarTaskDragTipScope>();
  }

  static _CalendarTaskDragTipScope? find(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<_CalendarTaskDragTipScope>();
    final widget = element?.widget;
    return widget is _CalendarTaskDragTipScope ? widget : null;
  }

  @override
  bool updateShouldNotify(covariant _CalendarTaskDragTipScope oldWidget) {
    return oldWidget.candidateModeActive != candidateModeActive ||
        oldWidget.activeCandidateId != activeCandidateId ||
        oldWidget.showcaseKey != showcaseKey ||
        oldWidget.showcaseScope != showcaseScope ||
        oldWidget.state != state;
  }
}

class _CalendarTaskDragTipCandidateState
    extends State<CalendarTaskDragTipCandidate> {
  final GlobalKey _measureKey = GlobalKey();
  _CalendarTaskDragTipHostState? _registeredState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRegistration();
  }

  @override
  void didUpdateWidget(covariant CalendarTaskDragTipCandidate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.taskId != widget.taskId ||
        oldWidget.enabled != widget.enabled) {
      _unregister();
    }
    _syncRegistration();
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final measuredChild = NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _registeredState?._scheduleCandidateSelection();
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: KeyedSubtree(key: _measureKey, child: widget.child),
      ),
    );
    final scope = _CalendarTaskDragTipScope.maybeOf(context);
    if (scope == null ||
        !scope.candidateModeActive ||
        scope.activeCandidateId != candidateId) {
      return measuredChild;
    }
    final motion = context.motion;
    final lowMotion = context.watch<SettingsCubit>().state.lowMotion;
    return Showcase(
      key: scope.showcaseKey,
      scope: scope.showcaseScope,
      title: context.l10n.calendarTaskDragHoldShowcaseTitle,
      description: context.l10n.calendarTaskDragShowcaseDescription,
      targetShapeBorder: RoundedSuperellipseBorder(
        borderRadius: context.radius,
      ),
      targetBorderRadius: context.radius,
      targetPadding: EdgeInsets.all(context.spacing.xs),
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
      disableDefaultTargetGestures: true,
      enableAutoScroll: false,
      onBarrierClick: () {
        AxiShowcaseController.maybeOf(context)?.dismissUser();
      },
      child: measuredChild,
    );
  }

  void _syncRegistration() {
    final scope = _CalendarTaskDragTipScope.maybeOf(context);
    if (widget.enabled && (scope?.candidateModeActive ?? false)) {
      _register(scope!.state);
    } else {
      _unregister();
    }
  }

  CalendarTaskDragTipSource get source => widget.source;

  String get candidateId => '${widget.source.name}:${widget.taskId}';

  bool get isTipCandidateActive => mounted && widget.enabled;

  Rect? selectableGlobalRectWithin(Rect hostRect) {
    final renderObject = _measureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize ||
        !_renderObjectCanPaint(renderObject)) {
      return null;
    }
    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    if (!_rectFullyInside(hostRect, rect) ||
        rect.width <= 0 ||
        rect.height <= 0 ||
        !_hitTestSamplesReachTarget(rect, renderObject)) {
      return null;
    }
    return rect;
  }

  bool _hitTestSamplesReachTarget(Rect rect, RenderBox renderObject) {
    final view = View.of(context);
    final inset = math.min(
      context.spacing.xs,
      math.min(rect.width, rect.height) / 2,
    );
    final sampledRect = rect.deflate(inset);
    final points = sampledRect.width <= 0 || sampledRect.height <= 0
        ? <Offset>[rect.center]
        : <Offset>[
            sampledRect.center,
            sampledRect.topLeft,
            sampledRect.topRight,
            sampledRect.bottomLeft,
            sampledRect.bottomRight,
          ];
    for (final point in points) {
      final result = HitTestResult();
      WidgetsBinding.instance.hitTestInView(result, point, view.viewId);
      if (!result.path.any((entry) => entry.target == renderObject)) {
        return false;
      }
    }
    return true;
  }

  void _register(_CalendarTaskDragTipHostState state) {
    if (identical(_registeredState, state)) {
      state._scheduleCandidateSelection();
      return;
    }
    _unregister();
    _registeredState = state;
    state.registerCandidate(this);
  }

  void _unregister() {
    final state = _registeredState;
    if (state == null) {
      return;
    }
    state.unregisterCandidate(this);
    _registeredState = null;
  }
}
