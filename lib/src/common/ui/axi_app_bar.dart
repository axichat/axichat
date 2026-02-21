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
    final spacing = context.spacing;
    final double titleGap = spacing.s;
    final baseTitleStyle = context.textTheme.h3;
    final titleStyle = baseTitleStyle.copyWith(
      fontFamily: gabaritoFontFamily,
      fontFamilyFallback: gabaritoFontFallback,
      fontWeight: appBarTitleFontWeight,
    );
    final trailingContent = ClipRect(
      child: Align(
        alignment: Alignment.centerRight,
        child: trailing ?? const AxiVersion(),
      ),
    );
    return Container(
      height: context.sizing.appBarHeight,
      padding: EdgeInsets.symmetric(vertical: spacing.s, horizontal: spacing.m),
      decoration: BoxDecoration(border: Border(bottom: context.borderSide)),
      child: hasTitle
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          if (hasLeading)
                            Flexible(
                              fit: FlexFit.loose,
                              child: ClipRect(child: leading!),
                            ),
                          if (hasLeading) SizedBox(width: titleGap),
                          Expanded(
                            child: Text(
                              appDisplayName,
                              style: titleStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                trailingContent,
              ],
            )
          : ClipRect(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (hasLeading)
                    Align(alignment: Alignment.centerLeft, child: leading!),
                  trailingContent,
                ],
              ),
            ),
    );
  }
}
