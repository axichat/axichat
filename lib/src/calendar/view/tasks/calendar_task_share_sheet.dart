// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/shell/feedback_system.dart';
import 'package:axichat/src/calendar/view/shell/calendar_modal_scope.dart';
import 'package:axichat/src/calendar/view/tasks/task_form_section.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show LucideIcons;

Future<void> showCalendarTaskShareSheet({
  required BuildContext context,
  required CalendarTask task,
}) async {
  final l10n = context.l10n;
  final BuildContext modalContext = context.calendarModalContext;
  final locate = modalContext.read;
  final List<Chat> chats = locate<ChatsCubit>().state.items ?? const <Chat>[];
  final List<Chat> available = chats
      .where((chat) => chat.type != ChatType.note)
      .toList(growable: false);
  if (available.isEmpty) {
    FeedbackSystem.showInfo(context, l10n.calendarTaskShareMissingChats);
    return;
  }
  final result = await showAdaptiveBottomSheet<bool>(
    context: modalContext,
    isScrollControlled: true,
    bottomSafeAreaBehavior: context.calendarSheetBottomSafeAreaBehavior,
    surfacePadding: EdgeInsets.zero,
    builder: (sheetContext) => CalendarTaskShareSheet(
      task: task,
      availableChats: available,
      locate: locate,
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
    required this.locate,
  });

  final CalendarTask task;
  final List<Chat> availableChats;
  final T Function<T>() locate;

  @override
  State<CalendarTaskShareSheet> createState() => _CalendarTaskShareSheetState();
}

class _CalendarTaskShareSheetState extends State<CalendarTaskShareSheet> {
  List<ComposerRecipient> _recipients = <ComposerRecipient>[];
  bool _isSending = false;
  final TextEditingController _bodyController = TextEditingController();
  final Object _recipientTextInputTapRegionGroup = Object();

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
    final rosterItems =
        context.read<RosterCubit>().state.items ??
        (context.read<RosterCubit>()[RosterCubit.itemsCacheKey]
            as List<RosterItem>?) ??
        const <RosterItem>[];
    final chatsSelfJid = widget.locate<ChatsCubit>().selfJid;
    final profileJid = context.watch<ProfileCubit>().state.jid;
    final resolvedProfileJid = profileJid.trim();
    final String? selfJid = resolvedProfileJid.isNotEmpty
        ? resolvedProfileJid
        : null;
    final selfIdentity = SelfAvatar(
      jid: selfJid,
      avatar: Avatar.tryParseOrNull(
        path: context.watch<ProfileCubit>().state.avatarPath,
        hash: null,
      ),
      hydrating: context.watch<ProfileCubit>().state.avatarHydrating,
    );
    const int messageMinLines = 2;
    const int messageMaxLines = 4;
    final EdgeInsets messageContentPadding = EdgeInsets.symmetric(
      horizontal: context.spacing.m,
      vertical: context.spacing.m,
    );
    final header = AxiSheetHeader(
      title: Text(l10n.calendarTaskShareTitle),
      subtitle: Text(l10n.calendarTaskShareSubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    return AxiSheetScaffold.sections(
      header: header,
      footer: widget.availableChats.isEmpty
          ? null
          : AxiSheetActions(
              children: [
                _TaskShareActionRow(
                  isBusy: _isSending,
                  onPressed: _handleSharePressed,
                  label: l10n.commonSend,
                ),
              ],
            ),
      sections: [
        if (widget.availableChats.isEmpty)
          AxiSheetSection(
            child: _TaskShareEmptyMessage(
              message: l10n.calendarTaskShareMissingChats,
            ),
          )
        else ...[
          AxiSheetSection.edge(
            child: BlocSelector<ChatsCubit, ChatsState, List<String>>(
              bloc: widget.locate<ChatsCubit>(),
              selector: (state) => state.recipientAddressSuggestions,
              builder: (context, recipientAddressSuggestions) =>
                  RecipientChipsBar(
                    recipients: _recipients,
                    availableChats: widget.availableChats,
                    rosterItems: rosterItems,
                    databaseSuggestionAddresses: recipientAddressSuggestions,
                    selfJid: chatsSelfJid,
                    selfIdentity: selfIdentity,
                    latestStatuses: const {},
                    collapsedByDefault: false,
                    allowAddressTargets: true,
                    showSuggestionsWhenEmpty: true,
                    horizontalPadding: 0,
                    tapRegionGroup: _recipientTextInputTapRegionGroup,
                    onRecipientAdded: _handleRecipientAdded,
                    onRecipientRemoved: _handleRecipientRemoved,
                  ),
            ),
          ),
          AxiSheetSection(
            child: TaskDescriptionField(
              controller: _bodyController,
              hintText: l10n.calendarDescriptionHint,
              minLines: messageMinLines,
              maxLines: messageMaxLines,
              contentPadding: messageContentPadding,
              groupId: _recipientTextInputTapRegionGroup,
            ),
          ),
        ],
      ],
    );
  }

  bool _handleRecipientAdded(Contact target) {
    if (_recipients.any((recipient) => recipient.key == target.key)) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    setState(() {
      _recipients = List<ComposerRecipient>.from(_recipients)
        ..add(ComposerRecipient(target: target));
    });
    return true;
  }

  void _handleRecipientRemoved(String key) {
    if (!mounted) return;
    setState(() {
      _recipients = _recipients
          .where((recipient) => recipient.key != key)
          .toList(growable: false);
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
    final List<Contact> targets = includedRecipients
        .map((recipient) => recipient.target)
        .toList(growable: false);
    final completer = Completer<CalendarShareResult>();
    context.read<CalendarBloc>().add(
      CalendarEvent.taskShareRequested(
        task: widget.task,
        recipients: targets,
        shareText: shareText,
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
          break;
        case CalendarShareFailure.permissionDenied:
          FeedbackSystem.showInfo(
            context,
            context.l10n.calendarTaskShareDenied,
          );
          break;
        case CalendarShareFailure.attachmentFailed:
        case CalendarShareFailure.sendFailed:
        case null:
          FeedbackSystem.showError(
            context,
            context.l10n.calendarTaskShareSendFailed,
          );
          break;
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
    return AxiButton.primary(
      onPressed: isBusy ? null : onPressed,
      loading: isBusy,
      widthBehavior: AxiButtonWidth.fit,
      leading: Icon(LucideIcons.send, size: context.sizing.iconButtonIconSize),
      child: Text(label),
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
