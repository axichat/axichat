// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_modal_scope.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart' show ComposerRecipient;
import 'package:axichat/src/chat/view/recipient_chips_bar.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const bool _taskShareReadOnlyDefault = true;

Future<void> showCalendarTaskShareSheet({
  required BuildContext context,
  required CalendarTask task,
}) async {
  final l10n = context.l10n;
  final List<Chat> chats =
      context.read<ChatsCubit?>()?.state.items ?? const <Chat>[];
  final List<Chat> available =
      chats.where((chat) => chat.type != ChatType.note).toList(growable: false);
  if (available.isEmpty) {
    FeedbackSystem.showInfo(context, l10n.calendarTaskShareMissingChats);
    return;
  }
  final BuildContext modalContext = context.calendarModalContext;
  final result = await showAdaptiveBottomSheet<bool>(
    context: modalContext,
    isScrollControlled: true,
    surfacePadding: EdgeInsets.zero,
    builder: (sheetContext) => CalendarTaskShareSheet(
      task: task,
      availableChats: available,
    ),
  );
  if (result != true || !context.mounted) {
    return;
  }
  FeedbackSystem.showSuccess(context, l10n.calendarTaskShareSuccess);
}

class CalendarTaskShareSheet extends StatefulWidget {
  const CalendarTaskShareSheet({
    super.key,
    required this.task,
    required this.availableChats,
  });

  final CalendarTask task;
  final List<Chat> availableChats;

  @override
  State<CalendarTaskShareSheet> createState() => _CalendarTaskShareSheetState();
}

class _CalendarTaskShareSheetState extends State<CalendarTaskShareSheet> {
  List<ComposerRecipient> _recipients = <ComposerRecipient>[];
  bool _isSending = false;
  bool _isReadOnly = _taskShareReadOnlyDefault;
  final TextEditingController _bodyController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool isReadOnly = _isReadOnly;
    final String readOnlyHint = isReadOnly
        ? l10n.calendarTaskShareReadOnlyHint
        : l10n.calendarTaskShareEditableHint;
    const int messageMinLines = 2;
    const int messageMaxLines = 4;
    const EdgeInsets messageContentPadding = EdgeInsets.symmetric(
      horizontal: calendarGutterLg,
      vertical: calendarGutterMd,
    );
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);
    final spacing = context.spacing;
    final header = AxiSheetHeader(
      title: Text(l10n.calendarTaskShareTitle),
      subtitle: Text(l10n.calendarTaskShareSubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    return AxiSheetScaffold.scroll(
      header: header,
      bodyPadding: EdgeInsets.only(bottom: viewInsets.bottom),
      children: [
        if (widget.availableChats.isEmpty)
          Padding(
            padding: _taskShareContentPadding(context),
            child: _TaskShareEmptyMessage(
              message: l10n.calendarTaskShareMissingChats,
            ),
          )
        else ...[
          RecipientChipsBar(
            recipients: _recipients,
            availableChats: widget.availableChats,
            latestStatuses: const {},
            collapsedByDefault: false,
            allowAddressTargets: true,
            showSuggestionsWhenEmpty: true,
            horizontalPadding: 0,
            onRecipientAdded: _handleRecipientAdded,
            onRecipientRemoved: _handleRecipientRemoved,
            onRecipientToggled: _handleRecipientToggled,
          ),
          SizedBox(height: spacing.m),
          Padding(
            padding: _taskShareContentPadding(context),
            child: TaskDescriptionField(
              controller: _bodyController,
              hintText: l10n.calendarDescriptionHint,
              minLines: messageMinLines,
              maxLines: messageMaxLines,
              contentPadding: messageContentPadding,
            ),
          ),
          SizedBox(height: spacing.m),
          Padding(
            padding: _taskShareContentPadding(context),
            child: _TaskShareEditAccessToggle(
              canEdit: !isReadOnly,
              hint: readOnlyHint,
              onChanged: _handleEditAccessChanged,
            ),
          ),
          SizedBox(height: spacing.m),
          Padding(
            padding: _taskShareContentPadding(context),
            child: _TaskShareActionRow(
              isBusy: _isSending,
              onPressed: _handleSharePressed,
              label: l10n.commonSend,
            ),
          ),
          SizedBox(height: spacing.m),
        ],
      ],
    );
  }

  void _handleRecipientAdded(FanOutTarget target) {
    if (_recipients.any((recipient) => recipient.key == target.key)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _recipients = List<ComposerRecipient>.from(_recipients)
        ..add(ComposerRecipient(target: target));
    });
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

  void _handleEditAccessChanged(bool canEdit) {
    if (!mounted) return;
    setState(() {
      _isReadOnly = !canEdit;
    });
  }

  Future<void> _handleSharePressed() async {
    final List<ComposerRecipient> includedRecipients = _recipients
        .where((recipient) => recipient.included)
        .toList(growable: false);
    if (includedRecipients.isEmpty) {
      FeedbackSystem.showInfo(
        context,
        context.l10n.calendarTaskShareMissingRecipient,
      );
      return;
    }
    if (_isSending) {
      return;
    }
    setState(() => _isSending = true);
    final String shareText = _bodyController.text.trim();
    final bool readOnly = _isReadOnly;
    final List<FanOutTarget> targets = includedRecipients
        .map((recipient) => recipient.target)
        .toList(growable: false);
    final completer = Completer<CalendarShareResult>();
    context.read<CalendarBloc>().add(
          CalendarEvent.taskShareRequested(
            task: widget.task,
            recipients: targets,
            shareText: shareText,
            readOnly: readOnly,
            completer: completer,
          ),
        );
    try {
      final CalendarShareResult result = await completer.future;
      if (!mounted) {
        return;
      }
      if (result.isSuccess) {
        Navigator.of(context).pop(true);
        return;
      }
      switch (result.failure) {
        case CalendarShareFailure.serviceUnavailable:
          FeedbackSystem.showInfo(
            context,
            context.l10n.calendarTaskShareServiceUnavailable,
          );
        case CalendarShareFailure.permissionDenied:
          FeedbackSystem.showInfo(
            context,
            context.l10n.calendarTaskShareDenied,
          );
        case CalendarShareFailure.attachmentFailed:
        case CalendarShareFailure.sendFailed:
        case null:
          FeedbackSystem.showError(
            context,
            context.l10n.calendarTaskShareSendFailed,
          );
      }
    } catch (_) {
      if (mounted) {
        FeedbackSystem.showError(
          context,
          context.l10n.calendarTaskShareSendFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }
}

class _TaskShareEditAccessToggle extends StatelessWidget {
  const _TaskShareEditAccessToggle({
    required this.canEdit,
    required this.hint,
    required this.onChanged,
  });

  final bool canEdit;
  final String hint;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sublabel = canEdit
        ? l10n.calendarTaskShareEditableLabel
        : l10n.calendarTaskShareReadOnlyLabel;
    final TextStyle hintStyle = context.textTheme.small.copyWith(
      color: context.colorScheme.mutedForeground,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadSwitch(
          label: Text(l10n.calendarTaskShareEditAccess),
          sublabel: Text(sublabel),
          value: canEdit,
          onChanged: onChanged,
        ),
        SizedBox(height: context.spacing.s),
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
    return Align(
      alignment: Alignment.centerRight,
      child: AxiButton.primary(
        onPressed: isBusy ? null : onPressed,
        loading: isBusy,
        widthBehavior: AxiButtonWidth.fit,
        leading: Icon(
          LucideIcons.send,
          size: context.sizing.iconButtonIconSize,
        ),
        child: Text(label),
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
      padding: EdgeInsets.symmetric(vertical: context.spacing.s),
      child: Text(
        message,
        style: context.textTheme.small.copyWith(
          color: context.colorScheme.mutedForeground,
        ),
      ),
    );
  }
}

EdgeInsets _taskShareContentPadding(BuildContext context) =>
    EdgeInsets.symmetric(horizontal: context.spacing.m);
