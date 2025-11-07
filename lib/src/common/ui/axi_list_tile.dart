import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiListTile extends StatelessWidget {
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
    this.menuItems,
    this.badgeCount = 0,
  });

  final Widget? leading;
  final BoxConstraints? leadingConstraints;
  final String? title;
  final String? subtitle;
  final String? subtitlePlaceholder;
  final List<Widget>? actions;
  final bool selected;
  final void Function()? onTap;
  final List<Widget>? menuItems;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final brightness = Theme.of(context).brightness;
    final selectionOverlay = colors.primary.withValues(
      alpha: brightness == Brightness.dark ? 0.12 : 0.06,
    );
    final backgroundColor = selected
        ? Color.alphaBlend(selectionOverlay, colors.card)
        : colors.card;
    final shape = ContinuousRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      side: BorderSide(color: colors.border),
    );

    Widget child = ListTile(
      titleAlignment: ListTileTitleAlignment.center,
      horizontalTitleGap: 16.0,
      contentPadding: const EdgeInsets.only(left: 16.0, right: 16.0),
      minTileHeight: 84.0,
      selected: selected,
      selectedTileColor: Colors.transparent,
      hoverColor: selectionOverlay,
      tileColor: Colors.transparent,
      iconColor: colors.foreground,
      onTap: onTap,
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
              style: context.textTheme.small
                  .copyWith(color: colors.foreground, height: 1.2),
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

    child = AnimatedContainer(
      duration: baseAnimationDuration,
      decoration: ShapeDecoration(
        color: backgroundColor,
        shape: shape,
      ),
      child: child,
    );

    if (badgeCount > 0) {
      child = AxiBadge(
        count: badgeCount,
        offset: const Offset(-5, 10),
        child: child,
      );
    }

    if (menuItems != null) {
      child = ShadContextMenuRegion(
        items: menuItems!,
        child: child,
      );
    }

    return child;
  }
}
