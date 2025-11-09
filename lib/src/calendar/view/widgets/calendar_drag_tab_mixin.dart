import 'dart:async';

import 'package:axichat/src/common/ui/axi_tab_bar.dart';
import 'package:flutter/material.dart';

import '../models/calendar_drag_payload.dart';

mixin CalendarDragTabMixin<T extends StatefulWidget> on State<T> {
  static const double _tabBarHeight = kTextTabBarHeight;
  static const double _edgeHotZoneWidth = 44.0;
  static const double _pointerHotZoneMinLeft = 32.0;
  static const double _pointerHotZoneMinRight = 32.0;
  static const double _pointerHotZoneMax = 56.0;
  static const double _pointerHotZoneFraction = 0.06;
  static const Duration _switchDelay = Duration(milliseconds: 320);
  Timer? _switchTimer;
  int? _pendingSwitchIndex;
  bool _evaluatingSwitch = false;
  Offset? _lastGlobalPosition;
  bool _gridDragActive = false;
  bool _edgeDragActive = false;
  bool _showLeftEdgeCue = false;
  bool _showRightEdgeCue = false;
  int? _tabCueIndex;

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
    final double height = _tabBarHeight + bottomInset;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          AxiTabBar(
            controller: mobileTabController,
            padding: EdgeInsets.only(bottom: bottomInset),
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
    required bool showCue,
    required Gradient gradient,
  }) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: _edgeHotZoneWidth,
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
              return AnimatedOpacity(
                opacity: showCue ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: Container(
                  height: double.infinity,
                  decoration: BoxDecoration(gradient: gradient),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleEdgeDragEvent(DragTargetDetails<CalendarDragPayload> details) {
    _setEdgeDragActive(true);
    if (_lastGlobalPosition == null) {
      final Offset? fallbackPosition = _pointerPositionForDetails(details);
      if (fallbackPosition == null) {
        _updateEdgeCue(null);
        _cancelSwitchTimer();
        return;
      }
      _recordPointerUpdate(fallbackPosition);
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
      return;
    }
    final Offset localPosition = box.globalToLocal(globalPosition);
    final double width = box.size.width;
    final double baseThreshold = width * _pointerHotZoneFraction;
    final double leftThreshold = baseThreshold.clamp(
      _pointerHotZoneMinLeft,
      _pointerHotZoneMax,
    );
    final double rightThreshold = baseThreshold.clamp(
      _pointerHotZoneMinRight,
      _pointerHotZoneMax,
    );
    int? cueIndex;
    final bool pointerInLeftZone = localPosition.dx <= leftThreshold;
    final bool pointerInRightZone =
        localPosition.dx >= width - rightThreshold;
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
}
