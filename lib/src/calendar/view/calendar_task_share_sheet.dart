// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/storage/calendar_linked_task_registry.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_identifiers.dart';
import 'package:axichat/src/calendar/utils/calendar_fragment_policy.dart';
import 'package:axichat/src/calendar/utils/calendar_transfer_service.dart';
import 'package:axichat/src/calendar/utils/task_share_formatter.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart' show ComposerRecipient;
import 'package:axichat/src/chat/view/recipient_chips_bar.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_ui/shadcn_ui.dart';

const double _taskShareSectionSpacing = 16.0;
const double _taskShareSectionGap = 8.0;
const double _taskShareHeaderIconSize = 18.0;
const double _taskShareProgressStrokeWidth = 2.0;
const double _taskShareLabelFontSize = 12.0;
const double _taskShareLabelLetterSpacing = 1.1;
const EdgeInsets _taskShareContentPadding =
    EdgeInsets.symmetric(horizontal: 16);

const String _taskShareTitle = 'Share task';
const String _taskShareSubtitle = 'Send a task to a chat as .ics.';
const String _taskShareTargetLabel = 'Share with';
const String _taskShareEditAccessLabel = 'Edit access';
const String _taskShareReadOnlyLabel = 'Read only';
const String _taskShareReadOnlyHint =
    'Recipients can view this task, but only you can edit it.';
const String _taskShareEditableHint =
    'Recipients can edit this task, and updates sync back to your calendar.';
const String _taskShareReadOnlyDisabledHint =
    'Editing is only available for chat calendars.';
const String _taskShareButtonLabel = 'Send';
const String _taskShareMissingChatsMessage = 'No chats available.';
const String _taskShareMissingRecipientMessage = 'Select a chat to share with.';
const String _taskShareMissingServiceMessage =
    'Calendar sharing is unavailable.';
const String _taskShareDeniedMessage =
    'Calendar cards are disabled for your role in this room.';
const String _taskShareSendFailureMessage = 'Failed to share task.';
const String _taskShareSendSuccessMessage = 'Task shared.';
const String _taskShareIcsMimeType = 'text/calendar';
const bool _taskShareReadOnlyDefault = true;

Future<void> showCalendarTaskShareSheet({
  required BuildContext context,
  required CalendarTask task,
  Chat? initialChat,
}) async {
  final List<Chat> chats =
      context.read<ChatsCubit?>()?.state.items ?? const <Chat>[];
  final List<Chat> available =
      chats.where((chat) => chat.type != ChatType.note).toList(growable: false);
  if (available.isEmpty) {
    FeedbackSystem.showInfo(context, _taskShareMissingChatsMessage);
    return;
  }
  final result = await showAdaptiveBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    surfacePadding: EdgeInsets.zero,
    builder: (sheetContext) => CalendarTaskShareSheet(
      task: task,
      availableChats: available,
      initialChat: initialChat,
    ),
  );
  if (result != true || !context.mounted) {
    return;
  }
  FeedbackSystem.showSuccess(context, _taskShareSendSuccessMessage);
}

class CalendarTaskShareSheet extends StatefulWidget {
  const CalendarTaskShareSheet({
    super.key,
    required this.task,
    required this.availableChats,
    this.initialChat,
  });

  final CalendarTask task;
  final List<Chat> availableChats;
  final Chat? initialChat;

  @override
  State<CalendarTaskShareSheet> createState() => _CalendarTaskShareSheetState();
}

class _CalendarTaskShareSheetState extends State<CalendarTaskShareSheet> {
  List<ComposerRecipient> _recipients = <ComposerRecipient>[];
  bool _isSending = false;
  bool _isReadOnly = _taskShareReadOnlyDefault;

  @override
  void initState() {
    super.initState();
    final Chat? initialChat = widget.initialChat ??
        (widget.availableChats.isEmpty ? null : widget.availableChats.first);
    if (initialChat != null) {
      _recipients = <ComposerRecipient>[
        ComposerRecipient(target: FanOutTarget.chat(initialChat)),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final Chat? selectedChat = _selectedChat;
    final bool readOnlyEnabled =
        selectedChat != null && selectedChat.supportsChatCalendar;
    final bool isReadOnly = readOnlyEnabled ? _isReadOnly : true;
    final String readOnlyHint = readOnlyEnabled
        ? (isReadOnly ? _taskShareReadOnlyHint : _taskShareEditableHint)
        : _taskShareReadOnlyDisabledHint;
    final header = AxiSheetHeader(
      title: const Text(_taskShareTitle),
      subtitle: const Text(_taskShareSubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    return AxiSheetScaffold.scroll(
      header: header,
      bodyPadding: EdgeInsets.zero,
      children: [
        const Padding(
          padding: _taskShareContentPadding,
          child: _TaskShareSectionLabel(text: _taskShareTargetLabel),
        ),
        if (widget.availableChats.isEmpty)
          const Padding(
            padding: _taskShareContentPadding,
            child: _TaskShareEmptyMessage(
              message: _taskShareMissingChatsMessage,
            ),
          )
        else
          RecipientChipsBar(
            recipients: _recipients,
            availableChats: widget.availableChats,
            latestStatuses: const {},
            collapsedByDefault: false,
            allowAddressTargets: false,
            showSuggestionsWhenEmpty: true,
            onRecipientAdded: _handleRecipientAdded,
            onRecipientRemoved: _handleRecipientRemoved,
            onRecipientToggled: _handleRecipientToggled,
          ),
        const SizedBox(height: _taskShareSectionSpacing),
        const Padding(
          padding: _taskShareContentPadding,
          child: _TaskShareSectionLabel(text: _taskShareEditAccessLabel),
        ),
        Padding(
          padding: _taskShareContentPadding,
          child: _TaskShareEditAccessToggle(
            value: isReadOnly,
            isEnabled: readOnlyEnabled,
            hint: readOnlyHint,
            onChanged: _handleReadOnlyChanged,
          ),
        ),
        const SizedBox(height: _taskShareSectionSpacing),
        Padding(
          padding: _taskShareContentPadding,
          child: _TaskShareActionRow(
            isBusy: _isSending,
            onPressed: _handleSharePressed,
            label: _taskShareButtonLabel,
          ),
        ),
      ],
    );
  }

  Chat? get _selectedChat {
    for (final recipient in _recipients) {
      final chat = recipient.target.chat;
      if (recipient.included && chat != null) {
        return chat;
      }
    }
    return null;
  }

  void _handleRecipientAdded(FanOutTarget target) {
    final Chat? chat = target.chat;
    if (chat == null) {
      FeedbackSystem.showInfo(context, _taskShareMissingRecipientMessage);
      return;
    }
    if (!mounted) return;
    setState(() {
      _recipients = <ComposerRecipient>[ComposerRecipient(target: target)];
      if (!chat.supportsChatCalendar) {
        _isReadOnly = true;
      }
    });
    _handleSharePressed();
  }

  void _handleRecipientRemoved(String key) {
    if (!mounted) return;
    setState(() {
      _recipients = _recipients
          .where((recipient) => recipient.key != key)
          .toList(growable: false);
    });
  }

  void _handleRecipientToggled(String key) {
    if (!mounted) return;
    setState(() {
      _recipients = _recipients
          .map(
            (recipient) => recipient.key == key
                ? recipient.copyWith(included: !recipient.included)
                : recipient,
          )
          .toList(growable: false);
    });
  }

  void _handleReadOnlyChanged(bool value) {
    if (!mounted) return;
    setState(() {
      _isReadOnly = value;
    });
  }

  Future<void> _handleSharePressed() async {
    final Chat? selected = _selectedChat;
    if (selected == null) {
      FeedbackSystem.showInfo(context, _taskShareMissingRecipientMessage);
      return;
    }
    if (_isSending) {
      return;
    }
    setState(() => _isSending = true);
    final String shareText = widget.task.toShareText();
    final bool readOnly = _isReadOnly || !selected.supportsChatCalendar;
    final XmppService? xmppService = _maybeReadXmppService(context);
    final EmailService? emailService = RepositoryProvider.of<EmailService?>(
      context,
    );
    try {
      if (selected.defaultTransport.isEmail) {
        if (emailService == null) {
          FeedbackSystem.showInfo(context, _taskShareMissingServiceMessage);
          return;
        }
        final EmailAttachment? attachment = await _buildCalendarTaskAttachment(
          widget.task,
        );
        if (!mounted) {
          return;
        }
        if (attachment == null) {
          FeedbackSystem.showError(context, _taskShareSendFailureMessage);
          return;
        }
        final EmailAttachment resolvedAttachment = attachment.copyWith(
          caption: shareText,
        );
        await emailService.sendAttachment(
          chat: selected,
          attachment: resolvedAttachment,
        );
      } else {
        if (xmppService == null) {
          FeedbackSystem.showInfo(context, _taskShareMissingServiceMessage);
          return;
        }
        final CalendarFragmentShareDecision decision =
            const CalendarFragmentPolicy().decisionForChat(
          chat: selected,
          roomState: xmppService.roomStateFor(selected.jid),
        );
        if (!decision.canWrite) {
          FeedbackSystem.showInfo(context, _taskShareDeniedMessage);
          return;
        }
        await xmppService.sendMessage(
          jid: selected.jid,
          text: shareText,
          encryptionProtocol: selected.encryptionProtocol,
          calendarTaskIcs: widget.task,
          calendarTaskIcsReadOnly: readOnly,
          chatType: selected.type,
        );
        if (!readOnly) {
          await _linkSharedTask(selected);
        }
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on Exception {
      if (mounted) {
        FeedbackSystem.showError(context, _taskShareSendFailureMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _linkSharedTask(Chat chat) async {
    if (!chat.supportsChatCalendar) {
      return;
    }
    final CalendarBloc? calendarBloc = _maybeReadCalendarBloc(context);
    if (calendarBloc == null) {
      return;
    }
    final String taskId = widget.task.id.trim();
    if (taskId.isEmpty) {
      return;
    }
    final String chatStorageId = chatCalendarStorageId(chat.jid);
    final Set<String> storageIds = <String>{calendarBloc.id, chatStorageId};
    if (storageIds.length < 2) {
      return;
    }
    await CalendarLinkedTaskRegistry.instance.addLinks(
      taskId: taskId,
      storageIds: storageIds,
    );
  }
}

class _TaskShareSectionLabel extends StatelessWidget {
  const _TaskShareSectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = context.textTheme.muted.copyWith(
      fontSize: _taskShareLabelFontSize,
      letterSpacing: _taskShareLabelLetterSpacing,
    );
    return Text(text.toUpperCase(), style: style);
  }
}

class _TaskShareEditAccessToggle extends StatelessWidget {
  const _TaskShareEditAccessToggle({
    required this.value,
    required this.isEnabled,
    required this.hint,
    required this.onChanged,
  });

  final bool value;
  final bool isEnabled;
  final String hint;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextStyle hintStyle = context.textTheme.small.copyWith(
      color: context.colorScheme.mutedForeground,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShadSwitch(
          label: const Text(_taskShareReadOnlyLabel),
          value: value,
          onChanged: isEnabled ? onChanged : null,
        ),
        const SizedBox(height: _taskShareSectionGap),
        Text(hint, style: hintStyle),
      ],
    );
  }
}

class _TaskShareActionRow extends StatelessWidget {
  const _TaskShareActionRow({
    required this.isBusy,
    required this.onPressed,
    required this.label,
  });

  final bool isBusy;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    const spinner = SizedBox(
      width: _taskShareHeaderIconSize,
      height: _taskShareHeaderIconSize,
      child: CircularProgressIndicator(
        strokeWidth: _taskShareProgressStrokeWidth,
      ),
    );
    return Align(
      alignment: Alignment.centerRight,
      child: ShadButton(
        size: ShadButtonSize.sm,
        onPressed: isBusy ? null : onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ButtonSpinnerSlot(
              isVisible: isBusy,
              spinner: spinner,
              slotSize: _taskShareHeaderIconSize,
              gap: _taskShareSectionGap,
              duration: baseAnimationDuration,
            ),
            if (!isBusy) ...[
              const Icon(LucideIcons.send, size: _taskShareHeaderIconSize),
              const SizedBox(width: _taskShareSectionGap),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _TaskShareEmptyMessage extends StatelessWidget {
  const _TaskShareEmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _taskShareSectionGap),
      child: Text(
        message,
        style: context.textTheme.small.copyWith(
          color: context.colorScheme.mutedForeground,
        ),
      ),
    );
  }
}

Future<EmailAttachment?> _buildCalendarTaskAttachment(CalendarTask task) async {
  try {
    const CalendarTransferService transferService = CalendarTransferService();
    final File file = await transferService.exportTaskIcs(task: task);
    CalendarTransferService.scheduleCleanup(file);
    final int sizeBytes = await file.length();
    return EmailAttachment(
      path: file.path,
      fileName: p.basename(file.path),
      sizeBytes: sizeBytes,
      mimeType: _taskShareIcsMimeType,
    );
  } on Exception {
    return null;
  }
}

XmppService? _maybeReadXmppService(BuildContext context) {
  try {
    return RepositoryProvider.of<XmppService>(context, listen: false);
  } on FlutterError {
    return null;
  }
}

CalendarBloc? _maybeReadCalendarBloc(BuildContext context) {
  try {
    return context.read<CalendarBloc>();
  } on FlutterError {
    return null;
  }
}
