// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/utils/chat_history_exporter.dart';
import 'package:axichat/src/chats/view/widgets/chat_export_action_button.dart';
import 'package:axichat/src/chats/view/widgets/selection_panel_shell.dart';
import 'package:axichat/src/common/ui/context_action_button.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
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
      padding: EdgeInsets.fromLTRB(
        spacing.m,
        spacing.m,
        spacing.m,
        spacing.s,
      ),
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
                  final chatsCubit = context.read<ChatsCubit>();
                  await chatsCubit.bulkToggleFavorited(
                    favorited: shouldFavorite,
                  );
                },
              ),
              ContextActionButton(
                icon: Icon(
                  shouldArchive ? LucideIcons.archive : LucideIcons.undo2,
                  size: sizing.menuItemIconSize,
                ),
                label:
                    shouldArchive ? l10n.commonArchive : l10n.commonUnarchive,
                onPressed: () async {
                  final chatsCubit = context.read<ChatsCubit>();
                  await chatsCubit.bulkToggleArchived(
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
                  final chatsCubit = context.read<ChatsCubit>();
                  await chatsCubit.bulkToggleHidden(
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
    final l10n = context.l10n;
    final showToast = ShadToaster.maybeOf(context)?.show;
    final String? fileLabel =
        widget.selectedChats.length == 1 ? null : l10n.chatsExportFileLabel;
    final confirmed = await _confirmChatExport();
    if (!context.mounted || !confirmed) return;
    setState(() {
      _exporting = true;
    });
    File? exportFile;
    try {
      final result = await ChatHistoryExporter.exportChats(
        chats: widget.selectedChats,
        loadHistory: context.read<ChatsCubit>().loadChatHistory,
        countHistory: context.read<ChatsCubit>().countChatHistoryMessages,
        loadHistoryPage: context.read<ChatsCubit>().loadChatHistoryPage,
        fileLabel: fileLabel,
      );
      exportFile = result.file;
      if (exportFile == null) {
        showToast?.call(
          FeedbackToast.info(
            title: l10n.chatSelectionExportEmptyTitle,
            message: l10n.chatSelectionExportEmptyMessage,
          ),
        );
        return;
      }
      await Share.shareXFiles(
        [XFile(exportFile.path)],
        text: l10n.chatSelectionExportShareText,
        subject: l10n.chatSelectionExportShareSubject,
      );
      showToast?.call(
        FeedbackToast.success(
          title: l10n.chatSelectionExportReadyTitle,
          message: l10n.chatSelectionExportReadyMessage(
            widget.selectedChats.length,
          ),
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
        context.read<ChatsCubit>().scheduleExportCleanup(exportFile);
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
    await context.read<ChatsCubit>().bulkDeleteSelectedChats();
  }

  Future<bool> _confirmChatExport() async {
    final l10n = context.l10n;
    final confirmed = await confirm(
      context,
      title: l10n.chatExportWarningTitle,
      message: l10n.chatExportWarningMessage,
      confirmLabel: l10n.commonContinue,
      cancelLabel: l10n.commonCancel,
      destructiveConfirm: false,
    );
    return confirmed == true;
  }
}
