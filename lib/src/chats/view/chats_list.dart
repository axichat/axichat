import 'package:chat/src/app.dart';
import 'package:chat/src/chats/bloc/chats_cubit.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatsList extends StatelessWidget {
  const ChatsList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChatsCubit, ChatsState, List<Chat>>(
      selector: (state) => state.items,
      builder: (context, items) {
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
            return AxiBadge(
              count: item.unreadCount,
              offset: const Offset(-5, 10),
              child: AxiListTile(
                key: Key(item.jid),
                onTap: () =>
                    context.read<ChatsCubit>().toggleChat(jid: item.jid),
                onDismissed: (_) =>
                    context.read<ChatsCubit>().deleteChat(jid: item.jid),
                dismissText: 'Delete chat: ${item.title}?',
                selected: item.open,
                leading: AxiAvatar(
                  jid: item.jid,
                ),
                title: item.title,
                subtitle: item.lastMessage,
                actions: [
                  DisplayTimeSince(timestamp: item.lastChangeTimestamp),
                  ShadButton.ghost(
                    width: 30.0,
                    height: 30.0,
                    icon: Icon(
                      item.favourited
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 22.0,
                    ),
                    onPressed: () =>
                        context.read<ChatsCubit>().toggleFavourited(
                              jid: item.jid,
                              favourited: !item.favourited,
                            ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
