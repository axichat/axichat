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
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BlocklistList extends StatefulWidget {
  const BlocklistList({super.key});

  @override
  State<BlocklistList> createState() => _BlocklistListState();
}

class _BlocklistListState extends State<BlocklistList> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSearchState(context, context.read<HomeSearchCubit>().state);
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
      child: BlocBuilder<HomeSearchCubit, HomeSearchState>(
        builder: (context, _) {
          return BlocBuilder<BlocklistCubit, BlocklistState>(
            builder: (context, state) {
              final cachedItems =
                  context.select<BlocklistCubit, List<BlocklistEntry>?>(
                (cubit) =>
                    cubit[blocklistItemsCacheKey] as List<BlocklistEntry>?,
              );
              final cachedVisibleItems =
                  context.select<BlocklistCubit, List<BlocklistEntry>?>(
                (cubit) => cubit[BlocklistCubit.visibleItemsCacheKey]
                    as List<BlocklistEntry>?,
              );
              final items = state is BlocklistAvailable
                  ? (state.items ?? cachedItems)
                  : cachedItems;
              if (items == null) {
                return Center(
                  child: AxiProgressIndicator(
                    color: context.colorScheme.foreground,
                  ),
                );
              }
              final visibleItems = state is BlocklistAvailable
                  ? (state.visibleItems ?? cachedVisibleItems ?? items)
                  : (cachedVisibleItems ?? items);
              return _BlocklistListBody(items: visibleItems);
            },
          );
        },
      ),
    );
  }
}

class _BlocklistListBody extends StatelessWidget {
  const _BlocklistListBody({required this.items});

  final List<BlocklistEntry> items;

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
          return ListItemPadding(child: BlocklistTile(entry: item));
        },
      ),
    );
  }
}
