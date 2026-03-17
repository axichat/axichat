// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/axi_attention_shake.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/calendar/view/shell/calendar_drag_cancel_bucket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show LucideIcons;

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/grid/calendar_drag_payload.dart';

enum _CalendarDragSwitchSource { edge, tabBar }

mixin CalendarDragTabMixin<T extends StatefulWidget> on State<T> {
  double get _leftEdgeHotZoneWidth =>
      calendarWeekHeaderHeight + context.spacing.l;
  double get _rightEdgeHotZoneWidth => _leftEdgeHotZoneWidth;
  static const Duration _switchDelay = calendarDragTabSwitchDelay;
  static const Duration _dayShiftDelay = calendarDragTabDayShiftDelay;
  double get _edgeActivationSlop => context.spacing.m;
  Timer? _switchTimer;
  int? _pendingSwitchIndex;
  _CalendarDragSwitchSource? _pendingSwitchSource;
  Timer? _dayShiftTimer;
  int? _dayShiftDelta;
  bool _evaluatingSwitch = false;
  Offset? _lastGlobalPosition;
  Offset? _dragStartGlobalPosition;
  double? _dragStartLocalDx;
  bool _dragStartInLeftZone = false;
  bool _dragStartInRightZone = false;
  bool _edgeActivationUnlocked = false;
  bool _gridDragActive = false;
  bool _edgeDragActive = false;
  bool _showLeftEdgeCue = false;
  bool _showRightEdgeCue = false;
  bool _showScheduleTabCue = false;
  bool _showTasksTabCue = false;
  bool _scheduleTabHovering = false;
  bool _tasksTabHovering = false;
  bool _cancelBucketHovering = false;
  bool _dragChromeHovering = false;
  final GlobalKey _cancelBucketKey = GlobalKey(
    debugLabel: 'calendarDragCancelBucket',
  );
  final FocusNode _cancelBucketFocusNode = FocusNode(
    debugLabel: 'calendarCancelBucketFocus',
  );
  CalendarDragPayload? _activeCancelPayload;

  TabController get mobileTabController;

  bool get isDragSwitcherEnabled;

  bool get isAnyDragActive => _isAnyDragActive;

  bool get _isAnyDragActive => _gridDragActive || _edgeDragActive;

  void onDragDayShiftRequested(int deltaDays);

  void _setGridDragActive(bool isActive) {
    if (_gridDragActive == isActive) {
      return;
    }
    if (!mounted) {
      _gridDragActive = isActive;
      return;
    }
    setState(() {
      _gridDragActive = isActive;
    });
  }

  void _setEdgeDragActive(bool isActive) {
    if (_edgeDragActive == isActive) {
      return;
    }
    if (!mounted) {
      _edgeDragActive = isActive;
      return;
    }
    setState(() {
      _edgeDragActive = isActive;
    });
  }

  void initCalendarDragTabMixin() {
    mobileTabController.addListener(_handleTabControllerChanged);
  }

  void disposeCalendarDragTabMixin() {
    mobileTabController.removeListener(_handleTabControllerChanged);
    _cancelSwitchTimer();
    _cancelDayShiftTimer();
    _cancelBucketFocusNode.dispose();
  }

  void handleGridDragSessionStarted() {
    _setGridDragActive(true);
    _lastGlobalPosition = null;
    _dragStartGlobalPosition = null;
    _dragStartLocalDx = null;
    _dragStartInLeftZone = false;
    _dragStartInRightZone = false;
    _edgeActivationUnlocked = false;
    _setScheduleTabCue(false);
    _setTasksTabCue(false);
    _cancelDayShiftTimer();
    _evaluateEdgeAutoSwitch();
  }

  void handleGridDragPositionChanged(Offset globalPosition) {
    _recordPointerUpdate(globalPosition);
    _evaluateEdgeAutoSwitch();
  }

  void handleGridDragSessionEnded() {
    _setGridDragActive(false);
    if (!_edgeDragActive) {
      _lastGlobalPosition = null;
    }
    _dragStartGlobalPosition = null;
    _dragStartLocalDx = null;
    _dragStartInLeftZone = false;
    _dragStartInRightZone = false;
    _edgeActivationUnlocked = false;
    _updateEdgeCue(null);
    _scheduleTabHovering = false;
    _tasksTabHovering = false;
    _setScheduleTabCue(false);
    _setTasksTabCue(false);
    _cancelSwitchTimer();
    _cancelDayShiftTimer();
    _updateDragChromeHovering();
  }

  Widget buildDragEdgeTargets() {
    if (!isDragSwitcherEnabled) {
      return const SizedBox.shrink();
    }
    final scheme = context.colorScheme;
    final Color base = scheme.primary;
    final Color fade = base.withValues(alpha: 0.0);
    final Color glow = base.withValues(alpha: 0.18);

    return Stack(
      children: [
        Positioned.fill(
          child: _DragEdgeTarget(
            alignment: Alignment.centerLeft,
            width: _leftEdgeHotZoneWidth,
            showCue: _showLeftEdgeCue,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[glow, fade],
            ),
            dragActive: _isAnyDragActive,
            onEvent: _handleEdgeDragEvent,
            onLeave: _handleEdgeDragLeave,
          ),
        ),
        Positioned.fill(
          child: _DragEdgeTarget(
            alignment: Alignment.centerRight,
            width: _rightEdgeHotZoneWidth,
            showCue: _showRightEdgeCue,
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: <Color>[glow, fade],
            ),
            dragActive: _isAnyDragActive,
            onEvent: _handleEdgeDragEvent,
            onLeave: _handleEdgeDragLeave,
          ),
        ),
      ],
    );
  }

  Widget buildDragAwareTabBar({
    required BuildContext context,
    required double bottomInset,
    required Widget scheduleTabLabel,
    required Widget tasksTabLabel,
  }) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final l10n = context.l10n;
    final bool lowMotion = context.watch<SettingsCubit>().state.lowMotion;
    final Duration animationDuration = context
        .watch<SettingsCubit>()
        .animationDuration;
    final double safeInset = _isAnyDragActive ? 0 : bottomInset;
    final EdgeInsetsDirectional navPadding = EdgeInsetsDirectional.only(
      start: spacing.xs,
      end: spacing.xs,
      top: spacing.s,
      bottom: spacing.s + safeInset,
    );
    final double iconSize = sizing.iconButtonIconSize + spacing.xxs;

    final Widget navBar = AnimatedBuilder(
      animation: mobileTabController,
      builder: (context, _) {
        final bool scheduleCueActive = _showScheduleTabCue && _isAnyDragActive;
        final bool tasksCueActive = _showTasksTabCue && _isAnyDragActive;
        final int displayedIndex = scheduleCueActive
            ? 0
            : tasksCueActive
            ? 1
            : mobileTabController.index;
        final bool scheduleSelected = displayedIndex == 0;
        final bool tasksSelected = displayedIndex == 1;
        final bool scheduleSwitchHintActive =
            _isAnyDragActive &&
            mobileTabController.index == 1 &&
            !scheduleCueActive;
        final bool tasksSwitchHintActive =
            _isAnyDragActive &&
            mobileTabController.index == 0 &&
            !tasksCueActive;
        final Color scheduleColor = scheduleSelected
            ? colors.foreground
            : colors.mutedForeground;
        final Color tasksColor = tasksSelected
            ? colors.foreground
            : colors.mutedForeground;

        return GNav(
          selectedIndex: displayedIndex,
          duration: animationDuration,
          haptic: true,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          tabMargin: EdgeInsets.symmetric(horizontal: spacing.xxs),
          tabBorderRadius: context.radii.squircle,
          curve: Curves.easeInOutCubic,
          gap: spacing.s,
          iconSize: iconSize,
          color: colors.mutedForeground,
          activeColor: colors.foreground,
          textStyle: context.textTheme.small.strong,
          tabBackgroundColor: colors.secondary.withValues(
            alpha: context.motion.tapHoverAlpha,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: spacing.s,
            vertical: spacing.s,
          ),
          onTabChange: (value) {
            if (mobileTabController.index != value) {
              mobileTabController.animateTo(value);
            }
          },
          tabs: [
            GButton(
              icon: LucideIcons.calendarClock,
              text: l10n.homeRailCalendar,
              leading: AxiAttentionShake(
                enabled: !lowMotion && scheduleSwitchHintActive,
                child: IconTheme.merge(
                  data: IconThemeData(color: scheduleColor, size: iconSize),
                  child: scheduleTabLabel,
                ),
              ),
              iconColor: colors.mutedForeground,
              iconActiveColor: colors.foreground,
            ),
            GButton(
              icon: LucideIcons.squareCheck,
              text: l10n.calendarFragmentTaskLabel,
              leading: AxiAttentionShake(
                enabled: !lowMotion && tasksSwitchHintActive,
                child: IconTheme.merge(
                  data: IconThemeData(color: tasksColor, size: iconSize),
                  child: tasksTabLabel,
                ),
              ),
              iconColor: colors.mutedForeground,
              iconActiveColor: colors.foreground,
            ),
          ],
        );
      },
    );

    final Widget tabContent = Padding(
      padding: navPadding,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          navBar,
          if (_isAnyDragActive)
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: DragTarget<CalendarDragPayload>(
                      hitTestBehavior: HitTestBehavior.translucent,
                      onWillAcceptWithDetails: _handleScheduleTabDragEvent,
                      onMove: _handleScheduleTabDragMove,
                      onLeave: (_) => _handleScheduleTabDragLeave(),
                      onAcceptWithDetails: (details) {
                        _handleScheduleTabDragLeave();
                        onDragCancelRequested(details.data);
                      },
                      builder: (context, _, _) => const SizedBox.expand(),
                    ),
                  ),
                  Expanded(
                    child: DragTarget<CalendarDragPayload>(
                      hitTestBehavior: HitTestBehavior.translucent,
                      onWillAcceptWithDetails: _handleTasksTabDragEvent,
                      onMove: _handleTasksTabDragMove,
                      onLeave: (_) => _handleTasksTabDragLeave(),
                      onAcceptWithDetails: (details) {
                        _handleTasksTabDragLeave();
                        onDragCancelRequested(details.data);
                      },
                      builder: (context, _, _) => const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return tabContent;
  }

  Widget buildDragCancelBucket({
    required BuildContext context,
    required double bottomInset,
  }) {
    if (!isDragSwitcherEnabled) {
      return const SizedBox.shrink();
    }
    final bool visible = _isAnyDragActive;
    if (!visible && _activeCancelPayload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _setActiveCancelPayload(null);
        }
      });
    }
    final double safeBottomPadding = math.max(bottomInset, 0.0);
    return CalendarDragCancelBucket(
      key: _cancelBucketKey,
      visible: visible,
      bottomInset: safeBottomPadding,
      hovering: _cancelBucketHovering,
      focusNode: _cancelBucketFocusNode,
      shortcuts: _cancelShortcuts,
      actions: {
        _CancelDragIntent: CallbackAction<_CancelDragIntent>(
          onInvoke: (_) {
            _triggerCancelBucketAction();
            return null;
          },
        ),
      },
      semanticEnabled: _activeCancelPayload != null,
      onSemanticTap: _activeCancelPayload == null
          ? null
          : _triggerCancelBucketAction,
      onWillAcceptWithDetails: (details) {
        final bool inside = _isPointerInsideCancelBucket(details);
        _setActiveCancelPayload(details.data);
        _setCancelBucketHovering(inside);
        return inside;
      },
      onMove: (details) {
        final bool inside = _isPointerInsideCancelBucket(details);
        _setCancelBucketHovering(inside);
      },
      onLeave: (_) {
        _setCancelBucketHovering(false);
        _setActiveCancelPayload(null);
      },
      onAcceptWithDetails: (details) {
        _setCancelBucketHovering(false);
        _handleCancelBucketDrop(details.data);
        _setActiveCancelPayload(null);
      },
    );
  }

  void _setCancelBucketHovering(bool value) {
    if (_cancelBucketHovering == value || !mounted) {
      return;
    }
    setState(() {
      _cancelBucketHovering = value;
    });
    _updateDragChromeHovering();
  }

  void _setActiveCancelPayload(CalendarDragPayload? payload) {
    if (_activeCancelPayload == payload) {
      return;
    }
    if (!mounted) {
      _activeCancelPayload = payload;
      return;
    }
    setState(() {
      _activeCancelPayload = payload;
    });
    if (payload != null) {
      _cancelBucketFocusNode.requestFocus();
    }
  }

  void _triggerCancelBucketAction() {
    final CalendarDragPayload? payload = _activeCancelPayload;
    if (payload == null) {
      return;
    }
    _setCancelBucketHovering(false);
    _handleCancelBucketDrop(payload);
  }

  bool handleKeyboardCancelBucket() {
    final CalendarDragPayload? payload = _activeCancelPayload;
    if (payload == null) {
      return false;
    }
    _triggerCancelBucketAction();
    return true;
  }

  Map<ShortcutActivator, Intent> get _cancelShortcuts =>
      const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space): _CancelDragIntent(),
        SingleActivator(LogicalKeyboardKey.enter): _CancelDragIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _CancelDragIntent(),
      };

  void _handleCancelBucketDrop(CalendarDragPayload payload) {
    _setCancelBucketHovering(false);
    onDragCancelRequested(payload);
  }

  void _handleEdgeDragEvent(DragTargetDetails<CalendarDragPayload> details) {
    _setEdgeDragActive(true);
    final Offset? pointer = _pointerPositionForDetails(details);
    if (pointer != null) {
      _recordPointerUpdate(pointer);
    } else if (_lastGlobalPosition == null) {
      _updateEdgeCue(null);
      _cancelSwitchTimer();
      return;
    }
    _evaluateEdgeAutoSwitch();
  }

  void _handleEdgeDragLeave() {
    _setEdgeDragActive(false);
    if (!_gridDragActive) {
      _lastGlobalPosition = null;
    }
    _updateEdgeCue(null);
    _cancelSwitchTimer();
    _cancelDayShiftTimer();
  }

  bool _handleScheduleTabDragEvent(
    DragTargetDetails<CalendarDragPayload> details,
  ) {
    _setScheduleTabHovering(true);
    final bool canSwitch = _canSwitchTo(0);
    if (!canSwitch) {
      _setScheduleTabCue(false);
      return false;
    }
    _setScheduleTabCue(true);
    _scheduleSwitch(0, source: _CalendarDragSwitchSource.tabBar);
    return true;
  }

  void _handleScheduleTabDragMove(
    DragTargetDetails<CalendarDragPayload> details,
  ) {
    _handleScheduleTabDragEvent(details);
  }

  void _handleScheduleTabDragLeave() {
    _setScheduleTabHovering(false);
    _setScheduleTabCue(false);
    if (_pendingSwitchIndex == 0 &&
        _pendingSwitchSource == _CalendarDragSwitchSource.tabBar) {
      _cancelSwitchTimer();
    }
  }

  bool _handleTasksTabDragEvent(
    DragTargetDetails<CalendarDragPayload> details,
  ) {
    _setTasksTabHovering(true);
    final bool canSwitch = _canSwitchTo(1);
    if (!canSwitch) {
      _setTasksTabCue(false);
      return false;
    }
    _setTasksTabCue(true);
    _scheduleSwitch(1, source: _CalendarDragSwitchSource.tabBar);
    return true;
  }

  void _handleTasksTabDragMove(DragTargetDetails<CalendarDragPayload> details) {
    _handleTasksTabDragEvent(details);
  }

  void _handleTasksTabDragLeave() {
    _setTasksTabHovering(false);
    _setTasksTabCue(false);
    if (_pendingSwitchIndex == 1 &&
        _pendingSwitchSource == _CalendarDragSwitchSource.tabBar) {
      _cancelSwitchTimer();
    }
  }

  void _evaluateEdgeAutoSwitch() {
    if (!mounted || !isDragSwitcherEnabled || !_isAnyDragActive) {
      _updateEdgeCue(null);
      _cancelSwitchTimer();
      _cancelDayShiftTimer();
      return;
    }
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Offset? globalPosition = _lastGlobalPosition;
    if (box == null || !box.hasSize || globalPosition == null) {
      _updateEdgeCue(null);
      _cancelSwitchTimer();
      _cancelDayShiftTimer();
      return;
    }
    final Offset localPosition = box.globalToLocal(globalPosition);
    final double width = box.size.width;
    final double leftThreshold = width <= 0
        ? 0
        : math.min(_leftEdgeHotZoneWidth, width * 0.5);
    final double rightThreshold = width <= 0
        ? 0
        : math.min(_rightEdgeHotZoneWidth, width * 0.5);
    _dragStartLocalDx ??= localPosition.dx;
    if (_dragStartLocalDx != null &&
        !_dragStartInLeftZone &&
        !_dragStartInRightZone) {
      _dragStartInLeftZone = _dragStartLocalDx! <= leftThreshold;
      _dragStartInRightZone = _dragStartLocalDx! >= width - rightThreshold;
    }

    final double horizontalTravel = _dragStartLocalDx == null
        ? 0
        : (localPosition.dx - _dragStartLocalDx!).abs();
    if (!_edgeActivationUnlocked && horizontalTravel >= _edgeActivationSlop) {
      _edgeActivationUnlocked = true;
    }

    if (!_edgeDragActive) {
      _updateEdgeCue(null);
      if (_pendingSwitchSource == _CalendarDragSwitchSource.edge) {
        _cancelSwitchTimer();
      }
      _cancelDayShiftTimer();
      return;
    }

    bool pointerInLeftZone = localPosition.dx <= leftThreshold;
    bool pointerInRightZone = localPosition.dx >= width - rightThreshold;

    if (!_edgeActivationUnlocked) {
      if (_dragStartInLeftZone && pointerInLeftZone) {
        pointerInLeftZone = false;
      }
      if (_dragStartInRightZone && pointerInRightZone) {
        pointerInRightZone = false;
      }
    }

    int? cueIndex;
    if (pointerInLeftZone) {
      cueIndex = 0;
    } else if (pointerInRightZone) {
      cueIndex = 1;
    }
    _updateEdgeCue(cueIndex);

    final int tabIndex = mobileTabController.index;
    if (tabIndex == 1) {
      _cancelDayShiftTimer();
      if (!pointerInLeftZone) {
        if (_pendingSwitchSource == _CalendarDragSwitchSource.edge) {
          _cancelSwitchTimer();
        }
        return;
      }
      _scheduleSwitch(0, source: _CalendarDragSwitchSource.edge);
      return;
    }

    if (_pendingSwitchSource == _CalendarDragSwitchSource.edge) {
      _cancelSwitchTimer();
    }

    if (pointerInLeftZone) {
      _scheduleDayShift(-1);
    } else if (pointerInRightZone) {
      _scheduleDayShift(1);
    } else {
      _cancelDayShiftTimer();
    }
  }

  void _scheduleSwitch(int index, {required _CalendarDragSwitchSource source}) {
    if (_pendingSwitchIndex == index &&
        _pendingSwitchSource == source &&
        _switchTimer?.isActive == true) {
      return;
    }
    _switchTimer?.cancel();
    _pendingSwitchIndex = index;
    _pendingSwitchSource = source;
    _switchTimer = Timer(_switchDelay, _tryPerformPendingSwitch);
  }

  void _scheduleDayShift(int deltaDays) {
    if (_dayShiftDelta == deltaDays && _dayShiftTimer?.isActive == true) {
      return;
    }
    _cancelDayShiftTimer();
    _dayShiftDelta = deltaDays;
    _dayShiftTimer = Timer.periodic(_dayShiftDelay, (_) {
      if (!mounted || !_isAnyDragActive || !isDragSwitcherEnabled) {
        _cancelDayShiftTimer();
        return;
      }
      if (mobileTabController.index != 0) {
        _cancelDayShiftTimer();
        return;
      }
      onDragDayShiftRequested(deltaDays);
    });
  }

  void _cancelSwitchTimer() {
    _switchTimer?.cancel();
    _switchTimer = null;
    _pendingSwitchIndex = null;
    _pendingSwitchSource = null;
  }

  void _cancelDayShiftTimer() {
    _dayShiftTimer?.cancel();
    _dayShiftTimer = null;
    _dayShiftDelta = null;
  }

  void _updateEdgeCue(int? cueIndex) {
    final bool showLeft = cueIndex == 0;
    final bool showRight = cueIndex == 1;
    if (!mounted ||
        (_showLeftEdgeCue == showLeft && _showRightEdgeCue == showRight)) {
      return;
    }
    setState(() {
      _showLeftEdgeCue = showLeft;
      _showRightEdgeCue = showRight;
    });
  }

  void _setScheduleTabCue(bool showCue) {
    if (!mounted || _showScheduleTabCue == showCue) {
      _showScheduleTabCue = showCue;
      _updateDragChromeHovering();
      return;
    }
    setState(() {
      _showScheduleTabCue = showCue;
    });
    _updateDragChromeHovering();
  }

  void _setTasksTabCue(bool showCue) {
    if (!mounted || _showTasksTabCue == showCue) {
      _showTasksTabCue = showCue;
      _updateDragChromeHovering();
      return;
    }
    setState(() {
      _showTasksTabCue = showCue;
    });
    _updateDragChromeHovering();
  }

  void _setScheduleTabHovering(bool isHovering) {
    if (_scheduleTabHovering == isHovering) {
      return;
    }
    _scheduleTabHovering = isHovering;
    _updateDragChromeHovering();
  }

  void _setTasksTabHovering(bool isHovering) {
    if (_tasksTabHovering == isHovering) {
      return;
    }
    _tasksTabHovering = isHovering;
    _updateDragChromeHovering();
  }

  void _cancelGridMotionForNonGridDragHover() {
    _updateEdgeCue(null);
    if (_pendingSwitchSource == _CalendarDragSwitchSource.edge) {
      _cancelSwitchTimer();
    }
    _cancelDayShiftTimer();
  }

  void _updateDragChromeHovering() {
    final bool isHovering =
        _cancelBucketHovering || _scheduleTabHovering || _tasksTabHovering;
    if (_dragChromeHovering == isHovering) {
      return;
    }
    _dragChromeHovering = isHovering;
    if (isHovering) {
      _cancelGridMotionForNonGridDragHover();
    }
    onCancelBucketHoverChanged(isHovering);
  }

  void _handleTabControllerChanged() {
    if (!_isAnyDragActive) {
      return;
    }
    _switchTimer?.cancel();
    _switchTimer = null;
    _pendingSwitchIndex = null;
    _pendingSwitchSource = null;
    _cancelDayShiftTimer();
    _setScheduleTabCue(false);
    _setTasksTabCue(false);
    if (_dragChromeHovering) {
      _cancelGridMotionForNonGridDragHover();
      return;
    }
    _evaluateEdgeAutoSwitch();
  }

  Offset? _pointerPositionForDetails(
    DragTargetDetails<CalendarDragPayload> details,
  ) {
    final Offset feedbackTopLeft = details.offset;
    if (!feedbackTopLeft.dx.isFinite || !feedbackTopLeft.dy.isFinite) {
      return null;
    }
    final CalendarDragPayload payload = details.data;
    final Rect? sourceBounds = payload.sourceBounds;
    final double normalized =
        ((payload.pointerNormalizedX ?? 0.5).clamp(0.0, 1.0) as num).toDouble();
    double width = sourceBounds?.width ?? 0.0;
    double height = sourceBounds?.height ?? 0.0;
    if (!width.isFinite || width <= 0) {
      width = 0.0;
    }
    if (!height.isFinite || height <= 0) {
      height = 0.0;
    }
    final double anchorDx = width > 0 ? width * normalized : 0.0;
    double anchorDy;
    final double? pointerOffsetY = payload.pointerOffsetY;
    if (pointerOffsetY != null && pointerOffsetY.isFinite) {
      if (height > 0) {
        anchorDy = (pointerOffsetY.clamp(0.0, height) as num).toDouble();
      } else {
        anchorDy = pointerOffsetY;
      }
    } else if (height > 0) {
      anchorDy = height / 2;
    } else {
      anchorDy = 0.0;
    }
    final Offset pointer = feedbackTopLeft + Offset(anchorDx, anchorDy);
    if (!pointer.dx.isFinite || !pointer.dy.isFinite) {
      return null;
    }
    return pointer;
  }

  bool _isPointerInsideCancelBucket(
    DragTargetDetails<CalendarDragPayload> details,
  ) {
    final BuildContext? bucketContext = _cancelBucketKey.currentContext;
    final RenderBox? box = bucketContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return false;
    }
    final Offset? pointer = _pointerPositionForDetails(details);
    if (pointer == null) {
      return false;
    }
    final Offset local = box.globalToLocal(pointer);
    if (!local.dx.isFinite || !local.dy.isFinite) {
      return false;
    }
    final Size size = box.size;
    if (!size.width.isFinite || !size.height.isFinite) {
      return false;
    }
    return local.dx >= 0 &&
        local.dx <= size.width &&
        local.dy >= 0 &&
        local.dy <= size.height;
  }

  void _recordPointerUpdate(Offset position) {
    _lastGlobalPosition = position;
    _dragStartGlobalPosition ??= position;
  }

  bool _canSwitchTo(int index) {
    if (!mounted ||
        !_isAnyDragActive ||
        !isDragSwitcherEnabled ||
        mobileTabController.index == index) {
      return false;
    }
    return true;
  }

  void _tryPerformPendingSwitch() {
    if (_evaluatingSwitch) {
      return;
    }
    _evaluatingSwitch = true;
    try {
      final int? targetIndex = _pendingSwitchIndex;
      if (targetIndex == null) {
        return;
      }
      if (_canSwitchTo(targetIndex)) {
        _pendingSwitchIndex = null;
        mobileTabController.animateTo(targetIndex);
      }
    } finally {
      _evaluatingSwitch = false;
    }
  }

  void onCancelBucketHoverChanged(bool isHovering) {}

  CalendarTask restoreTaskFromPayload(CalendarDragPayload payload) {
    return restoreCalendarTaskFromDragPayload(payload);
  }

  void onDragCancelRequested(CalendarDragPayload payload);
}

class _CancelDragIntent extends Intent {
  const _CancelDragIntent();
}

typedef _EdgeDragEventHandler =
    void Function(DragTargetDetails<CalendarDragPayload> details);

class _DragEdgeTarget extends StatelessWidget {
  const _DragEdgeTarget({
    required this.alignment,
    required this.width,
    required this.showCue,
    required this.gradient,
    required this.dragActive,
    required this.onEvent,
    required this.onLeave,
  });

  final Alignment alignment;
  final double width;
  final bool showCue;
  final Gradient gradient;
  final bool dragActive;
  final _EdgeDragEventHandler onEvent;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: width,
        child: IgnorePointer(
          ignoring: !dragActive,
          child: DragTarget<CalendarDragPayload>(
            hitTestBehavior: HitTestBehavior.translucent,
            onWillAcceptWithDetails: (details) {
              onEvent(details);
              return true;
            },
            onMove: onEvent,
            onLeave: (_) => onLeave(),
            onAcceptWithDetails: (_) => onLeave(),
            builder: (context, _, _) {
              return AnimatedContainer(
                duration: calendarSlotHoverAnimationDuration,
                height: double.infinity,
                decoration: showCue
                    ? BoxDecoration(gradient: gradient)
                    : const BoxDecoration(color: Colors.transparent),
              );
            },
          ),
        ),
      ),
    );
  }
}
