// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _shareIntentSectionSpacing = 16.0;
const double _shareIntentSectionGap = 8.0;
const double _shareIntentTileGap = 12.0;
const double _shareIntentAvatarSize = 36.0;
const double _shareIntentComposeIconSize = 18.0;
const double _shareIntentComposeIconAlpha = 0.12;
const double _shareIntentLabelFontSize = 12.0;
const double _shareIntentLabelLetterSpacing = 1.1;

const EdgeInsets _shareIntentTilePadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 8,
);

const String _shareIntentTitle = 'Share with';
const String _shareIntentSubtitle = 'Choose a chat or open a compose window.';
const String _shareIntentComposeLabel = 'New message';
const String _shareIntentComposeHint = 'Pick recipients in compose.';
const String _shareIntentChatsLabel = 'Chats';
const String _shareIntentEmptyChatsMessage = 'No chats available.';
const String _shareIntentChatTypeDirectLabel = 'Direct chat';
const String _shareIntentChatTypeGroupLabel = 'Group chat';
const String _shareIntentChatTypeNoteLabel = 'Notes';

sealed class ShareIntentDestination extends Equatable {
  const ShareIntentDestination();
}

final class ShareIntentComposeDestination extends ShareIntentDestination {
  const ShareIntentComposeDestination();

  @override
  List<Object?> get props => [];
}

final class ShareIntentChatDestination extends ShareIntentDestination {
  const ShareIntentChatDestination(this.chat);

  final Chat chat;

  @override
  List<Object?> get props => [chat];
}

Future<ShareIntentDestination?> showShareIntentSheet({
  required BuildContext context,
  required List<Chat> chats,
}) async {
  final List<Chat> available =
      chats.where((chat) => chat.type != ChatType.note).toList(growable: false);
  return showAdaptiveBottomSheet<ShareIntentDestination>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => ShareIntentSheet(
      availableChats: available,
    ),
  );
}

class ShareIntentSheet extends StatelessWidget {
  const ShareIntentSheet({
    super.key,
    required this.availableChats,
  });

  final List<Chat> availableChats;

  @override
  Widget build(BuildContext context) {
    final header = AxiSheetHeader(
      title: const Text(_shareIntentTitle),
      subtitle: const Text(_shareIntentSubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    return AxiSheetScaffold.scroll(
      header: header,
      children: [
        const _ShareIntentSectionLabel(text: _shareIntentComposeLabel),
        _ShareIntentComposeTile(
          onSelected: () => Navigator.of(context).pop(
            const ShareIntentComposeDestination(),
          ),
        ),
        const SizedBox(height: _shareIntentSectionSpacing),
        const _ShareIntentSectionLabel(text: _shareIntentChatsLabel),
        const SizedBox(height: _shareIntentSectionGap),
        if (availableChats.isEmpty)
          const _ShareIntentEmptyMessage(
            message: _shareIntentEmptyChatsMessage,
          )
        else
          _ShareIntentChatList(
            chats: availableChats,
            onSelected: (chat) => Navigator.of(context).pop(
              ShareIntentChatDestination(chat),
            ),
          ),
      ],
    );
  }
}

class _ShareIntentSectionLabel extends StatelessWidget {
  const _ShareIntentSectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = context.textTheme.muted.copyWith(
      fontSize: _shareIntentLabelFontSize,
      letterSpacing: _shareIntentLabelLetterSpacing,
    );
    return Text(text.toUpperCase(), style: style);
  }
}

class _ShareIntentComposeTile extends StatelessWidget {
  const _ShareIntentComposeTile({required this.onSelected});

  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return AxiListTile(
      leading: const _ShareIntentComposeIcon(),
      title: _shareIntentComposeLabel,
      subtitle: _shareIntentComposeHint,
      onTap: onSelected,
      contentPadding: _shareIntentTilePadding,
    );
  }
}

class _ShareIntentComposeIcon extends StatelessWidget {
  const _ShareIntentComposeIcon();

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.primary.withValues(alpha: _shareIntentComposeIconAlpha),
        shape: const CircleBorder(),
      ),
      child: SizedBox.square(
        dimension: _shareIntentAvatarSize,
        child: Icon(
          LucideIcons.pencilLine,
          size: _shareIntentComposeIconSize,
          color: colors.primary,
        ),
      ),
    );
  }
}

class _ShareIntentChatList extends StatelessWidget {
  const _ShareIntentChatList({
    required this.chats,
    required this.onSelected,
  });

  final List<Chat> chats;
  final ValueChanged<Chat> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final chat in chats) ...[
          AxiListTile(
            leading: AxiAvatar(
              jid: chat.jid,
              size: _shareIntentAvatarSize,
              avatarPath: chat.avatarPath,
              shape: AxiAvatarShape.circle,
            ),
            title: chat.displayName,
            subtitle: chat.type.label,
            onTap: () => onSelected(chat),
            contentPadding: _shareIntentTilePadding,
          ),
          const SizedBox(height: _shareIntentTileGap),
        ],
      ],
    );
  }
}

class _ShareIntentEmptyMessage extends StatelessWidget {
  const _ShareIntentEmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = context.textTheme.muted.copyWith(
      color: context.colorScheme.mutedForeground,
    );
    return Text(message, style: style);
  }
}

extension _ShareIntentChatTypeLabelX on ChatType {
  String get label => switch (this) {
        ChatType.chat => _shareIntentChatTypeDirectLabel,
        ChatType.groupChat => _shareIntentChatTypeGroupLabel,
        ChatType.note => _shareIntentChatTypeNoteLabel,
      };
}
