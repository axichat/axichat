import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/view/block_button_inline.dart';
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

        return ListView.separated(
          separatorBuilder: (_, __) => const AxiListDivider(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items![index];
            final open =
                context.watch<ChatsCubit?>()?.state.openJid == item.jid;
            return AxiListTile(
              key: Key(item.jid),
              onTap: () =>
                  context.read<ChatsCubit?>()?.toggleChat(jid: item.jid),
              onDismissed: state is RosterLoading && state.jid == item.jid
                  ? null
                  : (_) => context
                      .read<RosterCubit?>()
                      ?.removeContact(jid: item.jid),
              confirmDismiss: (_) => confirm(
                context,
                text: 'Remove ${item.jid} from contacts?',
              ),
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
                AxiMore(
                  options: [
                    (toggle) => ShadButton.ghost(
                          width: double.infinity,
                          child: const Text('Draft'),
                          onPressed: () => context.push(
                            const ComposeRoute().location,
                            extra: {
                              'locate': context.read,
                              'jids': [item.jid],
                            },
                          ),
                        ),
                    (toggle) => BlockButtonInline(
                          jid: item.jid,
                          callback: toggle,
                        ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
