import 'package:chat/src/app.dart';
import 'package:chat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:chat/src/chats/bloc/chats_cubit.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/roster/bloc/roster_cubit.dart';
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
        final items = (state as RosterAvailable).items;
        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Text(
                'No contacts yet',
                style: context.textTheme.muted,
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              final open =
                  context.watch<ChatsCubit>().state.openJid == item.jid;
              return ShadGestureDetector(
                onTap: () => context.read<ChatsCubit>().toggleChat(item.jid),
                cursor: SystemMouseCursors.click,
                child: AxiListTile(
                  color: open ? context.colorScheme.accent : null,
                  leading: AxiAvatar(
                    jid: item.jid,
                    presence: item.subscription.isTo || item.subscription.isBoth
                        ? item.presence
                        : null,
                    status: item.status,
                  ),
                  title: item.title,
                  subtitle: item.jid,
                  actions: [
                    BlocSelector<RosterCubit, RosterState, bool>(
                      selector: (state) =>
                          state is RosterLoading && state.jid == item.jid,
                      builder: (context, disabled) {
                        return TextButton(
                          onPressed: disabled
                              ? null
                              : () => context
                                  .read<RosterCubit>()
                                  .removeContact(jid: item.jid),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orange,
                          ),
                          child: const Text('Remove'),
                        );
                      },
                    ),
                    BlocSelector<BlocklistCubit, BlocklistState, bool>(
                      selector: (state) =>
                          state is BlocklistLoading &&
                          (state.jid == item.jid || state.jid == null),
                      builder: (context, disabled) {
                        return TextButton(
                          onPressed: disabled
                              ? null
                              : () => context
                                  .read<BlocklistCubit>()
                                  .block(jid: item.jid),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Block'),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
            childCount: items.length,
          ),
        );
      },
    );
  }
}
