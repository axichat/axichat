import 'package:chat/src/app.dart';
import 'package:chat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:chat/src/chats/bloc/chats_cubit.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/roster/bloc/roster_cubit.dart';
import 'package:chat/src/routes.dart';
import 'package:chat/src/storage/models.dart';
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
        late List<RosterItem> items;
        if (state is! RosterAvailable) {
          items = context.read<RosterCubit>()['items'];
        } else {
          items = state.items;
        }
        if (items.isEmpty) {
          return Center(
            child: Text(
              'No contacts yet',
              style: context.textTheme.muted,
            ),
          );
        }
        return ListView.separated(
          separatorBuilder: (_, __) => const AxiListDivider(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final open = context.watch<ChatsCubit>().state.openJid == item.jid;
            return AxiListTile(
              key: Key(item.jid),
              onTap: () => context.read<ChatsCubit>().toggleChat(jid: item.jid),
              onDismissed: state is RosterLoading && state.jid == item.jid
                  ? null
                  : (_) =>
                      context.read<RosterCubit>().removeContact(jid: item.jid),
              dismissText: 'Remove ${item.jid} from contacts?',
              selected: open,
              leading: AxiAvatar(
                jid: item.jid,
                subscription: item.subscription,
                presence: item.subscription.isTo || item.subscription.isBoth
                    ? item.presence
                    : null,
                status: item.status,
              ),
              title: item.title,
              subtitle: item.jid,
              actions: [
                ShadButton.ghost(
                  onPressed: () => context.push(
                    const ComposeRoute().location,
                    extra: {
                      'locate': context.read,
                      'jids': [item.jid],
                    },
                  ),
                  foregroundColor: context.colorScheme.primary,
                  text: const Text('Draft'),
                ),
                BlocSelector<BlocklistCubit, BlocklistState, bool>(
                  selector: (state) =>
                      state is BlocklistLoading &&
                      (state.jid == item.jid || state.jid == null),
                  builder: (context, disabled) {
                    return ShadButton.ghost(
                      onPressed: disabled
                          ? null
                          : () => context
                              .read<BlocklistCubit>()
                              .block(jid: item.jid),
                      foregroundColor: context.colorScheme.destructive,
                      text: const Text('Block'),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
