// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/view/compose_draft_content.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ComposeScreen extends StatelessWidget {
  const ComposeScreen({super.key, required this.seed, required this.locate});

  final ComposeDraftSeed seed;
  final T Function<T>() locate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        shape: Border(bottom: context.borderSide),
        leadingWidth: sizing.iconButtonTapTarget + spacing.m,
        leading: Navigator.canPop(context)
            ? Padding(
                padding: EdgeInsets.only(left: spacing.m),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: sizing.iconButtonSize,
                    height: sizing.iconButtonSize,
                    child: AxiIconButton.ghost(
                      iconData: LucideIcons.arrowLeft,
                      tooltip: l10n.commonBack,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              )
            : null,
        title: Text(l10n.composeTitle),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.m,
            spacing.m,
            spacing.m,
            keyboardVisible ? 0 : spacing.m,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: sizing.composeWindowExpandedWidth,
            ),
            child: AxiModalSurface(
              child: ComposeDraftContent(
                seed: seed,
                locate: locate,
                onClosed: () => Navigator.maybePop(context),
                onDiscarded: () => Navigator.maybePop(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
