import 'dart:async';
import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/context_action_button.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatSelectionActionBar extends StatefulWidget {
  const ChatSelectionActionBar({
    super.key,
    required this.chatsCubit,
    required this.selectedChats,
  });

  final ChatsCubit chatsCubit;
  final List<Chat> selectedChats;

  @override
  State<ChatSelectionActionBar> createState() => _ChatSelectionActionBarState();
}

class _ChatSelectionActionBarState extends State<ChatSelectionActionBar> {
  var _exporting = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final count = widget.selectedChats.length;
    final allFavorited = widget.selectedChats.every((chat) => chat.favorited);
    final allArchived = widget.selectedChats.every((chat) => chat.archived);
    final allHidden = widget.selectedChats.every((chat) => chat.hidden);
    final shouldFavorite = !allFavorited;
    final shouldArchive = !allArchived;
    final shouldHide = !allHidden;

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(
            top: BorderSide(color: colors.border, width: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$count selected',
                      style: textTheme.muted,
                    ),
                  ),
                  AxiIconButton(
                    iconData: LucideIcons.x,
                    tooltip: 'Clear selection',
                    onPressed: widget.chatsCubit.clearSelection,
                  ),
                ],
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
                      widget.chatsCubit.bulkToggleFavorited(
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
                      widget.chatsCubit
                          .bulkToggleArchived(archived: shouldArchive),
                    ),
                  ),
                  ContextActionButton(
                    icon: Icon(
                      shouldHide ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 16,
                    ),
                    label: shouldHide ? 'Hide' : 'Show',
                    onPressed: () => unawaited(
                      widget.chatsCubit.bulkToggleHidden(hidden: shouldHide),
                    ),
                  ),
                  ContextActionButton(
                    icon: _exporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.share2, size: 16),
                    label: _exporting ? 'Exporting...' : 'Export',
                    onPressed:
                        _exporting ? null : () => _exportSelectedChats(context),
                  ),
                  ContextActionButton(
                    icon: const Icon(LucideIcons.trash2, size: 16),
                    label: 'Delete',
                    destructive: true,
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      final buffer = StringBuffer();
      final formatter = intl.DateFormat('y-MM-dd HH:mm');
      for (final chat in widget.selectedChats) {
        final history = await widget.chatsCubit.loadChatHistory(chat.jid);
        if (history.isEmpty) continue;
        buffer
          ..writeln('=== ${chat.title} (${chat.jid}) ===')
          ..writeln();
        for (final message in history) {
          final timestampValue =
              message.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
          final timestamp = formatter.format(timestampValue);
          final author = message.senderJid;
          final content = message.body?.trim();
          if (content == null || content.isEmpty) continue;
          buffer.writeln('[$timestamp] $author: $content');
        }
        buffer.writeln();
      }
      final exportText = buffer.toString().trim();
      if (exportText.isEmpty) {
        showToast?.call(
          const ShadToast(
            title: Text('No messages to export'),
            description: Text('Select chats with text content'),
            alignment: Alignment.topRight,
            showCloseIconOnlyWhenHovered: false,
          ),
        );
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final fileName = 'chats-${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(exportText);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Chat exports from Axichat',
        subject: 'Axichat chats export',
      );
      showToast?.call(
        ShadToast(
          title: const Text('Export ready'),
          description: Text(
            'Shared ${widget.selectedChats.length} chat(s)',
          ),
          alignment: Alignment.topRight,
          showCloseIconOnlyWhenHovered: false,
        ),
      );
    } catch (_) {
      showToast?.call(
        const ShadToast.destructive(
          title: Text('Export failed'),
          description: Text('Unable to export selected chats'),
          alignment: Alignment.topRight,
          showCloseIconOnlyWhenHovered: false,
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

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ShadDialog(
        title: const Text('Delete chats?'),
        description: Text(
          'This removes ${widget.selectedChats.length} chats and all of their messages. This cannot be undone.',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ).withTapBounce(),
          ShadButton.destructive(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ).withTapBounce(),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.chatsCubit.bulkDeleteSelectedChats();
  }
}
