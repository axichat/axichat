import 'dart:async';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/utils/chat_history_exporter.dart';
import 'package:axichat/src/chats/view/widgets/chat_export_action_button.dart';
import 'package:axichat/src/chats/view/widgets/selection_panel_shell.dart';
import 'package:axichat/src/common/ui/context_action_button.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
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
                label: shouldFavorite ? 'Favorite' : 'Unfavorite',
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
                label: shouldArchive ? 'Archive' : 'Unarchive',
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
                label: shouldHide ? 'Hide' : 'Show',
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
                label: 'Delete',
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
    setState(() {
      _exporting = true;
    });
    final showToast = ShadToaster.maybeOf(context)?.show;
    try {
      final result = await ChatHistoryExporter.exportChats(
        chats: widget.selectedChats,
        loadHistory: context.read<ChatsCubit>().loadChatHistory,
        fileLabel: widget.selectedChats.length == 1 ? null : 'chats',
      );
      final file = result.file;
      if (file == null) {
        showToast?.call(
          FeedbackToast.info(
            title: 'No messages to export',
            message: 'Select chats with text content',
          ),
        );
        return;
      }
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Chat exports from Axichat',
        subject: 'Axichat chats export',
      );
      showToast?.call(
        FeedbackToast.success(
          title: 'Export ready',
          message: 'Shared ${widget.selectedChats.length} chat(s)',
        ),
      );
    } catch (_) {
      showToast?.call(
        FeedbackToast.error(
          title: 'Export failed',
          message: 'Unable to export selected chats',
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
    final confirmed = await confirm(
      context,
      title: 'Delete chats?',
      message:
          'This removes ${widget.selectedChats.length} chats and all of their messages. This cannot be undone.',
      confirmLabel: 'Delete',
      barrierDismissible: false,
    );
    if (!mounted || confirmed != true) return;
    await context.read<ChatsCubit>().bulkDeleteSelectedChats();
  }
}
