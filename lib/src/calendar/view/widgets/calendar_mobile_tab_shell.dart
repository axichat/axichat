import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Shared container used by both the authenticated and guest calendar mobile
/// layouts. Handles painting the background/border shell around the draggable
/// TabBar + cancel bucket so they stay visually consistent.
class CalendarMobileTabShell extends StatelessWidget {
  const CalendarMobileTabShell({
    super.key,
    required this.tabBar,
    required this.cancelBucket,
    this.backgroundColor,
    this.borderColor,
    this.dividerColor,
    this.showTopBorder = true,
    this.showDivider = false,
  });

  final Widget tabBar;
  final Widget cancelBucket;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? dividerColor;
  final bool showTopBorder;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final Color effectiveBackground = backgroundColor ?? colors.background;
    final Color effectiveBorder = borderColor ?? colors.border;
    final Color effectiveDivider = dividerColor ?? effectiveBorder;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveBackground,
        border: showTopBorder
            ? Border(
                top: BorderSide(color: effectiveBorder, width: 1),
              )
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDivider)
            Divider(
              height: 1,
              thickness: 1,
              color: effectiveDivider,
            ),
          tabBar,
          cancelBucket,
        ],
      ),
    );
  }
}

/// Animated "Tasks" Tab label with pulsing badge. Used by both calendar
/// surfaces to highlight when attention is required on the tasks tab.
class TasksTabLabel extends StatelessWidget {
  const TasksTabLabel({
    super.key,
    this.highlight = false,
    this.animation,
    this.text = 'Tasks',
    this.baseColor,
    this.textStyle,
  });

  final bool highlight;
  final Animation<double>? animation;
  final String text;
  final Color? baseColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    if (!highlight || animation == null) {
      return Text(
        text,
        style: textStyle ?? const TextStyle(fontWeight: FontWeight.w600),
      );
    }

    return AnimatedBuilder(
      animation: animation!,
      builder: (context, _) {
        final double t = animation!.value;
        final double scale = 0.85 + (0.25 * t);
        final Color primary =
            baseColor ?? ShadTheme.of(context).colorScheme.primary;
        final Color badgeColor = Color.lerp(
          primary.withValues(alpha: 0.55),
          primary,
          t,
        )!;
        final bool isRtl = Directionality.of(context) == TextDirection.rtl;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                text,
                style:
                    textStyle ?? const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Positioned(
              top: -6,
              right: isRtl ? null : -14,
              left: isRtl ? -14 : null,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        badgeColor.withValues(alpha: 0.9),
                        badgeColor,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withValues(alpha: 0.45),
                        blurRadius: 8 + (4 * t),
                        spreadRadius: 1.5 + t,
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.25 + (0.15 * t)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
