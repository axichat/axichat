import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatsList extends StatelessWidget {
  const ChatsList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChatsCubit, ChatsState, List<Chat>?>(
      selector: (state) => state.items?.where(state.filter).toList(),
      builder: (context, items) {
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
              'No chats yet',
              style: context.textTheme.muted,
            ),
          );
        }

        return ListView.separated(
          separatorBuilder: (_, __) => const AxiListDivider(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final locate = context.read;
            return AxiListTile(
              key: Key(item.jid),
              badgeCount: item.unreadCount,
              onTap: () => locate<ChatsCubit?>()?.toggleChat(jid: item.jid),
              onDismissed: (_) =>
                  locate<ChatsCubit?>()?.deleteChat(jid: item.jid),
              confirmDismiss: (_) => showShadDialog<bool>(
                context: context,
                builder: (context) {
                  var deleteMessages = false;
                  return StatefulBuilder(builder: (context, setState) {
                    return ShadDialog(
                      title: const Text('Confirm'),
                      actions: [
                        ShadButton.outline(
                          onPressed: () => context.pop(false),
                          child: const Text('Cancel'),
                        ),
                        ShadButton.destructive(
                          onPressed: () {
                            if (deleteMessages) {
                              locate<ChatsCubit?>()
                                  ?.deleteChatMessages(jid: item.jid);
                            }
                            return context.pop(true);
                          },
                          child: const Text('Continue'),
                        )
                      ],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete chat: ${item.title}',
                            style: context.textTheme.small,
                          ),
                          const SizedBox.square(dimension: 10.0),
                          ShadCheckbox(
                            value: deleteMessages,
                            onChanged: (value) =>
                                setState(() => deleteMessages = value),
                            label: Text(
                              'Permanently delete messages',
                              style: context.textTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    );
                  });
                },
              ),
              selected: item.open,
              leading: AxiAvatar(
                jid: item.jid,
              ),
              title: item.title,
              subtitle: item.lastMessage,
              subtitlePlaceholder: 'No messages',
              actions: [
                item.lastMessage == null
                    ? const SizedBox()
                    : DisplayTimeSince(timestamp: item.lastChangeTimestamp),
                ShadIconButton.ghost(
                  icon: Icon(
                    item.favorited
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                  ),
                  onPressed: () => context.read<ChatsCubit?>()?.toggleFavorited(
                        jid: item.jid,
                        favorited: !item.favorited,
                      ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
