import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class AxiAppBar extends StatelessWidget {
  const AxiAppBar({
    super.key,
    this.trailing,
    this.showTitle = true,
  });

  final Widget? trailing;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
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
          if (showTitle)
            Text(
              appDisplayName,
              style: context.textTheme.h3,
            ),
          const Spacer(),
          trailing ?? const AxiVersion(),
        ],
      ),
    );
  }
}
