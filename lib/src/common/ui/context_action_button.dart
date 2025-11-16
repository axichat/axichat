import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/axi_tap_bounce.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ContextActionButton extends StatelessWidget {
  const ContextActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.destructive = false,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final destructiveColor =
        destructive ? context.colorScheme.destructive : null;
    final textStyle = destructive
        ? context.textTheme.small.copyWith(color: destructiveColor)
        : null;
    final textScaler = MediaQuery.of(context).textScaler;
    double scaled(double value) => textScaler.scale(value);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: ShadButton.outline(
        onPressed: onPressed,
        child: IconTheme.merge(
          data: IconThemeData(color: destructiveColor),
          child: DefaultTextStyle.merge(
            style: textStyle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                icon,
                SizedBox(width: scaled(6)),
                Flexible(
                  child: Text(
                    label,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ).withTapBounce(enabled: onPressed != null),
    );
  }
}
