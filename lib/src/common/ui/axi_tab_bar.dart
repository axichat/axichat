// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

/// Shared tab bar used across Axichat surfaces so styling stays consistent.
class AxiTabBar extends StatelessWidget {
  const AxiTabBar({
    super.key,
    required this.tabs,
    this.badges = const <int>[],
    this.badgeOffset,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.minTabWidth = 90,
    this.isScrollableOverride,
    this.tabAlignmentOverride,
    this.indicatorColor,
    this.labelColor,
    this.unselectedLabelColor,
    this.indicatorWeight,
    this.indicatorSize = TabBarIndicatorSize.label,
  });

  final List<Widget> tabs;
  final List<int> badges;
  final Offset? badgeOffset;
  final TabController? controller;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final double minTabWidth;
  final bool? isScrollableOverride;
  final TabAlignment? tabAlignmentOverride;
  final Color? indicatorColor;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final double? indicatorWeight;
  final TabBarIndicatorSize indicatorSize;

  @override
  Widget build(BuildContext context) {
    assert(tabs.isNotEmpty, 'Tabs cannot be empty');
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final WidgetStateProperty<Color?> overlayColor =
        WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return scheme.primary.withValues(alpha: 0.14);
      }
      if (states.contains(WidgetState.focused) ||
          states.contains(WidgetState.hovered)) {
        return scheme.primary.withValues(alpha: 0.08);
      }
      return Colors.transparent;
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool useScrollable = isScrollableOverride ??
            (width.isFinite && width < tabs.length * minTabWidth);
        final TabAlignment alignment = tabAlignmentOverride ??
            (useScrollable ? TabAlignment.center : TabAlignment.fill);

        final resolvedBadges = List<int>.filled(tabs.length, 0);
        for (var i = 0; i < badges.length && i < resolvedBadges.length; i++) {
          resolvedBadges[i] = badges[i];
        }

        List<Widget> buildBadgeTabs() {
          return List<Widget>.generate(tabs.length, (index) {
            final count = resolvedBadges[index];
            if (count <= 0) return tabs[index];
            final child = tabs[index];
            final offset = badgeOffset ?? const Offset(0, -12);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                child,
                Positioned(
                  top: offset.dy,
                  right: offset.dx,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: backgroundColor ?? scheme.surface,
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          });
        }

        return Material(
          color: backgroundColor ?? scheme.surface,
          child: Padding(
            padding: padding,
            child: TabBar(
              controller: controller,
              tabs: buildBadgeTabs(),
              isScrollable: useScrollable,
              tabAlignment: alignment,
              dividerHeight: 0,
              indicator: indicatorColor == Colors.transparent &&
                      (indicatorWeight ?? 0) == 0
                  ? const BoxDecoration()
                  : null,
              indicatorColor: indicatorColor,
              indicatorWeight: indicatorWeight ?? 2,
              indicatorSize: indicatorSize,
              labelColor: labelColor ?? scheme.onSurface,
              unselectedLabelColor:
                  unselectedLabelColor ?? scheme.onSurfaceVariant,
              overlayColor: overlayColor,
            ),
          ),
        );
      },
    );
  }
}
