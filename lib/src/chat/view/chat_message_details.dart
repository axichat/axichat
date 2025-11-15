import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
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
        EmailService? emailService;
        try {
          emailService = RepositoryProvider.of<EmailService>(
            context,
            listen: false,
          );
        } catch (_) {
          emailService = null;
        }
        final emailSelfJid = emailService?.selfSenderJid;
        final isFromSelf = message.senderJid == profileState.jid ||
            (emailSelfJid != null && message.senderJid == emailSelfJid);
        final shareContext = state.shareContexts[message.stanzaID];
        final shareParticipants = _shareParticipants(
          shareContext?.participants ?? const <Chat>[],
          state.chat?.jid,
          profileState.jid,
        );
        final transport = state.chat?.transport;
        final protocolLabel = transport?.label ?? 'Chat';
        final timestamp = message.timestamp?.toLocal();
        final timestampLabel = timestamp == null
            ? 'Unknown'
            : intl.DateFormat.yMMMMEEEEd().add_jms().format(timestamp);
        final showEmailRecipients = isFromSelf &&
            (transport?.isEmail ?? false) &&
            shareParticipants.isNotEmpty;
        final showReactions = (transport == null || transport.isXmpp) &&
            message.reactionsPreview.isNotEmpty;
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
                if (shareContext?.subject?.isNotEmpty == true)
                  Column(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Subject',
                        style: context.textTheme.muted,
                      ),
                      Text(
                        shareContext!.subject!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                if (showEmailRecipients)
                  Column(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Recipients',
                        style: context.textTheme.muted,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final participant in shareParticipants)
                            _RecipientChip(
                              chat: participant,
                              onPressed: () => _showRecipientActions(
                                context,
                                recipient: participant,
                                emailService: emailService,
                              ),
                            ),
                        ],
                      ),
                    ],
                  )
                else if (shareParticipants.isNotEmpty)
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
                if (showReactions)
                  Column(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Reactions',
                        style: context.textTheme.muted,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final reaction in message.reactionsPreview)
                            _ReactionChip(reaction: reaction),
                        ],
                      ),
                    ],
                  ),
                if (isFromSelf)
                  Wrap(
                    spacing: 12.0,
                    runSpacing: 12.0,
                    alignment: WrapAlignment.center,
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
                Column(
                  spacing: 12,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _MessageDetailsInfo(
                      label: 'Timestamp',
                      value: timestampLabel,
                    ),
                    Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _MessageDetailsInfo(
                          label: 'Protocol',
                          value: protocolLabel,
                        ),
                        if (message.deviceID != null)
                          _MessageDetailsInfo(
                            label: 'Device',
                            value: '#${message.deviceID}',
                          ),
                      ],
                    ),
                  ],
                ),
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
                      Text(
                        message.error.asString,
                        textAlign: TextAlign.center,
                      ),
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

  Future<void> _showRecipientActions(
    BuildContext context, {
    required Chat recipient,
    required EmailService? emailService,
  }) async {
    final chatsCubit = context.read<ChatsCubit?>();
    final chatBloc = context.read<ChatBloc>();
    final messenger = ScaffoldMessenger.of(context);
    await showShadDialog<void>(
      context: context,
      builder: (dialogContext) {
        return ShadDialog(
          title: Text(recipient.contactDisplayName ?? recipient.title),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ).withTapBounce(),
          ],
          child: Column(
            spacing: 8,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShadButton.secondary(
                size: ShadButtonSize.sm,
                onPressed: () {
                  chatBloc.add(
                    ChatComposerRecipientAdded(FanOutTarget.chat(recipient)),
                  );
                  Navigator.of(dialogContext).pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Added ${recipient.contactDisplayName ?? recipient.title} to recipients',
                      ),
                    ),
                  );
                },
                child: const Text('Add to recipients'),
              ).withTapBounce(),
              ShadButton.secondary(
                size: ShadButtonSize.sm,
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  chatsCubit?.toggleChat(jid: recipient.jid);
                },
                child: const Text('Open chat'),
              ).withTapBounce(),
              if (emailService != null && recipient.deltaChatId == null)
                ShadButton.secondary(
                  size: ShadButtonSize.sm,
                  onPressed: () async {
                    try {
                      final ensured =
                          await emailService.ensureChatForEmailChat(recipient);
                      if (!context.mounted) return;
                      Navigator.of(dialogContext).pop();
                      chatsCubit?.toggleChat(jid: ensured.jid);
                    } catch (_) {
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Unable to create chat for ${recipient.contactDisplayName ?? recipient.title}',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Create chat'),
                ).withTapBounce(),
            ],
          ),
        );
      },
    );
  }
}

class _MessageDetailsInfo extends StatelessWidget {
  const _MessageDetailsInfo({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: context.textTheme.muted,
        ),
        SelectableText(
          value,
          textAlign: TextAlign.center,
          style: context.textTheme.small,
        ),
      ],
    );
  }
}

class _RecipientChip extends StatelessWidget {
  const _RecipientChip({
    required this.chat,
    required this.onPressed,
  });

  final Chat chat;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ShadButton.secondary(
      size: ShadButtonSize.sm,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.mail, size: 14),
          const SizedBox(width: 6),
          Text(
            chat.contactDisplayName?.isNotEmpty == true
                ? chat.contactDisplayName!
                : chat.title,
          ),
        ],
      ),
    ).withTapBounce();
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.reaction});

  final ReactionPreview reaction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final highlight = reaction.reactedBySelf;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlight ? colors.primary.withValues(alpha: 0.15) : colors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              reaction.emoji,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(
              '${reaction.count}',
              style: context.textTheme.small,
            ),
          ],
        ),
      ),
    );
  }
}
