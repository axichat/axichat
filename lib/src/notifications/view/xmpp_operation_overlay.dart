// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/ui/settings_cubit_lookup.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp_activity/bloc/xmpp_activity_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const double _overlayHorizontalPadding = 16.0;
const double _overlayBottomPadding = 32.0;
const double _overlayMaxWidth = 320.0;
const double _overlayMaxHeight = 320.0;
const double _overlayVerticalPadding = 4.0;
const double _overlayItemSpacing = 8.0;
const double _toastShadowPadding = 6.0;
const double _toastBorderRadius = 12.0;
const double _toastShadowBlur = 12.0;
const double _toastShadowOffsetY = 8.0;
const double _toastOpacity = 0.92;
const double _toastShadowAlpha = 0.14;
const double _toastHorizontalPadding = 16.0;
const double _toastVerticalPadding = 12.0;
const double _iconTextSpacing = 12.0;
const double _progressIndicatorSize = 18.0;
const double _progressIndicatorStrokeWidth = 2.2;
const double _statusIconSize = 20.0;
const double _surfaceBackgroundAlpha = 0.12;
const Duration _entryFallbackDuration = Duration(milliseconds: 300);
const double _entryOpacityStart = 0.0;
const double _entryOpacityEnd = 1.0;
const double _entrySizeStart = 0.0;
const double _entrySizeEnd = 1.0;
const double _entrySlideXOffset = 0.22;
const double _entrySlideYOffset = 0.0;
const Curve _entryAnimationCurve = Curves.easeOutCubic;
const Duration _entryStaggerBaseDelay = Duration(milliseconds: 60);
const int _entryStaggerMaxIndex = 3;

const EdgeInsets _toastPadding = EdgeInsets.symmetric(
  horizontal: _toastHorizontalPadding,
  vertical: _toastVerticalPadding,
);
const EdgeInsets _overlayListPadding = EdgeInsets.symmetric(
  vertical: _overlayVerticalPadding,
);

class XmppOperationOverlay extends StatelessWidget {
  const XmppOperationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<XmppActivityCubit, XmppActivityState>(
      builder: (context, state) {
        final operations = state.operations;
        if (operations.isEmpty) {
          return const SizedBox.shrink();
        }
        final mediaQuery = MediaQuery.of(context);
        final viewPadding = mediaQuery.viewPadding;
        final bottomInset = mediaQuery.viewInsets.bottom;
        final safeBottomInset =
            bottomInset > viewPadding.bottom ? bottomInset : viewPadding.bottom;
        final leftPadding = _overlayHorizontalPadding + viewPadding.left;
        final rightPadding = _overlayHorizontalPadding + viewPadding.right;
        final SettingsCubit? settingsCubit = maybeSettingsCubit(context);
        final Duration entryDuration = settingsCubit == null
            ? _entryFallbackDuration
            : context.select<SettingsCubit, Duration>(
                (cubit) => cubit.animationDuration,
              );
        return IgnorePointer(
          ignoring: true,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.only(
                left: leftPadding,
                right: rightPadding,
                bottom: _overlayBottomPadding + safeBottomInset,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _overlayMaxWidth,
                  maxHeight: _overlayMaxHeight,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: _overlayListPadding,
                  clipBehavior: Clip.none,
                  itemCount: operations.length,
                  itemBuilder: (context, index) {
                    final operation = operations[index];
                    final distanceFromBottom = operations.length - 1 - index;
                    final staggerIndex =
                        distanceFromBottom > _entryStaggerMaxIndex
                            ? _entryStaggerMaxIndex
                            : distanceFromBottom;
                    final entryDelay = Duration(
                      milliseconds:
                          _entryStaggerBaseDelay.inMilliseconds * staggerIndex,
                    );
                    return XmppOperationToastEntry(
                      key: ValueKey(operation.id),
                      operation: operation,
                      entryDuration: entryDuration,
                      entryDelay: entryDelay,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class XmppOperationToastEntry extends StatelessWidget {
  const XmppOperationToastEntry({
    super.key,
    required this.operation,
    required this.entryDuration,
    required this.entryDelay,
  });

  final XmppOperation operation;
  final Duration entryDuration;
  final Duration entryDelay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: _overlayItemSpacing + _toastShadowPadding,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: XmppOperationEntryTransition(
          duration: entryDuration,
          delay: entryDelay,
          child: _XmppOperationToast(operation: operation),
        ),
      ),
    );
  }
}

class XmppOperationEntryTransition extends StatefulWidget {
  const XmppOperationEntryTransition({
    super.key,
    required this.duration,
    required this.delay,
    required this.child,
  });

  final Duration duration;
  final Duration delay;
  final Widget child;

  @override
  State<XmppOperationEntryTransition> createState() =>
      _XmppOperationEntryTransitionState();
}

class _XmppOperationEntryTransitionState
    extends State<XmppOperationEntryTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _sizeAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    final CurvedAnimation curve = CurvedAnimation(
      parent: _controller,
      curve: _entryAnimationCurve,
    );
    _fadeAnimation = Tween<double>(
      begin: _entryOpacityStart,
      end: _entryOpacityEnd,
    ).animate(curve);
    _sizeAnimation = Tween<double>(
      begin: _entrySizeStart,
      end: _entrySizeEnd,
    ).animate(curve);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(_entrySlideXOffset, _entrySlideYOffset),
      end: Offset.zero,
    ).animate(curve);
    _startAnimation();
  }

  void _startAnimation() {
    if (widget.duration == Duration.zero) {
      _controller.value = _entryOpacityEnd;
      return;
    }
    if (widget.delay == Duration.zero) {
      _controller.forward();
      return;
    }
    _delayTimer = Timer(widget.delay, () {
      if (!mounted) return;
      _controller.forward();
    });
  }

  @override
  void didUpdateWidget(covariant XmppOperationEntryTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.delay != widget.delay && _controller.isDismissed) {
      _delayTimer?.cancel();
      _startAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return Align(
          alignment: Alignment.bottomLeft,
          heightFactor: _sizeAnimation.value,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
}

class _XmppOperationToast extends StatelessWidget {
  const _XmppOperationToast({required this.operation});

  final XmppOperation operation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shadowColor = colorScheme.shadow.withValues(alpha: _toastShadowAlpha);
    final surfaceColor = switch (operation.status) {
      XmppOperationStatus.inProgress => colorScheme.surfaceContainerHigh,
      XmppOperationStatus.success => colorScheme.surfaceBright,
      XmppOperationStatus.failure => colorScheme.errorContainer,
    };
    final textColor = switch (operation.status) {
      XmppOperationStatus.failure => colorScheme.onErrorContainer,
      _ => colorScheme.onSurface,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: _toastOpacity),
        borderRadius: BorderRadius.circular(_toastBorderRadius),
        boxShadow: [
          BoxShadow(
            blurRadius: _toastShadowBlur,
            offset: const Offset(0, _toastShadowOffsetY),
            color: shadowColor,
          ),
        ],
      ),
      child: Padding(
        padding: _toastPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OperationStatusIcon(status: operation.status),
            const SizedBox(width: _iconTextSpacing),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    operation.statusLabel(),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: textColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationStatusIcon extends StatelessWidget {
  const _OperationStatusIcon({required this.status});

  final XmppOperationStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (status) {
      XmppOperationStatus.inProgress => SizedBox(
          height: _progressIndicatorSize,
          width: _progressIndicatorSize,
          child: CircularProgressIndicator(
            strokeWidth: _progressIndicatorStrokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            backgroundColor: colorScheme.onSurface
                .withValues(alpha: _surfaceBackgroundAlpha),
          ),
        ),
      XmppOperationStatus.success => Icon(
          Icons.check_circle_rounded,
          size: _statusIconSize,
          color: colorScheme.primary,
        ),
      XmppOperationStatus.failure => Icon(
          Icons.error_rounded,
          size: _statusIconSize,
          color: colorScheme.onErrorContainer,
        ),
    };
  }
}
