// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_html/flutter_html.dart' as html_widget;
import 'package:axichat/src/chat/view/widgets/email_image_extension.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:intl/intl.dart' as intl;
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:shadcn_ui/shadcn_ui.dart';

String? _bareJid(String? jid) {
  if (jid == null || jid.isEmpty) return null;
  try {
    return mox.JID.fromString(jid).toBare().toString();
  } on Exception {
    return jid;
  }
}

const double _messageDetailsCopyIconSize = 16.0;
const double _messageDetailsCopySpacing = 6.0;
const double _messageDetailsSectionSpacing = 8.0;
const double _messageDetailsMetadataSpacing = 12.0;
const double _messageDetailsHeadersDialogMaxHeight = 320.0;
const double _messageDetailsHeadersCardPadding = 12.0;
const String _messageDetailsSenderLabel = 'Sender address';
const String _messageDetailsMetadataLabel = 'Message metadata';
const String _messageDetailsHeadersLabel = 'Raw headers';
const String _messageDetailsHeadersActionLabel = 'View headers';
const String _messageDetailsHeadersNote =
    'Headers are loaded from the original RFC822 message.';
const String _messageDetailsHeadersLoadingLabel = 'Loading headers...';
const String _messageDetailsHeadersUnavailableLabel = 'Headers unavailable.';
const String _messageDetailsStanzaIdLabel = 'Stanza ID';
const String _messageDetailsOriginIdLabel = 'Origin ID';
const String _messageDetailsOccupantIdLabel = 'Occupant ID';
const String _messageDetailsDeltaIdLabel = 'Delta message ID';
const String _messageDetailsLocalIdLabel = 'Local message ID';

class ChatMessageDetails extends StatelessWidget {
  const ChatMessageDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final l10n = context.l10n;
        final message = state.focused;
        if (message == null) return const SizedBox.shrink();
        return BlocSelector<ProfileCubit, ProfileState, String?>(
          selector: (profileState) => profileState.jid,
          builder: (context, profileJid) {
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
            final String? resolvedEmailSelfJid =
                emailSelfJid.resolveDeltaPlaceholderJid();
            final bareSender = _bareJid(message.senderJid);
            final bool isPlaceholderSender =
                bareSender?.isDeltaPlaceholderJid ?? false;
            final isFromSelf = isPlaceholderSender ||
                bareSender == _bareJid(profileJid) ||
                (resolvedEmailSelfJid != null &&
                    bareSender == _bareJid(resolvedEmailSelfJid));
            final shareContext = state.shareContexts[message.stanzaID];
            final shareParticipants = _shareParticipants(
              shareContext?.participants ?? const <Chat>[],
              state.chat?.jid,
              profileJid,
            );
            final transport = state.chat?.transport;
            final deltaMessageId = message.deltaMsgId;
            final isEmailMessage = deltaMessageId != null;
            final protocolLabel = isEmailMessage
                ? MessageTransport.email.label
                : transport?.label ?? MessageTransport.xmpp.label;
            final protocolIcon = Icon(
              isEmailMessage ? LucideIcons.mail : LucideIcons.messageCircle,
              size: 16,
              color: isEmailMessage
                  ? context.colorScheme.destructive
                  : context.colorScheme.primary,
            );
            final timestamp = message.timestamp?.toLocal();
            final timestampLabel = timestamp == null
                ? 'Unknown'
                : intl.DateFormat.yMMMMEEEEd().add_jms().format(timestamp);
            final showEmailRecipients = isFromSelf &&
                (transport?.isEmail ?? false) &&
                shareParticipants.isNotEmpty;
            final showReactions = (transport == null || transport.isXmpp) &&
                message.reactionsPreview.isNotEmpty;
            final copyLabel = l10n.chatActionCopy;
            final String? resolvedSenderAddress =
                message.senderJid.resolveDeltaPlaceholderJid(
              resolvedEmailSelfJid,
            );
            final senderAddress = resolvedSenderAddress?.trim() ?? '';
            final String? rawHeaders = deltaMessageId == null
                ? null
                : state.emailRawHeadersByDeltaId[deltaMessageId];
            final bool isHeadersLoading = deltaMessageId != null &&
                state.emailRawHeadersLoading.contains(deltaMessageId);
            final bool isHeadersUnavailable = deltaMessageId != null &&
                state.emailRawHeadersUnavailable.contains(deltaMessageId);
            final metadataItems = <Widget>[];
            final stanzaId = message.stanzaID.trim();
            if (stanzaId.isNotEmpty) {
              metadataItems.add(
                _MessageDetailsInfo(
                  label: _messageDetailsStanzaIdLabel,
                  value: stanzaId,
                  copyValue: stanzaId,
                  copyLabel: copyLabel,
                ),
              );
            }
            final originId = message.originID?.trim();
            if (originId?.isNotEmpty == true) {
              metadataItems.add(
                _MessageDetailsInfo(
                  label: _messageDetailsOriginIdLabel,
                  value: originId!,
                  copyValue: originId,
                  copyLabel: copyLabel,
                ),
              );
            }
            final occupantId = message.occupantID?.trim();
            if (occupantId?.isNotEmpty == true) {
              metadataItems.add(
                _MessageDetailsInfo(
                  label: _messageDetailsOccupantIdLabel,
                  value: occupantId!,
                  copyValue: occupantId,
                  copyLabel: copyLabel,
                ),
              );
            }
            if (deltaMessageId != null) {
              final deltaLabel = deltaMessageId.toString();
              metadataItems.add(
                _MessageDetailsInfo(
                  label: _messageDetailsDeltaIdLabel,
                  value: deltaLabel,
                  copyValue: deltaLabel,
                  copyLabel: copyLabel,
                ),
              );
            }
            final localId = message.id?.trim();
            if (localId?.isNotEmpty == true) {
              metadataItems.add(
                _MessageDetailsInfo(
                  label: _messageDetailsLocalIdLabel,
                  value: localId!,
                  copyValue: localId,
                  copyLabel: copyLabel,
                ),
              );
            }
            return SingleChildScrollView(
              child: Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  spacing: 24,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (message.htmlBody != null &&
                        message.htmlBody!.isNotEmpty)
                      Builder(
                        builder: (context) {
                          final messageId = message.id;
                          final shouldLoadImages = context
                                  .read<SettingsCubit>()
                                  .state
                                  .autoLoadEmailImages ||
                              (messageId != null &&
                                  state.loadedImageMessageIds
                                      .contains(messageId));
                          return html_widget.Html(
                            data: HtmlContentCodec.sanitizeHtml(
                              message.htmlBody ?? '',
                            ),
                            extensions: [
                              createEmailImageExtension(
                                shouldLoad: shouldLoadImages,
                                onLoadRequested: messageId == null
                                    ? null
                                    : () {
                                        context.read<ChatBloc>().add(
                                              ChatEmailImagesLoaded(messageId),
                                            );
                                      },
                              ),
                            ],
                            style: {
                              'body': html_widget.Style(
                                margin: html_widget.Margins.zero,
                                padding: html_widget.HtmlPaddings.zero,
                                fontSize: html_widget.FontSize(
                                  context.textTheme.lead.fontSize ?? 16.0,
                                ),
                              ),
                            },
                          );
                        },
                      )
                    else
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
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                      ),
                    if (transport?.isXmpp ?? false)
                      _RecipientsRow(
                        sender: state.chat?.displayName,
                        recipients: shareParticipants,
                      ),
                    if (showReactions)
                      _ReactionsRow(
                        reactions: message.reactionsPreview,
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
                                Text(l10n.chatMessageStatusSent),
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
                                Text(l10n.chatMessageStatusReceived),
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
                                Text(l10n.chatMessageStatusDisplayed),
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
                          label: l10n.chatMessageInfoTimestamp,
                          value: timestampLabel,
                        ),
                        Wrap(
                          spacing: 24,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            _MessageDetailsInfo(
                              label: l10n.chatMessageInfoProtocol,
                              value: protocolLabel,
                              leading: protocolIcon,
                            ),
                            if (message.deviceID != null)
                              _MessageDetailsInfo(
                                label: l10n.chatMessageInfoDevice,
                                value: '#${message.deviceID}',
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (senderAddress.isNotEmpty)
                      _MessageDetailsInfo(
                        label: _messageDetailsSenderLabel,
                        value: senderAddress,
                        copyValue: senderAddress,
                        copyLabel: copyLabel,
                      ),
                    if (metadataItems.isNotEmpty)
                      Column(
                        spacing: _messageDetailsSectionSpacing,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            _messageDetailsMetadataLabel,
                            style: context.textTheme.muted,
                          ),
                          Wrap(
                            spacing: _messageDetailsMetadataSpacing,
                            runSpacing: _messageDetailsMetadataSpacing,
                            alignment: WrapAlignment.center,
                            children: metadataItems,
                          ),
                        ],
                      ),
                    if (isEmailMessage)
                      _MessageHeadersSection(
                        headers: rawHeaders,
                        title: _messageDetailsHeadersLabel,
                        buttonLabel: _messageDetailsHeadersActionLabel,
                        note: _messageDetailsHeadersNote,
                        loadingLabel: _messageDetailsHeadersLoadingLabel,
                        unavailableLabel:
                            _messageDetailsHeadersUnavailableLabel,
                        isLoading: isHeadersLoading,
                        isUnavailable: isHeadersUnavailable,
                      ),
                    if (message.error.isNotNone)
                      Column(
                        spacing: 8,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.chatMessageInfoError,
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
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await showFadeScaleDialog<void>(
      context: context,
      builder: (dialogContext) {
        return ShadDialog(
          title: Text(
            recipient.contactDisplayName ?? recipient.title,
            style: context.modalHeaderTextStyle,
          ),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonClose),
            ).withTapBounce(),
          ],
          child: Column(
            spacing: 8,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShadButton.secondary(
                size: ShadButtonSize.sm,
                onPressed: () {
                  final recipientName =
                      recipient.contactDisplayName ?? recipient.title;
                  context.read<ChatBloc>().add(
                        ChatComposerRecipientAdded(
                            FanOutTarget.chat(recipient)),
                      );
                  Navigator.of(dialogContext).pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.chatMessageAddRecipientSuccess(recipientName),
                      ),
                    ),
                  );
                },
                child: Text(l10n.chatMessageAddRecipients),
              ).withTapBounce(),
              ShadButton.secondary(
                size: ShadButtonSize.sm,
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.read<ChatsCubit?>()?.openChat(jid: recipient.jid);
                },
                child: Text(l10n.chatMessageOpenChat),
              ).withTapBounce(),
              if (emailService != null && recipient.deltaChatId == null)
                ShadButton.secondary(
                  size: ShadButtonSize.sm,
                  onPressed: () async {
                    final recipientName =
                        recipient.contactDisplayName ?? recipient.title;
                    try {
                      final ensured =
                          await emailService.ensureChatForEmailChat(recipient);
                      if (!context.mounted) return;
                      Navigator.of(dialogContext).pop();
                      context.read<ChatsCubit?>()?.openChat(jid: ensured.jid);
                    } catch (_) {
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.chatMessageCreateChatFailure(recipientName),
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(l10n.chatMessageCreateChat),
                ).withTapBounce(),
            ],
          ),
        );
      },
    );
  }
}

class _MessageHeadersSection extends StatelessWidget {
  const _MessageHeadersSection({
    required this.headers,
    required this.title,
    required this.buttonLabel,
    required this.note,
    required this.loadingLabel,
    required this.unavailableLabel,
    required this.isLoading,
    required this.isUnavailable,
  });

  final String? headers;
  final String title;
  final String buttonLabel;
  final String note;
  final String loadingLabel;
  final String unavailableLabel;
  final bool isLoading;
  final bool isUnavailable;

  bool get _canOpen => headers?.trim().isNotEmpty == true;

  String? get _statusLabel {
    if (isLoading) return loadingLabel;
    if (isUnavailable) return unavailableLabel;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel;
    return Column(
      spacing: _messageDetailsSectionSpacing,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: context.textTheme.muted,
        ),
        ShadButton.secondary(
          size: ShadButtonSize.sm,
          onPressed: _canOpen ? () => _showHeadersDialog(context) : null,
          child: Text(buttonLabel),
        ).withTapBounce(),
        if (statusLabel != null)
          Text(
            statusLabel,
            style: context.textTheme.muted,
          ),
      ],
    );
  }

  Future<void> _showHeadersDialog(BuildContext context) async {
    final rawHeaders = headers;
    if (rawHeaders == null || !_canOpen) return;
    final l10n = context.l10n;
    await showFadeScaleDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _RawHeadersDialog(
          headers: rawHeaders,
          title: title,
          note: note,
          copyLabel: l10n.chatActionCopy,
          closeLabel: l10n.commonClose,
        );
      },
    );
  }
}

class _RawHeadersDialog extends StatelessWidget {
  const _RawHeadersDialog({
    required this.headers,
    required this.title,
    required this.note,
    required this.copyLabel,
    required this.closeLabel,
  });

  final String headers;
  final String title;
  final String note;
  final String copyLabel;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    final trimmedNote = note.trim();
    final hasNote = trimmedNote.isNotEmpty;
    return ShadDialog(
      title: Text(
        title,
        style: context.modalHeaderTextStyle,
      ),
      actions: [
        ShadButton.secondary(
          size: ShadButtonSize.sm,
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: headers),
            );
          },
          child: Text(copyLabel),
        ).withTapBounce(),
        ShadButton.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(closeLabel),
        ).withTapBounce(),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: _messageDetailsHeadersDialogMaxHeight,
        ),
        child: SingleChildScrollView(
          child: Column(
            spacing: _messageDetailsSectionSpacing,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasNote)
                Text(
                  trimmedNote,
                  style: context.textTheme.muted,
                ),
              ShadCard(
                padding:
                    const EdgeInsets.all(_messageDetailsHeadersCardPadding),
                child: SelectableText(
                  headers,
                  style: context.textTheme.small,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageDetailsInfo extends StatelessWidget {
  const _MessageDetailsInfo({
    required this.label,
    required this.value,
    this.leading,
    this.copyValue,
    this.copyLabel,
  });

  final String label;
  final String value;
  final Widget? leading;
  final String? copyValue;
  final String? copyLabel;

  @override
  Widget build(BuildContext context) {
    final trimmedCopyValue = copyValue?.trim();
    final canCopy = trimmedCopyValue?.isNotEmpty == true;
    final resolvedCopyLabel = copyLabel ?? context.l10n.chatActionCopy;
    final copyButton = canCopy
        ? AxiTooltip(
            builder: (context) => Text(resolvedCopyLabel),
            child: ShadIconButton.ghost(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: trimmedCopyValue!),
                );
              },
              icon: Icon(
                LucideIcons.copy,
                size: _messageDetailsCopyIconSize,
                color: context.colorScheme.mutedForeground,
              ),
              decoration: const ShadDecoration(
                secondaryBorder: ShadBorder.none,
                secondaryFocusedBorder: ShadBorder.none,
              ),
            ).withTapBounce(),
          )
        : null;
    final valueText = SelectableText(
      value,
      textAlign: TextAlign.center,
      style: context.textTheme.small,
    );
    final valueRow = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: _messageDetailsCopySpacing),
        ],
        Flexible(
          fit: FlexFit.loose,
          child: valueText,
        ),
        if (copyButton != null) ...[
          const SizedBox(width: _messageDetailsCopySpacing),
          copyButton,
        ],
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: context.textTheme.muted,
        ),
        valueRow,
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

class _RecipientsRow extends StatelessWidget {
  const _RecipientsRow({
    required this.sender,
    required this.recipients,
  });

  final String? sender;
  final List<Chat> recipients;

  @override
  Widget build(BuildContext context) {
    if (recipients.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (sender != null)
          Text(
            'From $sender',
            style: context.textTheme.muted,
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final participant in recipients)
              _RecipientChip(
                chat: participant,
                onPressed: () =>
                    context.read<ChatsCubit>().openChat(jid: participant.jid),
              ),
          ],
        ),
      ],
    );
  }
}

class _ReactionsRow extends StatelessWidget {
  const _ReactionsRow({required this.reactions});

  final List<ReactionPreview> reactions;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
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
            for (final reaction in reactions) _ReactionChip(reaction: reaction),
          ],
        ),
      ],
    );
  }
}
