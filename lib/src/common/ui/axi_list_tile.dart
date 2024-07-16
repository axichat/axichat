import 'package:chat/src/app.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiListTile extends StatelessWidget {
  const AxiListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.actions,
    this.color,
  });

  final Widget? leading;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: const EdgeInsets.all(12.0),
      rowCrossAxisAlignment: CrossAxisAlignment.center,
      rowMainAxisSize: MainAxisSize.max,
      backgroundColor: color,
      leading: leading == null
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 50.0,
                maxWidth: 50.0,
              ),
              child: leading,
            ),
      title: title == null
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 4.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: context.textTheme.small,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
      description: subtitle == null
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 150.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: Text(
                        subtitle!,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      trailing: actions == null
          ? null
          : Align(
              alignment: Alignment.centerRight,
              child: OverflowBar(
                spacing: 4.0,
                overflowSpacing: 4.0,
                overflowAlignment: OverflowBarAlignment.center,
                children: actions!,
              ),
            ),
    );
  }
}
