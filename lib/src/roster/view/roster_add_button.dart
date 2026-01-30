// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RosterAddButton extends StatelessWidget {
  const RosterAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    final l10n = context.l10n;
    return AxiDialogFab(
      tooltip: l10n.rosterAddTooltip,
      iconData: LucideIcons.userPlus,
      label: l10n.rosterAddLabel,
      dialogBuilder: (context) {
        String jid = '';
        String? title;
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: locate<RosterCubit>()),
            BlocProvider.value(value: locate<AuthenticationCubit>()),
          ],
          child: StatefulBuilder(
            builder: (context, setState) {
              return AxiInputDialog(
                title: Text(l10n.rosterAddTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BlocConsumer<RosterCubit, RosterState>(
                      listenWhen: (previous, current) =>
                          previous.actionState != current.actionState,
                      listener: (context, state) {
                        final actionState = state.actionState;
                        if (actionState is RosterActionSuccess &&
                            actionState.action == RosterActionType.add &&
                            context.canPop()) {
                          context.pop();
                        }
                      },
                      builder: (context, state) {
                        final actionState = state.actionState;
                        final errorMessage = switch (actionState) {
                          RosterActionFailure(:final reason)
                              when actionState.action == RosterActionType.add =>
                            _rosterFailureMessage(context, reason),
                          _ => null,
                        };
                        final isLoading = actionState is RosterActionLoading &&
                            actionState.action == RosterActionType.add;
                        return BlocSelector<AuthenticationCubit,
                            AuthenticationState, String>(
                          selector: (authState) => authState.server,
                          builder: (context, server) {
                            return JidInput(
                              enabled: !isLoading,
                              error: errorMessage,
                              jidOptions: ['${jid.split('@').first}@$server'],
                              onChanged: (value) {
                                setState(() => jid = value);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
                callback: jid.isEmpty
                    ? null
                    : () => context.read<RosterCubit>().addContact(
                          jid: jid,
                          title: title,
                        ),
              );
            },
          ),
        );
      },
    );
  }
}

String _rosterFailureMessage(
  BuildContext context,
  RosterFailureReason reason,
) {
  final l10n = context.l10n;
  return switch (reason) {
    RosterFailureReason.invalidJid => l10n.jidInputInvalid,
    RosterFailureReason.addFailed ||
    RosterFailureReason.removeFailed ||
    RosterFailureReason.rejectFailed =>
      l10n.authGenericError,
  };
}
