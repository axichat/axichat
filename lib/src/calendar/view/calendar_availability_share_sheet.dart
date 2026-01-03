// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:animations/animations.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_availability_share_state.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_preset_store.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/utils/calendar_fragment_policy.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_free_busy_editor.dart';
import 'package:axichat/src/calendar/view/widgets/schedule_range_fields.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';

const int _availabilityDefaultRangeDays = 7;
const int _availabilityRecipientPageSize = 20;
const int _availabilityPresetMaxCount = 5;
const double _availabilitySheetSectionSpacing = 16.0;
const double _availabilitySheetSectionGap = 8.0;
const double _availabilitySheetTileGap = 12.0;
const double _availabilitySheetHeaderIconSize = 18.0;
const double _availabilityChatAvatarSize = 36.0;
const double _availabilitySheetProgressStrokeWidth = 2.0;
const double _availabilitySheetLabelLetterSpacing = 0.4;
const double _availabilityChatTilePaddingHorizontal = 16.0;
const double _availabilityChatTilePaddingVertical = 8.0;
const double _availabilityPresetChipSpacing = 8.0;
const double _availabilityRecipientSearchHeight = 48.0;
const double _availabilityRecipientChipSpacing = 8.0;
const String _availabilityShareTitle = 'Share availability';
const String _availabilityShareSubtitle =
    'Pick a range, then edit for privacy or share.';
const String _availabilityShareChatSubtitle =
    'Pick a range to share in this chat.';
const String _availabilityShareRangeLabel = 'Range';
const String _availabilitySharePreviewLabel = 'Preview';
const String _availabilitySharePreviewEmptyLabel = 'Select a range to preview.';
const String _availabilityShareEditLabel = 'Edit for privacy';
const String _availabilityShareShareLabel = 'Share';
const String _availabilityShareSendLabel = 'Send';
const String _availabilityShareRecipientsLabel = 'Recipients';
const String _availabilityShareRecipientsHint = 'Search contacts';
const String _availabilityShareRecipientsEmptyLabel =
    'No contacts match your search.';
const String _availabilityShareRecipientsRequiredMessage =
    'Select at least one recipient.';
const String _availabilityShareMissingChatsMessage =
    'No eligible chats available.';
const String _availabilityShareLockedChatUnavailableMessage =
    'This chat cannot receive availability shares.';
const String _availabilityShareMissingJidMessage =
    'Calendar sharing is unavailable.';
const String _availabilityShareInvalidRangeMessage =
    'Select a valid range to share.';
const String _availabilityShareSuccessMessage = 'Availability shared.';
const String _availabilityShareFailureMessage = 'Failed to share availability.';
const String _availabilitySharePartialFailureMessage =
    'Some shares failed to send.';
const String _availabilityShareOwnerFallback = 'owner';
const String _availabilitySharePresetLabel = 'Recent sheets';
const String _availabilitySharePresetEmptyLabel = 'No recent sheets yet.';
const String _availabilityShareLoadMoreLabel = 'Load more';
const String _availabilityShareEditHeader = 'Edit free/busy';
const String _availabilityShareEditHint =
    'Drag to resize, split segments, or toggle free/busy.';
const String _availabilityShareBackLabel = 'Back';
const String _availabilityShareDoneLabel = 'Done';
const String _availabilityChatTypeDirectLabel = 'Direct chat';
const String _availabilityChatTypeGroupLabel = 'Group chat';
const String _availabilityChatTypeNoteLabel = 'Notes';

const EdgeInsets _availabilityChatTilePadding = EdgeInsets.symmetric(
  horizontal: _availabilityChatTilePaddingHorizontal,
  vertical: _availabilityChatTilePaddingVertical,
);

const Uuid _availabilityPresetIdGenerator = Uuid();

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

Future<void> showCalendarAvailabilityShareSheet({
  required BuildContext context,
  required CalendarAvailabilityShareCoordinator coordinator,
  required CalendarAvailabilityShareSource source,
  required CalendarModel model,
  required String ownerJid,
  Chat? initialChat,
  bool lockToChat = false,
}) async {
  final List<Chat> chats =
      context.read<ChatsCubit?>()?.state.items ?? const <Chat>[];
  final Chat? lockedChat = lockToChat ? initialChat : null;
  final bool canLockToChat =
      lockedChat != null && lockedChat.supportsChatCalendar;
  final List<Chat> available = lockToChat
      ? (canLockToChat ? <Chat>[lockedChat] : const <Chat>[])
      : chats
          .where(
              (chat) => chat.supportsChatCalendar && chat.type != ChatType.note)
          .toList(growable: false);
  if (available.isEmpty) {
    FeedbackSystem.showInfo(
      context,
      lockToChat
          ? _availabilityShareLockedChatUnavailableMessage
          : _availabilityShareMissingChatsMessage,
    );
    return;
  }
  final record = await showAdaptiveBottomSheet<CalendarAvailabilityShareRecord>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => CalendarAvailabilityShareSheet(
      coordinator: coordinator,
      source: source,
      model: model,
      ownerJid: ownerJid,
      availableChats: available,
      initialChat: initialChat,
      lockToChat: lockToChat,
    ),
  );
  if (record == null || !context.mounted) {
    return;
  }
  FeedbackSystem.showSuccess(context, _availabilityShareSuccessMessage);
}

enum _AvailabilityShareStep {
  range,
  editor,
  recipients;

  bool get isRange => this == _AvailabilityShareStep.range;
  bool get isEditor => this == _AvailabilityShareStep.editor;
  bool get isRecipients => this == _AvailabilityShareStep.recipients;
}

class CalendarAvailabilityShareSheet extends StatefulWidget {
  const CalendarAvailabilityShareSheet({
    super.key,
    required this.coordinator,
    required this.source,
    required this.model,
    required this.ownerJid,
    required this.availableChats,
    required this.lockToChat,
    this.initialChat,
  });

  final CalendarAvailabilityShareCoordinator coordinator;
  final CalendarAvailabilityShareSource source;
  final CalendarModel model;
  final String ownerJid;
  final List<Chat> availableChats;
  final bool lockToChat;
  final Chat? initialChat;

  @override
  State<CalendarAvailabilityShareSheet> createState() =>
      _CalendarAvailabilityShareSheetState();
}

class _CalendarAvailabilityShareSheetState
    extends State<CalendarAvailabilityShareSheet> {
  late DateTime? _rangeStart;
  late DateTime? _rangeEnd;
  late CalendarModel _localModel;
  late CalendarAvailabilityPresetStore _presetStore;
  late TextEditingController _searchController;
  List<CalendarFreeBusyInterval> _draftIntervals =
      const <CalendarFreeBusyInterval>[];
  List<CalendarAvailabilityPreset> _presets = <CalendarAvailabilityPreset>[];
  Chat? _selectedChat;
  bool _isSending = false;
  bool _hasCustomDraft = false;
  _AvailabilityShareStep _step = _AvailabilityShareStep.range;
  bool _stepReversing = false;
  int _recipientPageSize = _availabilityRecipientPageSize;
  final Set<String> _selectedRecipientJids = <String>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = _normalizeRangeStart(now);
    _rangeStart = start;
    _rangeEnd = start.add(const Duration(days: _availabilityDefaultRangeDays));
    _localModel = widget.model;
    _presetStore = CalendarAvailabilityPresetStore();
    _presets = _loadPresets();
    _searchController = TextEditingController()..addListener(_handleSearch);
    final Chat? lockedChat = widget.lockToChat ? widget.initialChat : null;
    _selectedChat = lockedChat ??
        (widget.availableChats.isEmpty ? null : widget.availableChats.first);
    if (lockedChat != null) {
      _selectedRecipientJids.add(lockedChat.jid);
    }
    _resetDraftIntervals();
  }

  @override
  void didUpdateWidget(covariant CalendarAvailabilityShareSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) {
      _localModel = widget.model;
      _resetDraftIntervals();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String subtitleText = widget.lockToChat
        ? _availabilityShareChatSubtitle
        : _availabilityShareSubtitle;
    final header = AxiSheetHeader(
      title: const Text(_availabilityShareTitle),
      subtitle: Text(subtitleText),
      onClose: () => Navigator.of(context).maybePop(),
    );
    final Widget stepChild = _step.isRange
        ? _AvailabilityRangeStep(
            rangeStart: _rangeStart,
            rangeEnd: _rangeEnd,
            preview: _previewWidget(),
            presets: _presets,
            onStartChanged: _handleRangeStartChanged,
            onEndChanged: _handleRangeEndChanged,
            onEditPressed: _handleEditPressed,
            onSharePressed: _handleSharePressed,
            onPresetSelected: _handlePresetSelected,
          )
        : _step.isEditor
            ? _AvailabilityEditorStep(
                hint: _availabilityShareEditHint,
                editor: _editorWidget(),
                onBack: _handleBackToRange,
                onDone: _handleDoneEditing,
              )
            : _AvailabilityRecipientsStep(
                queryController: _searchController,
                recipients: _visibleRecipients(),
                selectedJids: _selectedRecipientJids,
                isBusy: _isSending,
                canLoadMore: _canLoadMoreRecipients(),
                onLoadMore: _handleLoadMoreRecipients,
                onToggleRecipient: _handleRecipientToggled,
                onBack: _handleBackToRange,
                onSend: _handleSendPressed,
              );
    return AxiSheetScaffold.scroll(
      header: header,
      children: [
        PageTransitionSwitcher(
          duration: baseAnimationDuration,
          reverse: _stepReversing,
          transitionBuilder: (child, primaryAnimation, secondaryAnimation) =>
              SharedAxisTransition(
            animation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.horizontal,
            child: child,
          ),
          child: KeyedSubtree(
            key: ValueKey<_AvailabilityShareStep>(_step),
            child: stepChild,
          ),
        ),
      ],
    );
  }

  Widget _previewWidget() {
    final DateTime? start = _rangeStart;
    final DateTime? end = _rangeEnd;
    if (start == null || end == null || !end.isAfter(start)) {
      return const _AvailabilitySheetEmptyMessage(
        message: _availabilitySharePreviewEmptyLabel,
      );
    }
    return CalendarFreeBusyEditor.preview(
      rangeStart: start,
      rangeEnd: end,
      intervals: _draftIntervals,
      tzid: _resolveTimeZone(_localModel),
    );
  }

  int _stepIndex(_AvailabilityShareStep step) {
    return switch (step) {
      _AvailabilityShareStep.range => 0,
      _AvailabilityShareStep.editor => 1,
      _AvailabilityShareStep.recipients => 2,
    };
  }

  void _updateStep(_AvailabilityShareStep next) {
    if (_step == next) {
      return;
    }
    final int currentIndex = _stepIndex(_step);
    final int nextIndex = _stepIndex(next);
    setState(() {
      _stepReversing = nextIndex < currentIndex;
      _step = next;
    });
  }

  Widget _editorWidget() {
    final DateTime? start = _rangeStart;
    final DateTime? end = _rangeEnd;
    if (start == null || end == null || !end.isAfter(start)) {
      return const _AvailabilitySheetEmptyMessage(
        message: _availabilitySharePreviewEmptyLabel,
      );
    }
    return CalendarFreeBusyEditor(
      rangeStart: start,
      rangeEnd: end,
      intervals: _draftIntervals,
      tzid: _resolveTimeZone(_localModel),
      onIntervalsChanged: _handleDraftIntervalsChanged,
    );
  }

  void _handleSearch() {
    setState(() {
      _recipientPageSize = _availabilityRecipientPageSize;
    });
  }

  void _handleRangeStartChanged(DateTime? value) {
    setState(() {
      _rangeStart = value;
      final end = _rangeEnd;
      if (value != null && end != null && !end.isAfter(value)) {
        _rangeEnd =
            value.add(const Duration(days: _availabilityDefaultRangeDays));
      }
      _hasCustomDraft = false;
      _resetDraftIntervals();
    });
  }

  void _handleRangeEndChanged(DateTime? value) {
    setState(() {
      _rangeEnd = value;
      _hasCustomDraft = false;
      _resetDraftIntervals();
    });
  }

  void _handleEditPressed() {
    _updateStep(_AvailabilityShareStep.editor);
  }

  void _handleSharePressed() {
    if (widget.lockToChat) {
      _handleSendPressed();
      return;
    }
    _updateStep(_AvailabilityShareStep.recipients);
  }

  void _handleBackToRange() {
    _updateStep(_AvailabilityShareStep.range);
  }

  void _handleDoneEditing() {
    setState(() {
      _hasCustomDraft = true;
    });
    _updateStep(_AvailabilityShareStep.range);
  }

  void _handleDraftIntervalsChanged(List<CalendarFreeBusyInterval> intervals) {
    setState(() {
      _draftIntervals = intervals;
      _hasCustomDraft = true;
    });
  }

  void _handlePresetSelected(CalendarAvailabilityPreset preset) {
    setState(() {
      _rangeStart = preset.overlay.rangeStart.value;
      _rangeEnd = preset.overlay.rangeEnd.value;
      _draftIntervals = preset.overlay.intervals;
      _hasCustomDraft = true;
    });
    _updateStep(_AvailabilityShareStep.range);
  }

  void _handleRecipientToggled(Chat chat) {
    setState(() {
      if (_selectedRecipientJids.contains(chat.jid)) {
        _selectedRecipientJids.remove(chat.jid);
      } else {
        _selectedRecipientJids.add(chat.jid);
      }
    });
  }

  void _handleLoadMoreRecipients() {
    setState(() {
      _recipientPageSize += _availabilityRecipientPageSize;
    });
  }

  List<Chat> _visibleRecipients() {
    final String query = _searchController.text.trim().toLowerCase();
    final List<Chat> base = widget.availableChats
        .where((chat) => chat.type != ChatType.note)
        .toList(growable: false);
    final List<Chat> filtered = query.isEmpty
        ? base
        : base
            .where((chat) =>
                chat.displayName.toLowerCase().contains(query) ||
                chat.jid.toLowerCase().contains(query))
            .toList(growable: false);
    final int capped = math.min(filtered.length, _recipientPageSize);
    return filtered.take(capped).toList(growable: false);
  }

  bool _canLoadMoreRecipients() {
    final String query = _searchController.text.trim().toLowerCase();
    final int total = widget.availableChats
        .where((chat) => chat.type != ChatType.note)
        .where((chat) => query.isEmpty
            ? true
            : chat.displayName.toLowerCase().contains(query) ||
                chat.jid.toLowerCase().contains(query))
        .length;
    return _recipientPageSize < total;
  }

  Future<void> _handleSendPressed() async {
    if (_isSending) {
      return;
    }
    final DateTime? start = _rangeStart;
    final DateTime? end = _rangeEnd;
    if (start == null || end == null || !end.isAfter(start)) {
      FeedbackSystem.showError(context, _availabilityShareInvalidRangeMessage);
      return;
    }
    final String? ownerJid = _resolveOwnerJid(_selectedChat);
    if (ownerJid == null || ownerJid.isEmpty) {
      FeedbackSystem.showError(context, _availabilityShareMissingJidMessage);
      return;
    }
    final List<Chat> recipients = widget.lockToChat
        ? (_selectedChat == null ? const <Chat>[] : <Chat>[_selectedChat!])
        : widget.availableChats
            .where((chat) => _selectedRecipientJids.contains(chat.jid))
            .toList(growable: false);
    if (recipients.isEmpty) {
      FeedbackSystem.showError(
        context,
        _availabilityShareRecipientsRequiredMessage,
      );
      return;
    }
    setState(() {
      _isSending = true;
    });
    final String? tzid = _resolveTimeZone(_localModel);
    final CalendarAvailabilityOverlay? customOverlay =
        _hasCustomDraft ? _buildCustomOverlay(ownerJid, tzid) : null;
    CalendarAvailabilityShareRecord? latestRecord;
    var failures = 0;
    try {
      for (final Chat chat in recipients) {
        final String resolvedOwner = _resolveOwnerJid(chat) ?? ownerJid;
        final CalendarAvailabilityShareRecord? record =
            await widget.coordinator.createShare(
          source: widget.source,
          model: _localModel,
          ownerJid: resolvedOwner,
          chatJid: chat.jid,
          chatType: chat.type,
          rangeStart: CalendarDateTime(value: start, tzid: tzid),
          rangeEnd: CalendarDateTime(value: end, tzid: tzid),
          overrideOverlay: customOverlay,
          lockOverlay: _hasCustomDraft,
        );
        if (record == null) {
          failures += 1;
          continue;
        }
        latestRecord = record;
      }
      if (!mounted) {
        return;
      }
      if (latestRecord == null) {
        FeedbackSystem.showError(context, _availabilityShareFailureMessage);
        return;
      }
      if (failures > 0) {
        FeedbackSystem.showInfo(
          context,
          _availabilitySharePartialFailureMessage,
        );
      }
      await _savePresetIfNeeded(customOverlay ?? latestRecord.overlay);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(latestRecord);
    } catch (_) {
      if (!mounted) {
        return;
      }
      FeedbackSystem.showError(context, _availabilityShareFailureMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  CalendarAvailabilityOverlay? _buildCustomOverlay(
    String ownerJid,
    String? tzid,
  ) {
    final DateTime? start = _rangeStart;
    final DateTime? end = _rangeEnd;
    if (start == null || end == null || !end.isAfter(start)) {
      return null;
    }
    final String resolvedOwner =
        ownerJid.isEmpty ? _availabilityShareOwnerFallback : ownerJid;
    return CalendarAvailabilityOverlay(
      owner: resolvedOwner,
      rangeStart: CalendarDateTime(value: start, tzid: tzid),
      rangeEnd: CalendarDateTime(value: end, tzid: tzid),
      intervals: _draftIntervals,
      isRedacted: false,
    );
  }

  void _resetDraftIntervals() {
    final DateTime? start = _rangeStart;
    final DateTime? end = _rangeEnd;
    if (start == null || end == null || !end.isAfter(start)) {
      _draftIntervals = const <CalendarFreeBusyInterval>[];
      return;
    }
    final String? tzid = _resolveTimeZone(_localModel);
    final CalendarAvailabilityOverlay base = CalendarAvailabilityOverlay(
      owner: _availabilityShareOwnerFallback,
      rangeStart: CalendarDateTime(value: start, tzid: tzid),
      rangeEnd: CalendarDateTime(value: end, tzid: tzid),
      isRedacted: false,
    );
    final CalendarAvailabilityOverlay overlay =
        deriveAvailabilityOverlay(model: _localModel, base: base);
    _draftIntervals = overlay.intervals
        .map(
          (interval) => interval.copyWith(
            type: interval.type.isFree
                ? CalendarFreeBusyType.free
                : CalendarFreeBusyType.busy,
          ),
        )
        .toList(growable: false);
  }

  List<CalendarAvailabilityPreset> _loadPresets() {
    final records = _presetStore.readAll();
    final List<CalendarAvailabilityPreset> presets = records.values.toList();
    presets.sort(
      (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return presets.take(_availabilityPresetMaxCount).toList(growable: false);
  }

  Future<void> _savePresetIfNeeded(CalendarAvailabilityOverlay overlay) async {
    final CalendarAvailabilityPreset preset = CalendarAvailabilityPreset(
      id: _availabilityPresetIdGenerator.v4(),
      overlay: overlay,
      updatedAt: DateTime.now(),
    );
    final records = _presetStore.readAll()..[preset.id] = preset;
    final List<CalendarAvailabilityPreset> sorted = records.values.toList()
      ..sort(
        (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
    final Map<String, CalendarAvailabilityPreset> trimmed = {
      for (final preset in sorted.take(_availabilityPresetMaxCount))
        preset.id: preset,
    };
    await _presetStore.writeAll(trimmed);
    setState(() {
      _presets =
          sorted.take(_availabilityPresetMaxCount).toList(growable: false);
    });
  }

  String? _resolveOwnerJid(Chat? chat) {
    if (chat == null) {
      return null;
    }
    final String ownerJid = widget.ownerJid.trim();
    if (ownerJid.isEmpty) {
      return null;
    }
    if (chat.type != ChatType.groupChat) {
      return ownerJid;
    }
    final XmppService? xmppService = _maybeReadXmppService(context);
    if (xmppService == null) {
      return null;
    }
    final String? occupantId =
        xmppService.roomStateFor(chat.jid)?.myOccupantId?.trim();
    if (occupantId == null || occupantId.isEmpty) {
      return null;
    }
    return occupantId;
  }
}

class _AvailabilityRangeStep extends StatelessWidget {
  const _AvailabilityRangeStep({
    required this.rangeStart,
    required this.rangeEnd,
    required this.preview,
    required this.presets,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onEditPressed,
    required this.onSharePressed,
    required this.onPresetSelected,
  });

  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final Widget preview;
  final List<CalendarAvailabilityPreset> presets;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final VoidCallback onEditPressed;
  final VoidCallback onSharePressed;
  final ValueChanged<CalendarAvailabilityPreset> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AvailabilitySheetSectionLabel(
            text: _availabilityShareRangeLabel),
        ScheduleRangeFields(
          start: rangeStart,
          end: rangeEnd,
          onStartChanged: onStartChanged,
          onEndChanged: onEndChanged,
        ),
        const SizedBox(height: _availabilitySheetSectionSpacing),
        const _AvailabilitySheetSectionLabel(
            text: _availabilitySharePreviewLabel),
        preview,
        const SizedBox(height: _availabilitySheetSectionSpacing),
        _AvailabilityPresetSection(
          presets: presets,
          onPresetSelected: onPresetSelected,
        ),
        const SizedBox(height: _availabilitySheetSectionSpacing),
        _AvailabilityDualActionRow(
          primaryLabel: _availabilityShareEditLabel,
          secondaryLabel: _availabilityShareShareLabel,
          onPrimaryPressed: onEditPressed,
          onSecondaryPressed: onSharePressed,
        ),
      ],
    );
  }
}

class _AvailabilityEditorStep extends StatelessWidget {
  const _AvailabilityEditorStep({
    required this.hint,
    required this.editor,
    required this.onBack,
    required this.onDone,
  });

  final String hint;
  final Widget editor;
  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AvailabilitySheetSectionLabel(
            text: _availabilityShareEditHeader),
        Text(
          hint,
          style: context.textTheme.small.copyWith(
            color: context.colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: _availabilitySheetSectionSpacing),
        editor,
        const SizedBox(height: _availabilitySheetSectionSpacing),
        _AvailabilityDualActionRow(
          primaryLabel: _availabilityShareBackLabel,
          secondaryLabel: _availabilityShareDoneLabel,
          onPrimaryPressed: onBack,
          onSecondaryPressed: onDone,
        ),
      ],
    );
  }
}

class _AvailabilityRecipientsStep extends StatelessWidget {
  const _AvailabilityRecipientsStep({
    required this.queryController,
    required this.recipients,
    required this.selectedJids,
    required this.isBusy,
    required this.canLoadMore,
    required this.onLoadMore,
    required this.onToggleRecipient,
    required this.onBack,
    required this.onSend,
  });

  final TextEditingController queryController;
  final List<Chat> recipients;
  final Set<String> selectedJids;
  final bool isBusy;
  final bool canLoadMore;
  final VoidCallback onLoadMore;
  final ValueChanged<Chat> onToggleRecipient;
  final VoidCallback onBack;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final List<Widget> recipientTiles = recipients
        .map(
          (chat) => _AvailabilityRecipientTile(
            chat: chat,
            isSelected: selectedJids.contains(chat.jid),
            onToggle: () => onToggleRecipient(chat),
          ),
        )
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AvailabilitySheetSectionLabel(
          text: _availabilityShareRecipientsLabel,
        ),
        SizedBox(
          height: _availabilityRecipientSearchHeight,
          child: AxiTextField(
            controller: queryController,
            decoration: const InputDecoration(
              prefixIcon: Icon(LucideIcons.search),
              hintText: _availabilityShareRecipientsHint,
            ),
          ),
        ),
        const SizedBox(height: _availabilitySheetSectionGap),
        if (recipientTiles.isEmpty)
          const _AvailabilitySheetEmptyMessage(
            message: _availabilityShareRecipientsEmptyLabel,
          )
        else ...[
          Column(children: recipientTiles),
          if (canLoadMore) ...[
            const SizedBox(height: _availabilityRecipientChipSpacing),
            Align(
              alignment: Alignment.centerLeft,
              child: ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: onLoadMore,
                child: const Text(_availabilityShareLoadMoreLabel),
              ),
            ),
          ],
        ],
        const SizedBox(height: _availabilitySheetSectionSpacing),
        _AvailabilityActionRow(
          isBusy: isBusy,
          label: _availabilityShareSendLabel,
          onBack: onBack,
          onPressed: onSend,
        ),
      ],
    );
  }
}

class _AvailabilitySheetSectionLabel extends StatelessWidget {
  const _AvailabilitySheetSectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _availabilitySheetSectionGap),
      child: Text(
        text,
        style: context.textTheme.small.copyWith(
          fontWeight: FontWeight.w700,
          color: context.colorScheme.mutedForeground,
          letterSpacing: _availabilitySheetLabelLetterSpacing,
        ),
      ),
    );
  }
}

class _AvailabilitySheetEmptyMessage extends StatelessWidget {
  const _AvailabilitySheetEmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _availabilitySheetSectionGap),
      child: Text(
        message,
        style: context.textTheme.small.copyWith(
          color: context.colorScheme.mutedForeground,
        ),
      ),
    );
  }
}

class _AvailabilityPresetSection extends StatelessWidget {
  const _AvailabilityPresetSection({
    required this.presets,
    required this.onPresetSelected,
  });

  final List<CalendarAvailabilityPreset> presets;
  final ValueChanged<CalendarAvailabilityPreset> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = presets
        .map(
          (preset) => _AvailabilityPresetChip(
            preset: preset,
            onPressed: () => onPresetSelected(preset),
          ),
        )
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AvailabilitySheetSectionLabel(
          text: _availabilitySharePresetLabel,
        ),
        if (chips.isEmpty)
          const _AvailabilitySheetEmptyMessage(
            message: _availabilitySharePresetEmptyLabel,
          )
        else
          Wrap(
            spacing: _availabilityPresetChipSpacing,
            runSpacing: _availabilityPresetChipSpacing,
            children: chips,
          ),
      ],
    );
  }
}

class _AvailabilityPresetChip extends StatelessWidget {
  const _AvailabilityPresetChip({
    required this.preset,
    required this.onPressed,
  });

  final CalendarAvailabilityPreset preset;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final DateTime start = preset.overlay.rangeStart.value;
    final DateTime end = preset.overlay.rangeEnd.value;
    final String label =
        '${start.month}/${start.day} - ${end.month}/${end.day}';
    return ShadButton.ghost(
      size: ShadButtonSize.sm,
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _AvailabilityRecipientTile extends StatelessWidget {
  const _AvailabilityRecipientTile({
    required this.chat,
    required this.isSelected,
    required this.onToggle,
  });

  final Chat chat;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AxiListTile(
          leading: AxiAvatar(
            jid: chat.jid,
            size: _availabilityChatAvatarSize,
            avatarPath: chat.avatarPath,
            shape: AxiAvatarShape.circle,
          ),
          title: chat.displayName,
          subtitle: chat.type.label,
          selected: isSelected,
          onTap: onToggle,
          contentPadding: _availabilityChatTilePadding,
          actions: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => onToggle(),
            ),
          ],
        ),
        const SizedBox(height: _availabilitySheetTileGap),
      ],
    );
  }
}

class _AvailabilityDualActionRow extends StatelessWidget {
  const _AvailabilityDualActionRow({
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
  });

  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ShadButton.ghost(
          size: ShadButtonSize.sm,
          onPressed: onPrimaryPressed,
          child: Text(primaryLabel),
        ),
        const SizedBox(width: _availabilityRecipientChipSpacing),
        ShadButton(
          size: ShadButtonSize.sm,
          onPressed: onSecondaryPressed,
          child: Text(secondaryLabel),
        ),
      ],
    );
  }
}

class _AvailabilityActionRow extends StatelessWidget {
  const _AvailabilityActionRow({
    required this.isBusy,
    required this.label,
    required this.onBack,
    required this.onPressed,
  });

  final bool isBusy;
  final String label;
  final VoidCallback onBack;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ShadButton.ghost(
          size: ShadButtonSize.sm,
          onPressed: onBack,
          child: const Text(_availabilityShareBackLabel),
        ),
        const SizedBox(width: _availabilityRecipientChipSpacing),
        ShadButton(
          size: ShadButtonSize.sm,
          onPressed: isBusy ? null : onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy)
                const SizedBox(
                  width: _availabilitySheetHeaderIconSize,
                  height: _availabilitySheetHeaderIconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: _availabilitySheetProgressStrokeWidth,
                  ),
                )
              else
                const Icon(
                  LucideIcons.send,
                  size: _availabilitySheetHeaderIconSize,
                ),
              const SizedBox(width: _availabilitySheetSectionGap),
              Text(label),
            ],
          ),
        ),
      ],
    );
  }
}

DateTime _normalizeRangeStart(DateTime now) {
  return DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
  );
}

String? _resolveTimeZone(CalendarModel model) {
  final raw = model.collection?.timeZone?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return raw;
}

extension _ChatTypeLabelX on ChatType {
  String get label => switch (this) {
        ChatType.chat => _availabilityChatTypeDirectLabel,
        ChatType.groupChat => _availabilityChatTypeGroupLabel,
        ChatType.note => _availabilityChatTypeNoteLabel,
      };
}
