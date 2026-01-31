// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show LucideIcons;

class TransportGlyph extends StatelessWidget {
  const TransportGlyph({super.key, required this.transport});

  final MessageTransport transport;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final sizing = context.sizing;
    final background = transport.isEmail ? colors.destructive : colors.primary;
    final foreground = transport.isEmail
        ? colors.destructiveForeground
        : colors.primaryForeground;
    final icon =
        transport.isEmail ? LucideIcons.mail : LucideIcons.messageCircle;
    return Container(
      width: sizing.iconButtonIconSize,
      height: sizing.iconButtonIconSize,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(
          color: context.borderSide.color,
          width: context.borderSide.width,
        ),
      ),
      child: Icon(icon, size: sizing.menuItemIconSize, color: foreground),
    );
  }
}
