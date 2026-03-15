// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:flutter/material.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
        MessageTransport transport = MessageTransport.xmpp;
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: locate<BlocklistCubit>()),
            BlocProvider.value(value: locate<RosterCubit>()),
          ],
          child: StatefulBuilder(
            builder: (context, setState) {
              final l10n = context.l10n;
              final spacing = context.spacing;
              return AxiInputDialog(
                title: Text(l10n.blocklistBlockUser),
                loading: context.select<BlocklistCubit, bool>(
                  (cubit) => switch (cubit.state) {
                    BlocklistLoading(:final jid) => jid != null,
                    _ => false,
                  },
                ),
                content: BlocConsumer<BlocklistCubit, BlocklistState>(
                  listener: (context, state) {
                    if (state is BlocklistSuccess) {
                      context.pop();
                    }
                  },
                  builder: (context, state) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AxiSelect<MessageTransport>(
                          initialValue: transport,
                          enabled: state is! BlocklistLoading,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => transport = value);
                          },
                          options: [
                            ShadOption(
                              value: MessageTransport.xmpp,
                              child: Text(l10n.authEndpointXmppLabel),
                            ),
                            ShadOption(
                              value: MessageTransport.email,
                              child: Text(l10n.sessionCapabilityEmail),
                            ),
                          ],
                          selectedOptionBuilder: (_, value) => Text(
                            value == MessageTransport.xmpp
                                ? l10n.authEndpointXmppLabel
                                : l10n.sessionCapabilityEmail,
                          ),
                        ),
                        SizedBox(height: spacing.s),
                        JidInput(
                          enabled: state is! BlocklistLoading,
                          error: state is! BlocklistFailure
                              ? null
                              : state.notice.resolve(l10n),
                          jidOptions: locate<RosterCubit>().contacts.toList(),
                          onChanged: (value) {
                            setState(() => jid = value);
                          },
                        ),
                      ],
                    );
                  },
                ),
                callback: jid.isEmpty
                    ? null
                    : () => context.read<BlocklistCubit>().block(
                        address: jid,
                        transport: transport,
                      ),
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
        return AxiButton.destructive(
          loading: disabled,
          onPressed: () async {
            if (await confirm(context) != true) return;
            if (context.mounted) {
              context.read<BlocklistCubit>().unblockAll();
            }
          },
          child: Text(context.l10n.blocklistUnblockAll),
        );
      },
    );
  }
}
