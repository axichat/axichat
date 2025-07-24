import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiListTile extends StatelessWidget {
  const AxiListTile({
    super.key,
    this.leading,
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
    Widget child = ListTile(
      titleAlignment: ListTileTitleAlignment.center,
      horizontalTitleGap: 16.0,
      contentPadding: const EdgeInsets.only(left: 16.0, right: 16.0),
      minTileHeight: 70.0,
      selected: selected,
      selectedTileColor: context.colorScheme.accent,
      onTap: onTap,
      leading: leading == null
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 40.0,
                maxWidth: 40.0,
              ),
              child: leading,
            ),
      title: title == null
          ? null
          : Text(
              title!,
              style: context.textTheme.small,
              overflow: TextOverflow.ellipsis,
            ),
      subtitle: subtitle == null
          ? subtitlePlaceholder == null
              ? null
              : Text(
                  subtitlePlaceholder!,
                  style: context.textTheme.muted
                      .copyWith(fontStyle: FontStyle.italic),
                )
          : Text(
              subtitle!,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.muted,
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [...?actions],
      ),
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
