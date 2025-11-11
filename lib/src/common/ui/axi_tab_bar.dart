import 'package:flutter/material.dart';

/// Shared tab bar used across Axichat surfaces so styling stays consistent.
class AxiTabBar extends StatelessWidget {
  const AxiTabBar({
    super.key,
    required this.tabs,
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
        return Material(
          color: backgroundColor ?? scheme.surface,
          child: Padding(
            padding: padding,
            child: TabBar(
              controller: controller,
              tabs: tabs,
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
