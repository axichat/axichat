// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/attachments/bloc/attachment_gallery_bloc.dart';
import 'package:axichat/src/attachments/view/attachment_file_preview.dart';
import 'package:axichat/src/chat/view/composer/attachment_approval_dialog.dart';
import 'package:axichat/src/chat/view/composer/attachment_preview.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/unicode_safety.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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

String _galleryDisplayFilename(String filename) =>
    sanitizeUnicodeControls(filename).value;

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
    if (chat == null) {
      return const SizedBox.shrink();
    }
    return BlocProvider(
      create: (context) {
        final endpointConfig = context
            .read<SettingsCubit>()
            .state
            .endpointConfig;
        final emailService = endpointConfig.smtpEnabled
            ? context.read<EmailService>()
            : null;
        return AttachmentGalleryBloc(
          xmppService: context.read<XmppService>(),
          emailService: emailService,
          chatJid: chat!.jid,
          chatOverride: chat!,
          showChatLabel: false,
        );
      },
      child: AxiSheetScaffold(
        header: AxiSheetHeader(
          title: Text(title),
          subtitle: Text(chat!.displayName),
          onClose: onClose,
        ),
        body: AttachmentGalleryView(chatOverride: chat!, showChatLabel: false),
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

  Future<bool> _approveAttachment({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required Chat? chat,
    required bool isEmailChat,
    required bool isSelf,
  }) async {
    if (!mounted) return false;
    final senderEmail = chat?.emailAddress;
    final displaySender = senderEmail?.trim().isNotEmpty == true
        ? senderEmail!
        : senderJid;
    final canTrustChat = !isSelf && chat != null;
    final inheritedAutoDownloadEnabled = context
        .read<SettingsCubit>()
        .state
        .anyAttachmentAutoDownloadEnabled;
    final decision = await showFadeScaleDialog<AttachmentApprovalDecision>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AttachmentApprovalDialog(
          title: context.l10n.chatAttachmentConfirmTitle,
          message: context.l10n.chatAttachmentConfirmMessage(displaySender),
          confirmLabel: context.l10n.chatAttachmentConfirmButton,
          cancelLabel: context.l10n.commonCancel,
          showAutoTrustToggle: canTrustChat,
          autoDownloadValue: chat?.attachmentAutoDownload,
          inheritedAutoDownloadEnabled: inheritedAutoDownloadEnabled,
          autoTrustLabel: context.l10n.attachmentGalleryChatTrustLabel,
          autoTrustHint: context.l10n.attachmentGalleryChatTrustHint,
        );
      },
    );
    if (!mounted) return false;
    if (decision == null || !decision.approved) return false;

    context.read<AttachmentGalleryBloc>().add(
      AttachmentGalleryApprovalGranted(
        message: message,
        chat: chat,
        autoDownloadValue: decision.autoDownloadValue,
        updateAutoDownloadValue: decision.updateAutoDownloadValue,
        isEmailChat: isEmailChat,
        stanzaId: stanzaId,
      ),
    );
    return true;
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    context.read<AttachmentGalleryBloc>().add(
      AttachmentGalleryQueryChanged(query: _searchController.text),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sizing = context.sizing;
    return BlocListener<SettingsCubit, SettingsState>(
      listenWhen: (previous, current) =>
          previous.endpointConfig != current.endpointConfig,
      listener: (context, settings) {
        final emailService = settings.endpointConfig.smtpEnabled
            ? context.read<EmailService>()
            : null;
        context.read<AttachmentGalleryBloc>().add(
          AttachmentGalleryEmailServiceUpdated(emailService: emailService),
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
                  context.l10n.attachmentGalleryErrorMessage,
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.m,
                  spacing.s,
                  spacing.m,
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
                      AttachmentGallerySourceFilterChanged(sourceFilter: value),
                    );
                  },
                  onClearSearch: _searchController.clear,
                ),
              ),
              SizedBox(height: spacing.m),
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
                    : GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                          spacing.m,
                          0,
                          spacing.m,
                          spacing.m,
                        ),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent:
                              sizing.attachmentGalleryTileMaxCrossAxisExtent,
                          childAspectRatio:
                              sizing.attachmentGalleryTileAspectRatio,
                          mainAxisSpacing: spacing.s,
                          crossAxisSpacing: spacing.s,
                        ),
                        itemCount: state.entries.length,
                        itemBuilder: (context, index) {
                          return AttachmentGalleryEntry(
                            entry: state.entries[index],
                            showChatLabel: widget.showChatLabel,
                            onApproveAttachment: _approveAttachment,
                            metaSeparator:
                                context.l10n.attachmentGalleryMetaSeparator,
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
      spacing: context.spacing.s,
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
    return Row(
      children: [
        Expanded(
          child: SearchInputField(
            controller: searchController,
            placeholder: Text(context.l10n.commonSearch),
            clearTooltip: context.l10n.commonClear,
            onClear: onClearSearch,
          ),
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
    final spacing = context.spacing;
    final l10n = context.l10n;
    return Wrap(
      spacing: spacing.s,
      runSpacing: spacing.m,
      children: [
        AxiDropdown<AttachmentGallerySortOption>(
          value: sortOption,
          onChanged: onSortChanged,
          selectedBuilder: (context, value) => Text(
            l10n.attachmentGalleryFilterTriggerLabel(
              l10n.attachmentGallerySortFilterLabel,
              value.label(l10n),
            ),
          ),
          options: AttachmentGallerySortOption.values
              .map(
                (value) => AxiDropdownOption<AttachmentGallerySortOption>(
                  value: value,
                  label: value.label(l10n),
                ),
              )
              .toList(growable: false),
        ),
        AxiDropdown<AttachmentGalleryTypeFilter>(
          value: typeFilter,
          onChanged: onTypeFilterChanged,
          selectedBuilder: (context, value) => Text(
            l10n.attachmentGalleryFilterTriggerLabel(
              l10n.attachmentGalleryTypeFilterLabel,
              value.label(l10n),
            ),
          ),
          options: AttachmentGalleryTypeFilter.values
              .map(
                (value) => AxiDropdownOption<AttachmentGalleryTypeFilter>(
                  value: value,
                  label: value.label(l10n),
                ),
              )
              .toList(growable: false),
        ),
        AxiDropdown<AttachmentGallerySourceFilter>(
          value: sourceFilter,
          onChanged: onSourceFilterChanged,
          selectedBuilder: (context, value) => Text(
            l10n.attachmentGalleryFilterTriggerLabel(
              l10n.attachmentGallerySourceFilterLabel,
              value.label(l10n),
            ),
          ),
          options: AttachmentGallerySourceFilter.values
              .map(
                (value) => AxiDropdownOption<AttachmentGallerySourceFilter>(
                  value: value,
                  label: value.label(l10n),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class AttachmentGalleryEntry extends StatelessWidget {
  const AttachmentGalleryEntry({
    super.key,
    required this.showChatLabel,
    required this.entry,
    required this.onApproveAttachment,
    required this.metaSeparator,
  });

  final bool showChatLabel;
  final AttachmentGalleryEntryData entry;
  final Future<bool> Function({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required Chat? chat,
    required bool isEmailChat,
    required bool isSelf,
  })
  onApproveAttachment;
  final String metaSeparator;

  @override
  Widget build(BuildContext context) {
    final message = entry.item.message;
    final initialMetadata = entry.item.metadata;
    final metadataId = initialMetadata.id;
    return BlocSelector<
      AttachmentGalleryBloc,
      AttachmentGalleryState,
      ({FileMetadataData? metadata, bool metadataPending})
    >(
      selector: (state) => (
        metadata: state.fileMetadataById.containsKey(metadataId)
            ? state.fileMetadataById[metadataId]
            : initialMetadata,
        metadataPending: !state.fileMetadataById.containsKey(metadataId),
      ),
      builder: (context, metadataState) {
        final locate = context.read;
        final metadata = metadataState.metadata;
        final metadataPending = metadataState.metadataPending;
        final chat = entry.chat;
        final isEmailChat =
            (chat?.defaultTransport.isEmail ?? false) ||
            message.deltaMsgId != null ||
            message.deltaChatId != null;
        final allowAttachment = entry.allowByTrust || entry.allowOnce;
        final downloadDelegate = isEmailChat
            ? AttachmentDownloadDelegate(() async {
                final approved = await onApproveAttachment(
                  message: message,
                  senderJid: message.senderJid,
                  stanzaId: message.stanzaID,
                  chat: chat,
                  isEmailChat: isEmailChat,
                  isSelf: entry.isSelf,
                );
                if (!approved) return false;
                final completer = Completer<bool>();
                locate<AttachmentGalleryBloc>().add(
                  AttachmentGalleryEmailDownloadRequested(
                    message: message,
                    completer: completer,
                  ),
                );
                return completer.future;
              })
            : AttachmentDownloadDelegate(() async {
                final approved = await onApproveAttachment(
                  message: message,
                  senderJid: message.senderJid,
                  stanzaId: message.stanzaID,
                  chat: chat,
                  isEmailChat: isEmailChat,
                  isSelf: entry.isSelf,
                );
                if (!approved) return false;
                return locate<AttachmentGalleryBloc>()
                    .downloadInboundAttachment(
                      metadataId: initialMetadata.id,
                      stanzaId: message.stanzaID,
                    );
              });
        final allowPressed = allowAttachment
            ? null
            : () => onApproveAttachment(
                message: message,
                senderJid: message.senderJid,
                stanzaId: message.stanzaID,
                chat: chat,
                isEmailChat: isEmailChat,
                isSelf: entry.isSelf,
              );
        final metadataReloadDelegate = AttachmentMetadataReloadDelegate(
          () => context.read<AttachmentGalleryBloc>().reloadFileMetadata(
            initialMetadata.id,
          ),
        );
        final metaText = _resolveMetaText(
          chat: chat,
          showChatLabel: showChatLabel,
          separator: metaSeparator,
        );
        return AttachmentGalleryTile(
          metadata: metadata,
          metadataPending: metadataPending,
          stanzaId: message.stanzaID,
          allowed: allowAttachment,
          downloadDelegate: downloadDelegate,
          metadataReloadDelegate: metadataReloadDelegate,
          onAllowPressed: allowPressed,
          metaText: metaText,
        );
      },
    );
  }
}

class AttachmentGalleryTile extends StatelessWidget {
  const AttachmentGalleryTile({
    super.key,
    required this.metadata,
    required this.metadataPending,
    required this.stanzaId,
    required this.allowed,
    required this.downloadDelegate,
    required this.metadataReloadDelegate,
    required this.onAllowPressed,
    required this.metaText,
  });

  final FileMetadataData? metadata;
  final bool metadataPending;
  final String stanzaId;
  final bool allowed;
  final AttachmentDownloadDelegate? downloadDelegate;
  final AttachmentMetadataReloadDelegate metadataReloadDelegate;
  final VoidCallback? onAllowPressed;
  final String? metaText;

  @override
  Widget build(BuildContext context) {
    const previewMaxWidthFraction = 1.0;
    final metaLabel = metaText;
    final metadata = this.metadata;
    if (metadata?.mediaKind == FileMetadataMediaKind.file) {
      return AttachmentGalleryFileTile(
        metadata: metadata!,
        metadataPending: metadataPending,
        allowed: allowed,
        downloadDelegate: downloadDelegate,
        metadataReloadDelegate: metadataReloadDelegate,
        onAllowPressed: onAllowPressed,
        metaText: metaLabel,
      );
    }
    final preview = ChatAttachmentPreview(
      stanzaId: stanzaId,
      metadata: metadata,
      metadataPending: metadataPending,
      allowed: allowed,
      downloadDelegate: downloadDelegate,
      metadataReloadDelegate: metadataReloadDelegate,
      onAllowPressed: onAllowPressed,
      maxWidthFraction: previewMaxWidthFraction,
      galleryTapMode: true,
      messageDetails: metaLabel == null
          ? const <InlineSpan>[]
          : [TextSpan(text: metaLabel)],
    );
    return ClipRect(
      child: Align(alignment: Alignment.centerLeft, child: preview),
    );
  }
}

class AttachmentGalleryFileTile extends StatefulWidget {
  const AttachmentGalleryFileTile({
    super.key,
    required this.metadata,
    required this.metadataPending,
    required this.allowed,
    required this.downloadDelegate,
    required this.metadataReloadDelegate,
    required this.onAllowPressed,
    required this.metaText,
  });

  final FileMetadataData metadata;
  final bool metadataPending;
  final bool allowed;
  final AttachmentDownloadDelegate? downloadDelegate;
  final AttachmentMetadataReloadDelegate metadataReloadDelegate;
  final VoidCallback? onAllowPressed;
  final String? metaText;

  @override
  State<AttachmentGalleryFileTile> createState() =>
      _AttachmentGalleryFileTileState();
}

class _AttachmentGalleryFileTileState extends State<AttachmentGalleryFileTile> {
  final ShadPopoverController _actionsController = ShadPopoverController();
  _FileTileAction? _activeAction;
  String? _downloadedLocalPath;

  bool get _busy => _activeAction != null;

  String? get _effectiveLocalPath {
    final metadataPath = widget.metadata.path?.trim();
    if (metadataPath?.isNotEmpty == true) {
      return metadataPath;
    }
    final downloadedPath = _downloadedLocalPath?.trim();
    if (downloadedPath?.isNotEmpty == true) {
      return downloadedPath;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant AttachmentGalleryFileTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metadata.id != widget.metadata.id ||
        oldWidget.metadata.path != widget.metadata.path) {
      _downloadedLocalPath = null;
    }
  }

  @override
  void dispose() {
    _actionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.metadata;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final colors = context.colorScheme;
    final sizing = context.sizing;
    final localPath = _effectiveLocalPath;
    final hasPath = localPath != null;
    final canResolve = hasPath || widget.downloadDelegate != null;
    final saveLabel = hasPath
        ? l10n.chatAttachmentExportConfirm
        : l10n.chatAttachmentDownloadAndSave;
    final shareLabel = hasPath
        ? l10n.chatActionShare
        : l10n.chatAttachmentDownloadAndShare;
    final declaredReport = buildDeclaredFileTypeReport(
      declaredMimeType: metadata.mimeType,
      fileName: metadata.filename,
      path: metadata.path,
    );
    final previewKind = resolveAttachmentPreviewKind(
      report: declaredReport,
      fileName: metadata.filename,
      path: metadata.path,
      declaredMimeType: metadata.mimeType,
    );
    final previewEnabled =
        canResolve &&
        (previewKind == AttachmentPreviewKind.pdf ||
            previewKind == AttachmentPreviewKind.text);
    final sendEnabled = metadata.id.trim().isNotEmpty;
    final tile = AxiModalSurface(
      padding: EdgeInsets.all(spacing.s),
      backgroundColor: colors.card,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: sizing.attachmentPreviewExtent),
        child: widget.metadataPending
            ? Center(child: AxiProgressIndicator(color: colors.primary))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: spacing.xs,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.file,
                        size: sizing.menuItemIconSize,
                        color: colors.primary,
                      ),
                      const Spacer(),
                      if (widget.allowed || hasPath)
                        AxiPopover(
                          controller: _actionsController,
                          closeOnTapOutside: true,
                          padding: EdgeInsets.zero,
                          decoration: ShadDecoration.none,
                          shadows: const <BoxShadow>[],
                          popover: (context) {
                            return AxiMenu(
                              actions: [
                                AxiMenuAction(
                                  icon: LucideIcons.save,
                                  label: saveLabel,
                                  enabled: canResolve && !_busy,
                                  onPressed: () {
                                    _actionsController.hide();
                                    _saveAttachment();
                                  },
                                ),
                                AxiMenuAction(
                                  icon: LucideIcons.share2,
                                  label: shareLabel,
                                  enabled: canResolve && !_busy,
                                  onPressed: () {
                                    _actionsController.hide();
                                    _shareAttachment();
                                  },
                                ),
                                AxiMenuAction(
                                  icon: LucideIcons.send,
                                  label: l10n.commonSend,
                                  enabled: sendEnabled && !_busy,
                                  onPressed: () {
                                    _actionsController.hide();
                                    _sendAttachment();
                                  },
                                ),
                                if (previewEnabled)
                                  AxiMenuAction(
                                    icon: LucideIcons.eye,
                                    label: hasPath
                                        ? l10n.chatAttachmentPreview
                                        : l10n.chatAttachmentDownloadAndPreview,
                                    enabled: !_busy,
                                    onPressed: () {
                                      _actionsController.hide();
                                      _previewAttachment();
                                    },
                                  ),
                              ],
                            );
                          },
                          child: AxiIconButton.ghost(
                            iconData: Icons.more_horiz,
                            tooltip: l10n.commonMoreOptions,
                            loading: _busy,
                            iconSize: sizing.menuItemIconSize,
                            buttonSize: sizing.menuItemHeight,
                            tapTargetSize: sizing.menuItemHeight,
                            onPressed: _busy ? null : _actionsController.toggle,
                          ),
                        )
                      else
                        AxiIconButton.ghost(
                          iconData: LucideIcons.download,
                          tooltip: l10n.chatAttachmentLoad,
                          iconSize: sizing.menuItemIconSize,
                          buttonSize: sizing.menuItemHeight,
                          tapTargetSize: sizing.menuItemHeight,
                          onPressed: widget.onAllowPressed,
                        ),
                    ],
                  ),
                  Text(
                    _galleryDisplayFilename(metadata.filename),
                    style: context.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _galleryFileTileSizeLabel(
                      bytes: metadata.sizeBytes,
                      hasPath: hasPath,
                      l10n: l10n,
                    ),
                    style: context.textTheme.muted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.metaText != null)
                    Text(
                      widget.metaText!,
                      style: context.textTheme.muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
      ),
    );

    return _AttachmentGalleryTileTapTarget(
      onTap: widget.metadataPending ? null : _handleTileTap,
      child: tile,
    );
  }

  void _handleTileTap() {
    if (_busy) return;
    if (!widget.allowed && _effectiveLocalPath == null) {
      widget.onAllowPressed?.call();
      return;
    }
    final declaredReport = buildDeclaredFileTypeReport(
      declaredMimeType: widget.metadata.mimeType,
      fileName: widget.metadata.filename,
      path: widget.metadata.path,
    );
    final previewKind = resolveAttachmentPreviewKind(
      report: declaredReport,
      fileName: widget.metadata.filename,
      path: widget.metadata.path,
      declaredMimeType: widget.metadata.mimeType,
    );
    if ((_effectiveLocalPath != null || widget.downloadDelegate != null) &&
        (previewKind == AttachmentPreviewKind.pdf ||
            previewKind == AttachmentPreviewKind.text)) {
      _previewAttachment();
      return;
    }
    _actionsController.toggle();
  }

  void _sendAttachment() {
    if (_busy) return;
    openSingleAttachmentComposeDraft(
      context: context,
      metadata: widget.metadata,
    );
  }

  Future<void> _saveAttachment() async {
    await _withAction(_FileTileAction.save, () async {
      final file = await _resolveLocalFile();
      if (!mounted || file == null) return;
      final report = await _inspectResolvedFile(file);
      if (!mounted) return;
      final allowed = await confirmExportAllowed(
        context,
        metadata: widget.metadata,
        report: report,
        confirmLabel: context.l10n.chatAttachmentExportConfirm,
      );
      if (!mounted || !allowed) return;
      await saveAttachmentToDevice(
        context,
        file: file,
        filename: widget.metadata.filename,
      );
    });
  }

  Future<void> _shareAttachment() async {
    await _withAction(_FileTileAction.share, () async {
      final file = await _resolveLocalFile();
      if (!mounted || file == null) return;
      final report = await _inspectResolvedFile(file);
      if (!mounted) return;
      final allowed = await confirmExportAllowed(
        context,
        metadata: widget.metadata,
        report: report,
        confirmLabel: context.l10n.chatActionShare,
      );
      if (!mounted || !allowed) return;
      await shareAttachmentFromFile(
        context,
        file: file,
        filename: widget.metadata.filename,
      );
    });
  }

  Future<void> _previewAttachment() async {
    await _withAction(_FileTileAction.preview, () async {
      final file = await _resolveLocalFile();
      if (!mounted || file == null) return;
      final report = await _inspectResolvedFile(file);
      if (!mounted) return;
      final allowed = await confirmExportAllowed(
        context,
        metadata: widget.metadata,
        report: report,
        confirmLabel: context.l10n.chatAttachmentPreview,
      );
      if (!mounted || !allowed) return;
      final previewData = await resolveAttachmentPreviewData(
        file: file,
        attachment: attachmentPreviewSourceFromMetadata(
          metadata: widget.metadata,
          file: file,
        ),
        typeReport: report,
      );
      if (!mounted) return;
      if (previewData == null || !previewData.kind.opensDialog) {
        _showGalleryAttachmentToast(
          context,
          context.l10n.chatAttachmentUnavailable,
          destructive: true,
        );
        return;
      }
      await showAttachmentPreviewDialog(
        context: context,
        data: previewData,
        closeTooltip: context.l10n.commonClose,
        actions: localAttachmentPreviewDialogActions(
          ownerContext: context,
          file: file,
          metadata: widget.metadata,
          report: report,
          l10n: context.l10n,
        ),
      );
    });
  }

  Future<FileTypeReport> _inspectResolvedFile(File file) {
    return inspectFileType(
      file: file,
      declaredMimeType: widget.metadata.mimeType,
      fileName: widget.metadata.filename,
    );
  }

  Future<File?> _resolveLocalFile() async {
    final path = _effectiveLocalPath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) return file;
    }
    if (!mounted) return null;
    final l10n = context.l10n;
    final declaredReport = buildDeclaredFileTypeReport(
      declaredMimeType: widget.metadata.mimeType,
      fileName: widget.metadata.filename,
      path: widget.metadata.path,
    );
    final allowed = await confirmExportAllowed(
      context,
      metadata: widget.metadata,
      report: declaredReport,
      confirmLabel: l10n.chatAttachmentDownload,
    );
    if (!mounted || !allowed) return null;
    final downloaded = await widget.downloadDelegate?.download() ?? false;
    if (!mounted || !downloaded) {
      if (mounted) {
        _showGalleryAttachmentToast(
          context,
          context.l10n.chatAttachmentUnavailable,
          destructive: true,
        );
      }
      return null;
    }
    final refreshed = await widget.metadataReloadDelegate.reload();
    final refreshedPath = refreshed?.path?.trim();
    if (refreshedPath == null || refreshedPath.isEmpty) {
      if (mounted) {
        _showGalleryAttachmentToast(
          context,
          context.l10n.chatAttachmentUnavailable,
          destructive: true,
        );
      }
      return null;
    }
    final file = File(refreshedPath);
    if (await file.exists()) {
      _downloadedLocalPath = file.path;
      return file;
    }
    if (mounted) {
      _showGalleryAttachmentToast(
        context,
        context.l10n.chatAttachmentUnavailable,
        destructive: true,
      );
    }
    return null;
  }

  Future<void> _withAction(
    _FileTileAction action,
    Future<void> Function() operation,
  ) async {
    if (_busy) return;
    setState(() {
      _activeAction = action;
    });
    try {
      await operation();
    } on XmppFileTooBigException {
      if (!mounted) return;
      _showGalleryAttachmentToast(
        context,
        context.l10n.chatAttachmentUnavailable,
        destructive: true,
      );
    } on XmppMessageException {
      if (!mounted) return;
      _showGalleryAttachmentToast(
        context,
        context.l10n.chatAttachmentUnavailable,
        destructive: true,
      );
    } on EmailServiceException {
      if (!mounted) return;
      _showGalleryAttachmentToast(
        context,
        context.l10n.chatAttachmentUnavailable,
        destructive: true,
      );
    } on PlatformException {
      if (!mounted) return;
      _showGalleryAttachmentToast(
        context,
        context.l10n.chatAttachmentUnavailable,
        destructive: true,
      );
    } on FileSystemException {
      if (!mounted) return;
      _showGalleryAttachmentToast(
        context,
        context.l10n.chatAttachmentUnavailable,
        destructive: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _activeAction = null;
        });
      }
    }
  }
}

class _AttachmentGalleryTileTapTarget extends StatefulWidget {
  const _AttachmentGalleryTileTapTarget({
    required this.onTap,
    required this.child,
  });

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_AttachmentGalleryTileTapTarget> createState() =>
      _AttachmentGalleryTileTapTargetState();
}

class _AttachmentGalleryTileTapTargetState
    extends State<_AttachmentGalleryTileTapTarget> {
  final _bounceController = AxiTapBounceController();

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return ShadFocusable(
      canRequestFocus: enabled,
      builder: (context, focused, child) => child ?? const SizedBox.shrink(),
      child: ShadGestureDetector(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        behavior: HitTestBehavior.opaque,
        hoverStrategies: ShadTheme.of(context).hoverStrategies,
        onTap: widget.onTap,
        onTapDown: enabled ? _bounceController.handleTapDown : null,
        onTapUp: enabled ? _bounceController.handleTapUp : null,
        onTapCancel: enabled ? _bounceController.handleTapCancel : null,
        child: AxiTapBounce(
          controller: _bounceController,
          enabled: enabled,
          child: Material(
            color: Colors.transparent,
            shape: RoundedSuperellipseBorder(borderRadius: context.radius),
            clipBehavior: Clip.antiAlias,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

enum _FileTileAction { save, share, preview }

String _galleryFileTileSizeLabel({
  required int? bytes,
  required bool hasPath,
  required AppLocalizations l10n,
}) {
  final status = hasPath
      ? l10n.chatAttachmentOnThisDevice
      : l10n.chatAttachmentNotDownloadedYet;
  if (bytes == null || bytes <= 0) {
    return hasPath ? '$status • ${l10n.chatAttachmentUnknownSize}' : status;
  }
  final units = [
    l10n.commonFileSizeUnitBytes,
    l10n.commonFileSizeUnitKilobytes,
    l10n.commonFileSizeUnitMegabytes,
    l10n.commonFileSizeUnitGigabytes,
    l10n.commonFileSizeUnitTerabytes,
  ];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit += 1;
  }
  final formatted = unit == 0
      ? size.toStringAsFixed(0)
      : size.toStringAsFixed(size >= 10 ? 0 : 1);
  return '$status • $formatted ${units[unit]}';
}

void _showGalleryAttachmentToast(
  BuildContext context,
  String message, {
  bool destructive = false,
}) {
  final l10n = context.l10n;
  final toaster = ShadToaster.maybeOf(context);
  final toast = destructive
      ? FeedbackToast.error(title: l10n.toastWhoopsTitle, message: message)
      : FeedbackToast.info(title: l10n.toastHeadsUpTitle, message: message);
  toaster?.show(toast);
}
