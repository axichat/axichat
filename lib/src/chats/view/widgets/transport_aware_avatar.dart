// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

class TransportAwareAvatar extends StatelessWidget {
  const TransportAwareAvatar({
    super.key,
    required this.chat,
    this.size = 46.0,
    this.badgeOffset = const Offset(-6, -4),
    this.showBadge = true,
    this.presence,
    this.status,
    this.subscription,
  });

  final Chat chat;
  final double size;
  final Offset badgeOffset;
  final bool showBadge;
  final Presence? presence;
  final String? status;
  final Subscription? subscription;

  @override
  Widget build(BuildContext context) {
    ProfileState? profile;
    try {
      profile = context.watch<ProfileCubit?>()?.state;
    } on Exception {
      profile = null;
    }
    EmailService? emailService;
    try {
      emailService = RepositoryProvider.of<EmailService>(
        context,
        listen: false,
      );
    } on Exception {
      emailService = null;
    }
    XmppService? xmppService;
    try {
      xmppService = RepositoryProvider.of<XmppService>(
        context,
        listen: false,
      );
    } on Exception {
      xmppService = null;
    }
    final String? normalizedChatJid = _normalizeBareJid(chat.remoteJid);
    final resolvedProfileJid = profile?.jid.trim();
    final String? selfXmppJid = resolvedProfileJid?.isNotEmpty == true
        ? resolvedProfileJid
        : xmppService?.myJid;
    final String? normalizedXmppSelfJid = _normalizeBareJid(selfXmppJid);
    final String? normalizedEmailSelfJid =
        _normalizeBareJid(emailService?.selfSenderJid);
    final bool isSelfChat = normalizedChatJid != null &&
        ((normalizedXmppSelfJid != null &&
                normalizedChatJid == normalizedXmppSelfJid) ||
            (normalizedEmailSelfJid != null &&
                normalizedChatJid == normalizedEmailSelfJid));
    final String? selfAvatarPath = profile?.avatarPath?.trim();
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
          label: shouldLabelAll ? 'All' : null,
        );
      }
    }

    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AxiAvatar(
              jid: avatarIdentifier,
              shape: AxiAvatarShape.circle,
              size: size,
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
              right: badgeOffset.dx,
              bottom: badgeOffset.dy,
              child: badge,
            ),
        ],
      ),
    );
  }
}

String? _normalizeBareJid(String? jid) {
  final trimmed = jid?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  try {
    return mox.JID.fromString(trimmed).toBare().toString().toLowerCase();
  } on Exception {
    return trimmed.toLowerCase();
  }
}
