// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show LucideIcons;

const String _axichatAppIconAssetPath = 'assets/icons/app_icon_source.png';

ImageProvider<Object> axichatAppIconProvider(
  BuildContext context, {
  required double size,
}) {
  final baseSize = size < context.sizing.iconButtonTapTarget
      ? context.sizing.iconButtonTapTarget
      : size;
  final devicePixelRatio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
  final scaledSize = (baseSize * devicePixelRatio).ceil();
  final cacheExtent = scaledSize > 0 ? scaledSize : 1;
  return ResizeImage.resizeIfNeeded(
    cacheExtent,
    cacheExtent,
    const AssetImage(_axichatAppIconAssetPath),
  );
}

Future<void> precacheAxichatAppIcon(
  BuildContext context, {
  double? size,
}) async {
  final resolvedSize = size ?? context.sizing.iconButtonTapTarget;
  await precacheImage(
    axichatAppIconProvider(context, size: resolvedSize),
    context,
  );
}

class SelfIdentitySnapshot {
  const SelfIdentitySnapshot({
    required this.selfJid,
    required this.avatarPath,
    this.avatarLoading = false,
  });

  final String? selfJid;
  final String? avatarPath;
  final bool avatarLoading;
}

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
    final cutoutDepth = (badgeExtent / 2) + cutoutGap;
    final cutoutThickness = badgeExtent + (cutoutGap * 2);
    final cutoutCornerRadius = transport.isEmail
        ? context.radii.squircleSm
        : badgeExtent / 2;
    final cutoutInset = spacing.xxs;
    final cutoutAlignment = Alignment(1 - ((cutoutInset / size) * 2), 1);
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

class AxichatAppIconAvatar extends StatelessWidget {
  const AxichatAppIconAvatar({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final shape = SquircleBorder(cornerRadius: context.radii.squircle);
    final imageProvider = axichatAppIconProvider(context, size: size);
    return SizedBox.square(
      dimension: size,
      child: ClipPath(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        clipper: ShapeBorderClipper(shape: shape),
        child: Image(
          image: imageProvider,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
