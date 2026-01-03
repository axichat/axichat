// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/calendar_fragment_policy.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _criticalPathShareSectionSpacing = 16.0;
const double _criticalPathShareTileGap = 12.0;
const double _criticalPathShareAvatarSize = 36.0;
const double _criticalPathShareHeaderIconSize = 18.0;
const double _criticalPathShareProgressStrokeWidth = 2.0;
const double _criticalPathShareLabelLetterSpacing = 0.4;

const EdgeInsets _criticalPathShareChatTilePadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 8,
);

const String _criticalPathShareTitle = 'Share critical path';
const String _criticalPathShareSubtitle = 'Send a critical path to a chat.';
const String _criticalPathShareTargetLabel = 'Share with';
const String _criticalPathShareButtonLabel = 'Share';
const String _criticalPathShareMissingChatsMessage =
    'No eligible chats available.';
const String _criticalPathShareMissingRecipientMessage =
    'Select a chat to share with.';
const String _criticalPathShareMissingServiceMessage =
    'Calendar sharing is unavailable.';
const String _criticalPathShareDeniedMessage =
    'Calendar cards are disabled for your role in this room.';
const String _criticalPathShareSendFailureMessage =
    'Failed to share critical path.';
const String _criticalPathShareSendSuccessMessage = 'Critical path shared.';
const String _criticalPathShareChatTypeDirectLabel = 'Direct chat';
const String _criticalPathShareChatTypeGroupLabel = 'Group chat';
const String _criticalPathShareChatTypeNoteLabel = 'Notes';

Future<void> showCalendarCriticalPathShareSheet({
  required BuildContext context,
  required CalendarCriticalPath path,
  required List<CalendarTask> tasks,
  Chat? initialChat,
}) async {
  final List<Chat> chats =
      context.read<ChatsCubit?>()?.state.items ?? const <Chat>[];
  final List<Chat> available =
      chats.where((chat) => chat.supportsChatCalendar).toList(growable: false);
  if (available.isEmpty) {
    FeedbackSystem.showInfo(context, _criticalPathShareMissingChatsMessage);
    return;
  }
  final result = await showAdaptiveBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => CalendarCriticalPathShareSheet(
      path: path,
      tasks: tasks,
      availableChats: available,
      initialChat: initialChat,
    ),
  );
  if (result != true || !context.mounted) {
    return;
  }
  FeedbackSystem.showSuccess(context, _criticalPathShareSendSuccessMessage);
}

class CalendarCriticalPathShareSheet extends StatefulWidget {
  const CalendarCriticalPathShareSheet({
    super.key,
    required this.path,
    required this.tasks,
    required this.availableChats,
    this.initialChat,
  });

  final CalendarCriticalPath path;
  final List<CalendarTask> tasks;
  final List<Chat> availableChats;
  final Chat? initialChat;

  @override
  State<CalendarCriticalPathShareSheet> createState() =>
      _CalendarCriticalPathShareSheetState();
}

class _CalendarCriticalPathShareSheetState
    extends State<CalendarCriticalPathShareSheet> {
  static const CalendarFragmentFormatter _fragmentFormatter =
      CalendarFragmentFormatter();
  Chat? _selectedChat;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _selectedChat = widget.initialChat ??
        (widget.availableChats.isEmpty ? null : widget.availableChats.first);
  }

  @override
  Widget build(BuildContext context) {
    final header = AxiSheetHeader(
      title: const Text(_criticalPathShareTitle),
      subtitle: const Text(_criticalPathShareSubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    return AxiSheetScaffold.scroll(
      header: header,
      children: [
        const _CriticalPathShareSectionLabel(
          text: _criticalPathShareTargetLabel,
        ),
        if (widget.availableChats.isEmpty)
          const _CriticalPathShareEmptyMessage(
            message: _criticalPathShareMissingChatsMessage,
          )
        else
          _CriticalPathShareChatPicker(
            chats: widget.availableChats,
            selected: _selectedChat,
            onSelected: _handleChatSelected,
          ),
        const SizedBox(height: _criticalPathShareSectionSpacing),
        _CriticalPathShareActionRow(
          isBusy: _isSending,
          onPressed: _handleSharePressed,
          label: _criticalPathShareButtonLabel,
        ),
      ],
    );
  }

  void _handleChatSelected(Chat chat) {
    if (!mounted) return;
    setState(() {
      _selectedChat = chat;
    });
  }

  Future<void> _handleSharePressed() async {
    final selected = _selectedChat;
    if (selected == null) {
      FeedbackSystem.showInfo(
          context, _criticalPathShareMissingRecipientMessage);
      return;
    }
    if (_isSending) {
      return;
    }
    setState(() => _isSending = true);
    final XmppService? xmppService = _maybeReadXmppService(context);
    try {
      if (xmppService == null) {
        FeedbackSystem.showInfo(
            context, _criticalPathShareMissingServiceMessage);
        return;
      }
      final CalendarFragmentShareDecision decision =
          const CalendarFragmentPolicy().decisionForChat(
        chat: selected,
        roomState: xmppService.roomStateFor(selected.jid),
      );
      if (!decision.canWrite) {
        FeedbackSystem.showInfo(context, _criticalPathShareDeniedMessage);
        return;
      }
      final CalendarFragment fragment = _buildFragment();
      final String shareText = _fragmentFormatter.describe(fragment).trim();
      await xmppService.sendMessage(
        jid: selected.jid,
        text: shareText,
        encryptionProtocol: selected.encryptionProtocol,
        calendarFragment: fragment,
        chatType: selected.type,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on Exception {
      if (mounted) {
        FeedbackSystem.showError(context, _criticalPathShareSendFailureMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  CalendarFragment _buildFragment() {
    final Set<String> availableIds =
        widget.tasks.map((task) => task.id).toSet();
    final List<String> orderedIds = widget.path.taskIds
        .where(availableIds.contains)
        .toList(growable: false);
    final CalendarCriticalPath path = widget.path.copyWith(taskIds: orderedIds);
    return CalendarFragment.criticalPath(
      path: path,
      tasks: widget.tasks,
    );
  }
}

class _CriticalPathShareSectionLabel extends StatelessWidget {
  const _CriticalPathShareSectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.textTheme.muted.copyWith(
        letterSpacing: _criticalPathShareLabelLetterSpacing,
      ),
    );
  }
}

class _CriticalPathShareChatPicker extends StatelessWidget {
  const _CriticalPathShareChatPicker({
    required this.chats,
    required this.selected,
    required this.onSelected,
  });

  final List<Chat> chats;
  final Chat? selected;
  final ValueChanged<Chat> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final chat in chats) ...[
          AxiListTile(
            leading: AxiAvatar(
              jid: chat.jid,
              size: _criticalPathShareAvatarSize,
              avatarPath: chat.avatarPath,
              shape: AxiAvatarShape.circle,
            ),
            title: chat.displayName,
            subtitle: chat.type.label,
            selected: selected?.jid == chat.jid,
            onTap: () => onSelected(chat),
            contentPadding: _criticalPathShareChatTilePadding,
          ),
          const SizedBox(height: _criticalPathShareTileGap),
        ],
      ],
    );
  }
}

class _CriticalPathShareActionRow extends StatelessWidget {
  const _CriticalPathShareActionRow({
    required this.isBusy,
    required this.onPressed,
    required this.label,
  });

  final bool isBusy;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ShadButton(
        size: ShadButtonSize.sm,
        onPressed: isBusy ? null : onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy)
              const SizedBox(
                width: _criticalPathShareHeaderIconSize,
                height: _criticalPathShareHeaderIconSize,
                child: CircularProgressIndicator(
                  strokeWidth: _criticalPathShareProgressStrokeWidth,
                ),
              )
            else
              const Icon(
                LucideIcons.share2,
                size: _criticalPathShareHeaderIconSize,
              ),
            const SizedBox(width: _criticalPathShareSectionSpacing),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _CriticalPathShareEmptyMessage extends StatelessWidget {
  const _CriticalPathShareEmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _criticalPathShareTileGap),
      child: Text(
        message,
        style: context.textTheme.small.copyWith(
          color: context.colorScheme.mutedForeground,
        ),
      ),
    );
  }
}

XmppService? _maybeReadXmppService(BuildContext context) {
  try {
    return RepositoryProvider.of<XmppService>(
      context,
      listen: false,
    );
  } on FlutterError {
    return null;
  }
}

extension _ChatTypeLabelX on ChatType {
  String get label => switch (this) {
        ChatType.chat => _criticalPathShareChatTypeDirectLabel,
        ChatType.groupChat => _criticalPathShareChatTypeGroupLabel,
        ChatType.note => _criticalPathShareChatTypeNoteLabel,
      };
}
