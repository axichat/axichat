// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/blocklist/models/blocklist_entry.dart';
import 'package:axichat/src/blocklist/view/blocklist_button.dart';
import 'package:axichat/src/blocklist/view/blocklist_tile.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BlocklistList extends StatefulWidget {
  const BlocklistList({super.key});

  @override
  State<BlocklistList> createState() => _BlocklistListState();
}

class _BlocklistListState extends State<BlocklistList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncSearchState(context, context.read<HomeSearchCubit>().state);
    });
  }

  void _syncSearchState(BuildContext context, HomeSearchState searchState) {
    final tabState = searchState.stateFor(HomeTab.blocked);
    final query = searchState.active ? tabState.query : '';
    context.read<BlocklistCubit>().updateFilter(
          query: query,
          sortOrder: tabState.sort,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeSearchCubit, HomeSearchState>(
      listener: _syncSearchState,
      child: BlocBuilder<BlocklistCubit, BlocklistState>(
        builder: (context, state) {
          final items = state.items;
          if (items == null) {
            return Center(
              child: AxiProgressIndicator(
                color: context.colorScheme.foreground,
              ),
            );
          }
          final visibleItems = state.visibleItems ?? items;
          return BlocBuilder<RosterCubit, RosterState>(
            buildWhen: (previous, current) => previous.items != current.items,
            builder: (context, rosterState) {
              final cachedRosterItems = rosterState.items ??
                  (context.watch<RosterCubit>()['items'] as List<RosterItem>?);
              final avatarPathsByJid = <String, String>{};
              if (cachedRosterItems != null) {
                for (final item in cachedRosterItems) {
                  final path = item.avatarPath?.trim();
                  if (path == null || path.isEmpty) continue;
                  avatarPathsByJid[item.jid.toLowerCase()] = path;
                }
              }
              return _BlocklistListBody(
                items: visibleItems,
                avatarPathsByJid: avatarPathsByJid,
              );
            },
          );
        },
      ),
    );
  }
}

class _BlocklistListBody extends StatelessWidget {
  const _BlocklistListBody({required this.items, this.avatarPathsByJid});

  final List<BlocklistEntry> items;
  final Map<String, String>? avatarPathsByJid;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child:
            Text(context.l10n.blocklistEmpty, style: context.textTheme.muted),
      );
    }

    return ColoredBox(
      color: context.colorScheme.background,
      child: ListView.builder(
        itemCount: (items.length) + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: BlocklistUnblockAllButton(),
              ),
            );
          }
          final item = items[index - 1];
          return ListItemPadding(
            child: BlocklistTile(
              entry: item,
              avatarPathsByJid: avatarPathsByJid,
            ),
          );
        },
      ),
    );
  }
}
