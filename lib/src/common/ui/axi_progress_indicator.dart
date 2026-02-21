// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';

class AxiProgressIndicator extends StatelessWidget {
  const AxiProgressIndicator({super.key, this.color, this.semanticsLabel});

  final Color? color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.spacing.xxs),
      child: SizedBox.square(
        dimension: context.sizing.progressIndicatorSize,
        child: CircularProgressIndicator(
          color: color ?? context.colorScheme.foreground,
          semanticsLabel: semanticsLabel,
          strokeWidth: context.sizing.progressIndicatorStrokeWidth,
        ),
      ),
    );
  }
}
