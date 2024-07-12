import 'package:chat/src/app.dart';
import 'package:chat/src/chat/bloc/chat_bloc.dart';
import 'package:chat/src/profile/bloc/profile_cubit.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class Chat extends StatelessWidget {
  const Chat({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: context.colorScheme.border, width: 1.0),
        ),
      ),
      child: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          return DashChat(
            currentUser: ChatUser(
              id: context.watch<ProfileCubit>().state.jid,
              firstName: context.watch<ProfileCubit>().state.title,
            ),
            onSend: (message) {},
            messages: state.items.reversed
                .map((e) => ChatMessage(
                      user: ChatUser(id: e.senderJid, firstName: e.senderJid),
                      createdAt: e.timestamp!,
                      text: e.body ?? '',
                    ))
                .toList(),
            messageOptions: MessageOptions(
              borderRadius: 8,
              messageTextBuilder: (message, _, __) {
                return Text(message.text);
              },
            ),
            inputOptions: const InputOptions(
              sendOnEnter: true,
              alwaysShowSend: true,
            ),
          );
        },
      ),
    );
  }
}

class GuestChat extends StatefulWidget {
  const GuestChat({super.key});

  @override
  State<GuestChat> createState() => _GuestChatState();
}

class _GuestChatState extends State<GuestChat> {
  final messages = <ChatMessage>[
    ChatMessage(
      user: ChatUser(id: 'axichat', firstName: 'Axichat'),
      createdAt: DateTime.now(),
      text: 'Login... unless you just want to chat to yourself.',
    )
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: context.colorScheme.border, width: 1.0),
        ),
      ),
      child: DashChat(
        currentUser: ChatUser(id: 'me', firstName: 'You'),
        onSend: (message) {
          setState(() {
            messages.insert(0, message);
          });
        },
        messages: messages,
        inputOptions: const InputOptions(alwaysShowSend: true),
      ),
    );
  }
}
