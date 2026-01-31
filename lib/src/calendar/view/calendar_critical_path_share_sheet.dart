// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/calendar_fragment_policy.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_modal_scope.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart' show ComposerRecipient;
import 'package:axichat/src/chat/view/recipient_chips_bar.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _criticalPathShareHeaderIconSize = 18.0;
const double _criticalPathShareProgressStrokeWidth = 2.0;

Future<void> showCalendarCriticalPathShareSheet({
  required BuildContext context,
  required CalendarCriticalPath path,
  required List<CalendarTask> tasks,
  Chat? initialChat,
}) async {
  final List<Chat> chats =
      context.read<ChatsCubit>().state.items ?? const <Chat>[];
  final List<Chat> available =
      chats.where((chat) => chat.supportsChatCalendar).toList(growable: false);
  if (available.isEmpty) {
    FeedbackSystem.showInfo(
      context,
      context.l10n.calendarCriticalPathShareMissingChats,
    );
    return;
  }
  final BuildContext modalContext = context.calendarModalContext;
  final result = await showAdaptiveBottomSheet<bool>(
    context: modalContext,
    isScrollControlled: true,
    surfacePadding: EdgeInsets.zero,
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
  FeedbackSystem.showSuccess(
    context,
    context.l10n.calendarCriticalPathShareSuccess,
  );
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
  List<ComposerRecipient> _recipients = <ComposerRecipient>[];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final Chat? initialChat = widget.initialChat ??
        (widget.availableChats.isEmpty ? null : widget.availableChats.first);
    if (initialChat != null) {
      _recipients = <ComposerRecipient>[
        ComposerRecipient(
          target: FanOutTarget.chat(
            chat: initialChat,
            shareSignatureEnabled: initialChat.shareSignatureEnabled ??
                context.read<SettingsCubit>().state.shareTokenSignatureEnabled,
          ),
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final rosterItems =
        context.watch<RosterCubit>().state.items ?? const <RosterItem>[];
    final header = AxiSheetHeader(
      title: Text(context.l10n.calendarCriticalPathShareTitle),
      subtitle: Text(context.l10n.calendarCriticalPathShareSubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    return AxiSheetScaffold.scroll(
      header: header,
      bodyPadding: EdgeInsets.zero,
      children: [
        Padding(
          padding: _criticalPathShareContentPadding(context),
          child: _CriticalPathShareSectionLabel(
            text: context.l10n.calendarCriticalPathShareTargetLabel,
          ),
        ),
        if (widget.availableChats.isEmpty)
          Padding(
            padding: _criticalPathShareContentPadding(context),
            child: _CriticalPathShareEmptyMessage(
              message: context.l10n.calendarCriticalPathShareMissingChats,
            ),
          )
        else
          RecipientChipsBar(
            recipients: _recipients,
            availableChats: widget.availableChats,
            rosterItems: rosterItems,
            latestStatuses: const {},
            collapsedByDefault: false,
            allowAddressTargets: false,
            showSuggestionsWhenEmpty: true,
            onRecipientAdded: _handleRecipientAdded,
            onRecipientRemoved: _handleRecipientRemoved,
            onRecipientToggled: _handleRecipientToggled,
          ),
        SizedBox(height: context.spacing.m),
        Padding(
          padding: _criticalPathShareContentPadding(context),
          child: _CriticalPathShareActionRow(
            isBusy: _isSending,
            onPressed: _handleSharePressed,
            label: context.l10n.calendarCriticalPathShareButtonLabel,
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
      FeedbackSystem.showInfo(
        context,
        context.l10n.calendarCriticalPathShareMissingRecipient,
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _recipients = <ComposerRecipient>[ComposerRecipient(target: target)];
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

  Future<void> _handleSharePressed() async {
    final selected = _selectedChat;
    if (selected == null) {
      FeedbackSystem.showInfo(
        context,
        context.l10n.calendarCriticalPathShareMissingRecipient,
      );
      return;
    }
    if (_isSending) {
      return;
    }
    setState(() => _isSending = true);
    try {
      final CalendarFragment fragment = _buildFragment();
      final String shareText =
          CalendarFragmentFormatter(context.l10n).describe(fragment).trim();
      final completer = Completer<CalendarShareResult>();
      context.read<CalendarBloc>().add(
            CalendarEvent.criticalPathShareRequested(
              fragment: fragment,
              recipient: selected,
              shareText: shareText,
              completer: completer,
            ),
          );
      final result = await completer.future;
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
            context.l10n.calendarCriticalPathShareMissingService,
          );
        case CalendarShareFailure.permissionDenied:
          FeedbackSystem.showInfo(
            context,
            context.l10n.calendarCriticalPathShareDenied,
          );
        case CalendarShareFailure.attachmentFailed:
        case CalendarShareFailure.sendFailed:
        case null:
          FeedbackSystem.showError(
            context,
            context.l10n.calendarCriticalPathShareFailed,
          );
      }
    } catch (_) {
      if (mounted) {
        FeedbackSystem.showError(
          context,
          context.l10n.calendarCriticalPathShareFailed,
        );
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
    return CalendarFragment.criticalPath(path: path, tasks: widget.tasks);
  }
}

class _CriticalPathShareSectionLabel extends StatelessWidget {
  const _CriticalPathShareSectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.textTheme.sectionLabelM,
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
    final spinnerColor = context.colorScheme.primaryForeground;
    final spinner = SizedBox(
      width: _criticalPathShareHeaderIconSize,
      height: _criticalPathShareHeaderIconSize,
      child: CircularProgressIndicator(
        strokeWidth: _criticalPathShareProgressStrokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
      ),
    );
    return Align(
      alignment: Alignment.centerRight,
      child: ShadButton(
        size: ShadButtonSize.sm,
        onPressed: () {
          if (isBusy) {
            return;
          }
          onPressed();
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ButtonSpinnerSlot(
              isVisible: isBusy,
              spinner: spinner,
              slotSize: _criticalPathShareHeaderIconSize,
              gap: context.spacing.m,
              duration: baseAnimationDuration,
            ),
            if (!isBusy) ...[
              const Icon(
                LucideIcons.share2,
                size: _criticalPathShareHeaderIconSize,
              ),
              SizedBox(width: context.spacing.m),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}

EdgeInsets _criticalPathShareContentPadding(BuildContext context) =>
    EdgeInsets.symmetric(horizontal: context.spacing.m);

class _CriticalPathShareEmptyMessage extends StatelessWidget {
  const _CriticalPathShareEmptyMessage({required this.message});

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
