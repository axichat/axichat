import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class AxiIconButton extends StatelessWidget {
  static const double kDefaultSize = 36.0;
  static const double kTapTargetSize = 48.0;

  const AxiIconButton({
    super.key,
    required this.iconData,
    this.onPressed,
    this.onLongPress,
    this.tooltip,
    this.semanticLabel,
    this.color,
    this.backgroundColor,
    this.borderColor,
    this.iconSize,
    this.buttonSize,
    this.tapTargetSize,
    this.cornerRadius,
    this.borderWidth,
  });

  final IconData iconData;
  final void Function()? onPressed;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final String? semanticLabel;
  final Color? color;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? iconSize;
  final double? buttonSize;
  final double? tapTargetSize;
  final double? cornerRadius;
  final double? borderWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final env = EnvScope.maybeOf(context);
    final isDesktop = env?.isDesktopPlatform ?? false;
    final Color resolvedForeground = color ?? colors.foreground;
    final Color resolvedBorder = borderColor ?? colors.border;
    final Color resolvedBackground = backgroundColor ?? colors.card;
    final bool enabled = onPressed != null || onLongPress != null;
    final double resolvedIconSize =
        iconSize ?? (context.iconTheme.size ?? kDefaultSize * 0.6);
    final double resolvedButtonSize = buttonSize ?? kDefaultSize;
    final double resolvedTapTargetSize = tapTargetSize ?? kTapTargetSize;
    final double resolvedCornerRadius = cornerRadius ?? 18;
    final double resolvedBorderWidth = borderWidth ?? 1.0;
    final paintShape = SquircleBorder(
      cornerRadius: resolvedCornerRadius,
      side: BorderSide(
        color: resolvedBorder,
        width: resolvedBorderWidth,
      ),
    );
    final icon = Icon(
      iconData,
      size: resolvedIconSize,
      color: resolvedForeground,
    );

    Widget tappable = SizedBox(
      width: resolvedTapTargetSize,
      height: resolvedTapTargetSize,
      child: Center(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: resolvedBackground,
            shape: paintShape,
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: paintShape,
            clipBehavior: Clip.antiAlias,
            child: InkResponse(
              onTap: onPressed,
              onLongPress: onLongPress,
              containedInkWell: true,
              highlightShape: BoxShape.rectangle,
              customBorder: paintShape,
              splashFactory:
                  isDesktop ? NoSplash.splashFactory : InkRipple.splashFactory,
              splashColor: !enabled || isDesktop
                  ? Colors.transparent
                  : colors.primary.withValues(alpha: 0.18),
              hoverColor: enabled
                  ? colors.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              highlightColor: Colors.transparent,
              focusColor: Colors.transparent,
              child: SizedBox(
                width: resolvedButtonSize,
                height: resolvedButtonSize,
                child: Center(child: icon),
              ),
            ),
          ),
        ),
      ),
    ).withTapBounce(enabled: enabled);

    if (tooltip != null) {
      tappable = AxiTooltip(
        builder: (context) => Text(
          tooltip!,
          style: context.textTheme.muted,
        ),
        child: tappable,
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? tooltip,
      onTap: onPressed,
      onLongPress: onLongPress,
      child: tappable,
    );
  }
}
