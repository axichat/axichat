// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/view/blocklist_list.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BlocklistScreen extends StatelessWidget {
  const BlocklistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sizing = context.sizing;
    return Scaffold(
      backgroundColor: context.colorScheme.background,
      appBar: AppBar(
        title: Text(context.l10n.profileBlocklistTitle),
        backgroundColor: context.colorScheme.background,
        surfaceTintColor: context.colorScheme.background,
        shape: Border(bottom: context.borderSide),
        leadingWidth: sizing.iconButtonTapTarget + spacing.m,
        leading: Padding(
          padding: EdgeInsets.only(left: spacing.s),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AxiIconButton.ghost(
              iconData: LucideIcons.arrowLeft,
              tooltip: context.l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
      body: const ColoredBox(
        color: Colors.transparent,
        child: BlocklistList(bindHomeSearch: false),
      ),
    );
  }
}
