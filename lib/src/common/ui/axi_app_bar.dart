import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class AxiAppBar extends StatelessWidget {
  const AxiAppBar({
    super.key,
    this.trailing,
    this.showTitle = true,
    this.leading,
  });

  final Widget? trailing;
  final bool showTitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final hasLeading = leading != null;
    final hasTitle = showTitle;
    return Container(
      height: 56.0,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.colorScheme.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasLeading) leading!,
          if (hasLeading && hasTitle) const SizedBox(width: 12),
          if (hasTitle)
            Text(
              appDisplayName,
              style: context.textTheme.h3,
            ),
          if (hasTitle || hasLeading) const Spacer(),
          if (!hasTitle && !hasLeading) const Spacer(),
          trailing ?? const AxiVersion(),
        ],
      ),
    );
  }
}
