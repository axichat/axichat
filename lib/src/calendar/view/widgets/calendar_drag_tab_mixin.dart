// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/common/ui/settings_cubit_lookup.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/models/calendar_drag_payload.dart';

enum _CalendarDragSwitchSource { edge, tabBar }

mixin CalendarDragTabMixin<T extends StatefulWidget> on State<T> {
  double get _leftEdgeHotZoneWidth =>
      calendarWeekHeaderHeight + context.spacing.l;
  double get _rightEdgeHotZoneWidth => _leftEdgeHotZoneWidth;
  static const Duration _switchDelay = baseAnimationDuration;
  static final Duration _dayShiftDelay = axiMotion.statusBannerSuccessDuration;
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
  bool _cancelBucketHovering = false;
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
    _setScheduleTabCue(false);
    _setTasksTabCue(false);
    _cancelSwitchTimer();
    _cancelDayShiftTimer();
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
    final scheme = context.colorScheme;
    final bool scheduleCueActive = _showScheduleTabCue && _isAnyDragActive;
    final bool tasksCueActive = _showTasksTabCue && _isAnyDragActive;
    final bool lowMotion =
        maybeSettingsCubit(context)?.state.lowMotion ?? false;
    final bool scheduleSelected = mobileTabController.index == 0;
    final bool tasksSelected = mobileTabController.index == 1;
    final bool scheduleSwitchHintActive =
        _isAnyDragActive && mobileTabController.index == 1;
    final bool tasksSwitchHintActive =
        _isAnyDragActive && mobileTabController.index == 0;
    final double safeInset = _isAnyDragActive ? 0 : bottomInset;
    final double baseHeight = context.sizing.listButtonHeight;
    final double height = baseHeight + safeInset;
    final Color backgroundColor = context.colorScheme.background;

    final double minTabWidth = context.sizing.listButtonHeight * 2;
    final double indicatorWeight = context.borderSide.width * 3;
    final Duration indicatorDuration = lowMotion ? Duration.zero : _switchDelay;
    final Color hoverBackground = scheme.primary.withValues(alpha: 0.08);
    final Color pressedBackground = scheme.primary.withValues(alpha: 0.14);
    final ShadDecoration baseDecoration = ShadDecoration(
      border: ShadBorder.none,
      secondaryBorder: ShadBorder.none,
      secondaryFocusedBorder: ShadBorder.none,
      focusedBorder: ShadBorder.none,
      errorBorder: ShadBorder.none,
      secondaryErrorBorder: ShadBorder.none,
      disableSecondaryBorder: true,
    );
    final ShadDecoration selectedDecoration = baseDecoration;
    final ShadDecoration tabBarDecoration = ShadDecoration(
      color: backgroundColor,
      border: ShadBorder.none,
      secondaryBorder: ShadBorder.none,
      secondaryFocusedBorder: ShadBorder.none,
      focusedBorder: ShadBorder.none,
      errorBorder: ShadBorder.none,
      secondaryErrorBorder: ShadBorder.none,
      disableSecondaryBorder: true,
    );

    final Widget tabContent = SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          final bool useScrollable = width.isFinite && width < minTabWidth * 2;
          final Alignment tabBarAlignment =
              useScrollable ? Alignment.centerLeft : Alignment.center;

          return AnimatedBuilder(
            animation: mobileTabController,
            builder: (context, _) {
              final tabs = ShadTabs<int>(
                value: mobileTabController.index,
                padding: EdgeInsets.only(bottom: safeInset),
                gap: 0,
                scrollable: useScrollable,
                tabBarAlignment: tabBarAlignment,
                decoration: tabBarDecoration,
                onChanged: (value) {
                  if (mobileTabController.index != value) {
                    mobileTabController.animateTo(value);
                  }
                },
                tabs: <ShadTab<int>>[
                  ShadTab<int>(
                    value: 0,
                    decoration: baseDecoration,
                    selectedDecoration: selectedDecoration,
                    backgroundColor: Colors.transparent,
                    selectedBackgroundColor: Colors.transparent,
                    hoverBackgroundColor: hoverBackground,
                    selectedHoverBackgroundColor: hoverBackground,
                    pressedBackgroundColor: pressedBackground,
                    foregroundColor: scheme.mutedForeground,
                    selectedForegroundColor: scheme.foreground,
                    textStyle: context.textTheme.small,
                    child: DragTarget<CalendarDragPayload>(
                      hitTestBehavior: HitTestBehavior.translucent,
                      onWillAcceptWithDetails: _handleScheduleTabDragEvent,
                      onMove: _handleScheduleTabDragMove,
                      onLeave: (_) => _handleScheduleTabDragLeave(),
                      onAcceptWithDetails: (details) {
                        _handleScheduleTabDragLeave();
                        onDragCancelRequested(details.data);
                      },
                      builder: (context, _, __) => _DragTabLabel(
                        label: scheduleTabLabel,
                        scheme: scheme,
                        selected: scheduleSelected,
                        showCue: scheduleCueActive,
                        shake: !lowMotion &&
                            scheduleSwitchHintActive &&
                            !scheduleCueActive,
                      ),
                    ),
                  ),
                  ShadTab<int>(
                    value: 1,
                    decoration: baseDecoration,
                    selectedDecoration: selectedDecoration,
                    backgroundColor: Colors.transparent,
                    selectedBackgroundColor: Colors.transparent,
                    hoverBackgroundColor: hoverBackground,
                    selectedHoverBackgroundColor: hoverBackground,
                    pressedBackgroundColor: pressedBackground,
                    foregroundColor: scheme.mutedForeground,
                    selectedForegroundColor: scheme.foreground,
                    textStyle: context.textTheme.small,
                    child: DragTarget<CalendarDragPayload>(
                      hitTestBehavior: HitTestBehavior.translucent,
                      onWillAcceptWithDetails: _handleTasksTabDragEvent,
                      onMove: _handleTasksTabDragMove,
                      onLeave: (_) => _handleTasksTabDragLeave(),
                      onAcceptWithDetails: (details) {
                        _handleTasksTabDragLeave();
                        onDragCancelRequested(details.data);
                      },
                      builder: (context, _, __) => _DragTabLabel(
                        label: tasksTabLabel,
                        scheme: scheme,
                        selected: tasksSelected,
                        showCue: tasksCueActive,
                        shake: !lowMotion &&
                            tasksSwitchHintActive &&
                            !tasksCueActive,
                      ),
                    ),
                  ),
                ],
              );
              if (useScrollable) {
                return tabs;
              }
              return Stack(
                children: [
                  tabs,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedAlign(
                        duration: indicatorDuration,
                        curve: Curves.easeInOutCubic,
                        alignment: Alignment(
                          mobileTabController.index == 0 ? -1 : 1,
                          1,
                        ),
                        child: FractionallySizedBox(
                          widthFactor: 0.5,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                horizontal: context.spacing.s,
                              ),
                              height: indicatorWeight,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius:
                                    BorderRadius.circular(indicatorWeight),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
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
    final l10n = context.l10n;
    final bool visible = _isAnyDragActive;
    if (!visible && _activeCancelPayload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _setActiveCancelPayload(null);
        }
      });
    }
    const duration = calendarSlotHoverAnimationDuration;
    const curve = Curves.easeInOutCubic;
    final double safeBottomPadding = math.max(bottomInset, 0.0);
    const double bucketHeight = 48.0;
    final double totalHeight = bucketHeight + safeBottomPadding;
    final double targetHeight = visible ? totalHeight : 0;
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      height: targetHeight,
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: curve,
        switchOutCurve: curve,
        transitionBuilder: (child, animation) {
          final Animation<Offset> offsetAnimation = Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: curve));
          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: !visible
            ? const SizedBox.shrink()
            : FocusableActionDetector(
                focusNode: _cancelBucketFocusNode,
                enabled: visible,
                shortcuts: _cancelShortcuts,
                actions: {
                  _CancelDragIntent: CallbackAction<_CancelDragIntent>(
                    onInvoke: (_) {
                      _triggerCancelBucketAction();
                      return null;
                    },
                  ),
                },
                child: Semantics(
                  key: const ValueKey('calendar.drag.cancel-bucket'),
                  button: true,
                  enabled: _activeCancelPayload != null,
                  label: l10n.commonCancel,
                  hint: l10n.commonCancel,
                  onTap: _activeCancelPayload == null
                      ? null
                      : _triggerCancelBucketAction,
                  child: SizedBox(
                    width: double.infinity,
                    height: totalHeight,
                    child: DragTarget<CalendarDragPayload>(
                      key: _cancelBucketKey,
                      hitTestBehavior: HitTestBehavior.translucent,
                      onWillAcceptWithDetails: (details) {
                        final bool inside = _isPointerInsideCancelBucket(
                          details,
                        );
                        _setActiveCancelPayload(details.data);
                        _setCancelBucketHovering(inside);
                        return inside;
                      },
                      onMove: (details) {
                        final bool inside = _isPointerInsideCancelBucket(
                          details,
                        );
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
                      builder: (context, candidate, __) {
                        if (candidate.isNotEmpty) {
                          _setActiveCancelPayload(candidate.first);
                        }
                        final scheme = context.colorScheme;
                        final bool hovering =
                            _cancelBucketHovering || candidate.isNotEmpty;
                        final Color fillColor = scheme.destructive.withValues(
                          alpha: hovering ? 0.18 : 0.09,
                        );
                        final Color iconColor = scheme.destructive.withValues(
                          alpha: hovering ? 0.95 : 0.78,
                        );
                        return Container(
                          width: double.infinity,
                          height: totalHeight,
                          padding: EdgeInsets.only(bottom: safeBottomPadding),
                          color: fillColor,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.close_rounded,
                                  color: iconColor,
                                  size: context.sizing.menuItemIconSize,
                                ),
                                SizedBox(width: context.spacing.s),
                                Text(
                                  context.l10n.commonCancel,
                                  style: context.textTheme.label.strong
                                      .copyWith(color: iconColor),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  void _setCancelBucketHovering(bool value) {
    if (_cancelBucketHovering == value || !mounted) {
      return;
    }
    setState(() {
      _cancelBucketHovering = value;
    });
    onCancelBucketHoverChanged(value);
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
    final bool canSwitch = _canSwitchTo(0);
    if (!canSwitch) {
      _handleScheduleTabDragLeave();
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
    _setScheduleTabCue(false);
    if (_pendingSwitchIndex == 0 &&
        _pendingSwitchSource == _CalendarDragSwitchSource.tabBar) {
      _cancelSwitchTimer();
    }
  }

  bool _handleTasksTabDragEvent(
    DragTargetDetails<CalendarDragPayload> details,
  ) {
    final bool canSwitch = _canSwitchTo(1);
    if (!canSwitch) {
      _handleTasksTabDragLeave();
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
    final double leftThreshold =
        width <= 0 ? 0 : math.min(_leftEdgeHotZoneWidth, width * 0.5);
    final double rightThreshold =
        width <= 0 ? 0 : math.min(_rightEdgeHotZoneWidth, width * 0.5);
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
      return;
    }
    setState(() {
      _showScheduleTabCue = showCue;
    });
  }

  void _setTasksTabCue(bool showCue) {
    if (!mounted || _showTasksTabCue == showCue) {
      _showTasksTabCue = showCue;
      return;
    }
    setState(() {
      _showTasksTabCue = showCue;
    });
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
    _handleScheduleTabDragLeave();
    _handleTasksTabDragLeave();
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
    final CalendarTask snapshot = payload.snapshot;
    final DateTime? originalStart = payload.pickupScheduledTime ??
        snapshot.scheduledTime ??
        payload.originSlot;
    if (originalStart != null) {
      return snapshot.withScheduled(
        scheduledTime: originalStart,
        duration: snapshot.duration,
        endDate: snapshot.endDate,
      );
    }
    return snapshot.copyWith(scheduledTime: null, endDate: snapshot.endDate);
  }

  void onDragCancelRequested(CalendarDragPayload payload);
}

class _CancelDragIntent extends Intent {
  const _CancelDragIntent();
}

class _DragTabLabel extends StatelessWidget {
  const _DragTabLabel({
    required this.label,
    required this.scheme,
    required this.selected,
    required this.showCue,
    required this.shake,
  });

  final Widget label;
  final ShadColorScheme scheme;
  final bool selected;
  final bool showCue;
  final bool shake;

  @override
  Widget build(BuildContext context) {
    final duration = maybeSettingsCubit(context)?.animationDuration ??
        calendarTaskSplitPreviewAnimationDuration;
    final Color cueColor =
        showCue ? scheme.primary.withValues(alpha: 0.55) : Colors.transparent;
    final double width =
        showCue ? context.borderSide.width * 2 : context.borderSide.width;
    final bool emphasize = showCue || selected;
    final labelContent = AnimatedContainer(
      duration: duration,
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.s,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cueColor,
            width: width,
          ),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: context.textTheme.label.strongIf(emphasize),
        child: Align(alignment: Alignment.center, child: label),
      ),
    );
    if (!shake) {
      return labelContent;
    }
    return _ShakingDragTabLabel(child: labelContent);
  }
}

class _ShakingDragTabLabel extends StatefulWidget {
  const _ShakingDragTabLabel({required this.child});

  final Widget child;

  @override
  State<_ShakingDragTabLabel> createState() => _ShakingDragTabLabelState();
}

class _ShakingDragTabLabelState extends State<_ShakingDragTabLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: baseAnimationDuration,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amplitude = context.spacing.xxs;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final phase = _controller.value * math.pi * 6;
        final dx = math.sin(phase) * amplitude;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

typedef _EdgeDragEventHandler = void Function(
    DragTargetDetails<CalendarDragPayload> details);

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
            builder: (context, _, __) {
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
