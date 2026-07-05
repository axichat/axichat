// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AxiAdaptiveLayout extends StatelessWidget {
  static const Curve _paneResizeCurve = Curves.easeInOutCubic;
  static const Curve _compactSlideCurve = Curves.easeIn;
  static const double _primaryCollapseHandleWidth = 24;

  const AxiAdaptiveLayout({
    super.key,
    required this.primaryChild,
    required this.secondaryChild,
    this.invertPriority = false,
    this.showPrimary = true,
    this.showSecondary = true,
    this.animatePaneChanges = false,
    this.panePadding = EdgeInsets.zero,
    this.centerPrimary = true,
    this.centerSecondary = true,
    this.primaryAlignment,
    this.secondaryAlignment,
    this.primaryFlex = 4,
    this.secondaryFlex = 6,
    this.primaryCollapsed = false,
    this.onPrimaryCollapsedChanged,
    this.primaryCollapseTooltip,
    this.primaryExpandTooltip,
    this.onCompactSecondaryDismiss,
    this.allowSplitView = true,
    EdgeInsets? primaryPadding,
    EdgeInsets? secondaryPadding,
  }) : primaryPadding = primaryPadding ?? panePadding,
       secondaryPadding = secondaryPadding ?? panePadding;

  final Widget primaryChild;
  final Widget secondaryChild;
  final bool invertPriority;
  final bool showPrimary;
  final bool showSecondary;
  final bool animatePaneChanges;
  final EdgeInsets panePadding;
  final EdgeInsets primaryPadding;
  final EdgeInsets secondaryPadding;
  final bool centerPrimary;
  final bool centerSecondary;
  final Alignment? primaryAlignment;
  final Alignment? secondaryAlignment;
  final int primaryFlex;
  final int secondaryFlex;
  final bool primaryCollapsed;
  final ValueChanged<bool>? onPrimaryCollapsedChanged;
  final String? primaryCollapseTooltip;
  final String? primaryExpandTooltip;
  final FutureOr<bool> Function()? onCompactSecondaryDismiss;
  final bool allowSplitView;

  @override
  Widget build(BuildContext context) {
    if (!showPrimary && !showSecondary) {
      return const SizedBox.shrink();
    }
    final splitActive =
        allowSplitView && MediaQuery.sizeOf(context).width >= smallScreen;
    if (!splitActive) {
      return _CompactPaneTransition(
        primaryChild: primaryChild,
        secondaryChild: secondaryChild,
        showPrimary: showPrimary,
        showSecondary: showSecondary,
        invertPriority: invertPriority,
        duration: context.watch<SettingsCubit>().animationDuration,
        onCompactSecondaryDismiss: onCompactSecondaryDismiss,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool showSecondaryDivider = showPrimary && showSecondary;
        final bool showPrimaryCollapseToggle =
            onPrimaryCollapsedChanged != null && showPrimary && showSecondary;
        final bool collapsePrimary =
            showPrimaryCollapseToggle && primaryCollapsed;
        final BoxDecoration secondaryDividerDecoration = BoxDecoration(
          border: Border(left: context.borderSide),
        );
        final primaryAlign =
            primaryAlignment ??
            (centerPrimary ? Alignment.center : Alignment.topLeft);
        final secondaryAlign =
            secondaryAlignment ??
            (centerSecondary ? Alignment.center : Alignment.topLeft);
        final animationDuration = context
            .watch<SettingsCubit>()
            .animationDuration;
        if (!animatePaneChanges && !showPrimaryCollapseToggle) {
          return ConstrainedBox(
            constraints: constraints,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showPrimary)
                  Expanded(
                    flex: primaryFlex,
                    child: AxiAdaptivePane(
                      alignment: primaryAlign,
                      padding: primaryPadding,
                      child: primaryChild,
                    ),
                  ),
                if (showSecondary)
                  Expanded(
                    flex: secondaryFlex,
                    child: DecoratedBox(
                      decoration: showSecondaryDivider
                          ? secondaryDividerDecoration
                          : const BoxDecoration(),
                      child: AxiAdaptivePane(
                        alignment: secondaryAlign,
                        padding: secondaryPadding,
                        child: secondaryChild,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
        final int resolvedPrimaryFlex = showPrimary && !collapsePrimary
            ? primaryFlex
            : 0;
        final int resolvedSecondaryFlex = showSecondary ? secondaryFlex : 0;
        final int totalFlex = resolvedPrimaryFlex + resolvedSecondaryFlex;
        final double availableWidth = constraints.maxWidth;
        double widthForFlex(int flexValue) {
          if (totalFlex == 0) return 0.0;
          return availableWidth * (flexValue / totalFlex);
        }

        final double primaryWidth = widthForFlex(resolvedPrimaryFlex);
        final double secondaryWidth = showSecondary
            ? (availableWidth - primaryWidth).clamp(0.0, availableWidth)
            : 0.0;
        final paneAnimationDuration = animatePaneChanges
            ? animationDuration
            : Duration.zero;
        final double collapseHandleStart = collapsePrimary
            ? primaryWidth
            : (primaryWidth - _primaryCollapseHandleWidth).clamp(
                0.0,
                availableWidth,
              );
        return ConstrainedBox(
          constraints: constraints,
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedContainer(
                    duration: paneAnimationDuration,
                    curve: _paneResizeCurve,
                    width: primaryWidth,
                    child: ClipRect(
                      child: AxiAdaptivePane(
                        alignment: primaryAlign,
                        padding: primaryPadding,
                        child: primaryChild,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: paneAnimationDuration,
                    curve: _paneResizeCurve,
                    width: secondaryWidth,
                    child: DecoratedBox(
                      decoration: showSecondaryDivider
                          ? secondaryDividerDecoration
                          : const BoxDecoration(),
                      child: ClipRect(
                        child: AxiAdaptivePane(
                          alignment: secondaryAlign,
                          padding: secondaryPadding,
                          child: secondaryChild,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (showPrimaryCollapseToggle)
                AnimatedPositioned(
                  duration: paneAnimationDuration,
                  curve: _paneResizeCurve,
                  left: collapseHandleStart,
                  top: 0,
                  bottom: 0,
                  width: _primaryCollapseHandleWidth,
                  child: Center(
                    child: _AxiAdaptivePrimaryCollapseHandle(
                      collapsed: collapsePrimary,
                      collapseTooltip: primaryCollapseTooltip,
                      expandTooltip: primaryExpandTooltip,
                      onChanged: onPrimaryCollapsedChanged!,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AxiAdaptivePrimaryCollapseHandle extends StatelessWidget {
  static const double _height = 36;
  static const double _iconSize = 14;
  static const double _radius = 7;

  const _AxiAdaptivePrimaryCollapseHandle({
    required this.collapsed,
    required this.onChanged,
    required this.collapseTooltip,
    required this.expandTooltip,
  });

  final bool collapsed;
  final ValueChanged<bool> onChanged;
  final String? collapseTooltip;
  final String? expandTooltip;

  @override
  Widget build(BuildContext context) {
    final tooltip = collapsed ? expandTooltip : collapseTooltip;
    final borderRadius = BorderRadius.horizontal(
      left: Radius.circular(collapsed ? 0 : _radius),
      right: Radius.circular(collapsed ? _radius : 0),
    );
    final button = _AxiAdaptivePrimaryCollapseButton(
      collapsed: collapsed,
      borderRadius: borderRadius,
      onPressed: () => onChanged(!collapsed),
    );
    return Semantics(
      button: true,
      enabled: true,
      label: tooltip,
      child: tooltip == null
          ? button
          : Tooltip(message: tooltip, child: button),
    );
  }
}

class _AxiAdaptivePrimaryCollapseButton extends StatefulWidget {
  const _AxiAdaptivePrimaryCollapseButton({
    required this.collapsed,
    required this.borderRadius,
    required this.onPressed,
  });

  final bool collapsed;
  final BorderRadius borderRadius;
  final VoidCallback onPressed;

  @override
  State<_AxiAdaptivePrimaryCollapseButton> createState() =>
      _AxiAdaptivePrimaryCollapseButtonState();
}

class _AxiAdaptivePrimaryCollapseButtonState
    extends State<_AxiAdaptivePrimaryCollapseButton> {
  var _hovered = false;
  var _pressed = false;

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() {
      _hovered = value;
    });
  }

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final background = _pressed || _hovered
        ? Color.alphaBlend(
            context.colorScheme.secondary.withValues(alpha: 0.72),
            context.colorScheme.background,
          )
        : context.colorScheme.background;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) {
        _setHovered(false);
        _setPressed(false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: widget.borderRadius,
            border: Border(
              left: widget.collapsed ? BorderSide.none : context.borderSide,
              top: context.borderSide,
              right: widget.collapsed ? context.borderSide : BorderSide.none,
              bottom: context.borderSide,
            ),
          ),
          child: SizedBox(
            width: AxiAdaptiveLayout._primaryCollapseHandleWidth,
            height: _AxiAdaptivePrimaryCollapseHandle._height,
            child: Center(
              child: Icon(
                widget.collapsed ? Icons.chevron_right : Icons.chevron_left,
                size: _AxiAdaptivePrimaryCollapseHandle._iconSize,
                color: context.colorScheme.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactPaneTransition extends StatefulWidget {
  const _CompactPaneTransition({
    required this.primaryChild,
    required this.secondaryChild,
    required this.showPrimary,
    required this.showSecondary,
    required this.invertPriority,
    required this.duration,
    required this.onCompactSecondaryDismiss,
  });

  final Widget primaryChild;
  final Widget secondaryChild;
  final bool showPrimary;
  final bool showSecondary;
  final bool invertPriority;
  final Duration duration;
  final FutureOr<bool> Function()? onCompactSecondaryDismiss;

  @override
  State<_CompactPaneTransition> createState() => _CompactPaneTransitionState();
}

class _CompactPaneTransitionState extends State<_CompactPaneTransition>
    with SingleTickerProviderStateMixin {
  static const double _dismissProgressThreshold = 0.40;
  static const double _dismissVelocityThreshold = 500;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: _targetValue,
  );
  bool _dragging = false;
  bool _dismissInProgress = false;

  double get _targetValue => _targetValueFor(
    showPrimary: widget.showPrimary,
    showSecondary: widget.showSecondary,
    invertPriority: widget.invertPriority,
  );

  bool get _gestureEnabled =>
      widget.onCompactSecondaryDismiss != null &&
      widget.showPrimary &&
      widget.showSecondary &&
      widget.invertPriority &&
      axiShouldEnableIosEdgeSwipe(defaultTargetPlatform);

  @override
  void didUpdateWidget(covariant _CompactPaneTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dismissInProgress) {
      return;
    }
    final oldTargetValue = _targetValueFor(
      showPrimary: oldWidget.showPrimary,
      showSecondary: oldWidget.showSecondary,
      invertPriority: oldWidget.invertPriority,
    );
    if (oldTargetValue != _targetValue) {
      unawaited(_animateTo(_targetValue));
    } else if (!_dragging &&
        !_controller.isAnimating &&
        _controller.value != _targetValue) {
      _controller.value = _targetValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final moving =
            _dragging ||
            _dismissInProgress ||
            _controller.isAnimating ||
            (_controller.value > 0 && _controller.value < 1);
        final content = moving
            ? AxiSwipeBackTransition(
                value: _controller.value,
                background: widget.primaryChild,
                foreground: widget.secondaryChild,
                cupertinoStyle: axiShouldEnableIosEdgeSwipe(
                  defaultTargetPlatform,
                ),
                centerChildren: true,
              )
            : Center(child: _activeChild);
        if (!_gestureEnabled) {
          return content;
        }
        return Stack(
          children: [
            Positioned.fill(child: content),
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: context.sizing.compactPaneEdgeSwipeWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: _handleHorizontalDragStart,
                onHorizontalDragUpdate: _handleHorizontalDragUpdate,
                onHorizontalDragEnd: _handleHorizontalDragEnd,
                onHorizontalDragCancel: _handleHorizontalDragCancel,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget get _activeChild {
    if (widget.showPrimary && widget.showSecondary) {
      return widget.invertPriority
          ? widget.secondaryChild
          : widget.primaryChild;
    }
    return widget.showPrimary ? widget.primaryChild : widget.secondaryChild;
  }

  static double _targetValueFor({
    required bool showPrimary,
    required bool showSecondary,
    required bool invertPriority,
  }) {
    if (showPrimary && showSecondary) {
      return invertPriority ? 1 : 0;
    }
    return showSecondary ? 1 : 0;
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    if (!_gestureEnabled) {
      return;
    }
    _controller.stop();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _dragging = true;
      _dismissInProgress = false;
    });
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_dragging || _dismissInProgress) {
      return;
    }
    final width = context.size?.width ?? 0;
    if (width <= 0) {
      return;
    }
    final delta = details.primaryDelta ?? details.delta.dx;
    _controller.value = (_controller.value - (delta / width)).clamp(0.0, 1.0);
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (!_dragging || _dismissInProgress) {
      return;
    }
    final velocity =
        details.primaryVelocity ?? details.velocity.pixelsPerSecond.dx;
    final draggedProgress = 1 - _controller.value;
    if (draggedProgress >= _dismissProgressThreshold ||
        velocity >= _dismissVelocityThreshold) {
      unawaited(_completeDismiss());
      return;
    }
    setState(() {
      _dragging = false;
    });
    unawaited(_animateTo(1, useMinimumBaseDuration: true));
  }

  void _handleHorizontalDragCancel() {
    if (!_dragging || _dismissInProgress) {
      return;
    }
    setState(() {
      _dragging = false;
    });
    unawaited(_animateTo(1, useMinimumBaseDuration: true));
  }

  Future<void> _completeDismiss() async {
    setState(() {
      _dismissInProgress = true;
      _dragging = false;
    });
    await _animateTo(0, useMinimumBaseDuration: true);
    if (!mounted) {
      return;
    }
    final dismissed = await widget.onCompactSecondaryDismiss?.call() ?? false;
    if (!mounted) {
      return;
    }
    if (!dismissed) {
      setState(() {
        _dismissInProgress = false;
      });
      await _animateTo(1, useMinimumBaseDuration: true);
      return;
    }
    setState(() {
      _dismissInProgress = false;
    });
  }

  Future<void> _animateTo(
    double value, {
    bool useMinimumBaseDuration = false,
  }) async {
    if (_controller.value == value) {
      return;
    }
    final duration = useMinimumBaseDuration
        ? axiAtLeastBaseAnimationDuration(widget.duration)
        : widget.duration;
    if (duration == Duration.zero) {
      _controller.value = value;
      return;
    }
    await _controller.animateTo(
      value,
      duration: duration,
      curve: AxiAdaptiveLayout._compactSlideCurve,
    );
  }
}

class AxiAdaptivePane extends StatelessWidget {
  const AxiAdaptivePane({
    super.key,
    required this.alignment,
    required this.padding,
    required this.child,
  });

  final Alignment alignment;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Align(alignment: alignment, child: child),
    );
  }
}
