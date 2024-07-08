import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';

class Chat extends StatefulWidget {
  const Chat({super.key});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final messages = <ChatMessage>[
    ChatMessage(
      user: ChatUser(id: 'axichat', firstName: 'Axichat'),
      createdAt: DateTime.now(),
      text: 'Login... unless you just want to chat to yourself.',
    )
  ];

  @override
  Widget build(BuildContext context) {
    return DashChat(
      currentUser: ChatUser(id: 'me', firstName: 'You'),
      onSend: (message) {
        setState(() {
          messages.insert(0, message);
        });
      },
      messages: messages,
      inputOptions: const InputOptions(alwaysShowSend: true),
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
    return DashChat(
      currentUser: ChatUser(id: 'me', firstName: 'You'),
      onSend: (message) {
        setState(() {
          messages.insert(0, message);
        });
      },
      messages: messages,
      inputOptions: const InputOptions(alwaysShowSend: true),
    );
  }
}
