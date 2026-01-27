// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class AxiFab extends StatelessWidget {
  const AxiFab({
    super.key,
    required this.text,
    required this.iconData,
    this.onPressed,
    this.tooltip,
  });

  final String text;
  final IconData iconData;
  final void Function()? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget button = AxiButton.primary(
      onPressed: onPressed,
      leading: Icon(iconData),
      child: Text(text),
    );

    if (tooltip != null) {
      button = AxiTooltip(builder: (_) => Text(tooltip!), child: button);
    }

    return button;
  }
}
