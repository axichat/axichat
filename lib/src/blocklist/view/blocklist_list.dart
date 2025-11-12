import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/blocklist/view/blocklist_button.dart';
import 'package:axichat/src/blocklist/view/blocklist_tile.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BlocklistList extends StatelessWidget {
  const BlocklistList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BlocklistCubit, BlocklistState>(
      buildWhen: (_, current) => current is BlocklistAvailable,
      builder: (context, state) {
        late final List<BlocklistData>? items;

        if (state is! BlocklistAvailable) {
          items = context.read<BlocklistCubit>()['items'];
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

        final searchState = context.watch<HomeSearchCubit?>()?.state;
        final tabState = searchState?.stateFor(HomeTab.blocked);
        final searchActive = searchState?.active ?? false;
        final query =
            searchActive ? (tabState?.query.trim().toLowerCase() ?? '') : '';
        final sortOrder = tabState?.sort ?? SearchSortOrder.newestFirst;

        var visibleItems = List<BlocklistData>.from(items);

        if (query.isNotEmpty) {
          visibleItems = visibleItems
              .where((item) => _blockMatchesQuery(item, query))
              .toList();
        }

        visibleItems.sort(
          (a, b) => sortOrder.isNewestFirst
              ? a.jid.toLowerCase().compareTo(b.jid.toLowerCase())
              : b.jid.toLowerCase().compareTo(a.jid.toLowerCase()),
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
                  jid: item.jid,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

bool _blockMatchesQuery(BlocklistData item, String query) {
  final lower = query.toLowerCase();
  return item.jid.toLowerCase().contains(lower);
}
