// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';

class AxiTooltip extends StatefulWidget {
  const AxiTooltip({super.key, required this.builder, required this.child});

  final WidgetBuilder builder;
  final Widget child;

  @override
  State<AxiTooltip> createState() => _AxiTooltipState();
}

class _AxiTooltipState extends State<AxiTooltip> {
  final GlobalKey _childKey = GlobalKey();
  double _targetHeight = 0.0;

  @override
  void initState() {
    super.initState();
    _scheduleSizeUpdate();
  }

  @override
  void didUpdateWidget(covariant AxiTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleSizeUpdate();
  }

  void _scheduleSizeUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSize());
  }

  void _updateSize() {
    final BuildContext? context = _childKey.currentContext;
    final RenderObject? renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }
    const double minDelta = 0.5;
    final double nextHeight = renderObject.size.height;
    if ((nextHeight - _targetHeight).abs() < minDelta) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _targetHeight = nextHeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: context.spacing.s,
      vertical: context.spacing.xs,
    );
    final double fallbackHeight = context.sizing.iconButtonTapTarget;
    final double resolvedHeight =
        _targetHeight > 0 ? _targetHeight : fallbackHeight;
    final double verticalOffset = (resolvedHeight / 2) + context.spacing.xxs;
    final content = widget.builder(context);
    final colors = context.colorScheme;
    final radius = context.radius;
    final textStyle = content is Text && content.style != null
        ? content.style!
        : context.textTheme.muted;
    final plainText = _plainText(content);
    final bool hasPlainText = plainText != null;
    return Tooltip(
      richMessage: hasPlainText ? null : _richSpan(content, textStyle),
      message: hasPlainText ? plainText : null,
      preferBelow: true,
      verticalOffset: verticalOffset,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.popover,
        borderRadius: radius,
        border: Border.all(color: colors.border),
      ),
      textStyle: textStyle,
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (notification) {
          _scheduleSizeUpdate();
          return false;
        },
        child: SizeChangedLayoutNotifier(
          child: KeyedSubtree(
            key: _childKey,
            child: widget.child,
          ),
        ),
      ),
    );
  }

  InlineSpan _richSpan(Widget content, TextStyle fallbackStyle) {
    if (content is Text) {
      if (content.textSpan != null) {
        return content.textSpan!;
      }
      return TextSpan(
        text: content.data ?? '',
        style: content.style ?? fallbackStyle,
      );
    }
    if (content is RichText) {
      return content.text;
    }
    return WidgetSpan(child: content);
  }

  String? _plainText(Widget content) {
    if (content is Text) {
      return content.data ?? content.textSpan?.toPlainText();
    }
    if (content is RichText) {
      return content.text.toPlainText();
    }
    return null;
  }
}
