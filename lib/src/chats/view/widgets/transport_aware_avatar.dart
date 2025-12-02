import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';

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
