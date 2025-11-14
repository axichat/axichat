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
    final background = transport.isEmail ? colors.destructive : colors.primary;
    final foreground = transport.isEmail
        ? colors.destructiveForeground
        : colors.primaryForeground;
    final icon =
        transport.isEmail ? LucideIcons.mail : LucideIcons.messageCircle;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: colors.background, width: 2),
      ),
      child: Icon(icon, size: 10, color: foreground),
    );
  }
}
