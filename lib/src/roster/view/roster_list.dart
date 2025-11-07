import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/view/block_menu_item.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
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

        if (items.isEmpty) {
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
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items![index];
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
                    presence: item.subscription.isTo || item.subscription.isBoth
                        ? item.presence
                        : null,
                    status: item.status,
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
