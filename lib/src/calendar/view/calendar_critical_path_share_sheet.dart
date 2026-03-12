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
import 'package:axichat/src/chats/view/widgets/transport_aware_avatar.dart';
import 'package:axichat/src/common/ui/keyboard_pop_scope.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<void> showCalendarCriticalPathShareSheet({
  required BuildContext context,
  required CalendarCriticalPath path,
  required List<CalendarTask> tasks,
  Chat? initialChat,
}) async {
  final BuildContext modalContext = context.calendarModalContext;
  final locate = modalContext.read;
  final List<Chat> chats = locate<ChatsCubit>().state.items ?? const <Chat>[];
  final List<Chat> available = chats
      .where((chat) => chat.supportsChatCalendar)
      .toList(growable: false);
  if (available.isEmpty) {
    FeedbackSystem.showInfo(
      context,
      context.l10n.calendarCriticalPathShareMissingChats,
    );
    return;
  }
  final result = await showAdaptiveBottomSheet<bool>(
    context: modalContext,
    isScrollControlled: true,
    preferDialogOnMobile: true,
    surfacePadding: EdgeInsets.zero,
    builder: (sheetContext) => CalendarCriticalPathShareSheet(
      path: path,
      tasks: tasks,
      availableChats: available,
      initialChat: initialChat,
      locate: locate,
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
    required this.locate,
    this.initialChat,
  });

  final CalendarCriticalPath path;
  final List<CalendarTask> tasks;
  final List<Chat> availableChats;
  final T Function<T>() locate;
  final Chat? initialChat;

  @override
  State<CalendarCriticalPathShareSheet> createState() =>
      _CalendarCriticalPathShareSheetState();
}

class _CalendarCriticalPathShareSheetState
    extends State<CalendarCriticalPathShareSheet> {
  List<ComposerRecipient> _recipients = <ComposerRecipient>[];
  bool _isSending = false;
  Chat? _initialChat;
  bool _didInitRecipients = false;

  @override
  void initState() {
    super.initState();
    _initialChat =
        widget.initialChat ??
        (widget.availableChats.isEmpty ? null : widget.availableChats.first);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitRecipients) {
      return;
    }
    _didInitRecipients = true;
    final Chat? initialChat = _initialChat;
    if (initialChat == null) {
      return;
    }
    final bool shareSignatureEnabled =
        initialChat.shareSignatureEnabled ??
        widget.locate<SettingsCubit>().state.shareTokenSignatureEnabled;
    _recipients = <ComposerRecipient>[
      ComposerRecipient(
        target: FanOutTarget.chat(
          chat: initialChat,
          shareSignatureEnabled: shareSignatureEnabled,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
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
    final selfIdentity = SelfIdentitySnapshot(
      selfJid: selfJid,
      avatarPath: context.watch<ProfileCubit>().state.avatarPath,
      avatarLoading: context.watch<ProfileCubit>().state.avatarHydrating,
    );
    final header = AxiSheetHeader(
      title: Text(l10n.calendarCriticalPathShareTitle),
      subtitle: Text(l10n.calendarCriticalPathShareSubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    return AxiSheetScaffold.scroll(
      header: header,
      bodyPadding: EdgeInsets.zero,
      children: [
        Padding(
          padding: _criticalPathShareContentPadding(context),
          child: _CriticalPathShareSectionLabel(
            text: l10n.calendarCriticalPathShareTargetLabel,
          ),
        ),
        BlocSelector<ChatsCubit, ChatsState, List<String>>(
          bloc: widget.locate<ChatsCubit>(),
          selector: (state) => state.recipientAddressSuggestions,
          builder: (context, recipientAddressSuggestions) => RecipientChipsBar(
            recipients: _recipients,
            availableChats: widget.availableChats,
            rosterItems: rosterItems,
            databaseSuggestionAddresses: recipientAddressSuggestions,
            selfJid: chatsSelfJid,
            selfIdentity: selfIdentity,
            latestStatuses: const {},
            collapsedByDefault: false,
            allowAddressTargets: false,
            showSuggestionsWhenEmpty: true,
            horizontalPadding: 0,
            onRecipientAdded: _handleRecipientAdded,
            onRecipientRemoved: _handleRecipientRemoved,
            onRecipientToggled: _handleRecipientToggled,
          ),
        ),
        SizedBox(height: spacing.m),
        Padding(
          padding: _criticalPathShareContentPadding(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AxiButton.outline(
                onPressed: () => closeSheetWithKeyboardDismiss(
                  context,
                  () => Navigator.of(context).maybePop(),
                ),
                child: Text(l10n.commonCancel),
              ),
              SizedBox(width: spacing.s),
              _CriticalPathShareActionRow(
                isBusy: _isSending,
                onPressed: _handleSharePressed,
                label: l10n.commonSend,
              ),
            ],
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
      final String shareText = CalendarFragmentFormatter(
        context.l10n,
      ).describe(fragment).trim();
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
          break;
        case CalendarShareFailure.permissionDenied:
          FeedbackSystem.showInfo(
            context,
            context.l10n.calendarCriticalPathShareDenied,
          );
          break;
        case CalendarShareFailure.attachmentFailed:
        case CalendarShareFailure.sendFailed:
        case null:
          FeedbackSystem.showError(
            context,
            context.l10n.calendarCriticalPathShareFailed,
          );
          break;
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
    final Set<String> availableIds = widget.tasks
        .map((task) => task.id)
        .toSet();
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
    return Text(text.toUpperCase(), style: context.textTheme.sectionLabelM);
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
    return AxiButton.primary(
      onPressed: isBusy ? null : onPressed,
      loading: isBusy,
      widthBehavior: AxiButtonWidth.fit,
      leading: Icon(LucideIcons.send, size: context.sizing.iconButtonIconSize),
      child: Text(label),
    );
  }
}

EdgeInsets _criticalPathShareContentPadding(BuildContext context) =>
    EdgeInsets.symmetric(horizontal: context.spacing.m);
