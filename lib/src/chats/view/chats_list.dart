import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/calendar_tile.dart';
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
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              final calendarBloc = context.read<CalendarBloc?>();
              if (calendarBloc != null) {
                return BlocBuilder<CalendarBloc, CalendarState>(
                  bloc: calendarBloc,
                  builder: (context, state) => CalendarTile(
                    onTap: () => context.go('/calendar'),
                    nextTask: state.nextTask,
                    dueReminderCount: state.dueReminders?.length ?? 0,
                  ),
                );
              } else {
                return CalendarTile(
                  onTap: () => context.go('/calendar'),
                );
              }
            }
            final item = items[index - 1];
            final locate = context.read;
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
