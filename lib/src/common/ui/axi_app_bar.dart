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
    return Container(
      height: 56.0,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        border: Border(bottom: context.borderSide),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasLeading) leading!,
                    if (hasLeading && hasTitle) const SizedBox(width: 12),
                    if (hasTitle)
                      Text(
                        appDisplayName,
                        style: titleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing ?? const AxiVersion(),
            ),
          ),
        ],
      ),
    );
  }
}
