import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/view/block_menu_item.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RosterList extends StatelessWidget {
  const RosterList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RosterCubit, RosterState>(
      buildWhen: (_, current) => current is RosterAvailable,
      builder: (context, state) {
        late final List<RosterItem>? items;

        if (state is! RosterAvailable) {
          items = context.read<RosterCubit>()['items'];
        } else {
          items = state.items;
        }

        if (items == null) {
          return Center(
            child: AxiProgressIndicator(
              color: context.colorScheme.foreground,
            ),
          );
        }

        var visibleItems = List<RosterItem>.from(items);

        final searchState = context.watch<HomeSearchCubit?>()?.state;
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
              'No contacts yet',
              style: context.textTheme.muted,
            ),
          );
        }

        return ColoredBox(
          color: context.colorScheme.background,
          child: ListView.builder(
            itemCount: visibleItems.length,
            itemBuilder: (context, index) {
              final item = visibleItems[index];
              final open =
                  context.watch<ChatsCubit?>()?.state.openJid == item.jid;
              return ListItemPadding(
                child: AxiListTile(
                  key: Key(item.jid),
                  onTap: () =>
                      context.read<ChatsCubit?>()?.toggleChat(jid: item.jid),
                  menuItems: [
                    ShadContextMenuItem(
                      leading: const Icon(LucideIcons.pencilLine),
                      child: const Text('Compose'),
                      onPressed: () => context.push(
                        const ComposeRoute().location,
                        extra: {
                          'locate': context.read,
                          'jids': [item.jid],
                          'attachments': const <String>[],
                        },
                      ),
                    ),
                    BlockMenuItem(jid: item.jid),
                    AxiDeleteMenuItem(
                      onPressed: () async {
                        if (!(state is RosterLoading &&
                                state.jid == item.jid) &&
                            await confirm(context,
                                    text:
                                        'Remove ${item.jid} from contacts?') ==
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
                    status: null,
                  ),
                  title: item.title,
                  subtitle: item.jid,
                ),
              );
            },
          ),
        );
      },
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
