import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SpamList extends StatelessWidget {
  const SpamList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChatsCubit, ChatsState, List<Chat>?>(
      selector: (state) {
        final items = state.items;
        if (items == null) return null;
        return items.where((chat) => chat.spam).toList();
      },
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
              'No spam conversations',
              style: context.textTheme.muted,
            ),
          );
        }

        return ColoredBox(
          color: context.colorScheme.background,
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final chat = items[index];
              return ListItemPadding(
                child: AxiListTile(
                  key: Key(chat.jid),
                  onTap: () =>
                      context.read<ChatsCubit?>()?.toggleChat(jid: chat.jid),
                  leading: AxiAvatar(
                    jid: chat.jid,
                    shape: AxiAvatarShape.circle,
                  ),
                  title: chat.title,
                  subtitle: chat.lastMessage ?? chat.jid,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
