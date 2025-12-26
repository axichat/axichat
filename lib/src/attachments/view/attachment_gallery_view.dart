import 'package:axichat/src/app.dart';
import 'package:axichat/src/attachments/bloc/attachment_gallery_cubit.dart';
import 'package:axichat/src/chat/view/attachment_approval_dialog.dart';
import 'package:axichat/src/chat/view/chat_attachment_preview.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:shadcn_ui/shadcn_ui.dart';

const double _attachmentGalleryHorizontalPadding = 16.0;
const double _attachmentGalleryTopPadding = 12.0;
const double _attachmentGalleryBottomPadding = 16.0;
const double _attachmentGalleryItemSpacing = 16.0;
const double _attachmentGalleryTileSpacing = 8.0;
const double _attachmentGalleryMetaSpacing = 4.0;
const int _attachmentGalleryTextMaxLines = 1;
const String _attachmentGalleryMetaSeparator = ' - ';
const String _attachmentGalleryRosterTrustLabel =
    'Automatically download files from this user';
const String _attachmentGalleryRosterTrustHint =
    'You can turn this off later in chat settings.';
const String _attachmentGalleryChatTrustLabel =
    'Always allow attachments in this chat';
const String _attachmentGalleryChatTrustHint =
    'You can turn this off later in chat settings.';
const String _attachmentGalleryRosterErrorTitle = 'Unable to add contact';
const String _attachmentGalleryRosterErrorMessage =
    'Downloaded this attachment once, but automatic downloads are still disabled.';
const String _attachmentGalleryErrorMessage = 'Unable to load attachments.';

class AttachmentGalleryPanel extends StatelessWidget {
  const AttachmentGalleryPanel({
    super.key,
    required this.title,
    required this.onClose,
    this.chat,
  });

  final String title;
  final VoidCallback onClose;
  final Chat? chat;

  @override
  Widget build(BuildContext context) {
    final resolvedChat = chat;
    if (resolvedChat == null) {
      return const SizedBox.shrink();
    }
    final xmppService = context.read<XmppService>();
    return BlocProvider(
      create: (context) => AttachmentGalleryCubit(
        xmppService: xmppService,
        chatJid: resolvedChat.jid,
      ),
      child: AxiSheetScaffold(
        header: AxiSheetHeader(
          title: Text(title),
          subtitle: Text(resolvedChat.displayName),
          onClose: onClose,
        ),
        body: AttachmentGalleryView(
          chatOverride: resolvedChat,
          showChatLabel: false,
        ),
      ),
    );
  }
}

class AttachmentGalleryView extends StatefulWidget {
  const AttachmentGalleryView({
    super.key,
    this.chatOverride,
    required this.showChatLabel,
  });

  final Chat? chatOverride;
  final bool showChatLabel;

  @override
  State<AttachmentGalleryView> createState() => _AttachmentGalleryViewState();
}

class _AttachmentGalleryViewState extends State<AttachmentGalleryView> {
  final Set<String> _oneTimeAllowedStanzaIds = <String>{};

  bool _isOneTimeAttachmentAllowed(String stanzaId) {
    final trimmed = stanzaId.trim();
    if (trimmed.isEmpty) return false;
    return _oneTimeAllowedStanzaIds.contains(trimmed);
  }

  bool _shouldAllowAttachment({
    required String senderJid,
    required bool isSelf,
    required Set<String> knownContacts,
    required Chat? chat,
  }) {
    if (isSelf) return true;
    if (chat == null) return false;
    final isGroupChat = chat.type == ChatType.groupChat;
    final isEmailChat = chat.defaultTransport.isEmail;
    if (isGroupChat || isEmailChat) {
      return chat.attachmentAutoDownload.isAllowed;
    }
    final senderBare = _bareJid(senderJid) ?? senderJid;
    final normalizedSender =
        senderBare.trim().isNotEmpty ? senderBare.trim() : senderJid.trim();
    return knownContacts.contains(normalizedSender);
  }

  String? _bareJid(String? jid) {
    if (jid == null || jid.isEmpty) return null;
    try {
      return mox.JID.fromString(jid).toBare().toString();
    } on Exception {
      return jid;
    }
  }

  bool _isSelfMessage(
    Message message, {
    required XmppService xmppService,
    required EmailService? emailService,
  }) {
    if (!message.received) return true;
    final sender = message.senderJid.trim().toLowerCase();
    final xmppJid = xmppService.myJid?.trim().toLowerCase();
    if (xmppJid != null && sender == xmppJid) return true;
    final emailJid = emailService?.selfSenderJid?.trim().toLowerCase();
    if (emailJid != null && sender == emailJid) return true;
    return false;
  }

  Future<void> _approveAttachment({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required Chat? chat,
    required bool isGroupChat,
    required bool isEmailChat,
  }) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final senderEmail = chat?.emailAddress;
    final displaySender =
        senderEmail?.trim().isNotEmpty == true ? senderEmail! : senderJid;
    final senderBare = _bareJid(senderJid) ?? senderJid;
    final xmppService = context.read<XmppService>();
    final isSelf = xmppService.myJid?.trim().toLowerCase() ==
        senderBare.trim().toLowerCase();
    final canAddToRoster = !isSelf &&
        !isEmailChat &&
        !isGroupChat &&
        senderBare.isValidJid &&
        senderBare.trim().isNotEmpty;
    final canTrustChat = !isSelf && (isEmailChat || isGroupChat);
    final showAutoTrustToggle = canAddToRoster || canTrustChat;
    final autoTrustLabel = canAddToRoster
        ? _attachmentGalleryRosterTrustLabel
        : _attachmentGalleryChatTrustLabel;
    final autoTrustHint = canAddToRoster
        ? _attachmentGalleryRosterTrustHint
        : _attachmentGalleryChatTrustHint;
    final decision = await showShadDialog<AttachmentApprovalDecision>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AttachmentApprovalDialog(
          title: l10n.chatAttachmentConfirmTitle,
          message: l10n.chatAttachmentConfirmMessage(displaySender),
          confirmLabel: l10n.chatAttachmentConfirmButton,
          cancelLabel: l10n.commonCancel,
          showAutoTrustToggle: showAutoTrustToggle,
          autoTrustLabel: autoTrustLabel,
          autoTrustHint: autoTrustHint,
        );
      },
    );
    if (!mounted) return;
    if (decision == null || !decision.approved) return;

    final emailService = RepositoryProvider.of<EmailService?>(context);
    final showToast = ShadToaster.maybeOf(context)?.show;
    if (decision.alwaysAllow && canAddToRoster) {
      try {
        await xmppService.addToRoster(jid: senderBare);
      } on Exception {
        showToast?.call(
          FeedbackToast.error(
            title: _attachmentGalleryRosterErrorTitle,
            message: _attachmentGalleryRosterErrorMessage,
          ),
        );
      }
    }
    if (decision.alwaysAllow && canTrustChat) {
      final resolvedChat = chat;
      if (resolvedChat != null) {
        await xmppService.toggleChatAttachmentAutoDownload(
          jid: resolvedChat.jid,
          enabled: true,
        );
      }
    }
    if (isEmailChat && emailService != null) {
      await emailService.downloadFullMessage(message);
    }
    if (mounted) {
      setState(() {
        _oneTimeAllowedStanzaIds.add(stanzaId.trim());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const listPadding = EdgeInsets.fromLTRB(
      _attachmentGalleryHorizontalPadding,
      _attachmentGalleryTopPadding,
      _attachmentGalleryHorizontalPadding,
      _attachmentGalleryBottomPadding,
    );
    final chatsCubit = context.watch<ChatsCubit>();
    final chats = chatsCubit.state.items ?? const <Chat>[];
    final knownContacts = context.watch<RosterCubit>().contacts;
    final xmppService = context.read<XmppService>();
    final emailService = RepositoryProvider.of<EmailService?>(context);
    final chatOverride = widget.chatOverride;
    final showChatLabel = widget.showChatLabel;
    final chatLookup = <String, Chat>{
      for (final chat in chats) chat.jid: chat,
    };

    return BlocBuilder<AttachmentGalleryCubit, AttachmentGalleryState>(
      builder: (context, state) {
        final items = state.items;
        if (items.isEmpty) {
          if (state.status.isLoading) {
            return Center(
              child: AxiProgressIndicator(
                color: context.colorScheme.foreground,
              ),
            );
          }
          if (state.status.isFailure) {
            return Center(
              child: Text(
                _attachmentGalleryErrorMessage,
                style: context.textTheme.muted,
                textAlign: TextAlign.center,
              ),
            );
          }
          return Center(
            child: Text(
              context.l10n.draftNoAttachments,
              style: context.textTheme.muted,
            ),
          );
        }

        return ListView.separated(
          padding: listPadding,
          itemCount: items.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: _attachmentGalleryItemSpacing),
          itemBuilder: (context, index) {
            final item = items[index];
            final message = item.message;
            final metadata = item.metadata;
            final chat = chatOverride ?? chatLookup[message.chatJid];
            final isGroupChat = chat?.type == ChatType.groupChat;
            final isEmailChat = chat?.defaultTransport.isEmail ?? false;
            final isSelf = _isSelfMessage(
              message,
              xmppService: xmppService,
              emailService: emailService,
            );
            final allowByTrust = _shouldAllowAttachment(
              senderJid: message.senderJid,
              isSelf: isSelf,
              knownContacts: knownContacts,
              chat: chat,
            );
            final allowOnce = _isOneTimeAttachmentAllowed(message.stanzaID);
            final allowAttachment = allowByTrust || allowOnce;
            final downloadDelegate = isEmailChat && emailService != null
                ? AttachmentDownloadDelegate(
                    () => emailService.downloadFullMessage(message),
                  )
                : null;
            final autoDownload = allowAttachment && !isEmailChat;
            final autoDownloadUserInitiated = allowOnce && !isEmailChat;
            final metaText = _buildMetaText(
              chat: chat,
              showChatLabel: showChatLabel,
            );
            return AttachmentGalleryTile(
              metadata: metadata,
              stanzaId: message.stanzaID,
              allowed: allowAttachment,
              autoDownload: autoDownload,
              autoDownloadUserInitiated: autoDownloadUserInitiated,
              downloadDelegate: downloadDelegate,
              onAllowPressed: allowAttachment
                  ? null
                  : () => _approveAttachment(
                        message: message,
                        senderJid: message.senderJid,
                        stanzaId: message.stanzaID,
                        chat: chat,
                        isGroupChat: isGroupChat,
                        isEmailChat: isEmailChat,
                      ),
              metaText: metaText,
            );
          },
        );
      },
    );
  }

  String? _buildMetaText({
    required Chat? chat,
    required bool showChatLabel,
  }) {
    final parts = <String>[];
    if (showChatLabel && chat != null) {
      final label = chat.displayName.trim();
      if (label.isNotEmpty) {
        parts.add(label);
      }
    }
    if (parts.isEmpty) return null;
    return parts.join(_attachmentGalleryMetaSeparator);
  }
}

class AttachmentGalleryTile extends StatelessWidget {
  const AttachmentGalleryTile({
    super.key,
    required this.metadata,
    required this.stanzaId,
    required this.allowed,
    required this.autoDownload,
    required this.autoDownloadUserInitiated,
    required this.downloadDelegate,
    required this.onAllowPressed,
    required this.metaText,
  });

  final FileMetadataData metadata;
  final String stanzaId;
  final bool allowed;
  final bool autoDownload;
  final bool autoDownloadUserInitiated;
  final AttachmentDownloadDelegate? downloadDelegate;
  final VoidCallback? onAllowPressed;
  final String? metaText;

  @override
  Widget build(BuildContext context) {
    final metaLabel = metaText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _attachmentGalleryTileSpacing,
      children: [
        ChatAttachmentPreview(
          stanzaId: stanzaId,
          metadataStream:
              context.read<XmppService>().fileMetadataStream(metadata.id),
          initialMetadata: metadata,
          allowed: allowed,
          autoDownload: autoDownload,
          autoDownloadUserInitiated: autoDownloadUserInitiated,
          downloadDelegate: downloadDelegate,
          onAllowPressed: onAllowPressed,
        ),
        Text(
          metadata.filename,
          style: context.textTheme.small.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: _attachmentGalleryTextMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
        if (metaLabel != null)
          Text(
            metaLabel,
            style: context.textTheme.muted,
            maxLines: _attachmentGalleryTextMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        if (metaLabel == null)
          const SizedBox(height: _attachmentGalleryMetaSpacing),
      ],
    );
  }
}
