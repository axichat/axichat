import 'dart:async';
import 'dart:math' as math;

import 'package:axichat/src/common/ui/axi_tab_bar.dart';
import 'package:flutter/material.dart';

import '../models/calendar_drag_payload.dart';

mixin CalendarDragTabMixin<T extends StatefulWidget> on State<T> {
  static const double _tabBarHeight = kTextTabBarHeight;
  static const double _leftEdgeHotZoneWidth = 66.0;
  static const double _rightEdgeHotZoneWidth = 28.8;
  static const Duration _switchDelay = Duration(milliseconds: 320);
  static const double _edgeActivationSlop = 12.0;
  Timer? _switchTimer;
  int? _pendingSwitchIndex;
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
  int? _tabCueIndex;
  bool _cancelBucketHovering = false;

  TabController get mobileTabController;

  bool get isDragSwitcherEnabled;

  bool get _isAnyDragActive => _gridDragActive || _edgeDragActive;

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
  }

  void handleGridDragSessionStarted() {
    _setGridDragActive(true);
    _lastGlobalPosition = null;
    _dragStartGlobalPosition = null;
    _dragStartLocalDx = null;
    _dragStartInLeftZone = false;
    _dragStartInRightZone = false;
    _edgeActivationUnlocked = false;
    _evaluateEdgeAutoSwitch();
  }

  void handleGridDragPositionChanged(Offset globalPosition) {
    _recordPointerUpdate(globalPosition);
    _evaluateEdgeAutoSwitch();
    _tryPerformPendingSwitch();
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
    _cancelSwitchTimer();
  }

  Widget buildDragEdgeTargets() {
    if (!isDragSwitcherEnabled) {
      return const SizedBox.shrink();
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color base = scheme.primary;
    final Color fade = base.withValues(alpha: 0.0);
    final Color glow = base.withValues(alpha: 0.18);

    return Stack(
      children: [
        Positioned.fill(
          child: _buildEdgeTarget(
            alignment: Alignment.centerLeft,
            width: _leftEdgeHotZoneWidth,
            showCue: _showLeftEdgeCue,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[glow, fade],
            ),
          ),
        ),
        Positioned.fill(
          child: _buildEdgeTarget(
            alignment: Alignment.centerRight,
            width: _rightEdgeHotZoneWidth,
            showCue: _showRightEdgeCue,
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: <Color>[glow, fade],
            ),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool scheduleCueActive = _tabCueIndex == 0 && _isAnyDragActive;
    final bool tasksCueActive = _tabCueIndex == 1 && _isAnyDragActive;
    final double safeInset = _isAnyDragActive ? 0 : bottomInset;
    final double height = _tabBarHeight + safeInset;

    final Widget tabContent = SizedBox(
      height: height,
      child: Stack(
        children: [
          AxiTabBar(
            controller: mobileTabController,
            padding: EdgeInsets.only(bottom: safeInset),
            indicatorColor: scheme.primary,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: <Widget>[
              Tab(
                child: _buildTabLabel(
                  label: scheduleTabLabel,
                  scheme: scheme,
                  showCue: scheduleCueActive,
                ),
              ),
              Tab(
                child: _buildTabLabel(
                  label: tasksTabLabel,
                  scheme: scheme,
                  showCue: tasksCueActive,
                ),
              ),
            ],
          ),
          if (isDragSwitcherEnabled)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_isAnyDragActive,
                child: Row(
                  children: [
                    Expanded(child: _buildTabDragTarget(tabIndex: 0)),
                    Expanded(child: _buildTabDragTarget(tabIndex: 1)),
                  ],
                ),
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
    final Duration duration = const Duration(milliseconds: 200);
    final Curve curve = Curves.easeInOutCubic;
    final double safeBottomPadding = math.max(bottomInset, 0.0);
    const double bucketHeight = 48.0;
    final double totalHeight = bucketHeight + safeBottomPadding;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curve,
      switchOutCurve: curve,
      child: !visible
          ? const SizedBox.shrink()
          : SizedBox(
              key: const ValueKey('calendar.drag.cancel-bucket'),
              width: double.infinity,
              height: totalHeight,
              child: DragTarget<CalendarDragPayload>(
                hitTestBehavior: HitTestBehavior.translucent,
                onWillAcceptWithDetails: (details) {
                  _setCancelBucketHovering(true);
                  return true;
                },
                onMove: (_) => _setCancelBucketHovering(true),
                onLeave: (_) => _setCancelBucketHovering(false),
                onAcceptWithDetails: (details) {
                  _handleCancelBucketDrop(details.data);
                },
                builder: (context, candidate, __) {
                  final ColorScheme scheme = Theme.of(context).colorScheme;
                  final bool hovering =
                      _cancelBucketHovering || candidate.isNotEmpty;
                  final Color fillColor = scheme.error.withValues(
                    alpha: hovering ? 0.18 : 0.09,
                  );
                  final Color iconColor = scheme.error.withValues(
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
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cancel drag',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              color: iconColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildTabDragTarget({required int tabIndex}) {
    return DragTarget<CalendarDragPayload>(
      hitTestBehavior: HitTestBehavior.translucent,
      onWillAcceptWithDetails: (details) {
        _handleTabButtonDragEvent(tabIndex, details);
        return true;
      },
      onMove: (details) => _handleTabButtonDragEvent(tabIndex, details),
      onLeave: (_) => _handleTabButtonDragLeave(tabIndex),
      onAcceptWithDetails: (_) => _handleTabButtonDragLeave(tabIndex),
      builder: (context, _, __) => const SizedBox.expand(),
    );
  }

  Widget _buildTabLabel({
    required Widget label,
    required ColorScheme scheme,
    required bool showCue,
  }) {
    final Color cueColor =
        showCue ? scheme.primary.withValues(alpha: 0.55) : Colors.transparent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cueColor,
            width: 2,
          ),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontWeight: showCue ? FontWeight.w600 : FontWeight.w500,
        ),
        child: Align(
          alignment: Alignment.center,
          child: label,
        ),
      ),
    );
  }


  Widget _buildEdgeTarget({
    required Alignment alignment,
    required double width,
    required bool showCue,
    required Gradient gradient,
  }) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: width,
        child: IgnorePointer(
          ignoring: !_isAnyDragActive,
          child: DragTarget<CalendarDragPayload>(
            hitTestBehavior: HitTestBehavior.translucent,
            onWillAcceptWithDetails: (details) {
              _handleEdgeDragEvent(details);
              return true;
            },
            onMove: _handleEdgeDragEvent,
            onLeave: (_) => _handleEdgeDragLeave(),
            onAcceptWithDetails: (_) => _handleEdgeDragLeave(),
            builder: (context, _, __) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: double.infinity,
                color: showCue
                    ? Colors.deepOrange.withOpacity(0.3)
                    : Colors.deepOrange.withOpacity(0.15),
              );
            },
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
  }

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
    _tryPerformPendingSwitch();
  }

  void _handleEdgeDragLeave() {
    _setEdgeDragActive(false);
    if (!_gridDragActive) {
      _lastGlobalPosition = null;
    }
    _updateEdgeCue(null);
    _cancelSwitchTimer();
  }

  void _handleTabButtonDragEvent(
    int tabIndex,
    DragTargetDetails<CalendarDragPayload> details,
  ) {
    if (!isDragSwitcherEnabled || !_isAnyDragActive) {
      return;
    }
    final Offset? pointer = _pointerPositionForDetails(details);
    if (pointer != null) {
      _recordPointerUpdate(pointer);
    }
    _setEdgeCueVisibility(showLeft: false, showRight: false);
    _updateTabCueOnly(tabIndex);
    if (mobileTabController.index == tabIndex) {
      _cancelSwitchTimer();
      return;
    }
    _scheduleSwitch(tabIndex);
  }

  void _handleTabButtonDragLeave(int tabIndex) {
    if (!_isAnyDragActive) {
      return;
    }
    if (_tabCueIndex == tabIndex) {
      _updateTabCueOnly(null);
    }
    _evaluateEdgeAutoSwitch();
    _tryPerformPendingSwitch();
  }

  void _evaluateEdgeAutoSwitch() {
    if (!mounted || !isDragSwitcherEnabled || !_isAnyDragActive) {
      _updateEdgeCue(null);
      _cancelSwitchTimer();
      return;
    }
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Offset? globalPosition = _lastGlobalPosition;
    if (box == null || !box.hasSize || globalPosition == null) {
      _updateEdgeCue(null);
      _cancelSwitchTimer();
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
      _dragStartInRightZone =
          _dragStartLocalDx! >= width - rightThreshold;
    }

    final double horizontalTravel = _dragStartLocalDx == null
        ? 0
        : (localPosition.dx - _dragStartLocalDx!).abs();
    if (!_edgeActivationUnlocked &&
        horizontalTravel >= _edgeActivationSlop) {
      _edgeActivationUnlocked = true;
    }

    if (!_edgeDragActive) {
      _updateEdgeCue(null);
      _cancelSwitchTimer();
      return;
    }

    bool pointerInLeftZone = localPosition.dx <= leftThreshold;
    bool pointerInRightZone =
        localPosition.dx >= width - rightThreshold;

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
    if (cueIndex == null || mobileTabController.index == cueIndex) {
      if (cueIndex == null) {
        _cancelSwitchTimer();
      }
      return;
    }
    _scheduleSwitch(cueIndex);
  }

  void _scheduleSwitch(int index) {
    if (_pendingSwitchIndex == index && _switchTimer?.isActive == true) {
      _tryPerformPendingSwitch();
      return;
    }
    _switchTimer?.cancel();
    _pendingSwitchIndex = index;
    _switchTimer = Timer(_switchDelay, () {
      _tryPerformPendingSwitch();
    });
    _tryPerformPendingSwitch();
  }

  void _cancelSwitchTimer() {
    _switchTimer?.cancel();
    _switchTimer = null;
    _pendingSwitchIndex = null;
  }

  void _setEdgeCueVisibility({
    required bool showLeft,
    required bool showRight,
  }) {
    if (!mounted ||
        (_showLeftEdgeCue == showLeft && _showRightEdgeCue == showRight)) {
      return;
    }
    setState(() {
      _showLeftEdgeCue = showLeft;
      _showRightEdgeCue = showRight;
    });
  }

  void _updateTabCueOnly(int? cueIndex) {
    if (!mounted || _tabCueIndex == cueIndex) {
      return;
    }
    setState(() {
      _tabCueIndex = cueIndex;
    });
  }

  void _updateEdgeCue(int? cueIndex) {
    final bool showLeft = cueIndex == 0;
    final bool showRight = cueIndex == 1;
    if (!mounted ||
        (_showLeftEdgeCue == showLeft &&
            _showRightEdgeCue == showRight &&
            _tabCueIndex == cueIndex)) {
      return;
    }
    setState(() {
      _showLeftEdgeCue = showLeft;
      _showRightEdgeCue = showRight;
      _tabCueIndex = cueIndex;
    });
  }

  void _handleTabControllerChanged() {
    if (!_isAnyDragActive) {
      return;
    }
    _switchTimer?.cancel();
    _switchTimer = null;
    _pendingSwitchIndex = null;
    _evaluateEdgeAutoSwitch();
    _tryPerformPendingSwitch();
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

  void onDragCancelRequested(CalendarDragPayload payload);
}
