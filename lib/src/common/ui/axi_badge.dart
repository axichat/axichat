import 'package:flutter/material.dart';
import 'package:axichat/src/app.dart';

class AxiBadge extends StatelessWidget {
  const AxiBadge({
    super.key,
    required this.count,
    this.offset,
    required this.child,
  });

  final int count;
  final Offset? offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    final colors = context.colorScheme;
    final text = count > 99 ? '99+' : '$count';
    final resolvedOffset = offset ?? const Offset(10, -6);
    final badge = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colors.background,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: context.textTheme.small.copyWith(
            color: colors.primaryForeground,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: resolvedOffset.dy,
          right: resolvedOffset.dx,
          child: badge,
        ),
      ],
    );
  }
}
