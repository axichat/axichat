import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

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
  }) : assert(destinations.length > 0, 'Destinations cannot be empty');

  final List<AxiRailDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final radius = context.radius;
    final brightness = Theme.of(context).brightness;
    final selectionOverlay = colors.primary.withValues(
      alpha: brightness == Brightness.dark ? 0.12 : 0.08,
    );
    // Fixed width keeps labels readable and avoids the vertical text shown by
    // the stock rail when space is tight.
    const double railWidth = 216;
    final int safeIndex = destinations.isEmpty
        ? 0
        : selectedIndex.clamp(0, destinations.length - 1);
    return Container(
      width: railWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
          right: BorderSide(color: colors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTitle) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                appDisplayName,
                style: context.textTheme.large.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.foreground,
                ),
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
                onTap: () => onDestinationSelected(index),
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
    required this.onTap,
  });

  final AxiRailDestination destination;
  final bool selected;
  final BorderRadius radius;
  final Color selectionOverlay;
  final VoidCallback onTap;

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
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(selectionOverlay, colors.card)
              : colors.card,
          border: Border.all(
            color: selected
                ? colors.primary.withValues(alpha: 0.5)
                : colors.border,
          ),
          borderRadius: radius,
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          splashColor: colors.primary.withValues(alpha: 0.14),
          hoverColor: colors.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            child: Row(
              children: [
                icon,
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
            ),
          ),
        ),
      ),
    );
  }
}
