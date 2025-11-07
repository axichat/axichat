import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/calendar_drag_payload.dart';

enum _PointerUpdateSource { direct, fallback }

mixin CalendarDragTabMixin<T extends StatefulWidget> on State<T> {
  static const double _edgeActivationExtent = 72.0;
  static const double _pointerActivationExtent = 40.0;
  static const Duration _switchDelay = Duration(milliseconds: 220);
  static const Duration _pointerFallbackDelay = Duration(milliseconds: 90);
  static const Duration _pointerStaleTimeout = Duration(milliseconds: 120);
  static const double _minPointerThreshold = 32.0;
  static const double _maxPointerThreshold = 64.0;

  Timer? _switchTimer;
  int? _pendingSwitchIndex;
  bool _evaluatingSwitch = false;
  Offset? _lastGlobalPosition;
  DateTime? _dragSessionStartTime;
  DateTime? _lastPointerUpdateTime;
  _PointerUpdateSource? _lastPointerSource;
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
    _dragSessionStartTime = DateTime.now();
    _lastGlobalPosition = null;
    _lastPointerUpdateTime = null;
    _lastPointerSource = null;
    _evaluateEdgeAutoSwitch();
  }

  void handleGridDragPositionChanged(Offset globalPosition) {
    _recordPointerUpdate(globalPosition, _PointerUpdateSource.direct);
    _evaluateEdgeAutoSwitch();
    _tryPerformPendingSwitch();
  }

  void handleGridDragSessionEnded() {
    _setGridDragActive(false);
    if (!_edgeDragActive) {
      _lastGlobalPosition = null;
    }
    _dragSessionStartTime = null;
    _lastPointerUpdateTime = null;
    _lastPointerSource = null;
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
    required BoxConstraints constraints,
    required double bottomInset,
    required Widget scheduleTabLabel,
    required Widget tasksTabLabel,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final EdgeInsets padding = EdgeInsets.fromLTRB(
      16,
      8,
      16,
      bottomInset > 0 ? bottomInset : 12,
    );

    Widget decorateTab(Widget label, bool highlighted) {
      final Color highlightColor = scheme.primary.withValues(alpha: 0.12);
      return AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: highlighted ? highlightColor : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
          ),
          child: label,
        ),
      );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: TabBar(
        controller: mobileTabController,
        indicatorColor: scheme.primary,
        indicatorWeight: 3,
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelPadding: EdgeInsets.zero,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: <Widget>[
          Tab(
            child: decorateTab(
              scheduleTabLabel,
              _tabCueIndex == 0 && _isAnyDragActive,
            ),
          ),
          Tab(
            child: decorateTab(
              tasksTabLabel,
              _tabCueIndex == 1 && _isAnyDragActive,
            ),
          ),
        ],
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
        width: 56,
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
    final Offset? fallbackPosition = _pointerPositionForDetails(details);
    final bool shouldApplyFallback = _shouldUseFallbackPointer;
    if (_lastGlobalPosition == null && !shouldApplyFallback) {
      _updateEdgeCue(null);
      _cancelSwitchTimer();
      return;
    }
    if (shouldApplyFallback) {
      if (fallbackPosition == null) {
        _updateEdgeCue(null);
        _cancelSwitchTimer();
        return;
      }
      _recordPointerUpdate(fallbackPosition, _PointerUpdateSource.fallback);
    }
    if (_lastGlobalPosition == null) {
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
      _lastPointerUpdateTime = null;
      _lastPointerSource = null;
    }
    _updateEdgeCue(null);
    _cancelSwitchTimer();
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
    final double pointerThreshold = math.max(
      _minPointerThreshold,
      math.min(_maxPointerThreshold, width * 0.08),
    );
    int? cueIndex;
    final bool pointerInLeftZone = localPosition.dx <= pointerThreshold;
    final bool pointerInRightZone =
        localPosition.dx >= width - pointerThreshold;
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
        ((payload.pointerNormalizedX ?? 0.5).clamp(0.0, 1.0) as num)
            .toDouble();
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

  bool get _shouldUseFallbackPointer {
    final DateTime now = DateTime.now();
    final DateTime? lastUpdate = _lastPointerUpdateTime;
    if (lastUpdate != null && _lastPointerSource == _PointerUpdateSource.direct) {
      return now.difference(lastUpdate) > _pointerStaleTimeout;
    }
    if (lastUpdate != null && _lastPointerSource != _PointerUpdateSource.direct) {
      return true;
    }
    final DateTime? dragStart = _dragSessionStartTime;
    if (dragStart == null) {
      return false;
    }
    return now.difference(dragStart) > _pointerFallbackDelay;
  }

  void _recordPointerUpdate(Offset position, _PointerUpdateSource source) {
    _lastGlobalPosition = position;
    _lastPointerUpdateTime = DateTime.now();
    _lastPointerSource = source;
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
