// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _railHeaderHorizontalPaddingCollapsed = 12.0;
const double _railHeaderHorizontalPaddingExpanded = 18.0;
const FontWeight _railTitleFontWeight = FontWeight.w500;

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

class _RailBadge extends StatelessWidget {
  const _RailBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final radii = context.radii;
    final text = count > 99 ? '99+' : '$count';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(radii.pill),
        border: Border.all(
          color: colors.background,
          width: context.borderSide.width,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: context.textTheme.small.copyWith(
            color: colors.primaryForeground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
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
    this.toggleExpandedTooltip,
    this.toggleCollapsedTooltip,
    this.backgroundColor,
    this.footer,
  }) : assert(destinations.length > 0, 'Destinations cannot be empty');

  final List<AxiRailDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool showTitle;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;
  final String? toggleExpandedTooltip;
  final String? toggleCollapsedTooltip;
  final Color? backgroundColor;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final brightness = context.brightness;
    final selectionOverlay = colors.primary.withValues(
      alpha: brightness == Brightness.dark ? 0.12 : 0.08,
    );
    // Fixed width keeps labels readable and avoids the vertical text shown by
    // the stock rail when space is tight.
    const double expandedWidth = 216;
    const double collapsedWidth = 72;
    final double railWidth = collapsed ? collapsedWidth : expandedWidth;
    final int safeIndex = destinations.isEmpty
        ? 0
        : selectedIndex.clamp(0, destinations.length - 1);
    final Color surfaceColor = backgroundColor ?? colors.background;
    final titleStyle = context.textTheme.h2.copyWith(
      fontFamily: gabaritoFontFamily,
      fontFamilyFallback: gabaritoFontFallback,
      fontWeight: _railTitleFontWeight,
      color: colors.foreground,
    );
    final Widget? toggleButton = onToggleCollapse == null
        ? null
        : AxiIconButton.ghost(
            iconData: LucideIcons.menu,
            tooltip: collapsed ? toggleCollapsedTooltip : toggleExpandedTooltip,
            onPressed: onToggleCollapse,
            selected: true,
          );
    return AnimatedContainer(
      duration: context.watch<SettingsCubit>().animationDuration,
      curve: Curves.easeInOutCubic,
      width: railWidth,
      padding: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTitle) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.border)),
              ),
              child: SizedBox(
                height: kToolbarHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: collapsed
                        ? _railHeaderHorizontalPaddingCollapsed
                        : _railHeaderHorizontalPaddingExpanded,
                  ),
                  child: collapsed
                      ? Center(child: toggleButton ?? const SizedBox.shrink())
                      : Row(
                          children: [
                            if (toggleButton != null) toggleButton,
                            if (toggleButton != null) const SizedBox(width: 12),
                            if (showTitle)
                              Expanded(
                                child: Text(
                                  appDisplayName,
                                  style: titleStyle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            else
                              const Spacer(),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ...List.generate(destinations.length, (index) {
            final destination = destinations[index];
            final selected = index == safeIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: _AxiNavigationRailItem(
                destination: destination,
                selected: selected,
                selectionOverlay: selectionOverlay,
                collapsed: collapsed,
                onTap: () => onDestinationSelected(index),
                surfaceColor: surfaceColor,
              ),
            );
          }),
          if (footer != null) ...[
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: footer!,
            ),
          ],
        ],
      ),
    );
  }
}

class _AxiNavigationRailItem extends StatelessWidget {
  const _AxiNavigationRailItem({
    required this.destination,
    required this.selected,
    required this.selectionOverlay,
    required this.collapsed,
    required this.onTap,
    required this.surfaceColor,
  });

  final AxiRailDestination destination;
  final bool selected;
  final Color selectionOverlay;
  final bool collapsed;
  final VoidCallback onTap;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final bool isCollapsed = collapsed;
    final Color iconColor = selected ? colors.primary : colors.foreground;
    final Color textColor = selected ? colors.primary : colors.foreground;
    final Widget? badge = destination.badgeCount > 0
        ? _RailBadge(count: destination.badgeCount)
        : null;
    const iconSize = 20.0;
    final Widget collapsedIcon = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Icon(destination.icon, color: iconColor, size: iconSize),
        if (badge != null) Positioned(top: -6, right: -8, child: badge),
      ],
    );
    final Color? backgroundColor = selected
        ? (isCollapsed
            ? selectionOverlay
            : Color.alphaBlend(selectionOverlay, surfaceColor))
        : null;
    final Color? foregroundColor = selected ? textColor : null;
    return AxiListButton(
      selected: selected,
      collapsed: isCollapsed,
      collapsedIconData: destination.icon,
      collapsedIcon: collapsedIcon,
      collapsedTooltip: destination.label,
      collapsedForegroundColor: selected ? iconColor : null,
      collapsedBackgroundColor: isCollapsed ? backgroundColor : null,
      variant: AxiButtonVariant.ghost,
      leading: Icon(destination.icon, size: iconSize),
      trailing: badge,
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      onPressed: onTap,
      semanticLabel: destination.label,
      child: Text(
        destination.label,
        style: context.textTheme.small.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
