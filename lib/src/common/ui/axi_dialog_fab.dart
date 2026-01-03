// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'ui.dart';

class AxiDialogFab extends StatelessWidget {
  const AxiDialogFab({
    super.key,
    required this.tooltip,
    required this.iconData,
    required this.label,
    required this.dialogBuilder,
  });

  final String tooltip;
  final IconData iconData;
  final String label;
  final WidgetBuilder dialogBuilder;

  @override
  Widget build(BuildContext context) {
    return AxiFab(
      tooltip: tooltip,
      iconData: iconData,
      text: label,
      onPressed: () => showShadDialog(
        context: context,
        builder: dialogBuilder,
      ),
    );
  }
}
