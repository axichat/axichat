import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/transport.dart';
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

        return ColoredBox(
          color: context.colorScheme.background,
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final locate = context.read;
              final transport = item.transport;
              return ListItemPadding(
                child: AxiListTile(
                  key: Key(item.jid),
                  badgeCount: item.unreadCount,
                  onTap: () =>
                      context.read<ChatsCubit?>()?.toggleChat(jid: item.jid),
                  leadingConstraints: const BoxConstraints(
                    maxWidth: 72,
                    maxHeight: 80,
                  ),
                  menuItems: [
                    AxiDeleteMenuItem(
                      onPressed: () => showShadDialog<bool>(
                        context: context,
                        builder: (context) {
                          var deleteMessages = false;
                          return StatefulBuilder(builder: (context, setState) {
                            return ShadDialog(
                              title: const Text('Confirm'),
                              actions: [
                                ShadButton.outline(
                                  onPressed: () => context.pop(),
                                  child: const Text('Cancel'),
                                ),
                                ShadButton.destructive(
                                  onPressed: () {
                                    if (deleteMessages) {
                                      locate<ChatsCubit?>()
                                          ?.deleteChatMessages(jid: item.jid);
                                    }
                                    locate<ChatsCubit?>()
                                        ?.deleteChat(jid: item.jid);
                                    return context.pop();
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
                    ),
                  ],
                  selected: item.open,
                  leading: _TransportAwareAvatar(
                    jid: item.jid,
                    transport: transport,
                  ),
                  title: item.title,
                  subtitle: item.lastMessage,
                  subtitlePlaceholder: 'No messages',
                  actions: [
                    if (item.lastMessage != null)
                      DisplayTimeSince(timestamp: item.lastChangeTimestamp),
                    ShadIconButton.ghost(
                      icon: Icon(
                        item.favorited
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                      ),
                      onPressed: () =>
                          context.read<ChatsCubit?>()?.toggleFavorited(
                                jid: item.jid,
                                favorited: !item.favorited,
                              ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TransportAwareAvatar extends StatelessWidget {
  const _TransportAwareAvatar({
    required this.jid,
    required this.transport,
  });

  final String jid;
  final MessageTransport transport;

  @override
  Widget build(BuildContext context) {
    const avatarSize = 46.0;
    return SizedBox(
      width: avatarSize + 6,
      height: avatarSize + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AxiAvatar(
              jid: jid,
              shape: AxiAvatarShape.circle,
              size: avatarSize,
            ),
          ),
          Positioned(
            right: -6,
            bottom: -4,
            child: AxiTransportChip(
              transport: transport,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}
