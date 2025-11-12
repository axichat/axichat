import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatMessageDetails extends StatelessWidget {
  const ChatMessageDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final message = state.focused;
        if (message == null) return const SizedBox.shrink();
        final profileState = context.read<ProfileCubit>().state;
        final shareParticipants = _shareParticipants(
          state.shareContexts[message.stanzaID]?.participants ?? const <Chat>[],
          state.chat?.jid,
          profileState.jid,
        );
        return SingleChildScrollView(
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              spacing: 24,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SelectableText(
                  message.body ?? '',
                  style: context.textTheme.lead,
                ),
                if (shareParticipants.isNotEmpty)
                  Column(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Also sent to',
                        style: context.textTheme.muted,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final participant in shareParticipants)
                            ActionChip(
                              avatar: const Icon(Icons.mail_outline, size: 16),
                              label: Text(participant.title),
                              onPressed: () => context
                                  .read<ChatsCubit>()
                                  .toggleChat(jid: participant.jid),
                            ),
                        ],
                      ),
                    ],
                  ),
                Wrap(
                  spacing: 12.0,
                  children: [
                    ShadBadge.secondary(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        spacing: 6.0,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Sent'),
                          Icon(
                            message.acked.toIcon,
                            color: message.acked.toColor,
                          ),
                        ],
                      ),
                    ),
                    ShadBadge.secondary(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        spacing: 6.0,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Received'),
                          Icon(
                            message.received.toIcon,
                            color: message.received.toColor,
                          ),
                        ],
                      ),
                    ),
                    ShadBadge.secondary(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        spacing: 6.0,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Displayed'),
                          Icon(
                            message.displayed.toIcon,
                            color: message.displayed.toColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (message.deviceID != null)
                  Column(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Encrypted device',
                        style: context.textTheme.muted,
                      ),
                      Text('#${message.deviceID}'),
                    ],
                  )
                else
                  const Text('Not encrypted'),
                if (message.error.isNotNone)
                  Column(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Error',
                        style: context.textTheme.muted,
                      ),
                      Text(message.error.asString),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Chat> _shareParticipants(
    List<Chat> participants,
    String? chatJid,
    String? selfJid,
  ) {
    if (participants.isEmpty) {
      return const <Chat>[];
    }
    return participants.where((participant) {
      final jid = participant.jid;
      if (chatJid != null && jid == chatJid) {
        return false;
      }
      if (selfJid != null && jid == selfJid) {
        return false;
      }
      return true;
    }).toList();
  }
}
