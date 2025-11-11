import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/blocklist/view/blocklist_button.dart';
import 'package:axichat/src/blocklist/view/blocklist_tile.dart';
import 'package:axichat/src/common/ui/ui.dart';
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

        if (items.isEmpty) {
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
              final item = items![index - 1];
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
