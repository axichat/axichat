// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/context_action_button.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatExportActionButton extends StatelessWidget {
  const ChatExportActionButton({
    super.key,
    required this.exporting,
    required this.onPressed,
    required this.readyLabel,
    this.progressLabel,
    this.iconSize,
  });

  final bool exporting;
  final VoidCallback? onPressed;
  final String readyLabel;
  final String? progressLabel;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final resolvedIconSize = iconSize ?? context.sizing.menuItemIconSize;
    final label = exporting ? (progressLabel ?? readyLabel) : readyLabel;
    final progressIndicator = SizedBox.square(
      dimension: resolvedIconSize,
      child: const Center(child: AxiProgressIndicator()),
    );
    return ContextActionButton(
      icon: exporting
          ? progressIndicator
          : Icon(LucideIcons.share2, size: resolvedIconSize),
      label: label,
      onPressed: exporting ? null : onPressed,
    );
  }
}
