// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/common/ui/context_action_button.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatExportActionButton extends StatelessWidget {
  const ChatExportActionButton({
    super.key,
    required this.exporting,
    required this.onPressed,
    this.iconSize = 16,
    this.readyLabel = 'Export',
    this.progressLabel = 'Exporting...',
  });

  final bool exporting;
  final VoidCallback? onPressed;
  final double iconSize;
  final String readyLabel;
  final String progressLabel;

  @override
  Widget build(BuildContext context) {
    final progressIndicator = SizedBox(
      width: iconSize,
      height: iconSize,
      child: CircularProgressIndicator(
        strokeWidth: math.max(2, iconSize * 0.12),
      ),
    );
    return ContextActionButton(
      icon: exporting
          ? progressIndicator
          : Icon(LucideIcons.share2, size: iconSize),
      label: exporting ? progressLabel : readyLabel,
      onPressed: exporting ? null : onPressed,
    );
  }
}
