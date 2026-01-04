// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/in_bounds_fade_scale.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _tooltipVerticalOffset = 12;
const EdgeInsets _tooltipPadding =
    EdgeInsets.symmetric(horizontal: 12, vertical: 8);

class AxiTooltip extends StatelessWidget {
  const AxiTooltip({
    super.key,
    required this.builder,
    required this.child,
  });

  final WidgetBuilder builder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = builder(context);
    final colors = context.colorScheme;
    final radius = context.radius;
    final textStyle = content is Text && content.style != null
        ? content.style!
        : context.textTheme.muted;
    final decoration = ShadDecoration(
      color: colors.popover,
      border: ShadBorder.all(
        color: colors.border,
        radius: radius,
      ),
    );
    return ShadTooltip(
      anchor: const ShadAnchorAuto(
        offset: Offset(0, _tooltipVerticalOffset),
        followerAnchor: Alignment.topCenter,
        targetAnchor: Alignment.bottomCenter,
      ),
      effects: const [],
      padding: _tooltipPadding,
      decoration: decoration,
      builder: (context) => InBoundsFadeScale(
        child: DefaultTextStyle.merge(
          style: textStyle,
          child: content,
        ),
      ),
      child: child,
    );
  }
}
