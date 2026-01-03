// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class AxiListTile extends StatelessWidget {
  static const EdgeInsets _defaultContentPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const double _defaultMinTileHeight = 72.0;
  static const double _compactMinTileHeight = 56.0;

  const AxiListTile({
    super.key,
    this.leading,
    this.leadingConstraints,
    this.title,
    this.subtitle,
    this.subtitlePlaceholder,
    this.actions,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.menuItems,
    this.surfaceColor,
    this.surfaceShape,
    this.paintSurface = true,
    this.contentPadding,
    this.tapBounce = true,
    this.minTileHeight,
  });

  final Widget? leading;
  final BoxConstraints? leadingConstraints;
  final String? title;
  final String? subtitle;
  final String? subtitlePlaceholder;
  final List<Widget>? actions;
  final bool selected;
  final void Function()? onTap;
  final void Function()? onLongPress;
  final List<Widget>? menuItems;
  final Color? surfaceColor;
  final ShapeBorder? surfaceShape;
  final bool paintSurface;
  final EdgeInsetsGeometry? contentPadding;
  final bool tapBounce;
  final double? minTileHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final env = EnvScope.maybeOf(context);
    final isDesktop = env?.isDesktopPlatform ?? false;
    final brightness = Theme.of(context).brightness;
    final selectionOverlay = colors.primary.withValues(
      alpha: brightness == Brightness.dark ? 0.12 : 0.06,
    );
    Color backgroundColor = surfaceColor ?? colors.card;
    backgroundColor = selected
        ? Color.alphaBlend(selectionOverlay, backgroundColor)
        : backgroundColor;
    final shape = surfaceShape ??
        SquircleBorder(
          cornerRadius: 18,
          side: BorderSide(color: colors.border),
        );
    final resolvedMinTileHeight = minTileHeight ??
        (subtitle == null && subtitlePlaceholder == null
            ? _compactMinTileHeight
            : _defaultMinTileHeight);

    Widget child = ListTile(
      titleAlignment: ListTileTitleAlignment.center,
      horizontalTitleGap: 16.0,
      contentPadding: contentPadding ?? _defaultContentPadding,
      minTileHeight: resolvedMinTileHeight,
      selected: selected,
      selectedTileColor: Colors.transparent,
      hoverColor: selectionOverlay,
      tileColor: Colors.transparent,
      iconColor: colors.foreground,
      onTap: onTap,
      onLongPress: onLongPress,
      leading: leading == null
          ? null
          : ConstrainedBox(
              constraints: leadingConstraints ??
                  const BoxConstraints(
                    maxHeight: 40.0,
                    maxWidth: 40.0,
                  ),
              child: leading,
            ),
      title: title == null
          ? null
          : Text(
              title!,
              style: context.textTheme.small.copyWith(
                color: colors.foreground,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
      subtitle: subtitle == null
          ? subtitlePlaceholder == null
              ? null
              : Text(
                  subtitlePlaceholder!,
                  style: context.textTheme.muted.copyWith(
                    fontStyle: FontStyle.italic,
                    color: colors.mutedForeground,
                  ),
                )
          : Text(
              subtitle!,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.muted
                  .copyWith(color: colors.mutedForeground, height: 1.2),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [...?actions],
      ),
    );
    if (isDesktop) {
      child = Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: selectionOverlay,
        ),
        child: child,
      );
    }

    if (paintSurface) {
      child = AnimatedContainer(
        duration: baseAnimationDuration,
        decoration: ShapeDecoration(
          color: backgroundColor,
          shape: shape,
        ),
        child: child,
      );
    }

    if (menuItems != null) {
      child = AxiContextMenuRegion(
        items: menuItems!,
        child: child,
      );
    }

    if (tapBounce) {
      final enableBounce = onTap != null || (menuItems?.isNotEmpty ?? false);
      child = child.withTapBounce(enabled: enableBounce);
    }

    return child;
  }
}
