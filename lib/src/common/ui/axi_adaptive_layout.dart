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
    this.onCompactSecondaryDismiss,
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
  final VoidCallback? onCompactSecondaryDismiss;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool allowSplitView = constraints.maxWidth >= smallScreen;

        if (!showPrimary && !showSecondary) {
          return const SizedBox.shrink();
        }

        if (!allowSplitView) {
          return ConstrainedBox(
            constraints: constraints,
            child: _CompactPaneTransition(
              primaryChild: primaryChild,
              secondaryChild: secondaryChild,
              showPrimary: showPrimary,
              showSecondary: showSecondary,
              invertPriority: invertPriority,
              duration: context.watch<SettingsCubit>().animationDuration,
              onCompactSecondaryDismiss: onCompactSecondaryDismiss,
            ),
          );
        }

        final bool showSecondaryDivider = showPrimary && showSecondary;
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
        if (!animatePaneChanges) {
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
        final int resolvedPrimaryFlex = showPrimary ? primaryFlex : 0;
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
        return ConstrainedBox(
          constraints: constraints,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: animationDuration,
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
                duration: animationDuration,
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
        );
      },
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
  final VoidCallback? onCompactSecondaryDismiss;

  @override
  State<_CompactPaneTransition> createState() => _CompactPaneTransitionState();
}

class _CompactPaneTransitionState extends State<_CompactPaneTransition>
    with SingleTickerProviderStateMixin {
  static const double _primaryParallaxFraction = 1 / 3;
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
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void didUpdateWidget(covariant _CompactPaneTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
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
            _controller.isAnimating ||
            (_controller.value > 0 && _controller.value < 1);
        final content = moving
            ? _SlidingCompactPane(
                value: _controller.value,
                primaryChild: widget.primaryChild,
                secondaryChild: widget.secondaryChild,
                cupertinoStyle: defaultTargetPlatform == TargetPlatform.iOS,
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
    unawaited(_animateTo(1));
  }

  void _handleHorizontalDragCancel() {
    if (!_dragging || _dismissInProgress) {
      return;
    }
    setState(() {
      _dragging = false;
    });
    unawaited(_animateTo(1));
  }

  Future<void> _completeDismiss() async {
    setState(() {
      _dismissInProgress = true;
      _dragging = false;
    });
    await _animateTo(0);
    if (!mounted) {
      return;
    }
    _dismissInProgress = false;
    widget.onCompactSecondaryDismiss?.call();
  }

  Future<void> _animateTo(double value) async {
    if (_controller.value == value) {
      return;
    }
    if (widget.duration == Duration.zero) {
      _controller.value = value;
      return;
    }
    await _controller.animateTo(
      value,
      duration: widget.duration,
      curve: AxiAdaptiveLayout._compactSlideCurve,
    );
  }
}

class _SlidingCompactPane extends StatelessWidget {
  const _SlidingCompactPane({
    required this.value,
    required this.primaryChild,
    required this.secondaryChild,
    required this.cupertinoStyle,
  });

  final double value;
  final Widget primaryChild;
  final Widget secondaryChild;
  final bool cupertinoStyle;

  @override
  Widget build(BuildContext context) {
    final barrierColor = context.dialogBarrierColor;
    final scrimAlpha = cupertinoStyle
        ? (barrierColor.a *
                  context.motion.compactPaneSwipeScrimOpacityFactor *
                  value)
              .clamp(0.0, 1.0)
        : 0.0;
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            fit: StackFit.expand,
            children: [
              Transform.translate(
                offset: Offset(
                  cupertinoStyle
                      ? -width *
                            value *
                            _CompactPaneTransitionState._primaryParallaxFraction
                      : 0,
                  0,
                ),
                child: Center(child: primaryChild),
              ),
              if (scrimAlpha > 0)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: barrierColor.withValues(alpha: scrimAlpha),
                  ),
                ),
              Transform.translate(
                offset: Offset(width * (1 - value), 0),
                child: Center(child: secondaryChild),
              ),
            ],
          );
        },
      ),
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
