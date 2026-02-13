// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/view/block_menu_item.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RosterInvitesList extends StatelessWidget {
  const RosterInvitesList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeSearchCubit, HomeSearchState>(
      listener: (context, searchState) {
        final tabState = searchState.stateFor(HomeTab.invites);
        final query = searchState.active ? tabState.query : '';
        context.read<RosterCubit>().updateInvitesCriteria(
              query: query,
              sort: tabState.sort,
            );
      },
      child: BlocBuilder<RosterCubit, RosterState>(
        buildWhen: (previous, current) =>
            previous.visibleInvites != current.visibleInvites,
        builder: (context, state) {
          final cachedInvites =
              context.watch<RosterCubit>()['invites'] as List<Invite>?;
          final invites =
              state.visibleInvites ?? state.invites ?? cachedInvites;

          if (invites == null) {
            return Center(
              child:
                  AxiProgressIndicator(color: context.colorScheme.foreground),
            );
          }

          return _RosterInvitesBody(invites: invites);
        },
      ),
    );
  }
}

class _RosterInvitesBody extends StatelessWidget {
  const _RosterInvitesBody({required this.invites});

  final List<Invite> invites;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (invites.isEmpty) {
      return Center(
        child: Text(l10n.rosterInvitesEmpty, style: context.textTheme.muted),
      );
    }

    return ColoredBox(
      color: context.colorScheme.background,
      child: ListView.builder(
        itemCount: invites.length,
        itemBuilder: (context, index) {
          final invite = invites[index];
          return BlocSelector<RosterCubit, RosterState, bool>(
            selector: (state) {
              final actionState = state.actionState;
              return actionState is RosterActionLoading &&
                  actionState.jid == invite.jid;
            },
            builder: (context, disabled) {
              return ListItemPadding(
                child: AxiListTile(
                  key: Key(invite.jid),
                  menuItems: [
                    AxiDeleteMenuItem(
                      onPressed: () async {
                        if (!disabled &&
                            await confirm(
                                  context,
                                  text: l10n.rosterRejectInviteConfirm(
                                    invite.jid,
                                  ),
                                ) ==
                                true &&
                            context.mounted) {
                          context.read<RosterCubit>().rejectContact(
                                jid: invite.jid,
                              );
                        }
                      },
                    ),
                    BlockMenuItem(
                      jid: invite.jid,
                      transport: MessageTransport.xmpp,
                    ),
                    ReportSpamMenuItem(
                      jid: invite.jid,
                      transport: MessageTransport.xmpp,
                    ),
                  ],
                  leading: AxiAvatar(jid: invite.jid),
                  title: invite.title,
                  subtitle: invite.jid,
                  actions: [
                    AxiIconButton(
                      tooltip: l10n.rosterAddContactTooltip,
                      iconData: LucideIcons.userPlus,
                      color: axiGreen,
                      onPressed: disabled
                          ? null
                          : () {
                              context.read<RosterCubit>().addContact(
                                    jid: invite.jid,
                                    title: invite.title,
                                  );
                            },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
