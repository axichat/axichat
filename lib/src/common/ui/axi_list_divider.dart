// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiListDivider extends StatelessWidget {
  const AxiListDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadSeparator.horizontal(
      color: context.borderSide.color,
      thickness: context.borderSide.width,
    );
  }
}
