// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
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
    final text = count > 99 ? '99+' : '$count';
    return DecoratedBox(
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
      letterSpacing: -0.3,
      color: colors.foreground,
    );
    final Widget? toggleButton = onToggleCollapse == null
        ? null
        : AxiIconButton.ghost(
            iconData: LucideIcons.menu,
            tooltip: collapsed ? toggleCollapsedTooltip : toggleExpandedTooltip,
            onPressed: onToggleCollapse,
            usePrimary: true,
          );
    return AnimatedContainer(
      duration: context.watch<SettingsCubit>().animationDuration,
      curve: Curves.easeInOutCubic,
      width: railWidth,
      padding: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          right: BorderSide(color: colors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTitle) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.border),
                ),
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
                radius: radius,
                selectionOverlay: selectionOverlay,
                collapsed: collapsed,
                isDesktop: isDesktop,
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

class _AxiNavigationRailItem extends StatefulWidget {
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
  State<_AxiNavigationRailItem> createState() => _AxiNavigationRailItemState();
}

class _AxiNavigationRailItemState extends State<_AxiNavigationRailItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final bool isCollapsed = widget.collapsed;
    final Color baseIconColor =
        isCollapsed ? colors.primary : colors.foreground;
    final Color iconColor = widget.selected ? colors.primary : baseIconColor;
    final Color textColor =
        widget.selected ? colors.primary : colors.foreground;
    final itemShape = SquircleBorder(
      cornerRadius: widget.radius.topLeft.x,
      side: BorderSide(
        color: isCollapsed ? Colors.transparent : colors.border,
        width: isCollapsed ? 0 : 1,
      ),
    );
    final hoverTint = colors.primary.withValues(alpha: 0.06);
    final baseBackground = isCollapsed
        ? (widget.selected ? widget.selectionOverlay : Colors.transparent)
        : (widget.selected
            ? Color.alphaBlend(widget.selectionOverlay, widget.surfaceColor)
            : widget.surfaceColor);
    final background = _hovered && widget.isDesktop
        ? Color.alphaBlend(hoverTint, baseBackground)
        : baseBackground;

    final Widget icon = Icon(
      widget.destination.icon,
      color: iconColor,
      size: 20,
    );
    final Widget? badge = widget.destination.badgeCount > 0
        ? _RailBadge(count: widget.destination.badgeCount)
        : null;

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.collapsed ? 8 : 12,
        vertical: 12,
      ),
      child: widget.collapsed
          ? Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                icon,
                if (badge != null)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: badge,
                  ),
              ],
            )
          : Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.destination.label,
                    style: context.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  badge,
                ],
              ],
            ),
    );

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOutCubic,
      decoration: ShapeDecoration(
        color: background,
        shape: itemShape,
      ),
      child: widget.isDesktop
          ? content
          : InkWell(
              customBorder: itemShape,
              onTap: widget.onTap,
              highlightColor: Colors.transparent,
              splashColor: colors.primary.withValues(alpha: 0.12),
              hoverColor: hoverTint,
              child: content,
            ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.isDesktop ? widget.onTap : null,
        child: Semantics(
          selected: widget.selected,
          button: true,
          label: widget.destination.label,
          onTap: widget.onTap,
          child: child,
        ),
      ),
    );
  }
}
