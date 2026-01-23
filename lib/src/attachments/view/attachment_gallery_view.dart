// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/attachments/attachment_auto_download_settings.dart';
import 'package:axichat/src/attachments/attachment_metadata_extensions.dart';
import 'package:axichat/src/attachments/bloc/attachment_gallery_cubit.dart';
import 'package:axichat/src/chat/view/attachment_approval_dialog.dart';
import 'package:axichat/src/chat/view/chat_attachment_preview.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/attachment_gallery_repository.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum AttachmentGallerySortOption {
  newestFirst,
  oldestFirst,
  nameAscending,
  nameDescending,
  sizeAscending,
  sizeDescending,
  ;

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
    const fallbackEpochMs = 0;
    const sortBefore = -1;
    const sortAfter = 1;
    final fallbackTimestamp =
        DateTime.fromMillisecondsSinceEpoch(fallbackEpochMs);
    int compareByTimestamp({required bool descending}) {
      final aTimestamp = a.message.timestamp ?? fallbackTimestamp;
      final bTimestamp = b.message.timestamp ?? fallbackTimestamp;
      final result = aTimestamp.compareTo(bTimestamp);
      if (result == 0) return 0;
      return descending ? -result : result;
    }

    int compareByName({required bool descending}) {
      final result = a.metadata.normalizedFilename.compareTo(
        b.metadata.normalizedFilename,
      );
      if (result != 0) {
        return descending ? -result : result;
      }
      return compareByTimestamp(descending: true);
    }

    int compareBySize({required bool descending}) {
      final aSize = a.metadata.sizeBytes;
      final bSize = b.metadata.sizeBytes;
      if (aSize == null && bSize == null) {
        return compareByTimestamp(descending: true);
      }
      if (aSize == null) return sortAfter;
      if (bSize == null) return sortBefore;
      final result = aSize.compareTo(bSize);
      if (result != 0) {
        return descending ? -result : result;
      }
      return compareByTimestamp(descending: true);
    }

    return switch (this) {
      AttachmentGallerySortOption.newestFirst =>
        compareByTimestamp(descending: true),
      AttachmentGallerySortOption.oldestFirst =>
        compareByTimestamp(descending: false),
      AttachmentGallerySortOption.nameAscending =>
        compareByName(descending: false),
      AttachmentGallerySortOption.nameDescending =>
        compareByName(descending: true),
      AttachmentGallerySortOption.sizeAscending =>
        compareBySize(descending: false),
      AttachmentGallerySortOption.sizeDescending =>
        compareBySize(descending: true),
    };
  }
}

enum AttachmentGalleryTypeFilter {
  all,
  images,
  videos,
  files;

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

enum AttachmentGallerySourceFilter {
  all,
  sent,
  received;

  String label(AppLocalizations l10n) {
    return switch (this) {
      AttachmentGallerySourceFilter.all => l10n.attachmentGalleryAllLabel,
      AttachmentGallerySourceFilter.sent => l10n.attachmentGallerySentLabel,
      AttachmentGallerySourceFilter.received =>
        l10n.attachmentGalleryReceivedLabel,
    };
  }

  bool matches({required bool isSelf}) {
    return switch (this) {
      AttachmentGallerySourceFilter.all => true,
      AttachmentGallerySourceFilter.sent => isSelf,
      AttachmentGallerySourceFilter.received => !isSelf,
    };
  }
}

enum AttachmentGalleryLayout { grid, list }

AttachmentGalleryGridMetrics _resolveGridMetrics({
  required double maxWidth,
  required double horizontalPadding,
  required double minTileWidth,
  required double gridSpacing,
  required int minColumns,
  required int maxColumns,
  required double minAvailableWidth,
}) {
  final resolvedWidth = maxWidth > 0 ? maxWidth : minTileWidth;
  final availableWidth = (resolvedWidth - horizontalPadding)
      .clamp(minAvailableWidth, resolvedWidth)
      .toDouble();
  final rawCount = (availableWidth / minTileWidth).floor();
  final crossAxisCount = rawCount.clamp(minColumns, maxColumns).toInt();
  final totalSpacing = gridSpacing * (crossAxisCount - 1);
  final tileWidth = math.max(
    minAvailableWidth,
    (availableWidth - totalSpacing) / crossAxisCount,
  );
  return AttachmentGalleryGridMetrics(
    crossAxisCount: crossAxisCount,
    tileWidth: tileWidth,
  );
}

String? _resolveMetaText({
  required Chat? chat,
  required bool showChatLabel,
  required String separator,
}) {
  final parts = <String>[];
  if (showChatLabel && chat != null) {
    final label = chat.displayName.trim();
    if (label.isNotEmpty) {
      parts.add(label);
    }
  }
  if (parts.isEmpty) return null;
  return parts.join(separator);
}

class AttachmentGalleryGridMetrics {
  const AttachmentGalleryGridMetrics({
    required this.crossAxisCount,
    required this.tileWidth,
  });

  final int crossAxisCount;
  final double tileWidth;
}

class AttachmentGalleryEntryData {
  const AttachmentGalleryEntryData({
    required this.item,
    required this.chat,
    required this.isSelf,
  });

  final AttachmentGalleryItem item;
  final Chat? chat;
  final bool isSelf;
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
    final emailService = RepositoryProvider.of<EmailService?>(context);
    return BlocProvider(
      create: (context) => AttachmentGalleryCubit(
        xmppService: xmppService,
        emailService: emailService,
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
  AttachmentGalleryLayout? _layoutOverride;
  List<AttachmentGalleryEntryData> _filteredItems =
      const <AttachmentGalleryEntryData>[];
  Map<String, Chat> _chatLookup = const <String, Chat>{};

  String get _searchQuery => _searchController.text.trim().toLowerCase();

  AttachmentGalleryLayout _resolveLayout({required bool hasVisualMedia}) {
    final defaultLayout = hasVisualMedia
        ? AttachmentGalleryLayout.grid
        : AttachmentGalleryLayout.list;
    return _layoutOverride ?? defaultLayout;
  }

  void _setLayout(AttachmentGalleryLayout nextLayout) {
    if (_layoutOverride == nextLayout) return;
    setState(() {
      _layoutOverride = nextLayout;
    });
  }

  bool _isOneTimeAttachmentAllowed(String stanzaId) {
    final trimmed = stanzaId.trim();
    if (trimmed.isEmpty) return false;
    return _oneTimeAllowedStanzaIds.contains(trimmed);
  }

  bool _shouldAllowAttachment({required bool isSelf, required Chat? chat}) {
    if (isSelf) return true;
    final resolvedChat = chat;
    if (resolvedChat == null) return false;
    return resolvedChat.attachmentAutoDownload.isAllowed;
  }

  Future<void> _approveAttachment({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required Chat? chat,
    required bool isEmailChat,
  }) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final attachmentCubit = context.read<AttachmentGalleryCubit>();
    final chatsCubit = context.read<ChatsCubit>();
    final senderEmail = chat?.emailAddress;
    final displaySender =
        senderEmail?.trim().isNotEmpty == true ? senderEmail! : senderJid;
    final isSelfBeforeDialog =
        attachmentCubit.isSelfMessage(message);
    final decision = await showFadeScaleDialog<AttachmentApprovalDecision>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AttachmentApprovalDialog(
          title: l10n.chatAttachmentConfirmTitle,
          message: l10n.chatAttachmentConfirmMessage(displaySender),
          confirmLabel: l10n.chatAttachmentConfirmButton,
          cancelLabel: l10n.commonCancel,
          showAutoTrustToggle: !isSelfBeforeDialog && chat != null,
          autoTrustLabel: l10n.attachmentGalleryChatTrustLabel,
          autoTrustHint: l10n.attachmentGalleryChatTrustHint,
        );
      },
    );
    if (!mounted) return;
    if (decision == null || !decision.approved) return;

    if (decision.alwaysAllow &&
        !attachmentCubit.isSelfMessage(message) &&
        chat != null) {
      await chatsCubit.toggleAttachmentAutoDownload(
            jid: chat.jid,
            enabled: true,
          );
    }
    if (isEmailChat) {
      await attachmentCubit.downloadEmailMessage(message);
    }
    if (mounted) {
      setState(() {
        _oneTimeAllowedStanzaIds.add(stanzaId.trim());
      });
    }
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() {
      _updateChatLookup(context.read<ChatsCubit>().state.items);
      _rebuildFilteredItems(
        items: context.read<AttachmentGalleryCubit>().state.items,
        isSelfMessage: context.read<AttachmentGalleryCubit>().isSelfMessage,
      );
    });
  }

  void _updateChatLookup(List<Chat>? chats) {
    if (!widget.showChatLabel && _searchQuery.isEmpty) {
      _chatLookup = const <String, Chat>{};
      return;
    }
    final resolvedChats = chats ?? const <Chat>[];
    _chatLookup = <String, Chat>{
      for (final chat in resolvedChats) chat.jid: chat,
    };
  }

  void _rebuildFilteredItems({
    required List<AttachmentGalleryItem> items,
    required bool Function(Message message) isSelfMessage,
  }) {
    final query = _searchQuery;
    final chatOverride = widget.chatOverride;
    final showChatLabel = widget.showChatLabel;
    final filtered = <AttachmentGalleryEntryData>[];
    for (final item in items) {
      if (!_typeFilter.matches(item.metadata)) {
        continue;
      }
      final isSelf = isSelfMessage(item.message);
      if (!_sourceFilter.matches(isSelf: isSelf)) {
        continue;
      }
      if (query.isNotEmpty) {
        if (!item.metadata.normalizedFilename.contains(query)) {
          if (!showChatLabel) {
            continue;
          }
          final chat = chatOverride ?? _chatLookup[item.message.chatJid];
          final chatLabel = chat?.displayName.trim().toLowerCase() ?? '';
          if (chatLabel.isEmpty || !chatLabel.contains(query)) {
            continue;
          }
        }
      }
      filtered.add(
        AttachmentGalleryEntryData(
          item: item,
          chat: chatOverride ?? _chatLookup[item.message.chatJid],
          isSelf: isSelf,
        ),
      );
    }
    filtered.sort(
      (a, b) => _sortOption.compare(a.item, b.item),
    );
    _filteredItems = List.unmodifiable(filtered);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateChatLookup(context.read<ChatsCubit>().state.items);
    _rebuildFilteredItems(
      items: context.read<AttachmentGalleryCubit>().state.items,
      isSelfMessage: context.read<AttachmentGalleryCubit>().isSelfMessage,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = 16.0;
    const topPadding = 12.0;
    const bottomPadding = 16.0;
    const itemSpacing = 16.0;
    const gridSpacing = 12.0;
    const gridMinTileWidth = 200.0;
    const gridMinColumns = 2;
    const gridMaxColumns = 4;
    const gridMinAvailableWidth = 0.0;
    const gridHorizontalPadding = horizontalPadding * 2;
    final l10n = context.l10n;
    return BlocListener<ChatsCubit, ChatsState>(
      listenWhen: (previous, current) => previous.items != current.items,
      listener: (context, state) {
        if (!mounted) return;
        setState(() {
          _updateChatLookup(state.items);
          _rebuildFilteredItems(
            items: context.read<AttachmentGalleryCubit>().state.items,
            isSelfMessage: context.read<AttachmentGalleryCubit>().isSelfMessage,
          );
        });
      },
      child: BlocConsumer<AttachmentGalleryCubit, AttachmentGalleryState>(
        listenWhen: (previous, current) => previous.items != current.items,
        listener: (context, state) {
          if (!mounted) return;
          setState(() {
            _rebuildFilteredItems(
              items: state.items,
              isSelfMessage:
                  context.read<AttachmentGalleryCubit>().isSelfMessage,
            );
          });
        },
        builder: (context, state) {
          if (state.items.isEmpty) {
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

          final filteredItems = _filteredItems;
          final hasFilters = _hasActiveFilters;
          final hasVisualMedia = filteredItems.any(
            (entry) =>
                entry.item.metadata.mediaKind != AttachmentMediaKind.file,
          );
          final layout = _resolveLayout(hasVisualMedia: hasVisualMedia);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  0,
                ),
                child: AttachmentGalleryControls(
                  searchController: _searchController,
                  sortOption: _sortOption,
                  onSortChanged: (value) {
                    setState(() {
                      _sortOption = value;
                      _rebuildFilteredItems(
                        items:
                            context.read<AttachmentGalleryCubit>().state.items,
                        isSelfMessage: context
                            .read<AttachmentGalleryCubit>()
                            .isSelfMessage,
                      );
                    });
                  },
                  typeFilter: _typeFilter,
                  onTypeFilterChanged: (value) {
                    setState(() {
                      _typeFilter = value;
                      _rebuildFilteredItems(
                        items:
                            context.read<AttachmentGalleryCubit>().state.items,
                        isSelfMessage: context
                            .read<AttachmentGalleryCubit>()
                            .isSelfMessage,
                      );
                    });
                  },
                  sourceFilter: _sourceFilter,
                  onSourceFilterChanged: (value) {
                    setState(() {
                      _sourceFilter = value;
                      _rebuildFilteredItems(
                        items:
                            context.read<AttachmentGalleryCubit>().state.items,
                        isSelfMessage: context
                            .read<AttachmentGalleryCubit>()
                            .isSelfMessage,
                      );
                    });
                  },
                  layout: layout,
                  onLayoutChanged: _setLayout,
                  onClearSearch: _searchController.clear,
                ),
              ),
              const SizedBox(height: itemSpacing),
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
                    : layout == AttachmentGalleryLayout.list
                        ? ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              horizontalPadding,
                              0,
                              horizontalPadding,
                              bottomPadding,
                            ),
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: itemSpacing),
                            itemBuilder: (context, index) =>
                                AttachmentGalleryEntry(
                              entry: filteredItems[index],
                              showChatLabel: widget.showChatLabel,
                              autoDownloadSettings: context
                                  .watch<SettingsCubit>()
                                  .state
                                  .attachmentAutoDownloadSettings,
                              layout: layout,
                              isOneTimeAttachmentAllowed:
                                  _isOneTimeAttachmentAllowed,
                              shouldAllowAttachment: _shouldAllowAttachment,
                              onApproveAttachment: _approveAttachment,
                              metaSeparator:
                                  l10n.attachmentGalleryMetaSeparator,
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final gridMetrics = _resolveGridMetrics(
                                maxWidth: constraints.maxWidth,
                                horizontalPadding: gridHorizontalPadding,
                                minTileWidth: gridMinTileWidth,
                                gridSpacing: gridSpacing,
                                minColumns: gridMinColumns,
                                maxColumns: gridMaxColumns,
                                minAvailableWidth: gridMinAvailableWidth,
                              );
                              final rowCount = (filteredItems.length /
                                      gridMetrics.crossAxisCount)
                                  .ceil();
                              return ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  0,
                                  horizontalPadding,
                                  bottomPadding,
                                ),
                                itemCount: rowCount,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: gridSpacing),
                                itemBuilder: (context, rowIndex) {
                                  final rowStart =
                                      rowIndex * gridMetrics.crossAxisCount;
                                  final rowEnd = math.min(
                                    rowStart + gridMetrics.crossAxisCount,
                                    filteredItems.length,
                                  );
                                  final rowItems = filteredItems.sublist(
                                    rowStart,
                                    rowEnd,
                                  );
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (var index = 0;
                                          index < rowItems.length;
                                          index += 1) ...[
                                        SizedBox(
                                          width: gridMetrics.tileWidth,
                                          child: AttachmentGalleryEntry(
                                            entry: rowItems[index],
                                            showChatLabel: widget.showChatLabel,
                                            autoDownloadSettings: context
                                                .watch<SettingsCubit>()
                                                .state
                                                .attachmentAutoDownloadSettings,
                                            layout: layout,
                                            isOneTimeAttachmentAllowed:
                                                _isOneTimeAttachmentAllowed,
                                            shouldAllowAttachment:
                                                _shouldAllowAttachment,
                                            onApproveAttachment:
                                                _approveAttachment,
                                            metaSeparator: l10n
                                                .attachmentGalleryMetaSeparator,
                                          ),
                                        ),
                                        if (index < rowItems.length - 1)
                                          const SizedBox(width: gridSpacing),
                                      ],
                                    ],
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool get _hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _typeFilter != AttachmentGalleryTypeFilter.all ||
        _sourceFilter != AttachmentGallerySourceFilter.all;
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
    required this.layout,
    required this.onLayoutChanged,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final AttachmentGallerySortOption sortOption;
  final ValueChanged<AttachmentGallerySortOption> onSortChanged;
  final AttachmentGalleryTypeFilter typeFilter;
  final ValueChanged<AttachmentGalleryTypeFilter> onTypeFilterChanged;
  final AttachmentGallerySourceFilter sourceFilter;
  final ValueChanged<AttachmentGallerySourceFilter> onSourceFilterChanged;
  final AttachmentGalleryLayout layout;
  final ValueChanged<AttachmentGalleryLayout> onLayoutChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    const controlsSpacing = 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: controlsSpacing,
      children: [
        AttachmentGallerySearchRow(
          searchController: searchController,
          onClearSearch: onClearSearch,
          layout: layout,
          onLayoutChanged: onLayoutChanged,
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
    required this.layout,
    required this.onLayoutChanged,
  });

  final TextEditingController searchController;
  final VoidCallback onClearSearch;
  final AttachmentGalleryLayout layout;
  final ValueChanged<AttachmentGalleryLayout> onLayoutChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trimmedQuery = searchController.text.trim();
    const controlSpacing = 8.0;
    return Row(
      children: [
        Expanded(
          child: AxiTextInput(
            controller: searchController,
            placeholder: Text(l10n.commonSearch),
          ),
        ),
        const SizedBox(width: controlSpacing),
        AxiIconButton(
          iconData: LucideIcons.x,
          tooltip: l10n.commonClear,
          onPressed: trimmedQuery.isNotEmpty ? onClearSearch : null,
        ),
        const SizedBox(width: controlSpacing),
        AttachmentGalleryLayoutToggle(
          layout: layout,
          onChanged: onLayoutChanged,
        ),
      ],
    );
  }
}

class AttachmentGalleryLayoutToggle extends StatelessWidget {
  const AttachmentGalleryLayoutToggle({
    super.key,
    required this.layout,
    required this.onChanged,
  });

  final AttachmentGalleryLayout layout;
  final ValueChanged<AttachmentGalleryLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    const controlSpacing = 8.0;
    final l10n = context.l10n;
    final bool isGrid = layout == AttachmentGalleryLayout.grid;
    final bool isList = layout == AttachmentGalleryLayout.list;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AxiIconButton.ghost(
          iconData: LucideIcons.layoutGrid,
          tooltip: l10n.attachmentGalleryLayoutGridLabel,
          usePrimary: isGrid,
          onPressed:
              isGrid ? null : () => onChanged(AttachmentGalleryLayout.grid),
        ),
        const SizedBox(width: controlSpacing),
        AxiIconButton.ghost(
          iconData: LucideIcons.list,
          tooltip: l10n.attachmentGalleryLayoutListLabel,
          usePrimary: isList,
          onPressed:
              isList ? null : () => onChanged(AttachmentGalleryLayout.list),
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
    const controlsBreakpoint = 520.0;
    const controlRowSpacing = 12.0;
    const controlSpacing = 8.0;
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
        if (constraints.maxWidth < controlsBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: controlRowSpacing,
            children: [sortSelect, typeSelect, sourceSelect],
          );
        }
        return Row(
          children: [
            Expanded(child: sortSelect),
            const SizedBox(width: controlSpacing),
            Expanded(child: typeSelect),
            const SizedBox(width: controlSpacing),
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
    return AxiSelect<T>(
      initialValue: value,
      onChanged: (value) {
        if (value == null) return;
        onChanged(value);
      },
      options: options
          .map(
            (option) =>
                ShadOption<T>(value: option, child: Text(labelBuilder(option))),
          )
          .toList(growable: false),
      selectedOptionBuilder: (_, value) => Text(labelBuilder(value)),
    );
  }
}

class AttachmentGalleryEntry extends StatefulWidget {
  const AttachmentGalleryEntry({
    super.key,
    required this.showChatLabel,
    required this.entry,
    required this.autoDownloadSettings,
    required this.layout,
    required this.isOneTimeAttachmentAllowed,
    required this.shouldAllowAttachment,
    required this.onApproveAttachment,
    required this.metaSeparator,
  });

  final bool showChatLabel;
  final AttachmentGalleryEntryData entry;
  final AttachmentAutoDownloadSettings autoDownloadSettings;
  final AttachmentGalleryLayout layout;
  final bool Function(String stanzaId) isOneTimeAttachmentAllowed;
  final bool Function({required bool isSelf, required Chat? chat})
      shouldAllowAttachment;
  final Future<void> Function({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required Chat? chat,
    required bool isEmailChat,
  }) onApproveAttachment;
  final String metaSeparator;

  @override
  State<AttachmentGalleryEntry> createState() => _AttachmentGalleryEntryState();
}

class _AttachmentGalleryEntryState extends State<AttachmentGalleryEntry> {
  late Stream<FileMetadataData?> _metadataStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _metadataStream = _resolveMetadataStream(widget.entry.item.metadata.id);
  }

  @override
  void didUpdateWidget(covariant AttachmentGalleryEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextId = widget.entry.item.metadata.id;
    if (oldWidget.entry.item.metadata.id != nextId) {
      _metadataStream = _resolveMetadataStream(nextId);
    }
  }

  Stream<FileMetadataData?> _resolveMetadataStream(String id) =>
      context.read<AttachmentGalleryCubit>().fileMetadataStream(id);

  @override
  Widget build(BuildContext context) {
    final message = widget.entry.item.message;
    final metadata = widget.entry.item.metadata;
    final chat = widget.entry.chat;
    final isEmailChat = (chat?.defaultTransport.isEmail ?? false) ||
        message.deltaMsgId != null ||
        message.deltaChatId != null;
    final allowOnce = widget.isOneTimeAttachmentAllowed(message.stanzaID);
    final allowAttachment =
        widget.shouldAllowAttachment(isSelf: widget.entry.isSelf, chat: chat) ||
            allowOnce;
    final downloadDelegate = isEmailChat
        ? AttachmentDownloadDelegate(
            () => context
                .read<AttachmentGalleryCubit>()
                .downloadEmailMessage(message),
          )
        : null;
    final autoDownloadAllowed = allowAttachment && !isEmailChat;
    final autoDownloadUserInitiated = allowOnce && !isEmailChat;
    final metaText = _resolveMetaText(
      chat: chat,
      showChatLabel: widget.showChatLabel,
      separator: widget.metaSeparator,
    );
    final allowPressed = allowAttachment
        ? null
        : () => widget.onApproveAttachment(
              message: message,
              senderJid: message.senderJid,
              stanzaId: message.stanzaID,
              chat: chat,
              isEmailChat: isEmailChat,
            );
    return widget.layout == AttachmentGalleryLayout.list
        ? AttachmentGalleryListItem(
            metadataStream: _metadataStream,
            metadata: metadata,
            stanzaId: message.stanzaID,
            allowed: allowAttachment,
            autoDownloadSettings: widget.autoDownloadSettings,
            autoDownloadAllowed: autoDownloadAllowed,
            autoDownloadUserInitiated: autoDownloadUserInitiated,
            downloadDelegate: downloadDelegate,
            onAllowPressed: allowPressed,
            metaText: metaText,
          )
        : AttachmentGalleryTile(
            metadataStream: _metadataStream,
            metadata: metadata,
            stanzaId: message.stanzaID,
            allowed: allowAttachment,
            autoDownloadSettings: widget.autoDownloadSettings,
            autoDownloadAllowed: autoDownloadAllowed,
            autoDownloadUserInitiated: autoDownloadUserInitiated,
            downloadDelegate: downloadDelegate,
            onAllowPressed: allowPressed,
            metaText: metaText,
          );
  }
}

class AttachmentGalleryListItem extends StatelessWidget {
  const AttachmentGalleryListItem({
    super.key,
    required this.metadataStream,
    required this.metadata,
    required this.stanzaId,
    required this.allowed,
    required this.autoDownloadSettings,
    required this.autoDownloadAllowed,
    required this.autoDownloadUserInitiated,
    required this.downloadDelegate,
    required this.onAllowPressed,
    required this.metaText,
  });

  final Stream<FileMetadataData?> metadataStream;
  final FileMetadataData metadata;
  final String stanzaId;
  final bool allowed;
  final AttachmentAutoDownloadSettings autoDownloadSettings;
  final bool autoDownloadAllowed;
  final bool autoDownloadUserInitiated;
  final AttachmentDownloadDelegate? downloadDelegate;
  final VoidCallback? onAllowPressed;
  final String? metaText;

  @override
  Widget build(BuildContext context) {
    const metaMaxLines = 1;
    const metaSpacing = 4.0;
    const previewMaxWidthFraction = 1.0;
    final metaLabel = metaText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (metaLabel != null) ...[
          Text(
            metaLabel,
            style: context.textTheme.muted,
            maxLines: metaMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: metaSpacing),
        ],
        ChatAttachmentPreview(
          stanzaId: stanzaId,
          metadataStream: metadataStream,
          initialMetadata: metadata,
          allowed: allowed,
          autoDownloadSettings: autoDownloadSettings,
          autoDownloadAllowed: autoDownloadAllowed,
          autoDownloadUserInitiated: autoDownloadUserInitiated,
          downloadDelegate: downloadDelegate,
          onAllowPressed: onAllowPressed,
          maxWidthFraction: previewMaxWidthFraction,
        ),
      ],
    );
  }
}

class AttachmentGalleryTile extends StatelessWidget {
  const AttachmentGalleryTile({
    super.key,
    required this.metadataStream,
    required this.metadata,
    required this.stanzaId,
    required this.allowed,
    required this.autoDownloadSettings,
    required this.autoDownloadAllowed,
    required this.autoDownloadUserInitiated,
    required this.downloadDelegate,
    required this.onAllowPressed,
    required this.metaText,
  });

  final Stream<FileMetadataData?> metadataStream;
  final FileMetadataData metadata;
  final String stanzaId;
  final bool allowed;
  final AttachmentAutoDownloadSettings autoDownloadSettings;
  final bool autoDownloadAllowed;
  final bool autoDownloadUserInitiated;
  final AttachmentDownloadDelegate? downloadDelegate;
  final VoidCallback? onAllowPressed;
  final String? metaText;

  @override
  Widget build(BuildContext context) {
    const footerSpacing = 8.0;
    const filenameMaxLines = 2;
    const metaMaxLines = 1;
    const metaSpacing = 4.0;
    const previewMaxWidthFraction = 1.0;
    final metaLabel = metaText;
    final showFilename = metadata.mediaKind != AttachmentMediaKind.file;
    final preview = ChatAttachmentPreview(
      stanzaId: stanzaId,
      metadataStream: metadataStream,
      initialMetadata: metadata,
      allowed: allowed,
      autoDownloadSettings: autoDownloadSettings,
      autoDownloadAllowed: autoDownloadAllowed,
      autoDownloadUserInitiated: autoDownloadUserInitiated,
      downloadDelegate: downloadDelegate,
      onAllowPressed: onAllowPressed,
      maxWidthFraction: previewMaxWidthFraction,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        preview,
        const SizedBox(height: footerSpacing),
        if (showFilename)
          Text(
            metadata.filename,
            style: context.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: filenameMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        if (metaLabel != null)
          Text(
            metaLabel,
            style: context.textTheme.muted,
            maxLines: metaMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        if (!showFilename && metaLabel == null)
          const SizedBox(height: metaSpacing),
      ],
    );
  }
}
