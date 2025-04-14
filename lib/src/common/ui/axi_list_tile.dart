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
    this.actions,
    this.selected = false,
    this.onTap,
    this.onDismissed,
    this.dismissText = 'Are you sure you want to delete this item?',
    this.badgeCount = 0,
  });

  final Widget? leading;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool selected;
  final void Function()? onTap;
  final void Function(DismissDirection)? onDismissed;
  final String dismissText;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final dismissible = onDismissed != null && super.key != null;
    assert(onDismissed != null ? super.key != null : true);

    Widget child = ListTile(
      titleAlignment: ListTileTitleAlignment.center,
      horizontalTitleGap: 16.0,
      contentPadding: EdgeInsets.only(
        left: 16.0,
        right: dismissible ? 0.0 : 16.0,
      ),
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
          ? null
          : Text(
              subtitle!,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.muted,
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...?actions,
          if (dismissible)
            Container(
              height: 60.0,
              width: 4.0,
              margin: const EdgeInsets.all(7.0),
              decoration: BoxDecoration(
                color: context.colorScheme.border,
                borderRadius: BorderRadius.circular(20),
              ),
            )
        ],
      ),
    );

    if (badgeCount > 0) {
      child = AxiBadge(
        count: badgeCount,
        offset: const Offset(-5, 10),
        child: child,
      );
    }

    if (dismissible) {
      assert(
        super.key != null,
        'A key must be provided for dismissible tiles.',
      );
      child = Dismissible(
        key: super.key!,
        background: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: context.colorScheme.destructive,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                LucideIcons.trash,
                color: context.colorScheme.destructiveForeground,
              ),
              Icon(
                LucideIcons.trash,
                color: context.colorScheme.destructiveForeground,
              ),
            ],
          ),
        ),
        confirmDismiss: (_) => confirm(
          context,
          text: dismissText,
        ),
        onDismissed: onDismissed,
        child: child,
      );
    }

    return child;
  }
}
