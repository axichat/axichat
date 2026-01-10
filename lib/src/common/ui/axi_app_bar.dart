// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

const FontWeight _appTitleFontWeight = FontWeight.w500;

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
    final baseTitleStyle =
        Theme.of(context).appBarTheme.titleTextStyle ?? context.textTheme.h3;
    final titleStyle = baseTitleStyle.copyWith(
      fontFamily: gabaritoFontFamily,
      fontFamilyFallback: gabaritoFontFallback,
      fontWeight: _appTitleFontWeight,
    );
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
              style: titleStyle,
            ),
          if (hasTitle || hasLeading) const Spacer(),
          if (!hasTitle && !hasLeading) const Spacer(),
          trailing ?? const AxiVersion(),
        ],
      ),
    );
  }
}
