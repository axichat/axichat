// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/utils/message_exporter.dart';
import 'package:axichat/src/chats/view/chat_export_action_button.dart';
import 'package:axichat/src/chats/view/selection_panel_shell.dart';
import 'package:axichat/src/common/export_file_saver.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatSelectionActionBar extends StatefulWidget {
  const ChatSelectionActionBar({super.key, required this.selectedChats});

  final List<Chat> selectedChats;

  @override
  State<ChatSelectionActionBar> createState() => _ChatSelectionActionBarState();
}

class _ChatSelectionActionBarState extends State<ChatSelectionActionBar> {
  var _exporting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final count = widget.selectedChats.length;
    final allFavorited = widget.selectedChats.every((chat) => chat.favorited);
    final allArchived = widget.selectedChats.every((chat) => chat.archived);
    final allHidden = widget.selectedChats.every((chat) => chat.hidden);
    final shouldFavorite = !allFavorited;
    final shouldArchive = !allArchived;
    final shouldHide = !allHidden;

    return SelectionPanelShell(
      padding: EdgeInsets.fromLTRB(spacing.m, spacing.m, spacing.m, spacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectionSummaryHeader(
            count: count,
            onClear: () => context.read<ChatsCubit>().clearSelection(),
          ),
          SizedBox(height: spacing.s),
          Wrap(
            spacing: spacing.s,
            runSpacing: spacing.s,
            alignment: WrapAlignment.center,
            children: [
              ContextActionButton(
                icon: Icon(
                  shouldFavorite ? LucideIcons.star : LucideIcons.starOff,
                  size: sizing.menuItemIconSize,
                ),
                label: shouldFavorite
                    ? l10n.commonFavorite
                    : l10n.commonUnfavorite,
                onPressed: () async {
                  await context.read<ChatsCubit>().bulkToggleFavorited(
                    favorited: shouldFavorite,
                  );
                },
              ),
              ContextActionButton(
                icon: Icon(
                  shouldArchive ? LucideIcons.archive : LucideIcons.undo2,
                  size: sizing.menuItemIconSize,
                ),
                label: shouldArchive
                    ? l10n.commonArchive
                    : l10n.commonUnarchive,
                onPressed: () async {
                  await context.read<ChatsCubit>().bulkToggleArchived(
                    archived: shouldArchive,
                  );
                },
              ),
              ContextActionButton(
                icon: Icon(
                  shouldHide ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: sizing.menuItemIconSize,
                ),
                label: shouldHide ? l10n.commonHide : l10n.commonShow,
                onPressed: () async {
                  await context.read<ChatsCubit>().bulkToggleHidden(
                    hidden: shouldHide,
                  );
                },
              ),
              ChatExportActionButton(
                exporting: _exporting,
                readyLabel: l10n.commonExport,
                onPressed: () => _exportSelectedChats(context),
              ),
              ContextActionButton(
                icon: Icon(LucideIcons.trash2, size: sizing.menuItemIconSize),
                label: l10n.commonDelete,
                destructive: true,
                onPressed: _confirmDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportSelectedChats(BuildContext context) async {
    if (_exporting) return;
    if (widget.selectedChats.isEmpty) return;
    final selectedChats = List<Chat>.unmodifiable(widget.selectedChats);
    final selectedChatCount = selectedChats.length;
    final l10n = context.l10n;
    final showToast = ShadToaster.maybeOf(context)?.show;
    final chatsCubit = context.read<ChatsCubit>();
    final confirmed = await _confirmChatExport();
    if (!mounted || !confirmed) return;
    setState(() {
      _exporting = true;
    });
    File? exportFile;
    try {
      final result = await chatsCubit.exportChats(selectedChats);
      exportFile = result.file;
      if (result.outcome == MessageExportOutcome.failure ||
          result.outcome == MessageExportOutcome.incomplete &&
              exportFile == null) {
        showToast?.call(
          FeedbackToast.error(
            title: l10n.chatSelectionExportFailedTitle,
            message: l10n.chatSelectionExportFailedMessage,
          ),
        );
        return;
      }
      if (exportFile == null) {
        showToast?.call(
          FeedbackToast.info(
            title: l10n.chatSelectionExportEmptyTitle,
            message: l10n.chatSelectionExportEmptyMessage,
          ),
        );
        return;
      }
      final savePath = await saveExportFileWithPicker(
        file: exportFile,
        filename: p.basename(exportFile.path),
        platform: defaultTargetPlatform,
        maxBytesForBytesSave: defaultExportPickerBytesMaxSize,
        deleteSource: true,
      );
      exportFile = null;
      if (savePath == null || savePath.trim().isEmpty) return;
      if (result.outcome == MessageExportOutcome.incomplete) {
        showToast?.call(
          FeedbackToast.warning(
            title: l10n.chatsExportIncomplete,
            message: l10n.chatsExportIncompleteMessage,
          ),
        );
      } else {
        showToast?.call(
          FeedbackToast.success(
            title: l10n.chatSelectionExportReadyTitle,
            message: l10n.chatSelectionExportReadyMessage(selectedChatCount),
          ),
        );
      }
    } on ExportSaveFileTooLargeException {
      showToast?.call(
        FeedbackToast.error(
          title: l10n.chatSelectionExportFailedTitle,
          message: l10n.chatsExportTooLargeForDevice,
        ),
      );
    } catch (_) {
      showToast?.call(
        FeedbackToast.error(
          title: l10n.chatSelectionExportFailedTitle,
          message: l10n.chatSelectionExportFailedMessage,
        ),
      );
    } finally {
      if (exportFile != null) {
        try {
          if (await exportFile.exists()) {
            await exportFile.delete();
          }
        } on Exception {
          // Export temp cleanup is best-effort.
        }
      }
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final deleteSelectedChats = context
        .read<ChatsCubit>()
        .bulkDeleteSelectedChats;
    final confirmed = await confirm(
      context,
      title: l10n.chatSelectionDeleteConfirmTitle,
      message: l10n.chatSelectionDeleteConfirmMessage(
        widget.selectedChats.length,
      ),
      confirmLabel: l10n.commonDelete,
      barrierDismissible: false,
    );
    if (!mounted || confirmed != true) return;
    await deleteSelectedChats();
  }

  Future<bool> _confirmChatExport() async {
    final l10n = context.l10n;
    final confirmed = await confirm(
      context,
      title: l10n.chatExportWarningTitle,
      message: l10n.chatExportWarningMessage,
      confirmLabel: l10n.commonExport,
      cancelLabel: l10n.commonCancel,
      destructiveConfirm: false,
    );
    return confirmed == true;
  }
}
