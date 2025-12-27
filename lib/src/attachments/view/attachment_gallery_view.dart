import 'package:axichat/src/app.dart';
import 'package:axichat/src/attachments/attachment_gallery_repository.dart';
import 'package:axichat/src/attachments/attachment_metadata_extensions.dart';
import 'package:axichat/src/attachments/bloc/attachment_gallery_cubit.dart';
import 'package:axichat/src/chat/view/attachment_approval_dialog.dart';
import 'package:axichat/src/chat/view/chat_attachment_preview.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/app_localizations.dart';
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
const double _attachmentGalleryControlsSpacing = 12.0;
const double _attachmentGalleryControlSpacing = 8.0;
const double _attachmentGalleryControlRowSpacing = 12.0;
const double _attachmentGalleryControlsBreakpoint = 520.0;
const double _attachmentGalleryGridSpacing = 12.0;
const double _attachmentGalleryGridMinTileWidth = 160.0;
const int _attachmentGalleryGridMinColumns = 2;
const int _attachmentGalleryGridMaxColumns = 4;
const double _attachmentGalleryPreviewAspectRatio = 1.0;
const double _attachmentGalleryFooterHeight = 56.0;
const double _attachmentGalleryFooterSpacing = 8.0;
const double _attachmentGalleryMetaSpacing = 4.0;
const int _attachmentGalleryFilenameMaxLines = 2;
const int _attachmentGalleryMetaMaxLines = 1;
const String _attachmentGalleryMetaSeparator = ' - ';
const int _attachmentGallerySortBefore = -1;
const int _attachmentGallerySortAfter = 1;
const int _attachmentGalleryFallbackEpochMs = 0;
final DateTime _attachmentGalleryFallbackTimestamp =
    DateTime.fromMillisecondsSinceEpoch(_attachmentGalleryFallbackEpochMs);

enum AttachmentGallerySortOption {
  newestFirst,
  oldestFirst,
  nameAscending,
  nameDescending,
  sizeAscending,
  sizeDescending,
}

enum AttachmentGalleryTypeFilter {
  all,
  images,
  videos,
  files,
}

enum AttachmentGallerySourceFilter {
  all,
  sent,
  received,
}

extension AttachmentGallerySortOptionLabels on AttachmentGallerySortOption {
  String label(AppLocalizations l10n) {
    return switch (this) {
      AttachmentGallerySortOption.newestFirst => l10n.chatSearchSortNewestFirst,
      AttachmentGallerySortOption.oldestFirst => l10n.chatSearchSortOldestFirst,
      AttachmentGallerySortOption.nameAscending =>
        l10n.attachmentGallerySortNameAscLabel,
      AttachmentGallerySortOption.nameDescending =>
        l10n.attachmentGallerySortNameDescLabel,
      AttachmentGallerySortOption.sizeAscending =>
        l10n.attachmentGallerySortSizeAscLabel,
      AttachmentGallerySortOption.sizeDescending =>
        l10n.attachmentGallerySortSizeDescLabel,
    };
  }

  int compare(AttachmentGalleryItem a, AttachmentGalleryItem b) {
    return switch (this) {
      AttachmentGallerySortOption.newestFirst =>
        _compareByTimestamp(a, b, descending: true),
      AttachmentGallerySortOption.oldestFirst =>
        _compareByTimestamp(a, b, descending: false),
      AttachmentGallerySortOption.nameAscending =>
        _compareByName(a, b, descending: false),
      AttachmentGallerySortOption.nameDescending =>
        _compareByName(a, b, descending: true),
      AttachmentGallerySortOption.sizeAscending =>
        _compareBySize(a, b, descending: false),
      AttachmentGallerySortOption.sizeDescending =>
        _compareBySize(a, b, descending: true),
    };
  }
}

AttachmentGalleryGridMetrics _resolveGridMetrics(double maxWidth) {
  final resolvedWidth =
      maxWidth > 0 ? maxWidth : _attachmentGalleryGridMinTileWidth;
  final rawCount = (resolvedWidth / _attachmentGalleryGridMinTileWidth).floor();
  final crossAxisCount = rawCount
      .clamp(
        _attachmentGalleryGridMinColumns,
        _attachmentGalleryGridMaxColumns,
      )
      .toInt();
  final totalSpacing = _attachmentGalleryGridSpacing * (crossAxisCount - 1);
  final tileWidth = (resolvedWidth - totalSpacing) / crossAxisCount;
  final previewHeight = tileWidth / _attachmentGalleryPreviewAspectRatio;
  final tileHeight = previewHeight +
      _attachmentGalleryFooterHeight +
      _attachmentGalleryFooterSpacing;
  final childAspectRatio = tileWidth / tileHeight;
  return AttachmentGalleryGridMetrics(
    crossAxisCount: crossAxisCount,
    childAspectRatio: childAspectRatio,
  );
}

int _compareByTimestamp(
  AttachmentGalleryItem a,
  AttachmentGalleryItem b, {
  required bool descending,
}) {
  final aTimestamp = a.message.timestamp ?? _attachmentGalleryFallbackTimestamp;
  final bTimestamp = b.message.timestamp ?? _attachmentGalleryFallbackTimestamp;
  final result = aTimestamp.compareTo(bTimestamp);
  if (result == 0) return 0;
  return descending ? -result : result;
}

int _compareByName(
  AttachmentGalleryItem a,
  AttachmentGalleryItem b, {
  required bool descending,
}) {
  final result =
      a.metadata.normalizedFilename.compareTo(b.metadata.normalizedFilename);
  if (result != 0) {
    return descending ? -result : result;
  }
  return _compareByTimestamp(a, b, descending: true);
}

int _compareBySize(
  AttachmentGalleryItem a,
  AttachmentGalleryItem b, {
  required bool descending,
}) {
  final aSize = a.metadata.sizeBytes;
  final bSize = b.metadata.sizeBytes;
  if (aSize == null && bSize == null) {
    return _compareByTimestamp(a, b, descending: true);
  }
  if (aSize == null) return _attachmentGallerySortAfter;
  if (bSize == null) return _attachmentGallerySortBefore;
  final result = aSize.compareTo(bSize);
  if (result != 0) {
    return descending ? -result : result;
  }
  return _compareByTimestamp(a, b, descending: true);
}

extension AttachmentGalleryTypeFilterLabels on AttachmentGalleryTypeFilter {
  String label(AppLocalizations l10n) {
    return switch (this) {
      AttachmentGalleryTypeFilter.all => l10n.attachmentGalleryAllLabel,
      AttachmentGalleryTypeFilter.images => l10n.attachmentGalleryImagesLabel,
      AttachmentGalleryTypeFilter.videos => l10n.attachmentGalleryVideosLabel,
      AttachmentGalleryTypeFilter.files => l10n.attachmentGalleryFilesLabel,
    };
  }

  bool matches(FileMetadataData metadata) {
    return switch (this) {
      AttachmentGalleryTypeFilter.all => true,
      AttachmentGalleryTypeFilter.images => metadata.isImage,
      AttachmentGalleryTypeFilter.videos => metadata.isVideo,
      AttachmentGalleryTypeFilter.files =>
        metadata.mediaKind == AttachmentMediaKind.file,
    };
  }
}

extension AttachmentGallerySourceFilterLabels on AttachmentGallerySourceFilter {
  String label(AppLocalizations l10n) {
    return switch (this) {
      AttachmentGallerySourceFilter.all => l10n.attachmentGalleryAllLabel,
      AttachmentGallerySourceFilter.sent => l10n.attachmentGallerySentLabel,
      AttachmentGallerySourceFilter.received =>
        l10n.attachmentGalleryReceivedLabel,
    };
  }

  bool matches(Message message) {
    return switch (this) {
      AttachmentGallerySourceFilter.all => true,
      AttachmentGallerySourceFilter.sent => !message.received,
      AttachmentGallerySourceFilter.received => message.received,
    };
  }
}

class AttachmentGalleryGridMetrics {
  const AttachmentGalleryGridMetrics({
    required this.crossAxisCount,
    required this.childAspectRatio,
  });

  final int crossAxisCount;
  final double childAspectRatio;
}

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
  late final TextEditingController _searchController = TextEditingController()
    ..addListener(_handleSearchChanged);
  AttachmentGallerySortOption _sortOption =
      AttachmentGallerySortOption.newestFirst;
  AttachmentGalleryTypeFilter _typeFilter = AttachmentGalleryTypeFilter.all;
  AttachmentGallerySourceFilter _sourceFilter =
      AttachmentGallerySourceFilter.all;

  String get _searchQuery => _searchController.text.trim().toLowerCase();

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
    final rosterCubit = context.read<RosterCubit?>();
    final chatsCubit = context.read<ChatsCubit?>();
    final isSelf = xmppService.myJid?.trim().toLowerCase() ==
        senderBare.trim().toLowerCase();
    final canAddToRoster = !isSelf &&
        !isEmailChat &&
        !isGroupChat &&
        senderBare.isValidJid &&
        senderBare.trim().isNotEmpty;
    final canTrustChat =
        !isSelf && chat != null && (isEmailChat || isGroupChat);
    final showAutoTrustToggle = canAddToRoster || canTrustChat;
    final autoTrustLabel = canAddToRoster
        ? l10n.attachmentGalleryRosterTrustLabel
        : l10n.attachmentGalleryChatTrustLabel;
    final autoTrustHint = canAddToRoster
        ? l10n.attachmentGalleryRosterTrustHint
        : l10n.attachmentGalleryChatTrustHint;
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
      if (rosterCubit != null) {
        await rosterCubit.addContact(jid: senderBare);
      } else {
        try {
          await xmppService.addToRoster(jid: senderBare);
        } on Exception {
          showToast?.call(
            FeedbackToast.error(
              title: l10n.attachmentGalleryRosterErrorTitle,
              message: l10n.attachmentGalleryRosterErrorMessage,
            ),
          );
        }
      }
    }
    if (decision.alwaysAllow && canTrustChat) {
      final resolvedChat = chat;
      if (chatsCubit != null) {
        await chatsCubit.toggleAttachmentAutoDownload(
          jid: resolvedChat.jid,
          enabled: true,
        );
      } else {
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

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatsCubit = context.watch<ChatsCubit>();
    final chats = chatsCubit.state.items ?? const <Chat>[];
    final knownContacts = context.watch<RosterCubit>().contacts;
    final xmppService = context.read<XmppService>();
    final emailService = RepositoryProvider.of<EmailService?>(context);
    final l10n = context.l10n;
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
                l10n.attachmentGalleryErrorMessage,
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

        final filteredItems = _filterItems(
          items: items,
          chatLookup: chatLookup,
          chatOverride: chatOverride,
          showChatLabel: showChatLabel,
        );
        final hasFilters = _hasActiveFilters;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _attachmentGalleryHorizontalPadding,
                _attachmentGalleryTopPadding,
                _attachmentGalleryHorizontalPadding,
                0,
              ),
              child: AttachmentGalleryControls(
                searchController: _searchController,
                sortOption: _sortOption,
                onSortChanged: (value) {
                  setState(() {
                    _sortOption = value;
                  });
                },
                typeFilter: _typeFilter,
                onTypeFilterChanged: (value) {
                  setState(() {
                    _typeFilter = value;
                  });
                },
                sourceFilter: _sourceFilter,
                onSourceFilterChanged: (value) {
                  setState(() {
                    _sourceFilter = value;
                  });
                },
                onClearSearch: _searchController.clear,
              ),
            ),
            const SizedBox(height: _attachmentGalleryItemSpacing),
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        hasFilters
                            ? context.l10n.chatEmptySearch
                            : context.l10n.draftNoAttachments,
                        style: context.textTheme.muted,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final gridMetrics =
                            _resolveGridMetrics(constraints.maxWidth);
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            _attachmentGalleryHorizontalPadding,
                            0,
                            _attachmentGalleryHorizontalPadding,
                            _attachmentGalleryBottomPadding,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridMetrics.crossAxisCount,
                            mainAxisSpacing: _attachmentGalleryGridSpacing,
                            crossAxisSpacing: _attachmentGalleryGridSpacing,
                            childAspectRatio: gridMetrics.childAspectRatio,
                          ),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final message = item.message;
                            final metadata = item.metadata;
                            final chat =
                                chatOverride ?? chatLookup[message.chatJid];
                            final isGroupChat =
                                chat?.type == ChatType.groupChat;
                            final isEmailMessage = message.deltaMsgId != null ||
                                message.deltaChatId != null;
                            final isEmailChat =
                                (chat?.defaultTransport.isEmail ?? false) ||
                                    isEmailMessage;
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
                            final allowOnce =
                                _isOneTimeAttachmentAllowed(message.stanzaID);
                            final allowAttachment = allowByTrust || allowOnce;
                            final downloadDelegate =
                                isEmailChat && emailService != null
                                    ? AttachmentDownloadDelegate(
                                        () => emailService
                                            .downloadFullMessage(message),
                                      )
                                    : null;
                            final autoDownload =
                                allowAttachment && !isEmailChat;
                            final autoDownloadUserInitiated =
                                allowOnce && !isEmailChat;
                            final metaText = _resolveMetaText(
                              chat: chat,
                              showChatLabel: showChatLabel,
                            );
                            return AttachmentGalleryTile(
                              metadata: metadata,
                              stanzaId: message.stanzaID,
                              allowed: allowAttachment,
                              autoDownload: autoDownload,
                              autoDownloadUserInitiated:
                                  autoDownloadUserInitiated,
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
                    ),
            ),
          ],
        );
      },
    );
  }

  bool get _hasActiveFilters {
    final hasQuery = _searchQuery.isNotEmpty;
    final hasTypeFilter = _typeFilter != AttachmentGalleryTypeFilter.all;
    final hasSourceFilter = _sourceFilter != AttachmentGallerySourceFilter.all;
    return hasQuery || hasTypeFilter || hasSourceFilter;
  }

  List<AttachmentGalleryItem> _filterItems({
    required List<AttachmentGalleryItem> items,
    required Map<String, Chat> chatLookup,
    required Chat? chatOverride,
    required bool showChatLabel,
  }) {
    final query = _searchQuery;
    final hasQuery = query.isNotEmpty;
    final filtered = items.where((item) {
      if (!_typeFilter.matches(item.metadata)) return false;
      if (!_sourceFilter.matches(item.message)) return false;
      if (!hasQuery) return true;
      if (item.metadata.normalizedFilename.contains(query)) return true;
      if (!showChatLabel) return false;
      final chat = chatOverride ?? chatLookup[item.message.chatJid];
      final chatLabel = chat?.displayName.trim().toLowerCase() ?? '';
      if (chatLabel.isEmpty) return false;
      return chatLabel.contains(query);
    }).toList();
    filtered.sort(_sortOption.compare);
    return filtered;
  }

  String? _resolveMetaText({
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

class AttachmentGalleryControls extends StatelessWidget {
  const AttachmentGalleryControls({
    super.key,
    required this.searchController,
    required this.sortOption,
    required this.onSortChanged,
    required this.typeFilter,
    required this.onTypeFilterChanged,
    required this.sourceFilter,
    required this.onSourceFilterChanged,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final AttachmentGallerySortOption sortOption;
  final ValueChanged<AttachmentGallerySortOption> onSortChanged;
  final AttachmentGalleryTypeFilter typeFilter;
  final ValueChanged<AttachmentGalleryTypeFilter> onTypeFilterChanged;
  final AttachmentGallerySourceFilter sourceFilter;
  final ValueChanged<AttachmentGallerySourceFilter> onSourceFilterChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _attachmentGalleryControlsSpacing,
      children: [
        AttachmentGallerySearchRow(
          searchController: searchController,
          onClearSearch: onClearSearch,
        ),
        AttachmentGalleryFilterRow(
          sortOption: sortOption,
          onSortChanged: onSortChanged,
          typeFilter: typeFilter,
          onTypeFilterChanged: onTypeFilterChanged,
          sourceFilter: sourceFilter,
          onSourceFilterChanged: onSourceFilterChanged,
        ),
      ],
    );
  }
}

class AttachmentGallerySearchRow extends StatelessWidget {
  const AttachmentGallerySearchRow({
    super.key,
    required this.searchController,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trimmedQuery = searchController.text.trim();
    final canClear = trimmedQuery.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: ShadInput(
            controller: searchController,
            placeholder: Text(l10n.commonSearch),
          ),
        ),
        const SizedBox(width: _attachmentGalleryControlSpacing),
        AxiIconButton(
          iconData: LucideIcons.x,
          tooltip: l10n.commonClear,
          onPressed: canClear ? onClearSearch : null,
        ),
      ],
    );
  }
}

class AttachmentGalleryFilterRow extends StatelessWidget {
  const AttachmentGalleryFilterRow({
    super.key,
    required this.sortOption,
    required this.onSortChanged,
    required this.typeFilter,
    required this.onTypeFilterChanged,
    required this.sourceFilter,
    required this.onSourceFilterChanged,
  });

  final AttachmentGallerySortOption sortOption;
  final ValueChanged<AttachmentGallerySortOption> onSortChanged;
  final AttachmentGalleryTypeFilter typeFilter;
  final ValueChanged<AttachmentGalleryTypeFilter> onTypeFilterChanged;
  final AttachmentGallerySourceFilter sourceFilter;
  final ValueChanged<AttachmentGallerySourceFilter> onSourceFilterChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final sortSelect = AttachmentGallerySelect<AttachmentGallerySortOption>(
          value: sortOption,
          onChanged: onSortChanged,
          labelBuilder: (value) => value.label(l10n),
          options: AttachmentGallerySortOption.values,
        );
        final typeSelect = AttachmentGallerySelect<AttachmentGalleryTypeFilter>(
          value: typeFilter,
          onChanged: onTypeFilterChanged,
          labelBuilder: (value) => value.label(l10n),
          options: AttachmentGalleryTypeFilter.values,
        );
        final sourceSelect =
            AttachmentGallerySelect<AttachmentGallerySourceFilter>(
          value: sourceFilter,
          onChanged: onSourceFilterChanged,
          labelBuilder: (value) => value.label(l10n),
          options: AttachmentGallerySourceFilter.values,
        );
        if (constraints.maxWidth < _attachmentGalleryControlsBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: _attachmentGalleryControlRowSpacing,
            children: [
              sortSelect,
              typeSelect,
              sourceSelect,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: sortSelect),
            const SizedBox(width: _attachmentGalleryControlSpacing),
            Expanded(child: typeSelect),
            const SizedBox(width: _attachmentGalleryControlSpacing),
            Expanded(child: sourceSelect),
          ],
        );
      },
    );
  }
}

class AttachmentGallerySelect<T> extends StatelessWidget {
  const AttachmentGallerySelect({
    super.key,
    required this.value,
    required this.onChanged,
    required this.options,
    required this.labelBuilder,
  });

  final T value;
  final ValueChanged<T> onChanged;
  final List<T> options;
  final String Function(T) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return ShadSelect<T>(
      initialValue: value,
      onChanged: (value) {
        if (value == null) return;
        onChanged(value);
      },
      options: options
          .map(
            (option) => ShadOption<T>(
              value: option,
              child: Text(labelBuilder(option)),
            ),
          )
          .toList(growable: false),
      selectedOptionBuilder: (_, value) => Text(labelBuilder(value)),
    );
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
    final showFilename = metadata.mediaKind != AttachmentMediaKind.file;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ChatAttachmentPreview(
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
          ),
        ),
        const SizedBox(height: _attachmentGalleryFooterSpacing),
        if (showFilename)
          Text(
            metadata.filename,
            style: context.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: _attachmentGalleryFilenameMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        if (metaLabel != null)
          Text(
            metaLabel,
            style: context.textTheme.muted,
            maxLines: _attachmentGalleryMetaMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        if (!showFilename && metaLabel == null)
          const SizedBox(height: _attachmentGalleryMetaSpacing),
      ],
    );
  }
}
