import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/view/block_menu_item.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/search/search_models.dart';
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
    return BlocBuilder<RosterCubit, RosterState>(
      buildWhen: (_, current) => current is RosterAvailable,
      builder: (context, state) {
        final List<RosterItem>? items = (state as RosterAvailable).items;

        if (items == null) {
          return Center(
            child: AxiProgressIndicator(
              color: context.colorScheme.foreground,
            ),
          );
        }

        return BlocBuilder<ChatsCubit, ChatsState>(
          builder: (context, chatsState) {
            return BlocBuilder<HomeSearchCubit, HomeSearchState>(
              builder: (context, searchState) => _RosterListBody(
                items: items,
                rosterState: state,
                searchState: searchState,
                chatsState: chatsState,
              ),
            );
          },
        );
      },
    );
  }
}

class _RosterListBody extends StatelessWidget {
  const _RosterListBody({
    required this.items,
    required this.rosterState,
    this.searchState,
    this.chatsState,
  });

  final List<RosterItem> items;
  final RosterState rosterState;
  final HomeSearchState? searchState;
  final ChatsState? chatsState;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    var visibleItems = List<RosterItem>.from(items);
    final tabState = searchState?.stateFor(HomeTab.contacts);
    final searchActive = searchState?.active ?? false;
    final query =
        searchActive ? (tabState?.query.trim().toLowerCase() ?? '') : '';
    final filterId = tabState?.filterId;
    final sortOrder = tabState?.sort ?? SearchSortOrder.newestFirst;

    if (filterId != null) {
      visibleItems = visibleItems
          .where((item) => _rosterMatchesFilter(item, filterId))
          .toList();
    }

    if (visibleItems.isNotEmpty && query.isNotEmpty) {
      visibleItems = visibleItems
          .where((item) => _rosterMatchesQuery(item, query))
          .toList();
    }

    visibleItems.sort(
      (a, b) => sortOrder.isNewestFirst
          ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
          : b.title.toLowerCase().compareTo(a.title.toLowerCase()),
    );

    if (visibleItems.isEmpty) {
      return Center(
        child: Text(
          l10n.rosterEmpty,
          style: context.textTheme.muted,
        ),
      );
    }

    final openJid = chatsState?.openJid;

    return ColoredBox(
      color: context.colorScheme.background,
      child: ListView.builder(
        itemCount: visibleItems.length,
        itemBuilder: (context, index) {
          final item = visibleItems[index];
          final open = openJid == item.jid;
          return ListItemPadding(
            child: AxiListTile(
              key: Key(item.jid),
              onTap: () => context.read<ChatsCubit?>()?.openChat(jid: item.jid),
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
                BlockMenuItem(jid: item.jid),
                AxiDeleteMenuItem(
                  onPressed: () async {
                    final isLoading = switch (rosterState) {
                      RosterLoading(:final jid) => jid == item.jid,
                      _ => false,
                    };
                    if (!isLoading &&
                        await confirm(context,
                                text: l10n.rosterRemoveConfirm(item.jid)) ==
                            true &&
                        context.mounted) {
                      context
                          .read<RosterCubit?>()
                          ?.removeContact(jid: item.jid);
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
      ),
    );
  }
}

bool _rosterMatchesFilter(RosterItem item, String? filterId) {
  switch (filterId) {
    case 'online':
      return !item.presence.isUnavailable;
    case 'offline':
      return item.presence.isUnavailable;
    default:
      return true;
  }
}

bool _rosterMatchesQuery(RosterItem item, String query) {
  final lower = query.toLowerCase();
  return item.title.toLowerCase().contains(lower) ||
      item.jid.toLowerCase().contains(lower) ||
      (item.status?.toLowerCase().contains(lower) ?? false);
}
