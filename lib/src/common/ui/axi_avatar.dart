import 'package:chat/src/common/ui/presence_indicator.dart';
import 'package:chat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:moxxmpp_color/moxxmpp_color.dart';

class AxiAvatar extends CircleAvatar {
  const AxiAvatar({
    super.key,
    required this.jid,
    this.presence,
    this.status,
    this.active = false,
  });

  final String jid;
  final Presence? presence;
  final String? status;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 50.0,
        maxWidth: 50.0,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircleAvatar(
            backgroundColor: consistentColorSync(jid),
            child: Text(jid.substring(0, 1).toUpperCase()),
          ),
          presence == null
              ? const SizedBox()
              : Align(
                  alignment: Alignment.bottomRight,
                  child: PresenceIndicator(
                    presence: presence!,
                    status: status,
                    active: active,
                  ),
                ),
        ],
      ),
    );
  }
}
