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
  });

  final Widget? leading;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: const EdgeInsets.all(12.0),
      rowCrossAxisAlignment: CrossAxisAlignment.center,
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
                  Text(
                    title!,
                    style: context.textTheme.small,
                  ),
                ],
              ),
            ),
      description: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Row(
                children: [
                  Text(subtitle!),
                ],
              ),
            ),
      trailing: actions == null
          ? null
          : Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: OverflowBar(
                  spacing: 4.0,
                  overflowSpacing: 4.0,
                  overflowAlignment: OverflowBarAlignment.center,
                  children: actions!,
                ),
              ),
            ),
    );
  }
}
