// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/view/block_menu_item.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/view/compose_launcher.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RosterList extends StatelessWidget {
  const RosterList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeSearchCubit, HomeSearchState>(
      listener: (context, searchState) {
        final tabState = searchState.stateFor(HomeTab.contacts);
        final query = searchState.active ? tabState.query : '';
        context.read<RosterCubit>().updateContactsCriteria(
              query: query,
              sort: tabState.sort,
            );
      },
      child: BlocBuilder<RosterCubit, RosterState>(
        buildWhen: (previous, current) =>
            previous.visibleItems != current.visibleItems,
        builder: (context, state) {
          final cachedItems =
              context.read<RosterCubit>()[RosterCubit.itemsCacheKey]
                  as List<RosterItem>?;
          final cachedVisibleItems =
              context.read<RosterCubit>()[RosterCubit.visibleItemsCacheKey]
                  as List<RosterItem>?;
          final items = state.visibleItems ??
              cachedVisibleItems ??
              state.items ??
              cachedItems;

          if (items == null) {
            return Center(
              child:
                  AxiProgressIndicator(color: context.colorScheme.foreground),
            );
          }

          return BlocBuilder<ChatsCubit, ChatsState>(
            builder: (context, chatsState) => _RosterListBody(
              items: items,
              chatsState: chatsState,
            ),
          );
        },
      ),
    );
  }
}

class _RosterListBody extends StatelessWidget {
  const _RosterListBody({
    required this.items,
    this.chatsState,
  });

  final List<RosterItem> items;
  final ChatsState? chatsState;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (items.isEmpty) {
      return Center(
        child: Text(l10n.rosterEmpty, style: context.textTheme.muted),
      );
    }

    final openJid = chatsState?.openJid;

    return ColoredBox(
      color: context.colorScheme.background,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return BlocSelector<RosterCubit, RosterState, bool>(
            selector: (state) {
              final actionState = state.actionState;
              return actionState is RosterActionLoading &&
                  actionState.action == RosterActionType.remove &&
                  actionState.jid == item.jid;
            },
            builder: (context, isLoading) {
              final open = openJid == item.jid;
              return ListItemPadding(
                child: AxiListTile(
                  key: Key(item.jid),
                  onTap: () =>
                      context.read<ChatsCubit>().openChat(jid: item.jid),
                  menuItems: [
                    ShadContextMenuItem(
                      leading: const Icon(LucideIcons.pencilLine),
                      child: Text(l10n.rosterCompose),
                      onPressed: () => openComposeDraft(
                        context,
                        jids: [item.jid],
                        attachmentMetadataIds: const <String>[],
                      ),
                    ),
                    BlockMenuItem(
                      jid: item.jid,
                      transport: MessageTransport.xmpp,
                    ),
                    ReportSpamMenuItem(
                      jid: item.jid,
                      transport: MessageTransport.xmpp,
                    ),
                    AxiDeleteMenuItem(
                      onPressed: () async {
                        if (!isLoading &&
                            await confirm(
                                  context,
                                  text: l10n.rosterRemoveConfirm(item.jid),
                                ) ==
                                true &&
                            context.mounted) {
                          context.read<RosterCubit>().removeContact(
                                jid: item.jid,
                              );
                        }
                      },
                    ),
                  ],
                  selected: open,
                  leading: AxiAvatar(
                    jid: item.jid,
                    subscription: item.subscription,
                    // Presence is parsed for MUC/identity purposes but not shown
                    // in the contacts UI because it is unreliable across servers.
                    presence: null,
                    status: item.status,
                    avatarPath: item.avatarPath,
                  ),
                  title: item.title,
                  subtitle: item.jid,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
