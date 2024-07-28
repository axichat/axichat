import 'package:chat/src/app.dart';
import 'package:chat/src/chat/bloc/chat_bloc.dart';
import 'package:chat/src/chats/bloc/chats_cubit.dart';
import 'package:chat/src/common/policy.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/profile/bloc/profile_cubit.dart';
import 'package:chat/src/settings/bloc/settings_cubit.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _emojiPopoverController = ShadPopoverController();
  late FocusNode _focusNode;
  late TextEditingController _textController;

  void _typingListener() {
    if (!context.read<SettingsCubit>().state.indicateTyping) return;
    if (_textController.text.isEmpty) return;
    context.read<ChatBloc>().add(const ChatTypingStarted());
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _textController = TextEditingController();
    _textController.addListener(_typingListener);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.removeListener(_typingListener);
    _textController.dispose();
    _emojiPopoverController.dispose();
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
      child: BlocConsumer<ChatBloc, ChatState>(
        listener: (context, state) async {
          if (state.focused == null) return;
          final message = state.focused!;
          await showShadDialog(
            context: context,
            builder: (context) {
              const iconSize = 24.0;
              var copied = false;
              return StatefulBuilder(
                builder: (context, setState) {
                  return ShadDialog(
                    title: Text(message.stanzaID),
                    content: Column(
                      children: [
                        Row(
                          children: [
                            SelectableText.rich(
                              TextSpan(
                                text: 'Body: ',
                                style: context.textTheme.muted,
                                children: [
                                  TextSpan(
                                    text: message.body,
                                    style: context.textTheme.small,
                                  )
                                ],
                              ),
                            ),
                            ShadButton.ghost(
                              width: iconSize + 8,
                              height: iconSize + 8,
                              icon: const Icon(
                                LucideIcons.copy,
                                size: iconSize,
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: message.body ?? ''));
                                setState(() {
                                  copied = true;
                                });
                              },
                            ),
                            if (copied)
                              const Text(
                                'Copied!',
                                style: TextStyle(color: Colors.greenAccent),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('Sent: ${message.acked || message.received}'),
                            AxiTooltip(
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(
                                  LucideIcons.info,
                                  size: iconSize,
                                ),
                              ),
                              builder: (context) {
                                return ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 300.0),
                                  child: const Text(
                                    'If false, the message may still have '
                                    'been received but server acknowledgement '
                                    'was disabled. Logging out and back in may '
                                    'solve the problem.',
                                    textAlign: TextAlign.left,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('Error: ${message.error.name}'),
                            if (message.error.tooltip != null)
                              AxiTooltip(
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    LucideIcons.info,
                                    size: iconSize,
                                  ),
                                ),
                                builder: (context) {
                                  return ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 300.0),
                                    child: Text(
                                      message.error.tooltip!,
                                      textAlign: TextAlign.left,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
          if (context.mounted) {
            context.read<ChatBloc>().add(const ChatMessageUnfocused());
          }
        },
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
            body: LayoutBuilder(
              builder: (context, constraints) => DashChat(
                currentUser: user,
                onSend: (message) {
                  context
                      .read<ChatBloc>()
                      .add(ChatMessageSent(text: message.text));
                  _focusNode.requestFocus();
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
                          'id': e.stanzaID,
                          'edited': e.edited,
                          'retracted': e.retracted,
                          'error': e.error,
                        },
                      ),
                    )
                    .toList(),
                messageOptions: MessageOptions(
                  borderRadius: 8,
                  maxWidth: constraints.maxWidth,
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
                    return ShadGestureDetector(
                      cursor: SystemMouseCursors.click,
                      onTap: !self
                          ? null
                          : () => context.read<ChatBloc>().add(
                              ChatMessageFocused(
                                  message.customProperties!['id'])),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          self
                              ? Text(
                                  message.text,
                                  style: TextStyle(color: textColor),
                                )
                              : SelectableText(
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
                      ),
                    );
                  },
                ),
                messageListOptions: const MessageListOptions(
                  separatorFrequency: SeparatorFrequency.hours,
                ),
                inputOptions: InputOptions(
                  sendOnEnter: true,
                  alwaysShowSend: true,
                  focusNode: _focusNode,
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
                      controller: _emojiPopoverController,
                      child: ShadButton.ghost(
                        onPressed: _emojiPopoverController.toggle,
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
