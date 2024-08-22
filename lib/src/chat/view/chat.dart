import 'package:chat/src/app.dart';
import 'package:chat/src/chat/bloc/chat_bloc.dart';
import 'package:chat/src/chats/bloc/chats_cubit.dart';
import 'package:chat/src/common/policy.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/draft/bloc/draft_cubit.dart';
import 'package:chat/src/profile/bloc/profile_cubit.dart';
import 'package:chat/src/roster/bloc/roster_cubit.dart';
import 'package:chat/src/settings/bloc/settings_cubit.dart';
import 'package:chat/src/storage/models.dart';
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
    return Material(
      child: Container(
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
                var copied = false;
                return StatefulBuilder(
                  builder: (context, setState) {
                    return ShadDialog(
                      gap: 16.0,
                      title: Text(message.stanzaID),
                      content: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Row(
                                  textBaseline: TextBaseline.alphabetic,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  children: [
                                    Text(
                                      'Body: ',
                                      style: context.textTheme.muted,
                                    ),
                                    Expanded(
                                      child: SelectableText(
                                        message.body ?? '',
                                        style: context.textTheme.small,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ShadButton.ghost(
                                icon: const Icon(
                                  LucideIcons.copy,
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
                          Divider(
                            thickness: 1,
                            color: context.colorScheme.border,
                          ),
                          Row(
                            children: [
                              Text(
                                  'Sent: ${message.acked || message.received ? 'true' : 'unknown'}'),
                              AxiTooltip(
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    LucideIcons.info,
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
                          Divider(
                            thickness: 1,
                            color: context.colorScheme.border,
                          ),
                          Row(
                            children: [
                              Text(
                                  'Encrypted: ${message.encryptionProtocol.isNotNone}'),
                            ],
                          ),
                          Divider(
                            thickness: 1,
                            color: context.colorScheme.border,
                          ),
                          Row(
                            children: [
                              Text('Error: ${message.error.name}'),
                              if (message.error.tooltip != null)
                                AxiTooltip(
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      LucideIcons.info,
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
            final chatType = state.chat?.type;
            final jid = state.chat?.jid;
            return Column(
              children: [
                Container(
                  height: 56.0,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: context.colorScheme.border),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShadButton.ghost(
                        size: ShadButtonSize.sm,
                        icon: const Icon(
                          LucideIcons.arrowLeft,
                          size: 20.0,
                        ),
                        onPressed: () {
                          if (_textController.text.isNotEmpty) {
                            context.read<DraftCubit>().saveDraft(
                                id: null,
                                jids: [state.chat!.jid],
                                body: _textController.text);
                          }
                          context
                              .read<ChatsCubit>()
                              .toggleChat(jid: state.chat!.jid);
                        },
                      ),
                      jid == null
                          ? const SizedBox.shrink()
                          : Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: BlocBuilder<RosterCubit, RosterState>(
                                  buildWhen: (_, current) =>
                                      current is RosterAvailable,
                                  builder: (context, rosterState) {
                                    final item =
                                        (rosterState is! RosterAvailable
                                                ? context.read<RosterCubit>()[
                                                    'items'] as List<RosterItem>
                                                : rosterState.items)
                                            .where((e) => e.jid == jid)
                                            .singleOrNull;
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 40.0,
                                            maxHeight: 40.0,
                                          ),
                                          child: (item == null)
                                              ? AxiAvatar(jid: jid)
                                              : AxiAvatar(
                                                  jid: item.jid,
                                                  subscription:
                                                      item.subscription,
                                                  presence: item.presence,
                                                  status: item.status,
                                                ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                          ),
                                          child: Text(
                                            state.chat?.title ?? '',
                                            style: context.textTheme.h4,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item?.status ?? '',
                                            overflow: TextOverflow.ellipsis,
                                            style: context.textTheme.muted,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => DashChat(
                      currentUser: user,
                      onSend: (message) {
                        context
                            .read<ChatBloc>()
                            .add(ChatMessageSent(text: message.text));
                        _focusNode.requestFocus();
                      },
                      messages: state.items
                          .map(
                            (e) => ChatMessage(
                              user: ChatUser(
                                  id: e.senderJid,
                                  firstName: state.chat?.title),
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
                                'encrypted': e.encryptionProtocol.isNotNone,
                              },
                            ),
                          )
                          .toList(),
                      messageOptions: MessageOptions(
                        showOtherUsersAvatar: chatType == ChatType.groupChat,
                        borderRadius: 8,
                        maxWidth: constraints.maxWidth * 0.7,
                        messagePadding: const EdgeInsets.all(7.0),
                        currentUserContainerColor: context.colorScheme.primary,
                        containerColor: context.colorScheme.muted,
                        userNameBuilder: (user) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(left: 2.0, bottom: 2.0),
                            child: Text(
                              user.getFullName(),
                              style: context.textTheme.muted
                                  .copyWith(fontSize: 12.0),
                            ),
                          );
                        },
                        messageTextBuilder: (message, _, __) {
                          final extraStyle = context.textTheme.muted.copyWith(
                            fontStyle: FontStyle.italic,
                          );
                          final self = message.user.id == profile.jid;
                          final textColor = self
                              ? context.colorScheme.primaryForeground
                              : null;
                          const iconSize = 12.0;
                          final iconFamily = message.status!.icon.fontFamily;
                          final iconPackage = message.status!.icon.fontPackage;
                          return ShadGestureDetector(
                            cursor: SystemMouseCursors.click,
                            onTap: () => context.read<ChatBloc>().add(
                                ChatMessageFocused(
                                    message.customProperties!['id'])),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DynamicInlineText(
                                  key: UniqueKey(),
                                  text: TextSpan(
                                    text: message.text,
                                    style: context.textTheme.small
                                        .copyWith(color: textColor),
                                  ),
                                  details: [
                                    TextSpan(
                                      text:
                                          '${message.createdAt.hour.toString().padLeft(2, '0')}:'
                                          '${message.createdAt.minute.toString().padLeft(2, '0')}'
                                          '${message.createdAt.hour < 12 ? 'am' : 'pm'}',
                                      style: context.textTheme.muted.copyWith(
                                        color: textColor,
                                        fontSize: iconSize,
                                      ),
                                    ),
                                    if (self)
                                      TextSpan(
                                        text: String.fromCharCode(
                                            message.status!.icon.codePoint),
                                        style: TextStyle(
                                          color: context
                                              .colorScheme.primaryForeground,
                                          fontSize: iconSize,
                                          fontFamily: iconFamily,
                                          package: iconPackage,
                                        ),
                                      ),
                                    // TextSpan(
                                    //   text: String.fromCharCode(
                                    //       (message.customProperties![
                                    //                   'encrypted']
                                    //               ? LucideIcons.lock
                                    //               : LucideIcons.lockOpen)
                                    //           .codePoint),
                                    //   style: context.textTheme.muted.copyWith(
                                    //     color: message
                                    //             .customProperties!['encrypted']
                                    //         ? textColor
                                    //         : context.colorScheme.destructive,
                                    //     fontSize: iconSize,
                                    //     fontFamily: iconFamily,
                                    //     package: iconPackage,
                                    //   ),
                                    // )
                                  ],
                                ),
                                if (message.customProperties?['retracted'] ??
                                    false)
                                  Text(
                                    '(retracted)',
                                    style: extraStyle,
                                  )
                                else if (message.customProperties?['edited'] ??
                                    false)
                                  Text('(edited)', style: extraStyle),
                              ],
                            ),
                          );
                        },
                      ),
                      messageListOptions: MessageListOptions(
                        separatorFrequency: SeparatorFrequency.days,
                        typingBuilder: (_) => const Padding(
                          padding: EdgeInsets.only(left: 16, top: 24),
                          child: TypingIndicator(),
                        ),
                        onLoadEarlier:
                            state.items.length % ChatBloc.messageBatchSize != 0
                                ? null
                                : () async => context
                                    .read<ChatBloc>()
                                    .add(const ChatLoadEarlier()),
                        loadEarlierBuilder: Container(
                          padding: const EdgeInsets.all(12.0),
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            color: context.colorScheme.primary,
                          ),
                        ),
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
                        inputToolbarStyle: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: context.colorScheme.border),
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
                                bottomActionBarConfig:
                                    const BottomActionBarConfig(),
                                searchViewConfig: const SearchViewConfig(),
                              ),
                            ),
                          )
                        ],
                        showTraillingBeforeSend: true,
                        // trailing: [
                        //   if (state.chat case final chat?) ...[
                        //     ShadButton.ghost(
                        //       onPressed: () => context.push(
                        //         '/encryption/${chat.jid}',
                        //         extra: context.read,
                        //       ),
                        //       foregroundColor: chat.encryptionProtocol.isNotNone
                        //           ? context.colorScheme.primary
                        //           : context.colorScheme.destructive,
                        //       icon: Icon(
                        //         chat.encryptionProtocol.isNotNone
                        //             ? LucideIcons.lockKeyhole
                        //             : LucideIcons.lockKeyholeOpen,
                        //       ),
                        //     ),
                        //   ]
                        // ],
                      ),
                      typingUsers: [
                        if (state.typing == true) user,
                        if (state.chat?.chatState?.name == 'composing')
                          ChatUser(
                            id: state.chat!.jid,
                            firstName: state.chat!.title,
                          )
                      ].take(1).toList(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
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
  final _emojiPopoverController = ShadPopoverController();
  final _encryptionPopoverController = ShadPopoverController();
  late FocusNode _focusNode;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    _emojiPopoverController.dispose();
    _encryptionPopoverController.dispose();
    super.dispose();
  }

  final user = ChatUser(id: 'me', firstName: 'You');

  final messages = <ChatMessage>[
    ChatMessage(
      user: ChatUser(id: 'axichat', firstName: appDisplayName),
      createdAt: DateTime.now(),
      text: 'Open a chat! Unless you just want to talk to yourself.',
    )
  ];

  @override
  Widget build(BuildContext context) {
    const messagePadding = EdgeInsets.all(7.0);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: context.colorScheme.border, width: 1.0),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => DashChat(
          currentUser: user,
          onSend: (message) {
            setState(() => messages.insert(0, message));
            _focusNode.requestFocus();
          },
          messages: messages
              .map(
                (e) => ChatMessage(
                  user: e.user,
                  createdAt: e.createdAt,
                  text: e.text,
                  status: MessageStatus.sent,
                ),
              )
              .toList(),
          messageOptions: MessageOptions(
            showOtherUsersAvatar: false,
            borderRadius: 8,
            maxWidth: constraints.maxWidth * 0.7,
            messagePadding: messagePadding,
            currentUserContainerColor: context.colorScheme.primary,
            containerColor: context.colorScheme.muted,
            userNameBuilder: (user) {
              return Padding(
                padding: const EdgeInsets.only(left: 2.0, bottom: 2.0),
                child: Text(
                  user.getFullName(),
                  style: context.textTheme.muted.copyWith(fontSize: 12.0),
                ),
              );
            },
            messageTextBuilder: (message, _, __) {
              final self = message.user.id == user.id;
              final textColor =
                  self ? context.colorScheme.primaryForeground : null;
              const iconSize = 12.0;
              final iconFamily = message.status!.icon.fontFamily;
              final iconPackage = message.status!.icon.fontPackage;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DynamicInlineText(
                    key: UniqueKey(),
                    text: TextSpan(
                      text: message.text,
                      style: context.textTheme.small.copyWith(color: textColor),
                    ),
                    details: [
                      TextSpan(
                        text:
                            '${message.createdAt.hour.toString().padLeft(2, '0')}:'
                            '${message.createdAt.minute.toString().padLeft(2, '0')}'
                            '${message.createdAt.hour < 12 ? 'am' : 'pm'}',
                        style: context.textTheme.muted.copyWith(
                          color: textColor,
                          fontSize: iconSize,
                        ),
                      ),
                      if (self)
                        TextSpan(
                          text: String.fromCharCode(
                              message.status!.icon.codePoint),
                          style: TextStyle(
                            color: context.colorScheme.primaryForeground,
                            fontSize: iconSize,
                            fontFamily: iconFamily,
                            package: iconPackage,
                          ),
                        ),
                      TextSpan(
                        text: String.fromCharCode(LucideIcons.lock.codePoint),
                        style: context.textTheme.muted.copyWith(
                          color: textColor,
                          fontSize: iconSize,
                          fontFamily: iconFamily,
                          package: iconPackage,
                        ),
                      )
                    ],
                  ),
                ],
              );
            },
          ),
          messageListOptions: const MessageListOptions(
            separatorFrequency: SeparatorFrequency.days,
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
            inputToolbarStyle: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.colorScheme.border),
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
                      emojiSizeMax: context.read<Policy>().getMaxEmojiSize(),
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
        ),
      ),
    );
  }
}
