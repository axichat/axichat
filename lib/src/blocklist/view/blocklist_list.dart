// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/blocklist/models/blocklist_entry.dart';
import 'package:axichat/src/blocklist/view/blocklist_button.dart';
import 'package:axichat/src/blocklist/view/blocklist_tile.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BlocklistList extends StatelessWidget {
  const BlocklistList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BlocklistCubit, BlocklistState>(
      builder: (context, state) {
        final items = state is BlocklistAvailable
            ? state.items ??
                context.select<BlocklistCubit, List<BlocklistEntry>?>(
                  (cubit) =>
                      cubit[blocklistItemsCacheKey] as List<BlocklistEntry>?,
                )
            : context.select<BlocklistCubit, List<BlocklistEntry>?>(
                (cubit) =>
                    cubit[blocklistItemsCacheKey] as List<BlocklistEntry>?,
              );

        if (items == null) {
          return Center(
            child: AxiProgressIndicator(
              color: context.colorScheme.foreground,
            ),
          );
        }

        return BlocBuilder<HomeSearchCubit, HomeSearchState>(
          builder: (context, searchState) => _BlocklistListBody(
            items: items,
            searchState: searchState,
          ),
        );
      },
    );
  }
}

class _BlocklistListBody extends StatelessWidget {
  const _BlocklistListBody({
    required this.items,
    this.searchState,
  });

  final List<BlocklistEntry> items;
  final HomeSearchState? searchState;

  @override
  Widget build(BuildContext context) {
    final tabState = searchState?.stateFor(HomeTab.blocked);
    final searchActive = searchState?.active ?? false;
    final query =
        searchActive ? (tabState?.query.trim().toLowerCase() ?? '') : '';
    final sortOrder = tabState?.sort ?? SearchSortOrder.newestFirst;

    var visibleItems = List<BlocklistEntry>.from(items);

    if (query.isNotEmpty) {
      visibleItems = visibleItems
          .where((item) => _blockMatchesQuery(item, query))
          .toList();
    }

    visibleItems.sort(
      (a, b) => sortOrder.isNewestFirst
          ? b.blockedAt.compareTo(a.blockedAt)
          : a.blockedAt.compareTo(b.blockedAt),
    );

    if (visibleItems.isEmpty) {
      return Center(
        child: Text(
          'Nobody blocked',
          style: context.textTheme.muted,
        ),
      );
    }

    return ColoredBox(
      color: context.colorScheme.background,
      child: ListView.builder(
        itemCount: (visibleItems.length) + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: BlocklistUnblockAllButton(),
              ),
            );
          }
          final item = visibleItems[index - 1];
          return ListItemPadding(
            child: BlocklistTile(
              entry: item,
            ),
          );
        },
      ),
    );
  }
}

bool _blockMatchesQuery(BlocklistEntry item, String query) {
  final lower = query.toLowerCase();
  return item.address.toLowerCase().contains(lower);
}
