import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:flutter/material.dart';

class AxiTransportChip extends StatelessWidget {
  const AxiTransportChip({
    super.key,
    required this.transport,
    this.compact = false,
  });

  final MessageTransport transport;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final isEmail = transport.isEmail;
    final background = isEmail ? colors.destructive : colors.primary;
    final foreground =
        isEmail ? colors.destructiveForeground : colors.primaryForeground;
    final borderColor = colors.background;

    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
    final borderRadius = compact ? 10.0 : 12.0;
    final borderWidth = compact ? 1.5 : 2.0;
    final fontSize = compact ? 9.0 : 10.0;

    return Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: background,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(color: borderColor, width: borderWidth),
        ),
      ),
      child: Text(
        transport.label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: context.textTheme.small.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: foreground,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
