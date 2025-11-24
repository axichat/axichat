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
    final paintShape = SquircleBorder(
      cornerRadius: 18,
      side: BorderSide(color: resolvedBorder),
    );
    final icon = Icon(
      iconData,
      size: context.iconTheme.size,
      color: resolvedForeground,
    );

    Widget tappable = SizedBox(
      width: kTapTargetSize,
      height: kTapTargetSize,
      child: Center(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.card,
            shape: paintShape,
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: paintShape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              customBorder: paintShape,
              splashFactory: InkRipple.splashFactory,
              child: SizedBox(
                width: kDefaultSize,
                height: kDefaultSize,
                child: Center(child: icon),
              ),
            ),
          ),
        ),
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
