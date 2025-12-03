import 'dart:async';
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
  const ChatSelectionActionBar({
    super.key,
    required this.selectedChats,
  });

  final List<Chat> selectedChats;

  @override
  State<ChatSelectionActionBar> createState() => _ChatSelectionActionBarState();
}

class _ChatSelectionActionBarState extends State<ChatSelectionActionBar> {
  var _exporting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final count = widget.selectedChats.length;
    final allFavorited = widget.selectedChats.every((chat) => chat.favorited);
    final allArchived = widget.selectedChats.every((chat) => chat.archived);
    final allHidden = widget.selectedChats.every((chat) => chat.hidden);
    final shouldFavorite = !allFavorited;
    final shouldArchive = !allArchived;
    final shouldHide = !allHidden;

    return SelectionPanelShell(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectionSummaryHeader(
            count: count,
            onClear: () => context.read<ChatsCubit>().clearSelection(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ContextActionButton(
                icon: Icon(
                  shouldFavorite ? LucideIcons.star : LucideIcons.starOff,
                  size: 16,
                ),
                label: shouldFavorite
                    ? l10n.commonFavorite
                    : l10n.commonUnfavorite,
                onPressed: () => unawaited(
                  context.read<ChatsCubit>().bulkToggleFavorited(
                        favorited: shouldFavorite,
                      ),
                ),
              ),
              ContextActionButton(
                icon: Icon(
                  shouldArchive ? LucideIcons.archive : LucideIcons.undo2,
                  size: 16,
                ),
                label:
                    shouldArchive ? l10n.commonArchive : l10n.commonUnarchive,
                onPressed: () => unawaited(
                  context.read<ChatsCubit>().bulkToggleArchived(
                        archived: shouldArchive,
                      ),
                ),
              ),
              ContextActionButton(
                icon: Icon(
                  shouldHide ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 16,
                ),
                label: shouldHide ? l10n.commonHide : l10n.commonShow,
                onPressed: () => unawaited(
                  context.read<ChatsCubit>().bulkToggleHidden(
                        hidden: shouldHide,
                      ),
                ),
              ),
              ChatExportActionButton(
                exporting: _exporting,
                onPressed: () => _exportSelectedChats(context),
              ),
              ContextActionButton(
                icon: const Icon(LucideIcons.trash2, size: 16),
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
    final l10n = context.l10n;
    if (_exporting) return;
    if (widget.selectedChats.isEmpty) return;
    setState(() {
      _exporting = true;
    });
    final showToast = ShadToaster.maybeOf(context)?.show;
    try {
      final result = await ChatHistoryExporter.exportChats(
        chats: widget.selectedChats,
        loadHistory: context.read<ChatsCubit>().loadChatHistory,
        fileLabel:
            widget.selectedChats.length == 1 ? null : l10n.chatsExportFileLabel,
      );
      final file = result.file;
      if (file == null) {
        showToast?.call(
          FeedbackToast.info(
            title: l10n.chatSelectionExportEmptyTitle,
            message: l10n.chatSelectionExportEmptyMessage,
          ),
        );
        return;
      }
      await Share.shareXFiles(
        [XFile(file.path)],
        text: l10n.chatSelectionExportShareText,
        subject: l10n.chatSelectionExportShareSubject,
      );
      showToast?.call(
        FeedbackToast.success(
          title: l10n.chatSelectionExportReadyTitle,
          message:
              l10n.chatSelectionExportReadyMessage(widget.selectedChats.length),
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
}
