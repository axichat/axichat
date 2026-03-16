// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show LucideIcons;

class AvatarTransportBadgeOverlay extends StatelessWidget {
  const AvatarTransportBadgeOverlay({
    super.key,
    required this.size,
    required this.transport,
    required this.child,
  });

  final double size;
  final MessageTransport transport;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final spacing = context.spacing;
    final cutoutShape = transport.isEmail
        ? CutoutShape.squircle
        : CutoutShape.circle;
    final badgeExtent = sizing.menuItemIconSize + spacing.xxs;
    final cutoutGap = spacing.xxs + (spacing.xxs / 2);
    final horizontalOffset = transport.isEmail ? -1.0 : -1.0;
    final verticalOffset = transport.isEmail ? -4.0 : 0.0;
    final cutoutDepth = (badgeExtent / 2) + cutoutGap - verticalOffset;
    final cutoutThickness = badgeExtent + (cutoutGap * 2);
    final cutoutCornerRadius = transport.isEmail
        ? context.radii.squircleSm
        : badgeExtent / 2;
    final cutoutInset = spacing.xxs;
    final cutoutAlignment = Alignment(
      (1 - ((cutoutInset / size) * 2)) + ((horizontalOffset / size) * 2),
      1,
    );
    return SizedBox.square(
      dimension: size,
      child: CutoutSurface(
        backgroundColor: Colors.transparent,
        borderColor: Colors.transparent,
        shape: SquircleBorder(cornerRadius: context.radii.squircle),
        cutouts: [
          CutoutSpec(
            edge: CutoutEdge.bottom,
            alignment: cutoutAlignment,
            depth: cutoutDepth,
            thickness: cutoutThickness,
            cornerRadius: cutoutCornerRadius,
            shape: cutoutShape,
            child: _AvatarTransportBadge(
              transport: transport,
              size: badgeExtent,
            ),
          ),
        ],
        child: child,
      ),
    );
  }
}

class _AvatarTransportBadge extends StatelessWidget {
  const _AvatarTransportBadge({required this.transport, required this.size});

  final MessageTransport transport;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final iconData = transport.isEmail
        ? LucideIcons.mail
        : LucideIcons.messageCircle;
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Icon(
          iconData,
          size: context.sizing.menuItemIconSize,
          color: colors.foreground,
        ),
      ),
    );
  }
}
