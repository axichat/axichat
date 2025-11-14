import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class AxiIconButton extends StatelessWidget {
  static const double kDefaultSize = 36.0;
  static const double kTapTargetSize = 48.0;

  const AxiIconButton({
    super.key,
    required this.iconData,
    this.onPressed,
    this.tooltip,
    this.color,
    this.borderColor,
  });

  final IconData iconData;
  final void Function()? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final Color resolvedForeground = color ?? colors.foreground;
    final Color resolvedBorder = borderColor ?? colors.border;

    final decoration = ShapeDecoration(
      color: colors.card,
      shape: SquircleBorder(
        cornerRadius: 18,
        side: BorderSide(color: resolvedBorder),
      ),
    );

    Widget visual = Container(
      width: kDefaultSize,
      height: kDefaultSize,
      decoration: decoration,
      alignment: Alignment.center,
      child: Icon(
        iconData,
        size: context.iconTheme.size,
        color: resolvedForeground,
      ),
    );

    visual = SizedBox(
      width: kTapTargetSize,
      height: kTapTargetSize,
      child: Center(child: visual),
    );

    Widget tappable = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        customBorder: SquircleBorder(cornerRadius: 24),
        child: visual,
      ),
    ).withTapBounce(enabled: onPressed != null);

    if (tooltip != null) {
      tappable = AxiTooltip(
        builder: (context) => Text(
          tooltip!,
          style: context.textTheme.muted,
        ),
        child: tappable,
      );
    }

    return tappable;
  }
}
