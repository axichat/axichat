import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/bloc/chat_transport_cubit.dart';
import 'package:axichat/src/chat/view/chat_alert.dart';
import 'package:axichat/src/chat/view/chat_drawer.dart';
import 'package:axichat/src/chat/view/chat_message_details.dart';
import 'package:axichat/src/chat/view/chat_verification_list.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

extension on MessageStatus {
  IconData get icon => switch (this) {
        MessageStatus.read => LucideIcons.checkCheck,
        MessageStatus.received || MessageStatus.sent => LucideIcons.check,
        MessageStatus.failed => LucideIcons.x,
        _ => LucideIcons.dot,
      };
}

enum _ChatRoute {
  main,
  verification,
  details,
}

const _bubblePadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
const _bubbleRadius = 18.0;

ShapeDecoration _bubbleDecoration({
  required Color background,
  Color? borderColor,
}) {
  final side = borderColor == null || borderColor.a == 0
      ? BorderSide.none
      : BorderSide(color: borderColor, width: 1);
  return ShapeDecoration(
    color: background,
    shape: ContinuousRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(_bubbleRadius)),
      side: side,
    ),
  );
}

InputDecoration _chatInputDecoration(
  BuildContext context, {
  required String hintText,
}) {
  final colors = context.colorScheme;
  final brightness = Theme.of(context).brightness;
  final border = OutlineInputBorder(
    borderRadius: context.radius,
    borderSide: BorderSide(color: colors.border),
  );
  final focusedBorder = border.copyWith(
    borderSide: BorderSide(
      color: colors.primary,
      width: 1.5,
    ),
  );
  final errorBorder = border.copyWith(
    borderSide: BorderSide(color: colors.destructive),
  );
  return defaultInputDecoration().copyWith(
    hintText: hintText,
    hintStyle: context.textTheme.muted.copyWith(
      color: colors.mutedForeground,
    ),
    filled: true,
    fillColor: colors.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: border,
    enabledBorder: border,
    disabledBorder: border.copyWith(
      borderSide: BorderSide(
        color: colors.border.withValues(alpha: 0.6),
      ),
    ),
    focusedBorder: focusedBorder,
    errorBorder: errorBorder,
    focusedErrorBorder: errorBorder,
    hoverColor: colors.primary.withValues(
      alpha: brightness == Brightness.dark ? 0.08 : 0.04,
    ),
  );
}

class Chat extends StatefulWidget {
  const Chat({super.key});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  late final ShadPopoverController _emojiPopoverController;
  late final FocusNode _focusNode;
  late final TextEditingController _textController;

  var _chatRoute = _ChatRoute.main;

  void _typingListener() {
    if (!context.read<SettingsCubit>().state.indicateTyping) return;
    if (_textController.text.isEmpty) return;
    context.read<ChatBloc>().add(const ChatTypingStarted());
  }

  @override
  void initState() {
    super.initState();
    _emojiPopoverController = ShadPopoverController();
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
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final profile = context.watch<ProfileCubit?>()?.state;
        final emailService =
            RepositoryProvider.of<EmailService>(context, listen: false);
        final emailSelfJid = emailService.selfSenderJid;
        final jid = state.chat?.jid;
        final transport = context.watch<ChatTransportCubit>().state;
        final canUseEmail = (state.chat?.deltaChatId != null) ||
            (state.chat?.emailAddress?.isNotEmpty ?? false);
        final isEmailTransport = canUseEmail && transport.isEmail;
        final currentUserId = isEmailTransport
            ? (emailSelfJid ?? profile?.jid ?? '')
            : (profile?.jid ?? '');
        final user = ChatUser(
          id: currentUserId,
          firstName: profile?.username ?? '',
        );
        return Container(
          decoration: BoxDecoration(
            color: context.colorScheme.background,
            border: Border(
              left: BorderSide(color: context.colorScheme.border),
            ),
          ),
          child: Scaffold(
            backgroundColor: context.colorScheme.background,
            endDrawerEnableOpenDragGesture: false,
            endDrawer: jid == null
                ? null
                : ChatDrawer(
                    state: state,
                    showVerification: () => setState(() {
                      _chatRoute = _ChatRoute.verification;
                    }),
                  ),
            appBar: AppBar(
              scrolledUnderElevation: 0,
              forceMaterialTransparency: true,
              shape:
                  Border(bottom: BorderSide(color: context.colorScheme.border)),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 8.0),
              leading: ShadIconButton.ghost(
                icon: const Icon(
                  LucideIcons.arrowLeft,
                  size: 20.0,
                ),
                onPressed: () {
                  if (_chatRoute != _ChatRoute.main) {
                    context
                        .read<ChatBloc>()
                        .add(const ChatMessageFocused(null));
                    return setState(() {
                      _chatRoute = _ChatRoute.main;
                    });
                  }
                  if (_textController.text.isNotEmpty) {
                    if (!isEmailTransport) {
                      context.read<DraftCubit?>()?.saveDraft(
                            id: null,
                            jids: [state.chat!.jid],
                            body: _textController.text,
                          );
                    }
                  }
                  context.read<ChatsCubit>().toggleChat(jid: state.chat!.jid);
                },
              ),
              title: jid == null
                  ? const SizedBox.shrink()
                  : BlocBuilder<RosterCubit, RosterState>(
                      buildWhen: (_, current) => current is RosterAvailable,
                      builder: (context, rosterState) {
                        final item = (rosterState is! RosterAvailable
                                ? context.read<RosterCubit>()['items']
                                    as List<RosterItem>
                                : rosterState.items)
                            ?.where((e) => e.jid == jid)
                            .singleOrNull;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 40.0,
                                maxHeight: 40.0,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: (item == null)
                                        ? AxiAvatar(jid: jid)
                                        : AxiAvatar(
                                            jid: item.jid,
                                            subscription: item.subscription,
                                            presence: item.presence,
                                            status: item.status,
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
              actions: [
                if (jid == null || _chatRoute != _ChatRoute.main)
                  const SizedBox.shrink()
                else
                  Builder(
                    builder: (context) => AxiIconButton(
                      iconData: LucideIcons.settings,
                      onPressed: Scaffold.of(context).openEndDrawer,
                    ),
                  )
              ],
            ),
            body: Column(
              children: [
                const ChatAlert(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: context.watch<SettingsCubit>().animationDuration,
                    reverseDuration:
                        context.watch<SettingsCubit>().animationDuration,
                    switchInCurve: Curves.easeIn,
                    switchOutCurve: Curves.easeOut,
                    child: IndexedStack(
                      key: ValueKey(_chatRoute.index),
                      index: _chatRoute.index,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact =
                                constraints.maxWidth < smallScreen;
                            return Column(
                              children: [
                                Expanded(
                                  child: DashChat(
                                    currentUser: user,
                                    onSend: (message) {
                                      context.read<ChatBloc>().add(
                                          ChatMessageSent(text: message.text));
                                      _focusNode.requestFocus();
                                    },
                                    messages: state.items
                                        .where((e) =>
                                            e.body != null || e.error.isNotNone)
                                        .map((e) {
                                      final isSelfXmpp =
                                          e.senderJid == profile?.jid;
                                      final isSelfEmail =
                                          emailSelfJid != null &&
                                              e.senderJid == emailSelfJid;
                                      final isSelf = isSelfXmpp || isSelfEmail;
                                      final author = isSelf
                                          ? user
                                          : ChatUser(
                                              id: e.senderJid,
                                              firstName: state.chat?.title,
                                            );
                                      return ChatMessage(
                                        user: author,
                                        createdAt: e.timestamp!,
                                        text:
                                            '${e.error.isNotNone ? e.error.asString : ''}'
                                            '${e.error.isNotNone && e.body?.isNotEmpty == true ? ': "${e.body}"' : e.body}',
                                        status: e.error.isNotNone
                                            ? MessageStatus.failed
                                            : e.displayed
                                                ? MessageStatus.read
                                                : e.received
                                                    ? MessageStatus.received
                                                    : e.acked
                                                        ? MessageStatus.sent
                                                        : MessageStatus.pending,
                                        customProperties: {
                                          'id': e.stanzaID,
                                          'body': e.body,
                                          'edited': e.edited,
                                          'retracted': e.retracted,
                                          'error': e.error,
                                          'encrypted':
                                              e.encryptionProtocol.isNotNone,
                                          'trust': e.trust,
                                          'trusted': e.trusted,
                                          'isSelf': isSelf,
                                        },
                                      );
                                    }).toList(),
                                    messageOptions: MessageOptions(
                                      showOtherUsersAvatar: false,
                                      borderRadius: 0,
                                      maxWidth: constraints.maxWidth *
                                          (isCompact ? 0.8 : 0.7),
                                      messagePadding: EdgeInsets.zero,
                                      currentUserContainerColor:
                                          Colors.transparent,
                                      containerColor: Colors.transparent,
                                      userNameBuilder: (user) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              left: 2.0, bottom: 2.0),
                                          child: Text(
                                            user.getFullName(),
                                            style: context.textTheme.muted
                                                .copyWith(fontSize: 12.0),
                                          ),
                                        );
                                      },
                                      messageTextBuilder: (message, _, __) {
                                        final colors = context.colorScheme;
                                        final chatTokens = context.chatTheme;
                                        final extraStyle =
                                            context.textTheme.muted.copyWith(
                                          fontStyle: FontStyle.italic,
                                        );
                                        final self = message
                                                    .customProperties?['isSelf']
                                                as bool? ??
                                            (message.user.id == profile?.jid);
                                        final error =
                                            message.customProperties!['error']
                                                as MessageError;
                                        final isError = error.isNotNone;
                                        final bubbleColor = isError
                                            ? colors.destructive
                                            : self
                                                ? colors.primary
                                                : colors.card;
                                        final borderColor = self || isError
                                            ? Colors.transparent
                                            : chatTokens.recvEdge;
                                        final textColor = isError
                                            ? colors.destructiveForeground
                                            : self
                                                ? colors.primaryForeground
                                                : colors.foreground;
                                        final timestampColor =
                                            chatTokens.timestamp;
                                        final encrypted =
                                            message.customProperties![
                                                    'encrypted'] ==
                                                true;
                                        const iconSize = 13.0;
                                        final iconFamily =
                                            message.status!.icon.fontFamily;
                                        final iconPackage =
                                            message.status!.icon.fontPackage;
                                        final text = TextSpan(
                                          text: message.text,
                                          style:
                                              context.textTheme.small.copyWith(
                                            color: textColor,
                                            height: 1.3,
                                          ),
                                        );
                                        final timeColor = isError
                                            ? textColor
                                            : self
                                                ? colors.primaryForeground
                                                : timestampColor;
                                        final time = TextSpan(
                                          text:
                                              '${message.createdAt.hour.toString().padLeft(2, '0')}:'
                                              '${message.createdAt.minute.toString().padLeft(2, '0')}',
                                          style:
                                              context.textTheme.muted.copyWith(
                                            color: timeColor,
                                            fontSize: 11.0,
                                          ),
                                        );
                                        final status = TextSpan(
                                          text: String.fromCharCode(
                                            message.status!.icon.codePoint,
                                          ),
                                          style: TextStyle(
                                            color: self
                                                ? colors.primaryForeground
                                                : timestampColor,
                                            fontSize: iconSize,
                                            fontFamily: iconFamily,
                                            package: iconPackage,
                                          ),
                                        );
                                        final encryption = TextSpan(
                                          text: String.fromCharCode(
                                            (encrypted
                                                    ? LucideIcons.lockKeyhole
                                                    : LucideIcons
                                                        .lockKeyholeOpen)
                                                .codePoint,
                                          ),
                                          style:
                                              context.textTheme.muted.copyWith(
                                            color: encrypted
                                                ? (self
                                                    ? colors.primaryForeground
                                                    : colors.foreground)
                                                : colors.destructive,
                                            fontSize: iconSize,
                                            fontFamily: iconFamily,
                                            package: iconPackage,
                                          ),
                                        );
                                        final trusted =
                                            message.customProperties!['trusted']
                                                as bool?;
                                        final verification = trusted == null
                                            ? null
                                            : TextSpan(
                                                text: String.fromCharCode(
                                                  trusted
                                                      .toShieldIcon.codePoint,
                                                ),
                                                style: context.textTheme.muted
                                                    .copyWith(
                                                  color: trusted
                                                      ? axiGreen
                                                      : colors.destructive,
                                                  fontSize: iconSize,
                                                  fontFamily: iconFamily,
                                                  package: iconPackage,
                                                ),
                                              );
                                        final bubbleKey = message
                                                .customProperties?['id'] ??
                                            '${message.user.id}-${message.createdAt.microsecondsSinceEpoch}';
                                        Widget bubbleChild;
                                        if (isError) {
                                          bubbleChild = Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            spacing: 4.0,
                                            children: [
                                              Text(
                                                'Error!',
                                                style: context.textTheme.small
                                                    .copyWith(
                                                  color: textColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              DynamicInlineText(
                                                key: ValueKey(bubbleKey),
                                                text: text,
                                                details: [time],
                                              ),
                                            ],
                                          );
                                        } else {
                                          bubbleChild = Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              DynamicInlineText(
                                                key: ValueKey(bubbleKey),
                                                text: text,
                                                details: [
                                                  time,
                                                  if (self) status,
                                                  encryption,
                                                  if (verification != null)
                                                    verification,
                                                ],
                                              ),
                                              if (message.customProperties?[
                                                      'retracted'] ??
                                                  false)
                                                Text(
                                                  '(retracted)',
                                                  style: extraStyle,
                                                )
                                              else if (message
                                                          .customProperties?[
                                                      'edited'] ??
                                                  false)
                                                Text(
                                                  '(edited)',
                                                  style: extraStyle,
                                                ),
                                            ],
                                          );
                                        }
                                        return ShadContextMenuRegion(
                                          items: [
                                            ShadContextMenuItem(
                                              leading: const Icon(
                                                LucideIcons.copy,
                                              ),
                                              onPressed: () async {
                                                await Clipboard.setData(
                                                  ClipboardData(
                                                      text: message.text),
                                                );
                                              },
                                              child: const Text('Copy'),
                                            ),
                                            ShadContextMenuItem(
                                              leading: const Icon(
                                                LucideIcons.info,
                                              ),
                                              onPressed: () {
                                                context.read<ChatBloc>().add(
                                                    ChatMessageFocused(message
                                                            .customProperties![
                                                        'id']));
                                                setState(() {
                                                  _chatRoute =
                                                      _ChatRoute.details;
                                                  if (_focusNode.hasFocus) {
                                                    _focusNode.unfocus();
                                                  }
                                                });
                                              },
                                              child: const Text('Details'),
                                            ),
                                          ],
                                          child: DecoratedBox(
                                            decoration: _bubbleDecoration(
                                              background: bubbleColor,
                                              borderColor: borderColor,
                                            ),
                                            child: Padding(
                                              padding: _bubblePadding,
                                              child: bubbleChild,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    messageListOptions: MessageListOptions(
                                      separatorFrequency:
                                          SeparatorFrequency.days,
                                      typingBuilder: (_) => const Padding(
                                        padding:
                                            EdgeInsets.only(left: 16, top: 16),
                                        child: TypingIndicator(),
                                      ),
                                      onLoadEarlier: state.items.length %
                                                  ChatBloc.messageBatchSize !=
                                              0
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
                                      chatFooterBuilder: state.items.isEmpty
                                          ? Center(
                                              child: Text(
                                                'No messages',
                                                style: context.textTheme.muted,
                                              ),
                                            )
                                          : null,
                                    ),
                                    inputOptions: InputOptions(
                                      sendOnEnter: true,
                                      alwaysShowSend: true,
                                      focusNode: _focusNode,
                                      textController: _textController,
                                      sendButtonBuilder: (send) =>
                                          ShadIconButton.ghost(
                                        onPressed: send,
                                        icon: const Icon(
                                          Icons.send,
                                          size: 24,
                                        ),
                                      ),
                                      inputDecoration: _chatInputDecoration(
                                        context,
                                        hintText: isEmailTransport
                                            ? 'Send email message'
                                            : 'Send ${state.chat?.encryptionProtocol.isNone ?? false ? 'plaintext' : 'encrypted'} message',
                                      ),
                                      inputToolbarStyle: BoxDecoration(
                                        color: context.colorScheme.background,
                                        border: Border(
                                          top: BorderSide(
                                              color:
                                                  context.colorScheme.border),
                                        ),
                                      ),
                                      leading: [
                                        ShadPopover(
                                          controller: _emojiPopoverController,
                                          child: ShadIconButton.ghost(
                                            onPressed:
                                                _emojiPopoverController.toggle,
                                            icon: const Icon(
                                              LucideIcons.smile,
                                              size: 24,
                                            ),
                                          ),
                                          popover: (context) => EmojiPicker(
                                            textEditingController:
                                                _textController,
                                            config: Config(
                                              emojiViewConfig: EmojiViewConfig(
                                                emojiSizeMax: context
                                                    .read<Policy>()
                                                    .getMaxEmojiSize(),
                                              ),
                                            ),
                                          ),
                                        ),
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
                                      if (state.chat?.chatState?.name ==
                                          'composing')
                                        ChatUser(
                                          id: state.chat!.jid,
                                          firstName: state.chat!.title,
                                        ),
                                    ].take(1).toList(),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        VerificationList(jid: jid),
                        const ChatMessageDetails(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.background,
        border: Border(
          left: BorderSide(color: context.colorScheme.border),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < smallScreen;
          return DashChat(
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
              borderRadius: 0,
              maxWidth: constraints.maxWidth * (isCompact ? 0.8 : 0.7),
              messagePadding: EdgeInsets.zero,
              currentUserContainerColor: Colors.transparent,
              containerColor: Colors.transparent,
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
                final colors = context.colorScheme;
                final chatTokens = context.chatTheme;
                final self = message.user.id == user.id;
                final textColor =
                    self ? colors.primaryForeground : colors.foreground;
                final timestampColor = chatTokens.timestamp;
                final iconFamily = message.status!.icon.fontFamily;
                final iconPackage = message.status!.icon.fontPackage;
                const iconSize = 12.0;
                return DecoratedBox(
                  decoration: _bubbleDecoration(
                    background: self ? colors.primary : colors.card,
                    borderColor:
                        self ? Colors.transparent : chatTokens.recvEdge,
                  ),
                  child: Padding(
                    padding: _bubblePadding,
                    child: DynamicInlineText(
                      key: ValueKey(message.createdAt.microsecondsSinceEpoch),
                      text: TextSpan(
                        text: message.text,
                        style: context.textTheme.small.copyWith(
                          color: textColor,
                        ),
                      ),
                      details: [
                        TextSpan(
                          text:
                              '${message.createdAt.hour.toString().padLeft(2, '0')}:'
                              '${message.createdAt.minute.toString().padLeft(2, '0')}',
                          style: context.textTheme.muted.copyWith(
                            color: self
                                ? colors.primaryForeground
                                : timestampColor,
                            fontSize: iconSize,
                          ),
                        ),
                        if (self)
                          TextSpan(
                            text: String.fromCharCode(
                              message.status!.icon.codePoint,
                            ),
                            style: TextStyle(
                              color: colors.primaryForeground,
                              fontSize: iconSize,
                              fontFamily: iconFamily,
                              package: iconPackage,
                            ),
                          ),
                        TextSpan(
                          text: String.fromCharCode(
                            LucideIcons.lockKeyhole.codePoint,
                          ),
                          style: context.textTheme.muted.copyWith(
                            color: self
                                ? colors.primaryForeground
                                : timestampColor,
                            fontSize: iconSize,
                            fontFamily: iconFamily,
                            package: iconPackage,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            inputOptions: InputOptions(
              sendOnEnter: true,
              alwaysShowSend: true,
              focusNode: _focusNode,
              textController: _textController,
              sendButtonBuilder: (send) => ShadIconButton.ghost(
                onPressed: send,
                icon: const Icon(
                  Icons.send,
                  size: 24,
                ),
              ),
              inputDecoration: _chatInputDecoration(
                context,
                hintText: 'Send a message',
              ),
              inputToolbarStyle: BoxDecoration(
                color: context.colorScheme.background,
                border: Border(
                  top: BorderSide(color: context.colorScheme.border),
                ),
              ),
              leading: [
                ShadPopover(
                  controller: _emojiPopoverController,
                  child: ShadIconButton.ghost(
                    onPressed: _emojiPopoverController.toggle,
                    icon: const Icon(
                      LucideIcons.smile,
                      size: 24,
                    ),
                  ),
                  popover: (context) => EmojiPicker(
                    textEditingController: _textController,
                    config: Config(
                      emojiViewConfig: EmojiViewConfig(
                        emojiSizeMax: context.read<Policy>().getMaxEmojiSize(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
