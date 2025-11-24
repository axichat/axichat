import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiRailDestination {
  const AxiRailDestination({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final int badgeCount;
}

/// Desktop-friendly navigation rail that matches Axichat styling instead of the
/// stock Material rail. Labels stay horizontal and spacing is roomy enough to
/// avoid cramped layouts.
class AxiNavigationRail extends StatelessWidget {
  const AxiNavigationRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.showTitle = true,
    this.collapsed = false,
    this.onToggleCollapse,
    this.backgroundColor,
  }) : assert(destinations.length > 0, 'Destinations cannot be empty');

  final List<AxiRailDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool showTitle;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final env = EnvScope.maybeOf(context);
    final isDesktop = env?.isDesktopPlatform ?? false;
    final radius = context.radius;
    final brightness = Theme.of(context).brightness;
    final selectionOverlay = colors.primary.withValues(
      alpha: brightness == Brightness.dark ? 0.12 : 0.08,
    );
    // Fixed width keeps labels readable and avoids the vertical text shown by
    // the stock rail when space is tight.
    const double expandedWidth = 216;
    const double collapsedWidth = 96;
    final double railWidth = collapsed ? collapsedWidth : expandedWidth;
    final int safeIndex = destinations.isEmpty
        ? 0
        : selectedIndex.clamp(0, destinations.length - 1);
    final Color surfaceColor = backgroundColor ?? colors.background;
    final Widget? collapseControl = onToggleCollapse == null
        ? null
        : AxiIconButton(
            iconData:
                collapsed ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
            tooltip: collapsed ? 'Expand menu' : 'Collapse menu',
            onPressed: onToggleCollapse,
          );
    return Container(
      width: railWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          right: BorderSide(color: colors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTitle || collapseControl != null) ...[
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 4 : 6,
              ),
              child: Row(
                children: [
                  if (showTitle && !collapsed)
                    Expanded(
                      child: Text(
                        appDisplayName,
                        style: context.textTheme.large.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.foreground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else if (showTitle)
                    const Spacer(),
                  if (collapseControl != null) collapseControl,
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          ...List.generate(destinations.length, (index) {
            final destination = destinations[index];
            final selected = index == safeIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _AxiNavigationRailItem(
                destination: destination,
                selected: selected,
                radius: radius,
                selectionOverlay: selectionOverlay,
                collapsed: collapsed,
                isDesktop: isDesktop,
                onTap: () => onDestinationSelected(index),
                surfaceColor: surfaceColor,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AxiNavigationRailItem extends StatelessWidget {
  const _AxiNavigationRailItem({
    required this.destination,
    required this.selected,
    required this.radius,
    required this.selectionOverlay,
    required this.collapsed,
    required this.isDesktop,
    required this.onTap,
    required this.surfaceColor,
  });

  final AxiRailDestination destination;
  final bool selected;
  final BorderRadius radius;
  final Color selectionOverlay;
  final bool collapsed;
  final bool isDesktop;
  final VoidCallback onTap;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final iconColor = selected ? colors.primary : colors.foreground;
    final textColor = selected ? colors.primary : colors.foreground;

    Widget icon = Icon(
      destination.icon,
      color: iconColor,
      size: 20,
    );
    if (destination.badgeCount > 0) {
      icon = AxiBadge(
        count: destination.badgeCount,
        offset: const Offset(10, -6),
        child: icon,
      );
    }

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: ShapeDecoration(
          color: selected
              ? Color.alphaBlend(selectionOverlay, surfaceColor)
              : surfaceColor,
          shape: SquircleBorder(
            cornerRadius: radius.topLeft.x,
            side: BorderSide(
              color: selected
                  ? colors.primary.withValues(alpha: 0.5)
                  : colors.border,
            ),
          ),
        ),
        child: InkWell(
          customBorder: SquircleBorder(cornerRadius: radius.topLeft.x),
          onTap: onTap,
          splashFactory:
              isDesktop ? NoSplash.splashFactory : InkRipple.splashFactory,
          hoverColor: colors.primary.withValues(alpha: 0.08),
          splashColor: colors.primary.withValues(alpha: 0.14),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 10 : 12,
              vertical: 12,
            ),
            child: Row(
              children: [
                icon,
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      destination.label,
                      style: context.textTheme.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
