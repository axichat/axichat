// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/message_error_l10n.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/common/url_safety.dart';
import 'package:axichat/src/chat/view/widgets/email_html_web_view.dart';
import 'package:axichat/src/chat/view/widgets/email_image_extension.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatMessageDetails extends StatefulWidget {
  const ChatMessageDetails({
    super.key,
    this.onAddRecipient,
    required this.loadedEmailImageMessageIds,
    required this.onEmailImagesApproved,
  });

  final ValueChanged<Chat>? onAddRecipient;
  final Set<String> loadedEmailImageMessageIds;
  final ValueChanged<String> onEmailImagesApproved;

  @override
  State<ChatMessageDetails> createState() => _ChatMessageDetailsState();
}

class _ChatMessageDetailsState extends State<ChatMessageDetails> {
  final Logger _log = Logger('ChatMessageDetails');
  Locale? _lastLocale;
  String? _lastLoggedEmailDebugDumpKey;
  late intl.DateFormat _timestampFormat;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_lastLocale == locale) return;
    _lastLocale = locale;
    _timestampFormat = intl.DateFormat.yMMMMEEEEd(
      locale.toLanguageTag(),
    ).add_jms();
    _maybeLogEmailDebugDump(context.read<ChatBloc>().state);
  }

  void _maybeLogEmailDebugDump(ChatState state) {
    final message = state.focused;
    final deltaMessageId = message?.deltaMsgId;
    if (deltaMessageId == null) {
      return;
    }
    final debugDump = state.emailDebugDumpByDeltaId[deltaMessageId]?.trim();
    if (debugDump == null || debugDump.isEmpty) {
      return;
    }
    final dumpKey = '$deltaMessageId:${debugDump.hashCode}';
    if (_lastLoggedEmailDebugDumpKey == dumpKey) {
      return;
    }
    _lastLoggedEmailDebugDumpKey = dumpKey;
    _log.info(
      '===== AXICHAT DELTA DEBUG DUMP BEGIN delta=$deltaMessageId =====',
    );
    for (final line in debugDump.split('\n')) {
      _log.info(line);
    }
    _log.info('===== AXICHAT DELTA DEBUG DUMP END delta=$deltaMessageId =====');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatBloc, ChatState>(
      listenWhen: (previous, current) =>
          previous.focused?.deltaMsgId != current.focused?.deltaMsgId ||
          previous.emailDebugDumpByDeltaId != current.emailDebugDumpByDeltaId,
      listener: (context, state) {
        _maybeLogEmailDebugDump(state);
      },
      child: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          final l10n = context.l10n;
          final message = state.focused;
          if (message == null) return const SizedBox.shrink();
          return BlocSelector<ProfileCubit, ProfileState, String?>(
            selector: (profileState) => profileState.jid,
            builder: (context, profileJid) {
              final resolvedEmailSelfJid = state.emailSelfJid
                  ?.resolveDeltaPlaceholderJid();
              final bareSender = bareAddress(message.senderJid);
              final bool isPlaceholderSender =
                  bareSender?.isDeltaPlaceholderJid ?? false;
              final isFromSelf =
                  isPlaceholderSender ||
                  bareSender == bareAddress(profileJid) ||
                  (resolvedEmailSelfJid != null &&
                      bareSender == bareAddress(resolvedEmailSelfJid));
              final shareContext = state.shareContexts[message.stanzaID];
              final shareParticipants = _shareParticipants(
                shareContext?.participants ?? const <Chat>[],
                state.chat?.jid,
                profileJid,
              );
              final transport = state.chat?.transport;
              final deltaMessageId = message.deltaMsgId;
              final isEmailMessage = deltaMessageId != null;
              final isEmailTransport =
                  isEmailMessage || transport?.isEmail == true;
              final protocolLabel = isEmailMessage
                  ? MessageTransport.email.label
                  : transport?.label ?? MessageTransport.xmpp.label;
              final colors = context.colorScheme;
              final spacing = context.spacing;
              final sizing = context.sizing;
              final textTheme = context.textTheme;
              final settings = context.watch<SettingsCubit>().state;
              final protocolIcon = Icon(
                isEmailMessage ? LucideIcons.mail : LucideIcons.messageCircle,
                size: sizing.menuItemIconSize,
                color: isEmailMessage ? colors.destructive : colors.primary,
              );
              final timestamp = message.timestamp?.toLocal();
              final timestampLabel = timestamp == null
                  ? l10n.commonUnknownLabel
                  : _timestampFormat.format(timestamp);
              final showEmailRecipients =
                  isFromSelf &&
                  (transport?.isEmail ?? false) &&
                  shareParticipants.isNotEmpty;
              final showReactions =
                  (transport == null || transport.isXmpp) &&
                  message.reactionsPreview.isNotEmpty;
              final copyLabel = l10n.chatActionCopy;
              final String? resolvedSenderAddress = message.senderJid
                  .resolveDeltaPlaceholderJid(resolvedEmailSelfJid);
              final senderAddress = resolvedSenderAddress?.trim() ?? '';
              final hideSenderAddress =
                  state.chat?.isAxichatWelcomeThread == true;
              final String? rawHeaders = deltaMessageId == null
                  ? null
                  : state.emailRawHeadersByDeltaId[deltaMessageId];
              final bool isHeadersLoading =
                  deltaMessageId != null &&
                  state.emailRawHeadersLoading.contains(deltaMessageId);
              final bool isHeadersUnavailable =
                  deltaMessageId != null &&
                  state.emailRawHeadersUnavailable.contains(deltaMessageId);
              final String? debugDump = deltaMessageId == null
                  ? null
                  : state.emailDebugDumpByDeltaId[deltaMessageId];
              final bool isDebugDumpLoading =
                  deltaMessageId != null &&
                  state.emailDebugDumpLoading.contains(deltaMessageId);
              final bool isDebugDumpUnavailable =
                  deltaMessageId != null &&
                  state.emailDebugDumpUnavailable.contains(deltaMessageId);
              final String? resolvedHtmlBody = deltaMessageId == null
                  ? message.htmlBody
                  : state.emailFullHtmlByDeltaId[deltaMessageId] ??
                        message.htmlBody;
              final String? resolvedQuotedText = deltaMessageId == null
                  ? null
                  : state.emailQuotedTextByDeltaId[deltaMessageId];
              final String? resolvedHtmlText = resolvedHtmlBody == null
                  ? null
                  : HtmlContentCodec.toPlainText(resolvedHtmlBody).trim();
              final shouldLoadImages =
                  settings.autoLoadEmailImages ||
                  (message.id != null &&
                      widget.loadedEmailImageMessageIds.contains(message.id));
              final VoidCallback? onLoadRequested = message.id == null
                  ? null
                  : () => widget.onEmailImagesApproved(message.id!);
              final bool hasRemoteHtmlImages =
                  resolvedHtmlBody != null &&
                  HtmlContentCodec.containsRemoteImages(resolvedHtmlBody);
              final String? quotedFallbackText =
                  (resolvedHtmlText == null || resolvedHtmlText.isEmpty) &&
                      resolvedQuotedText?.trim().isNotEmpty == true
                  ? resolvedQuotedText!.trim()
                  : null;
              final String? emailFallbackText =
                  resolvedHtmlText?.isNotEmpty == true
                  ? resolvedHtmlText
                  : quotedFallbackText;
              final bool shouldShowImageGallery = hasRemoteHtmlImages;
              final xmppCapabilities = state.xmppCapabilities;
              final supportsMarkers =
                  isEmailTransport || xmppCapabilities?.supportsMarkers == true;
              final supportsReceipts =
                  isEmailTransport ||
                  xmppCapabilities?.supportsReceipts == true;
              final metadataItems = <Widget>[];
              final stanzaId = message.stanzaID.trim();
              if (stanzaId.isNotEmpty) {
                metadataItems.add(
                  _MessageDetailsInfo(
                    label: l10n.chatMessageDetailsStanzaIdLabel,
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
                    label: l10n.chatMessageDetailsOriginIdLabel,
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
                    label: l10n.chatMessageDetailsOccupantIdLabel,
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
                    label: l10n.chatMessageDetailsDeltaIdLabel,
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
                    label: l10n.chatMessageDetailsLocalIdLabel,
                    value: localId!,
                    copyValue: localId,
                    copyLabel: copyLabel,
                  ),
                );
              }
              void handleBack() {
                context.read<ChatsCubit>().setOpenChatRoute(
                  route: ChatRouteIndex.main,
                );
              }

              return SingleChildScrollView(
                child: Container(
                  width: double.maxFinite,
                  padding: EdgeInsets.all(spacing.m),
                  child: Column(
                    spacing: spacing.l,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AxiIconButton.ghost(
                          iconData: LucideIcons.arrowLeft,
                          tooltip: l10n.commonBack,
                          onPressed: handleBack,
                        ),
                      ),
                      if (resolvedHtmlBody != null &&
                          resolvedHtmlBody.isNotEmpty)
                        DecoratedBox(
                          decoration: ShapeDecoration(
                            color: context.colorScheme.card,
                            shape: RoundedSuperellipseBorder(
                              borderRadius: BorderRadius.circular(
                                context.radii.squircle,
                              ),
                              side: context.borderSide,
                            ),
                          ),
                          child: EmailHtmlWebView(
                            html: resolvedHtmlBody,
                            allowRemoteImages: shouldLoadImages,
                            simplifyLayout: true,
                            maxHeight:
                                MediaQuery.sizeOf(context).height *
                                context.sizing.dialogMaxHeightFraction,
                            minHeight: context.sizing.attachmentPreviewExtent,
                            onLinkTap: (url) => _handleLinkTap(context, url),
                          ),
                        )
                      else if (emailFallbackText != null &&
                          emailFallbackText.isNotEmpty)
                        SelectableText(emailFallbackText, style: textTheme.lead)
                      else if (emailFallbackText == null ||
                          emailFallbackText.isEmpty)
                        SelectableText(
                          message.body ?? '',
                          style: textTheme.lead,
                        ),
                      if (shouldShowImageGallery &&
                          !shouldLoadImages &&
                          onLoadRequested != null)
                        EmailImagePlaceholder(onTap: onLoadRequested),
                      if (shareContext?.subject?.isNotEmpty == true)
                        Column(
                          spacing: spacing.s,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              context.l10n.chatMessageSubjectLabel,
                              style: textTheme.muted,
                            ),
                            Text(
                              shareContext!.subject!,
                              style: textTheme.p.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      if (showEmailRecipients)
                        Column(
                          spacing: spacing.s,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              context.l10n.chatMessageRecipientsLabel,
                              style: textTheme.muted,
                            ),
                            Wrap(
                              spacing: spacing.s,
                              runSpacing: spacing.s,
                              alignment: WrapAlignment.center,
                              children: [
                                for (final participant in shareParticipants)
                                  _RecipientChip(
                                    chat: participant,
                                    onPressed: () => _showRecipientActions(
                                      context,
                                      recipient: participant,
                                      canCreateEmailChat:
                                          state.emailServiceAvailable &&
                                          participant.deltaChatId == null,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        )
                      else if (shareParticipants.isNotEmpty)
                        Column(
                          spacing: spacing.s,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              context.l10n.chatMessageAlsoSentToLabel,
                              style: textTheme.muted,
                            ),
                            Wrap(
                              spacing: spacing.s,
                              runSpacing: spacing.s,
                              alignment: WrapAlignment.center,
                              children: [
                                for (final participant in shareParticipants)
                                  _RecipientChip(
                                    chat: participant,
                                    onPressed: () => _showRecipientActions(
                                      context,
                                      recipient: participant,
                                      canCreateEmailChat:
                                          state.emailServiceAvailable &&
                                          participant.deltaChatId == null,
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
                        _ReactionsRow(reactions: message.reactionsPreview),
                      if (isFromSelf)
                        Wrap(
                          spacing: spacing.m,
                          runSpacing: spacing.m,
                          alignment: WrapAlignment.center,
                          children: [
                            ShadBadge.secondary(
                              padding: EdgeInsets.all(spacing.s),
                              child: Row(
                                spacing: spacing.xs,
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
                            if (supportsMarkers || supportsReceipts)
                              ShadBadge.secondary(
                                padding: EdgeInsets.all(spacing.s),
                                child: Row(
                                  spacing: spacing.xs,
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
                            if (supportsMarkers)
                              ShadBadge.secondary(
                                padding: EdgeInsets.all(spacing.s),
                                child: Row(
                                  spacing: spacing.xs,
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
                        spacing: spacing.m,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _MessageDetailsInfo(
                            label: l10n.chatMessageInfoTimestamp,
                            value: timestampLabel,
                          ),
                          Wrap(
                            spacing: spacing.l,
                            runSpacing: spacing.m,
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
                      if (!hideSenderAddress && senderAddress.isNotEmpty)
                        _MessageDetailsInfo(
                          label: l10n.chatMessageDetailsSenderLabel,
                          value: senderAddress,
                          copyValue: senderAddress,
                          copyLabel: copyLabel,
                        ),
                      if (metadataItems.isNotEmpty)
                        Column(
                          spacing: spacing.s,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              l10n.chatMessageDetailsMetadataLabel,
                              style: textTheme.muted,
                            ),
                            Wrap(
                              spacing: spacing.m,
                              runSpacing: spacing.m,
                              alignment: WrapAlignment.center,
                              children: metadataItems,
                            ),
                          ],
                        ),
                      if (isEmailMessage)
                        _MessageTextDumpSection(
                          content: rawHeaders,
                          title: l10n.chatMessageDetailsHeadersLabel,
                          buttonLabel:
                              l10n.chatMessageDetailsHeadersActionLabel,
                          note: l10n.chatMessageDetailsHeadersNote,
                          loadingLabel:
                              l10n.chatMessageDetailsHeadersLoadingLabel,
                          unavailableLabel:
                              l10n.chatMessageDetailsHeadersUnavailableLabel,
                          isLoading: isHeadersLoading,
                          isUnavailable: isHeadersUnavailable,
                        ),
                      if (isEmailMessage)
                        _MessageTextDumpSection(
                          content: debugDump,
                          title: l10n.chatMessageDetailsDebugDumpLabel,
                          buttonLabel:
                              l10n.chatMessageDetailsDebugDumpActionLabel,
                          note: l10n.chatMessageDetailsDebugDumpNote,
                          loadingLabel:
                              l10n.chatMessageDetailsDebugDumpLoadingLabel,
                          unavailableLabel:
                              l10n.chatMessageDetailsDebugDumpUnavailableLabel,
                          isLoading: isDebugDumpLoading,
                          isUnavailable: isDebugDumpUnavailable,
                        ),
                      if (message.error.isNotNone)
                        Column(
                          spacing: spacing.s,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.chatMessageInfoError,
                              style: textTheme.muted,
                            ),
                            Text(
                              message.error.label(l10n),
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
      ),
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
    required bool canCreateEmailChat,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final onAddRecipient = widget.onAddRecipient;
    await showFadeScaleDialog<void>(
      context: context,
      builder: (dialogContext) {
        final spacing = context.spacing;
        var creating = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return ShadDialog(
              constraints: BoxConstraints(
                maxWidth: context.sizing.dialogMaxWidth,
              ),
              title: Text(
                recipient.contactDisplayName ?? recipient.title,
                style: context.modalHeaderTextStyle,
              ),
              actions: [
                AxiButton(
                  variant: AxiButtonVariant.outline,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.commonClose),
                ),
              ],
              child: Column(
                spacing: spacing.s,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (onAddRecipient != null)
                    AxiButton(
                      variant: AxiButtonVariant.secondary,
                      onPressed: () {
                        final recipientName =
                            recipient.contactDisplayName ?? recipient.title;
                        onAddRecipient(recipient);
                        Navigator.of(dialogContext).pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.chatMessageAddRecipientSuccess(
                                recipientName,
                              ),
                            ),
                          ),
                        );
                      },
                      child: Text(context.l10n.chatMessageAddRecipients),
                    ),
                  AxiButton(
                    variant: AxiButtonVariant.secondary,
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      context.read<ChatsCubit>().openChat(jid: recipient.jid);
                    },
                    child: Text(context.l10n.chatMessageOpenChat),
                  ),
                  if (canCreateEmailChat)
                    AxiButton(
                      variant: AxiButtonVariant.secondary,
                      loading: creating,
                      onPressed: creating
                          ? null
                          : () {
                              setState(() {
                                creating = true;
                              });
                              Navigator.of(dialogContext).pop();
                              final recipientName =
                                  recipient.contactDisplayName ??
                                  recipient.title;
                              context.read<ChatBloc>().add(
                                ChatRecipientEmailChatRequested(
                                  recipient: recipient,
                                  failureMessage: context.l10n
                                      .chatMessageCreateChatFailure(
                                        recipientName,
                                      ),
                                ),
                              );
                            },
                      child: Text(context.l10n.chatMessageCreateChat),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleLinkTap(BuildContext context, String url) async {
    if (!context.mounted) return;
    final l10n = context.l10n;
    final report = assessLinkSafety(raw: url, kind: LinkSafetyKind.message);
    if (report == null || !report.isSafe) {
      _showSnackbar(context, l10n.chatInvalidLink(url.trim()));
      return;
    }
    final hostLabel = formatLinkSchemeHostLabel(report);
    final baseMessage = report.needsWarning
        ? l10n.chatOpenLinkWarningMessage(report.displayUri, hostLabel)
        : l10n.chatOpenLinkMessage(report.displayUri, hostLabel);
    final warningBlock = formatLinkWarningText(report.warnings);
    final action = await showLinkActionDialog(
      context,
      title: l10n.chatOpenLinkTitle,
      message: '$baseMessage$warningBlock',
      openLabel: l10n.chatOpenLinkConfirm,
      copyLabel: l10n.chatActionCopy,
      cancelLabel: l10n.commonCancel,
    );
    if (!context.mounted) return;
    if (action == null) return;
    if (action == LinkAction.copy) {
      await Clipboard.setData(ClipboardData(text: report.displayUri));
      return;
    }
    final launched = await launchUrl(
      report.uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      _showSnackbar(context, l10n.chatUnableToOpenHost(report.displayHost));
    }
  }

  void _showSnackbar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MessageTextDumpSection extends StatelessWidget {
  const _MessageTextDumpSection({
    required this.content,
    required this.title,
    required this.buttonLabel,
    required this.note,
    required this.loadingLabel,
    required this.unavailableLabel,
    required this.isLoading,
    required this.isUnavailable,
  });

  final String? content;
  final String title;
  final String buttonLabel;
  final String note;
  final String loadingLabel;
  final String unavailableLabel;
  final bool isLoading;
  final bool isUnavailable;

  bool get _canOpen => content?.trim().isNotEmpty == true;

  String? get _statusLabel {
    if (isLoading) return loadingLabel;
    if (isUnavailable) return unavailableLabel;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel;
    final spacing = context.spacing;
    final trimmedNote = note.trim();
    final hasNote = trimmedNote.isNotEmpty;
    return Column(
      spacing: spacing.s,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: context.textTheme.muted),
        Wrap(
          spacing: spacing.s,
          runSpacing: spacing.s,
          alignment: WrapAlignment.center,
          children: [
            AxiButton(
              variant: AxiButtonVariant.secondary,
              onPressed: _canOpen ? () => _showTextDumpDialog(context) : null,
              child: Text(buttonLabel),
            ),
            AxiButton(
              variant: AxiButtonVariant.outline,
              onPressed: _canOpen
                  ? () async {
                      await Clipboard.setData(ClipboardData(text: content!));
                    }
                  : null,
              child: Text(context.l10n.chatActionCopy),
            ),
          ],
        ),
        if (statusLabel != null)
          Text(statusLabel, style: context.textTheme.muted),
        if (hasNote) Text(trimmedNote, style: context.textTheme.muted),
        if (_canOpen)
          ShadCard(
            padding: EdgeInsets.all(spacing.m),
            child: SelectableText(content!, style: context.textTheme.small),
          ),
      ],
    );
  }

  Future<void> _showTextDumpDialog(BuildContext context) async {
    final text = content;
    if (text == null || !_canOpen) return;
    final l10n = context.l10n;
    await showFadeScaleDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _TextDumpDialog(
          content: text,
          title: title,
          note: note,
          copyLabel: l10n.chatActionCopy,
          closeLabel: l10n.commonClose,
        );
      },
    );
  }
}

class _TextDumpDialog extends StatelessWidget {
  const _TextDumpDialog({
    required this.content,
    required this.title,
    required this.note,
    required this.copyLabel,
    required this.closeLabel,
  });

  final String content;
  final String title;
  final String note;
  final String copyLabel;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    final trimmedNote = note.trim();
    final hasNote = trimmedNote.isNotEmpty;
    final spacing = context.spacing;
    final maxHeight =
        MediaQuery.sizeOf(context).height *
        context.sizing.dialogMaxHeightFraction;
    return ShadDialog(
      constraints: BoxConstraints(maxWidth: context.sizing.dialogMaxWidth),
      title: Text(title, style: context.modalHeaderTextStyle),
      actions: [
        AxiButton(
          variant: AxiButtonVariant.secondary,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: content));
          },
          child: Text(copyLabel),
        ),
        AxiButton(
          variant: AxiButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(closeLabel),
        ),
      ],
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            spacing: spacing.s,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasNote) Text(trimmedNote, style: context.textTheme.muted),
              ShadCard(
                padding: EdgeInsets.all(spacing.m),
                child: SelectableText(content, style: context.textTheme.small),
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
    final spacing = context.spacing;
    final sizing = context.sizing;
    final copyButton = canCopy
        ? AxiIconButton.ghost(
            tooltip: resolvedCopyLabel,
            iconData: LucideIcons.copy,
            iconSize: sizing.menuItemIconSize,
            color: context.colorScheme.mutedForeground,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: trimmedCopyValue!));
            },
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
        if (leading != null) ...[leading!, SizedBox(width: spacing.xs)],
        Flexible(fit: FlexFit.loose, child: valueText),
        if (copyButton != null) ...[SizedBox(width: spacing.xs), copyButton],
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: context.textTheme.muted),
        valueRow,
      ],
    );
  }
}

class _RecipientChip extends StatelessWidget {
  const _RecipientChip({required this.chat, required this.onPressed});

  final Chat chat;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sizing = context.sizing;
    return AxiButton(
      variant: AxiButtonVariant.secondary,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.mail, size: sizing.menuItemIconSize),
          SizedBox(width: spacing.xs),
          Text(
            chat.contactDisplayName?.isNotEmpty == true
                ? chat.contactDisplayName!
                : chat.title,
          ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.reaction});

  final ReactionPreview reaction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final highlight = reaction.reactedBySelf;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlight ? colors.secondary : colors.card,
        borderRadius: context.radius,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.m,
          vertical: spacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reaction.emoji, style: context.textTheme.p),
            SizedBox(width: spacing.xs),
            Text('${reaction.count}', style: context.textTheme.small),
          ],
        ),
      ),
    );
  }
}

class _RecipientsRow extends StatelessWidget {
  const _RecipientsRow({required this.sender, required this.recipients});

  final String? sender;
  final List<Chat> recipients;

  @override
  Widget build(BuildContext context) {
    if (recipients.isEmpty) {
      return const SizedBox.shrink();
    }
    final spacing = context.spacing;
    return Column(
      spacing: spacing.s,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (sender != null)
          Text(
            context.l10n.chatMessageFromLabel(sender!),
            style: context.textTheme.muted,
          ),
        Wrap(
          spacing: spacing.s,
          runSpacing: spacing.s,
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
    final spacing = context.spacing;
    return Column(
      spacing: spacing.s,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          context.l10n.chatMessageReactionsLabel,
          style: context.textTheme.muted,
        ),
        Wrap(
          spacing: spacing.s,
          runSpacing: spacing.s,
          alignment: WrapAlignment.center,
          children: [
            for (final reaction in reactions) _ReactionChip(reaction: reaction),
          ],
        ),
      ],
    );
  }
}
