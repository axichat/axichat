// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:axichat/src/common/ui/ui.dart';

class ListItemPadding extends StatelessWidget {
  const ListItemPadding({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            axiSpaceM,
            axiSpaceS,
            axiSpaceM,
            axiSpaceS,
          ),
      child: child,
    );
  }
}
