// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

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
    final baseTitleStyle = context.textTheme.h3;
    final titleStyle = baseTitleStyle.copyWith(
      fontFamily: gabaritoFontFamily,
      fontFamilyFallback: gabaritoFontFallback,
      fontWeight: appBarTitleFontWeight,
    );
    final spacing = context.spacing;
    return Container(
      padding: EdgeInsets.symmetric(vertical: spacing.s, horizontal: spacing.m),
      decoration: BoxDecoration(
        border: Border(bottom: context.borderSide),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasLeading) leading!,
          if (hasLeading && hasTitle) SizedBox(width: spacing.s + spacing.xs),
          if (hasTitle)
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
          Flexible(
            fit: FlexFit.loose,
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerRight,
                child: trailing ?? const AxiVersion(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
