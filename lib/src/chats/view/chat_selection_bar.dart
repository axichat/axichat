import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/context_action_button.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatSelectionActionBar extends StatelessWidget {
  const ChatSelectionActionBar({
    super.key,
    required this.chatsCubit,
    required this.selectedChats,
  });

  final ChatsCubit chatsCubit;
  final List<Chat> selectedChats;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final count = selectedChats.length;
    final allFavorited = selectedChats.every((chat) => chat.favorited);
    final allArchived = selectedChats.every((chat) => chat.archived);
    final allHidden = selectedChats.every((chat) => chat.hidden);
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
                  ShadButton.outline(
                    onPressed: chatsCubit.clearSelection,
                    child: const Text('Cancel'),
                  ).withTapBounce(),
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
                      chatsCubit.bulkToggleFavorited(
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
                      chatsCubit.bulkToggleArchived(archived: shouldArchive),
                    ),
                  ),
                  ContextActionButton(
                    icon: Icon(
                      shouldHide ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 16,
                    ),
                    label: shouldHide ? 'Hide' : 'Show',
                    onPressed: () => unawaited(
                      chatsCubit.bulkToggleHidden(hidden: shouldHide),
                    ),
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

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ShadDialog(
        title: const Text('Delete chats?'),
        description: Text(
          'This removes ${selectedChats.length} chats and all of their messages. This cannot be undone.',
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
    await chatsCubit.bulkDeleteSelectedChats();
  }
}
