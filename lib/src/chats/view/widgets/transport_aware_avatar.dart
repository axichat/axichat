// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';

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

class TransportAwareAvatar extends StatelessWidget {
  const TransportAwareAvatar({
    super.key,
    required this.chat,
    required this.selfIdentity,
    this.size,
    this.badgeOffset,
    this.showBadge = true,
    this.presence,
    this.status,
    this.subscription,
    this.avatarPathOverride,
  });

  final Chat chat;
  final SelfIdentitySnapshot selfIdentity;
  final double? size;
  final Offset? badgeOffset;
  final bool showBadge;
  final Presence? presence;
  final String? status;
  final Subscription? subscription;
  final String? avatarPathOverride;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final spacing = context.spacing;
    final resolvedSize = size ?? sizing.iconButtonTapTarget;
    final resolvedBadgeOffset = badgeOffset ?? Offset(-spacing.s, -spacing.xs);
    final String? selfJid = selfIdentity.selfJid?.trim();
    final bool isSelfChat = chat.remoteJid.sameBare(selfJid);
    final String? selfAvatarPath = selfIdentity.avatarPath?.trim();
    final bool selfAvatarLoading = selfIdentity.avatarLoading;
    final bool hasSelfAvatarPath = selfAvatarPath?.isNotEmpty == true;
    final isWelcomeChat = chat.isAxichatWelcomeThread;
    final avatarLabel = chat.contactDisplayName?.trim().isNotEmpty == true
        ? chat.contactDisplayName!.trim()
        : chat.title.trim().isNotEmpty
        ? chat.title.trim()
        : chat.avatarIdentifier;
    final supportsEmail = chat.transport.isEmail;
    final isAxiCompatible = chat.isAxiContact;
    final shouldLabelAll = !supportsEmail && isAxiCompatible;
    final Subscription effectiveSubscription =
        subscription ??
        (isAxiCompatible ? Subscription.both : Subscription.none);
    Widget? badge;
    if (showBadge && !isWelcomeChat) {
      if (supportsEmail && isAxiCompatible) {
        badge = const AxiCompatibilityBadge(compact: true);
      } else if (supportsEmail) {
        badge = const AxiTransportChip(
          transport: MessageTransport.email,
          compact: true,
        );
      } else {
        badge = AxiTransportChip(
          transport: MessageTransport.xmpp,
          compact: true,
          label: shouldLabelAll ? context.l10n.commonAll : null,
        );
      }
    }

    return SizedBox.square(
      dimension: resolvedSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: isWelcomeChat
                ? AxichatAppIconAvatar(size: resolvedSize)
                : AxiAvatar(
                    jid: avatarLabel,
                    colorSeed: chat.avatarColorSeed,
                    size: resolvedSize,
                    presence: presence,
                    status: status,
                    subscription: effectiveSubscription,
                    loading: isSelfChat && selfAvatarLoading,
                    avatarPath: avatarPathOverride?.trim().isNotEmpty == true
                        ? avatarPathOverride!.trim()
                        : isSelfChat && hasSelfAvatarPath
                        ? selfAvatarPath
                        : chat.avatarPath ?? chat.contactAvatarPath,
                  ),
          ),
          if (badge != null)
            Positioned(
              right: resolvedBadgeOffset.dx,
              bottom: resolvedBadgeOffset.dy,
              child: badge,
            ),
        ],
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
