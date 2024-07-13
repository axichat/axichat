import 'package:chat/src/app.dart';
import 'package:chat/src/chat/bloc/chat_bloc.dart';
import 'package:chat/src/common/policy.dart';
import 'package:chat/src/profile/bloc/profile_cubit.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

extension on MessageStatus {
  IconData get icon => switch (this) {
        MessageStatus.read ||
        MessageStatus.received ||
        MessageStatus.sent =>
          LucideIcons.check,
        MessageStatus.failed => LucideIcons.x,
        _ => LucideIcons.dot,
      };
}

class Chat extends StatefulWidget {
  const Chat({super.key});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final _textController = TextEditingController();
  final _popoverController = ShadPopoverController();

  void _typingListener() =>
      context.read<ChatBloc>().add(const ChatTypingStarted());

  @override
  void initState() {
    super.initState();
    _textController.addListener(_typingListener);
  }

  @override
  void dispose() {
    _textController.removeListener(_typingListener);
    _textController.dispose();
    _popoverController.dispose();
    super.dispose();
  }

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
          final profile = context.watch<ProfileCubit>().state;
          final user = ChatUser(
            id: profile.jid,
            firstName: profile.title,
          );
          return Scaffold(
            appBar: AppBar(
              shape: Border(
                bottom: BorderSide(color: context.colorScheme.border),
              ),
              title: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(state.chat?.title ?? ''),
              ),
            ),
            body: DashChat(
              currentUser: user,
              onSend: (message) {
                context
                    .read<ChatBloc>()
                    .add(ChatMessageSent(text: message.text));
              },
              messages: state.items.reversed
                  .map(
                    (e) => ChatMessage(
                      user: ChatUser(
                          id: e.senderJid, firstName: state.chat?.title),
                      createdAt: e.timestamp!,
                      text: e.body ?? '',
                      status: e.error.isNotNone
                          ? MessageStatus.failed
                          : e.received
                              ? MessageStatus.received
                              : e.acked
                                  ? MessageStatus.sent
                                  : MessageStatus.pending,
                      customProperties: {
                        'edited': e.edited,
                        'retracted': e.retracted
                      },
                    ),
                  )
                  .toList(),
              messageOptions: MessageOptions(
                borderRadius: 8,
                messageTextBuilder: (message, _, __) {
                  final extraStyle = context.textTheme.muted.copyWith(
                    fontStyle: FontStyle.italic,
                  );
                  final self = message.user.id == profile.jid;
                  final textColor = self
                      ? context.colorScheme.primaryForeground
                      : Colors.black;
                  const iconSize = 8.0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.text,
                            style: TextStyle(color: textColor),
                          ),
                          if (message.customProperties?['retracted'] ?? false)
                            Text(
                              '(retracted)',
                              style: extraStyle,
                            )
                          else if (message.customProperties?['edited'] ?? false)
                            Text('(edited)', style: extraStyle),
                        ],
                      ),
                      if (self)
                        Positioned(
                          right: -iconSize,
                          bottom: -iconSize,
                          width: iconSize,
                          height: iconSize,
                          child: Icon(
                            message.status!.icon,
                            color: context.colorScheme.primaryForeground,
                            size: iconSize,
                            weight: 1.0,
                          ),
                        ),
                    ],
                  );
                },
              ),
              inputOptions: InputOptions(
                sendOnEnter: true,
                alwaysShowSend: true,
                textController: _textController,
                leading: [
                  ShadPopover(
                    controller: _popoverController,
                    child: ShadButton.ghost(
                      onPressed: _popoverController.toggle,
                      icon: const Icon(LucideIcons.smile),
                    ),
                    popover: (context) => EmojiPicker(
                      textEditingController: _textController,
                      config: Config(
                        height: 256,
                        checkPlatformCompatibility: true,
                        emojiViewConfig: EmojiViewConfig(
                          emojiSizeMax:
                              context.read<Policy>().getMaxEmojiSize(),
                        ),
                        swapCategoryAndBottomBar: false,
                        skinToneConfig: const SkinToneConfig(),
                        categoryViewConfig: const CategoryViewConfig(),
                        bottomActionBarConfig: const BottomActionBarConfig(),
                        searchViewConfig: const SearchViewConfig(),
                      ),
                    ),
                  )
                ],
              ),
              typingUsers: [
                if (state.typing == true) user,
                if (state.chat?.chatState?.name == 'composing')
                  ChatUser(id: state.chat!.jid, firstName: state.chat!.title)
              ],
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
