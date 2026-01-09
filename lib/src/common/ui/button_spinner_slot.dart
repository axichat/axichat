// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

class ButtonSpinnerSlot extends StatelessWidget {
  const ButtonSpinnerSlot({
    super.key,
    required this.isVisible,
    required this.spinner,
    required this.slotSize,
    required this.gap,
    required this.duration,
    this.curve = Curves.easeInOut,
  });

  final bool isVisible;
  final Widget spinner;
  final double slotSize;
  final double gap;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: duration,
          curve: curve,
          width: isVisible ? slotSize : 0,
          height: isVisible ? slotSize : 0,
          child: isVisible ? spinner : null,
        ),
        AnimatedContainer(
          duration: duration,
          curve: curve,
          width: isVisible ? gap : 0,
        ),
      ],
    );
  }
}
