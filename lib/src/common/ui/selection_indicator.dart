import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SelectionIndicator extends StatelessWidget {
  const SelectionIndicator({
    super.key,
    required this.visible,
    required this.selected,
  });

  final bool visible;
  final bool selected;

  static const _size = 22.0;
  static const _animationDuration = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final iconColor =
        selected ? colors.primaryForeground : colors.mutedForeground;
    final background =
        selected ? colors.primary : colors.card.withValues(alpha: 0.92);
    final borderColor =
        selected ? colors.primary : colors.border.withValues(alpha: 0.8);

    return AnimatedOpacity(
      duration: _animationDuration,
      opacity: visible ? 1 : 0,
      child: AnimatedScale(
        duration: _animationDuration,
        scale: visible ? 1 : 0.9,
        curve: Curves.easeInOut,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: background,
            border: Border.all(color: borderColor),
          ),
          child: SizedBox(
            width: _size,
            height: _size,
            child: Icon(
              selected ? LucideIcons.check : LucideIcons.circle,
              size: selected ? 14 : 12,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
