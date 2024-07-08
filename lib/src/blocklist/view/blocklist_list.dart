import 'package:chat/main.dart';
import 'package:chat/src/blocklist/bloc/blocklist_bloc.dart';
import 'package:chat/src/blocklist/view/blocklist_button.dart';
import 'package:chat/src/blocklist/view/blocklist_tile.dart';
import 'package:chat/src/storage/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BlocklistList extends StatelessWidget {
  const BlocklistList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BlocklistBloc, BlocklistState, List<BlocklistData>>(
      selector: (state) => state.items,
      builder: (context, items) {
        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Text(
                'Nobody blocked',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == 0) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: BlocklistUnblockAllButton(),
                  ),
                );
              }
              final item = items[index - 1];
              return BlocklistTile(
                jid: item.jid,
              );
            },
            childCount: items.length + 1,
          ),
        );
      },
    );
  }
}
