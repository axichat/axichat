// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransportAwareAvatar extends StatelessWidget {
  const TransportAwareAvatar({
    super.key,
    required this.chat,
    this.size,
    this.badgeOffset,
    this.showBadge = true,
    this.presence,
    this.status,
    this.subscription,
  });

  final Chat chat;
  final double? size;
  final Offset? badgeOffset;
  final bool showBadge;
  final Presence? presence;
  final String? status;
  final Subscription? subscription;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileCubit>().state;
    final emailService = context.watch<EmailService>();
    final xmppService = context.watch<XmppService>();
    final sizing = context.sizing;
    final spacing = context.spacing;
    final resolvedSize = size ?? sizing.iconButtonTapTarget;
    final resolvedBadgeOffset = badgeOffset ?? Offset(-spacing.s, -spacing.xs);
    final resolvedProfileJid = profile.jid.trim();
    final String? selfXmppJid =
        resolvedProfileJid.isNotEmpty ? resolvedProfileJid : xmppService.myJid;
    final String? selfEmailJid = emailService.selfSenderJid;
    final bool isSelfChat = chat.remoteJid.sameBare(selfXmppJid) ||
        chat.remoteJid.sameBare(selfEmailJid);
    final String? selfAvatarPath = profile.avatarPath?.trim();
    final bool hasSelfAvatarPath = selfAvatarPath?.isNotEmpty == true;
    final avatarIdentifier = chat.contactDisplayName?.trim().isNotEmpty == true
        ? chat.contactDisplayName!.trim()
        : chat.title.trim().isNotEmpty
            ? chat.title.trim()
            : chat.avatarIdentifier;
    final supportsEmail = chat.transport.isEmail;
    final isAxiCompatible = chat.isAxiContact;
    final shouldLabelAll = !supportsEmail && isAxiCompatible;
    final Subscription effectiveSubscription = subscription ??
        (isAxiCompatible ? Subscription.both : Subscription.none);
    Widget? badge;
    if (showBadge) {
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
            child: AxiAvatar(
              jid: avatarIdentifier,
              size: resolvedSize,
              presence: presence,
              status: status,
              subscription: effectiveSubscription,
              avatarPath: isSelfChat && hasSelfAvatarPath
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
