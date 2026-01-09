// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:flutter/material.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _blocklistSpinnerDimension = 16.0;
const double _blocklistSpinnerPadding = 1.0;
const double _blocklistSpinnerSlotSize =
    _blocklistSpinnerDimension + (_blocklistSpinnerPadding * 2);
const double _blocklistSpinnerGap = 8.0;

class BlocklistAddButton extends StatelessWidget {
  const BlocklistAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    return AxiDialogFab(
      tooltip: context.l10n.blocklistAddTooltip,
      iconData: LucideIcons.userX,
      label: context.l10n.blocklistBlock,
      dialogBuilder: (context) {
        String jid = '';
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(
              value: locate<BlocklistCubit>(),
            ),
            BlocProvider.value(
              value: locate<RosterCubit>(),
            ),
          ],
          child: StatefulBuilder(
            builder: (context, setState) {
              return AxiInputDialog(
                title: Text(context.l10n.blocklistBlockUser),
                content: BlocConsumer<BlocklistCubit, BlocklistState>(
                  listener: (context, state) {
                    if (state is BlocklistSuccess) {
                      context.pop();
                    }
                  },
                  builder: (context, state) {
                    return JidInput(
                      enabled: state is! BlocklistLoading,
                      error: state is! BlocklistFailure ? null : state.message,
                      jidOptions:
                          locate<RosterCubit?>()?.contacts.toList() ?? [],
                      onChanged: (value) {
                        setState(() => jid = value);
                      },
                    );
                  },
                ),
                callback: jid.isEmpty
                    ? null
                    : () =>
                        context.read<BlocklistCubit?>()?.block(address: jid),
              );
            },
          ),
        );
      },
    );
  }
}

class BlocklistUnblockAllButton extends StatelessWidget {
  const BlocklistUnblockAllButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BlocklistCubit, BlocklistState, bool>(
      selector: (state) => state is BlocklistLoading && state.jid == null,
      builder: (context, disabled) {
        final spinner = AxiProgressIndicator(
          dimension: _blocklistSpinnerDimension,
          color: context.colorScheme.foreground,
          semanticsLabel: context.l10n.blocklistWaitingForUnblock,
        );
        return ShadButton.destructive(
          enabled: !disabled,
          onPressed: () async {
            if (await confirm(context) != true) return;
            if (context.mounted) {
              context.read<BlocklistCubit?>()?.unblockAll();
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: baseAnimationDuration,
                curve: Curves.easeInOut,
                width: disabled ? _blocklistSpinnerSlotSize : 0,
                height: disabled ? _blocklistSpinnerSlotSize : 0,
                child: disabled ? spinner : null,
              ),
              AnimatedContainer(
                duration: baseAnimationDuration,
                curve: Curves.easeInOut,
                width: disabled ? _blocklistSpinnerGap : 0,
              ),
              Text(context.l10n.blocklistUnblockAll),
            ],
          ),
        ).withTapBounce(enabled: !disabled);
      },
    );
  }
}
