import 'package:chat/main.dart';
import 'package:chat/src/blocklist/bloc/blocklist_bloc.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/roster/bloc/roster_bloc.dart';
import 'package:chat/src/roster/view/roster_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RosterList extends StatelessWidget {
  const RosterList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<RosterBloc, RosterState, List<RosterItem>>(
      selector: (state) => state.items,
      builder: (context, items) {
        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Text(
                'No contacts yet',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              return RosterCard(
                content: ListTile(
                  leading: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 50.0,
                      maxWidth: 50.0,
                    ),
                    child: AxiAvatar(
                      jid: item.jid,
                      presence:
                          item.subscription.isTo || item.subscription.isBoth
                              ? item.presence
                              : null,
                      status: item.status,
                    ),
                  ),
                  title: Text(item.title),
                  subtitle: Text(item.jid),
                  titleAlignment: ListTileTitleAlignment.titleHeight,
                  minTileHeight: 80.0,
                ),
                buttons: [
                  BlocSelector<RosterBloc, RosterState, bool>(
                    selector: (state) =>
                        state is RosterLoading && state.jid == item.jid,
                    builder: (context, disabled) {
                      return TextButton(
                        onPressed: disabled
                            ? null
                            : () => context
                                .read<RosterBloc>()
                                .add(RosterSubscriptionRemoved(jid: item.jid)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                        child: const Text('Remove'),
                      );
                    },
                  ),
                  BlocSelector<BlocklistBloc, BlocklistState, bool>(
                    selector: (state) =>
                        state is BlocklistLoading &&
                        (state.jid == item.jid || state.jid == null),
                    builder: (context, disabled) {
                      return TextButton(
                        onPressed: disabled
                            ? null
                            : () => context
                                .read<BlocklistBloc>()
                                .add(BlocklistBlocked(jid: item.jid)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Block'),
                      );
                    },
                  ),
                ],
              );
            },
            childCount: items.length,
          ),
        );
      },
    );
  }
}
