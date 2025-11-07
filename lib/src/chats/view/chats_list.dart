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

        return ListView.separated(
          separatorBuilder: (_, __) => const AxiListDivider(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final locate = context.read;
            final transport = item.transport;
            return AxiListTile(
              key: Key(item.jid),
              badgeCount: item.unreadCount,
              onTap: () =>
                  context.read<ChatsCubit?>()?.toggleChat(jid: item.jid),
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
              leading: AxiAvatar(
                jid: item.jid,
              ),
              title: item.title,
              subtitle: item.lastMessage,
              subtitlePlaceholder: 'No messages',
              actions: [
                _TransportLabel(transport: transport),
                if (item.lastMessage != null)
                  DisplayTimeSince(timestamp: item.lastChangeTimestamp),
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

class _TransportLabel extends StatelessWidget {
  const _TransportLabel({required this.transport});

  final MessageTransport transport;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final background = transport.isEmail
        ? colors.destructive.withValues(alpha: 0.12)
        : colors.accent.withValues(alpha: 0.12);
    final defaultMutedColor = context.textTheme.muted.color ??
        colors.foreground.withValues(alpha: 0.7);
    final foreground =
        transport.isEmail ? colors.destructive : defaultMutedColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        transport.label,
        style: context.textTheme.muted.copyWith(
          fontWeight: FontWeight.w600,
          color: foreground,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
