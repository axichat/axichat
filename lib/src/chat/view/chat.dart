import 'package:chat/src/app.dart';
import 'package:chat/src/chat/bloc/chat_bloc.dart';
import 'package:chat/src/chats/bloc/chats_cubit.dart';
import 'package:chat/src/common/policy.dart';
import 'package:chat/src/profile/bloc/profile_cubit.dart';
import 'package:chat/src/settings/bloc/settings_cubit.dart';
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

  void _typingListener() {
    if (!context.read<SettingsCubit>().state.indicateTyping) return;
    if (_textController.text.isEmpty) return;
    context.read<ChatBloc>().add(const ChatTypingStarted());
  }

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
              scrolledUnderElevation: 0.0,
              shape: Border(
                bottom: BorderSide(color: context.colorScheme.border),
              ),
              leading: Padding(
                padding: const EdgeInsets.all(4.0),
                child: ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  icon: const Icon(
                    LucideIcons.arrowLeft,
                    size: 20.0,
                  ),
                  onPressed: () =>
                      context.read<ChatsCubit>().toggleChat(state.chat!.jid),
                ),
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
                messagePadding: const EdgeInsets.all(7.0),
                messageTextBuilder: (message, _, __) {
                  final extraStyle = context.textTheme.muted.copyWith(
                    fontStyle: FontStyle.italic,
                  );
                  final self = message.user.id == profile.jid;
                  final textColor = self
                      ? context.colorScheme.primaryForeground
                      : Colors.black;
                  const iconSize = 9.0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SelectableText(
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
                      if (self)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Icon(
                            message.status!.icon,
                            color: context.colorScheme.primaryForeground,
                            size: iconSize,
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
                sendButtonBuilder: (send) => ShadButton.ghost(
                  icon: const Icon(
                    Icons.send,
                  ),
                  onPressed: send,
                ),
                inputDecoration: defaultInputDecoration().copyWith(
                  fillColor: context.colorScheme.input,
                  border: OutlineInputBorder(
                    borderRadius: context.radius,
                    borderSide: const BorderSide(
                      width: 0.0,
                      style: BorderStyle.none,
                    ),
                  ),
                ),
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
      text: 'Open a chat! Unless you just want to talk to yourself.',
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
        onSend: (message) => setState(() {
          messages.insert(0, message);
        }),
        messages: messages,
        inputOptions: const InputOptions(alwaysShowSend: true),
      ),
    );
  }
}
