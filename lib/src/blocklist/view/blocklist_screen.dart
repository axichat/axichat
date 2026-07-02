// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/blocklist/view/blocklist_button.dart';
import 'package:axichat/src/blocklist/view/blocklist_list.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
        title: Text(
          context.l10n.profileBlocklistTitle,
          style: context.modalHeaderTextStyle,
        ),
        centerTitle: false,
        backgroundColor: context.colorScheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: context.borderSide),
        leadingWidth: sizing.iconButtonTapTarget + spacing.m,
        leading: Padding(
          padding: EdgeInsets.only(left: spacing.m),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: sizing.iconButtonSize,
              height: sizing.iconButtonSize,
              child: AxiIconButton.ghost(
                iconData: LucideIcons.arrowLeft,
                tooltip: context.l10n.commonBack,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: const _BlocklistFloatingActions(),
      body: const ColoredBox(
        color: Colors.transparent,
        child: BlocklistList(bindHomeSearch: false),
      ),
    );
  }
}

class _BlocklistFloatingActions extends StatelessWidget {
  const _BlocklistFloatingActions();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return BlocBuilder<BlocklistCubit, BlocklistState>(
      buildWhen: (previous, current) => previous.items != current.items,
      builder: (context, state) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.items?.isNotEmpty ?? false) ...[
              const BlocklistUnblockAllFab(),
              SizedBox(width: spacing.s),
            ],
            const BlocklistAddButton(),
          ],
        );
      },
    );
  }
}
