// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/attachments/bloc/attachment_gallery_bloc.dart';
import 'package:axichat/src/chat/view/attachment_approval_dialog.dart';
import 'package:axichat/src/chat/view/chat_attachment_preview.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    return BlocProvider(
      create: (context) => AttachmentGalleryBloc(
        xmppService: context.read<XmppService>(),
        emailService: context.read<EmailService>(),
        chatJid: resolvedChat.jid,
        chatOverride: resolvedChat,
        showChatLabel: false,
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
  late final TextEditingController _searchController = TextEditingController()
    ..addListener(_handleSearchChanged);
  AttachmentGalleryLayout _resolveLayout({
    required bool hasVisualMedia,
    required AttachmentGalleryLayout? overrideLayout,
  }) {
    final defaultLayout = hasVisualMedia
        ? AttachmentGalleryLayout.grid
        : AttachmentGalleryLayout.list;
    return overrideLayout ?? defaultLayout;
  }

  void _handleLayoutChanged(AttachmentGalleryLayout nextLayout) {
    context.read<AttachmentGalleryBloc>().add(
          AttachmentGalleryLayoutChanged(layout: nextLayout),
        );
  }

  Future<void> _approveAttachment({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required Chat? chat,
    required bool isEmailChat,
    required bool isSelf,
  }) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final senderEmail = chat?.emailAddress;
    final displaySender =
        senderEmail?.trim().isNotEmpty == true ? senderEmail! : senderJid;
    final decision = await showFadeScaleDialog<AttachmentApprovalDecision>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AttachmentApprovalDialog(
          title: l10n.chatAttachmentConfirmTitle,
          message: l10n.chatAttachmentConfirmMessage(displaySender),
          confirmLabel: l10n.chatAttachmentConfirmButton,
          cancelLabel: l10n.commonCancel,
          showAutoTrustToggle: !isSelf && chat != null,
          autoTrustLabel: l10n.attachmentGalleryChatTrustLabel,
          autoTrustHint: l10n.attachmentGalleryChatTrustHint,
        );
      },
    );
    if (!mounted) return;
    if (decision == null || !decision.approved) return;

    context.read<AttachmentGalleryBloc>().add(
          AttachmentGalleryApprovalGranted(
            message: message,
            chat: chat,
            alwaysAllow: decision.alwaysAllow,
            isEmailChat: isEmailChat,
            stanzaId: stanzaId,
          ),
        );
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    context.read<AttachmentGalleryBloc>().add(
          AttachmentGalleryQueryChanged(
            query: _searchController.text,
          ),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<AttachmentGalleryBloc>().add(
          AttachmentGalleryChatsUpdated(
            items: context.read<ChatsCubit>().state.items ?? const <Chat>[],
          ),
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
        context.read<AttachmentGalleryBloc>().add(
              AttachmentGalleryChatsUpdated(
                items: state.items ?? const <Chat>[],
              ),
            );
      },
      child: BlocBuilder<AttachmentGalleryBloc, AttachmentGalleryState>(
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

          final layout = _resolveLayout(
            hasVisualMedia: state.entries.any(
              (entry) =>
                  entry.item.metadata.mediaKind != FileMetadataMediaKind.file,
            ),
            overrideLayout: state.layoutOverride,
          );
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
                  sortOption: state.sortOption,
                  onSortChanged: (value) {
                    context.read<AttachmentGalleryBloc>().add(
                          AttachmentGallerySortChanged(sortOption: value),
                        );
                  },
                  typeFilter: state.typeFilter,
                  onTypeFilterChanged: (value) {
                    context.read<AttachmentGalleryBloc>().add(
                          AttachmentGalleryTypeFilterChanged(typeFilter: value),
                        );
                  },
                  sourceFilter: state.sourceFilter,
                  onSourceFilterChanged: (value) {
                    context.read<AttachmentGalleryBloc>().add(
                          AttachmentGallerySourceFilterChanged(
                            sourceFilter: value,
                          ),
                        );
                  },
                  layout: layout,
                  onLayoutChanged: _handleLayoutChanged,
                  onClearSearch: _searchController.clear,
                ),
              ),
              const SizedBox(height: itemSpacing),
              Expanded(
                child: state.entries.isEmpty
                    ? Center(
                        child: Text(
                          state.query.trim().isNotEmpty ||
                                  state.typeFilter !=
                                      AttachmentGalleryTypeFilter.all ||
                                  state.sourceFilter !=
                                      AttachmentGallerySourceFilter.all
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
                            itemCount: state.entries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: itemSpacing),
                            itemBuilder: (context, index) =>
                                AttachmentGalleryEntry(
                              entry: state.entries[index],
                              showChatLabel: widget.showChatLabel,
                              autoDownloadImages: context
                                  .watch<SettingsCubit>()
                                  .state
                                  .autoDownloadImages,
                              autoDownloadVideos: context
                                  .watch<SettingsCubit>()
                                  .state
                                  .autoDownloadVideos,
                              autoDownloadDocuments: context
                                  .watch<SettingsCubit>()
                                  .state
                                  .autoDownloadDocuments,
                              autoDownloadArchives: context
                                  .watch<SettingsCubit>()
                                  .state
                                  .autoDownloadArchives,
                              layout: layout,
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
                              final rowCount = (state.entries.length /
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
                                    state.entries.length,
                                  );
                                  final rowItems = state.entries.sublist(
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
                                            autoDownloadImages: context
                                                .watch<SettingsCubit>()
                                                .state
                                                .autoDownloadImages,
                                            autoDownloadVideos: context
                                                .watch<SettingsCubit>()
                                                .state
                                                .autoDownloadVideos,
                                            autoDownloadDocuments: context
                                                .watch<SettingsCubit>()
                                                .state
                                                .autoDownloadDocuments,
                                            autoDownloadArchives: context
                                                .watch<SettingsCubit>()
                                                .state
                                                .autoDownloadArchives,
                                            layout: layout,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AxiIconButton.ghost(
          iconData: LucideIcons.layoutGrid,
          tooltip: l10n.attachmentGalleryLayoutGridLabel,
          usePrimary: layout == AttachmentGalleryLayout.grid,
          onPressed: layout == AttachmentGalleryLayout.grid
              ? null
              : () => onChanged(AttachmentGalleryLayout.grid),
        ),
        const SizedBox(width: controlSpacing),
        AxiIconButton.ghost(
          iconData: LucideIcons.list,
          tooltip: l10n.attachmentGalleryLayoutListLabel,
          usePrimary: layout == AttachmentGalleryLayout.list,
          onPressed: layout == AttachmentGalleryLayout.list
              ? null
              : () => onChanged(AttachmentGalleryLayout.list),
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
    required this.autoDownloadImages,
    required this.autoDownloadVideos,
    required this.autoDownloadDocuments,
    required this.autoDownloadArchives,
    required this.layout,
    required this.onApproveAttachment,
    required this.metaSeparator,
  });

  final bool showChatLabel;
  final AttachmentGalleryEntryData entry;
  final bool autoDownloadImages;
  final bool autoDownloadVideos;
  final bool autoDownloadDocuments;
  final bool autoDownloadArchives;
  final AttachmentGalleryLayout layout;
  final Future<void> Function({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required Chat? chat,
    required bool isEmailChat,
    required bool isSelf,
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
      context.read<AttachmentGalleryBloc>().fileMetadataStream(id);

  @override
  Widget build(BuildContext context) {
    final message = widget.entry.item.message;
    final metadata = widget.entry.item.metadata;
    final chat = widget.entry.chat;
    final isEmailChat = (chat?.defaultTransport.isEmail ?? false) ||
        message.deltaMsgId != null ||
        message.deltaChatId != null;
    final allowAttachment = widget.entry.allowByTrust || widget.entry.allowOnce;
    final downloadDelegate = isEmailChat
        ? AttachmentDownloadDelegate(
            () {
              final completer = Completer<bool>();
              context.read<AttachmentGalleryBloc>().add(
                    AttachmentGalleryEmailDownloadRequested(
                      message: message,
                      completer: completer,
                    ),
                  );
              return completer.future;
            },
          )
        : null;
    final autoDownloadAllowed = allowAttachment && !isEmailChat;
    final autoDownloadUserInitiated = widget.entry.allowOnce && !isEmailChat;
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
              isSelf: widget.entry.isSelf,
            );
    return widget.layout == AttachmentGalleryLayout.list
        ? AttachmentGalleryListItem(
            metadataStream: _metadataStream,
            metadata: metadata,
            stanzaId: message.stanzaID,
            allowed: allowAttachment,
            autoDownloadImages: widget.autoDownloadImages,
            autoDownloadVideos: widget.autoDownloadVideos,
            autoDownloadDocuments: widget.autoDownloadDocuments,
            autoDownloadArchives: widget.autoDownloadArchives,
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
            autoDownloadImages: widget.autoDownloadImages,
            autoDownloadVideos: widget.autoDownloadVideos,
            autoDownloadDocuments: widget.autoDownloadDocuments,
            autoDownloadArchives: widget.autoDownloadArchives,
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
    required this.autoDownloadImages,
    required this.autoDownloadVideos,
    required this.autoDownloadDocuments,
    required this.autoDownloadArchives,
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
  final bool autoDownloadImages;
  final bool autoDownloadVideos;
  final bool autoDownloadDocuments;
  final bool autoDownloadArchives;
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
          autoDownloadImages: autoDownloadImages,
          autoDownloadVideos: autoDownloadVideos,
          autoDownloadDocuments: autoDownloadDocuments,
          autoDownloadArchives: autoDownloadArchives,
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
    required this.autoDownloadImages,
    required this.autoDownloadVideos,
    required this.autoDownloadDocuments,
    required this.autoDownloadArchives,
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
  final bool autoDownloadImages;
  final bool autoDownloadVideos;
  final bool autoDownloadDocuments;
  final bool autoDownloadArchives;
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
    final showFilename = metadata.mediaKind != FileMetadataMediaKind.file;
    final preview = ChatAttachmentPreview(
      stanzaId: stanzaId,
      metadataStream: metadataStream,
      initialMetadata: metadata,
      allowed: allowed,
      autoDownloadImages: autoDownloadImages,
      autoDownloadVideos: autoDownloadVideos,
      autoDownloadDocuments: autoDownloadDocuments,
      autoDownloadArchives: autoDownloadArchives,
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
