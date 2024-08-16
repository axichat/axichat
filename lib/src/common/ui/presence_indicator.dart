import 'package:chat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PresenceIndicator extends StatelessWidget {
  const PresenceIndicator({
    super.key,
    required this.presence,
    this.status,
  });

  final Presence presence;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return PresenceCircle(presence: presence);
  }
}

class PresenceCircle extends StatelessWidget {
  const PresenceCircle({super.key, required this.presence});

  final Presence presence;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14.0,
      width: 14.0,
      decoration: ShapeDecoration(
        shape: CircleBorder(
          side: BorderSide(
            color: Color.lerp(presence.toColor, Colors.white, 0.6)!,
            width: 1.0,
          ),
        ),
        color: presence.toColor,
      ),
      child: presence.isDnd
          ? const Icon(
              LucideIcons.minus,
              color: Colors.white,
              size: 10.0,
            )
          : null,
    );
  }
}
