// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:animations/animations.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_availability_share_state.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_preset_store.dart';
import 'package:axichat/src/calendar/utils/calendar_fragment_policy.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_free_busy_editor.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_modal_scope.dart';
import 'package:axichat/src/calendar/view/widgets/schedule_range_fields.dart';
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
import 'package:uuid/uuid.dart';

const int _availabilityDefaultRangeDays = 7;
const int _availabilityPresetMaxCount = 5;
const double _availabilitySheetSectionSpacing = 16.0;
const double _availabilitySheetSectionGap = 8.0;
const EdgeInsets _availabilityRecipientsContentPadding =
    EdgeInsets.symmetric(horizontal: 16);
const double _availabilityEditorPanelGap = 16.0;
const double _availabilityEditorPanelMaxWidth = 420.0;
const bool _calendarUseRootNavigator = false;
const double _availabilityPresetChipSpacing = 8.0;
const double _availabilityRecipientChipSpacing = 8.0;
const double _availabilityShareEditorFallbackHeight = 360.0;
const double _availabilityShareHeaderSpacing = 12.0;
const double _availabilityShareHeaderGap = 4.0;

const Uuid _availabilityPresetIdGenerator = Uuid();

Future<void> showCalendarAvailabilityShareSheet({
  required BuildContext context,
  required CalendarAvailabilityShareSource source,
  required CalendarModel model,
  required String ownerJid,
  Chat? initialChat,
  bool lockToChat = false,
}) async {
  final l10n = context.l10n;
  final List<Chat> chats =
      context.read<ChatsCubit>().state.items ?? const <Chat>[];
  final Chat? lockedChat = lockToChat ? initialChat : null;
  final bool canLockToChat =
      lockedChat != null && lockedChat.supportsChatCalendar;
  final List<Chat> available = lockToChat
      ? (canLockToChat ? <Chat>[lockedChat] : const <Chat>[])
      : chats
          .where(
            (chat) => chat.supportsChatCalendar && chat.type != ChatType.note,
          )
          .toList(growable: false);
  if (available.isEmpty) {
    FeedbackSystem.showInfo(
      context,
      lockToChat
          ? l10n.calendarAvailabilityShareLockedChatUnavailable
          : l10n.calendarAvailabilityShareMissingChats,
    );
    return;
  }
  final BuildContext modalContext = context.calendarModalContext;
  final record =
      await Navigator.of(modalContext).push<CalendarAvailabilityShareRecord>(
    AxiFadePageRoute(
      duration: baseAnimationDuration,
      fullscreenDialog: true,
      builder: (routeContext) => CalendarAvailabilityShareScreen(
        source: source,
        model: model,
        ownerJid: ownerJid,
        availableChats: available,
        initialChat: initialChat,
        lockToChat: lockToChat,
      ),
    ),
  );
  if (record == null || !context.mounted) {
    return;
  }
  FeedbackSystem.showSuccess(context, l10n.calendarAvailabilityShareSuccess);
}

enum _AvailabilityShareStep {
  editor,
  recipients;

  bool get isEditor => this == _AvailabilityShareStep.editor;
  bool get isRecipients => this == _AvailabilityShareStep.recipients;
}

class CalendarAvailabilityShareScreen extends StatefulWidget {
  const CalendarAvailabilityShareScreen({
    super.key,
    required this.source,
    required this.model,
    required this.ownerJid,
    required this.availableChats,
    required this.lockToChat,
    this.initialChat,
  });

  final CalendarAvailabilityShareSource source;
  final CalendarModel model;
  final String ownerJid;
  final List<Chat> availableChats;
  final bool lockToChat;
  final Chat? initialChat;

  @override
  State<CalendarAvailabilityShareScreen> createState() =>
      _CalendarAvailabilityShareScreenState();
}

class _CalendarAvailabilityShareScreenState
    extends State<CalendarAvailabilityShareScreen> {
  late DateTime? _rangeStart;
  late DateTime? _rangeEnd;
  late CalendarModel _localModel;
  late CalendarAvailabilityPresetStore _presetStore;
  List<CalendarFreeBusyInterval> _draftIntervals =
      const <CalendarFreeBusyInterval>[];
  List<CalendarAvailabilityPreset> _presets = <CalendarAvailabilityPreset>[];
  Chat? _selectedChat;
  bool _isSending = false;
  bool _hasCustomDraft = false;
  _AvailabilityShareStep _step = _AvailabilityShareStep.editor;
  bool _stepReversing = false;
  List<ComposerRecipient> _recipients = <ComposerRecipient>[];

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
    final Chat? lockedChat = widget.lockToChat ? widget.initialChat : null;
    _selectedChat = lockedChat ??
        (widget.availableChats.isEmpty ? null : widget.availableChats.first);
    if (lockedChat != null) {
      _recipients = <ComposerRecipient>[
        ComposerRecipient(
          target: FanOutTarget.chat(
            chat: lockedChat,
            shareSignatureEnabled: lockedChat.shareSignatureEnabled ??
                context.read<SettingsCubit>().state.shareTokenSignatureEnabled,
          ),
          pinned: true,
        ),
      ];
    }
    _resetDraftIntervals();
  }

  @override
  void didUpdateWidget(covariant CalendarAvailabilityShareScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) {
      _localModel = widget.model;
      _resetDraftIntervals();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String subtitleText = widget.lockToChat
        ? l10n.calendarAvailabilityShareChatSubtitle
        : l10n.calendarAvailabilityShareSubtitle;
    final Widget stepChild = _step.isEditor
        ? _AvailabilityEditorStep(
            rangeStart: _rangeStart,
            rangeEnd: _rangeEnd,
            presets: _presets,
            editor: _AvailabilityEditorContent(
              rangeStart: _rangeStart,
              rangeEnd: _rangeEnd,
              intervals: _draftIntervals,
              tzid: _resolveTimeZone(_localModel),
              invalidMessage:
                  context.l10n.calendarAvailabilityShareInvalidRange,
              onIntervalsChanged: _handleDraftIntervalsChanged,
            ),
            onStartChanged: _handleRangeStartChanged,
            onEndChanged: _handleRangeEndChanged,
            onPresetSelected: _handlePresetSelected,
            onSavePreset: _handleSavePresetPressed,
            onSharePressed: _handleSharePressed,
          )
        : _AvailabilityRecipientsStep(
            rangeLabel: _rangeSummaryLabel(),
            recipients: _recipients,
            availableChats: widget.availableChats,
            isBusy: _isSending,
            onRecipientAdded: _handleRecipientAdded,
            onRecipientRemoved: _handleRecipientRemoved,
            onRecipientToggled: _handleRecipientToggled,
            onBack: _handleBackToEditor,
            onSend: _handleSendPressed,
          );
    final Widget paddedStepChild = _step.isEditor
        ? Padding(padding: calendarMarginLarge, child: stepChild)
        : stepChild;
    return Scaffold(
      backgroundColor: _availabilityShareBackgroundColor(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AvailabilityShareHeader(
              title: l10n.calendarAvailabilityShareTitle,
              subtitle: subtitleText,
              onClose: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: PageTransitionSwitcher(
                duration: baseAnimationDuration,
                reverse: _stepReversing,
                transitionBuilder:
                    (child, primaryAnimation, secondaryAnimation) =>
                        SharedAxisTransition(
                  animation: primaryAnimation,
                  secondaryAnimation: secondaryAnimation,
                  transitionType: SharedAxisTransitionType.horizontal,
                  child: child,
                ),
                child: KeyedSubtree(
                  key: ValueKey<_AvailabilityShareStep>(_step),
                  child: paddedStepChild,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _stepIndex(_AvailabilityShareStep step) {
    return switch (step) {
      _AvailabilityShareStep.editor => 0,
      _AvailabilityShareStep.recipients => 1,
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

  String _rangeSummaryLabel() {
    final DateTime? start = _rangeStart;
    final DateTime? end = _rangeEnd;
    if (start == null || end == null || !end.isAfter(start)) {
      return context.l10n.calendarAvailabilityShareInvalidRange;
    }
    final String startLabel =
        TimeFormatter.formatFriendlyDateTime(context.l10n, start);
    final String endLabel =
        TimeFormatter.formatFriendlyDateTime(context.l10n, end);
    if (startLabel == endLabel) {
      return startLabel;
    }
    return context.l10n.commonRangeLabel(startLabel, endLabel);
  }

  void _handleRangeStartChanged(DateTime? value) {
    setState(() {
      _rangeStart = value;
      final end = _rangeEnd;
      if (value != null && end != null && !end.isAfter(value)) {
        _rangeEnd = value.add(
          const Duration(days: _availabilityDefaultRangeDays),
        );
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

  void _handleSharePressed() {
    if (widget.lockToChat) {
      _handleSendPressed();
      return;
    }
    _updateStep(_AvailabilityShareStep.recipients);
  }

  void _handleBackToEditor() {
    _updateStep(_AvailabilityShareStep.editor);
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
    _updateStep(_AvailabilityShareStep.editor);
  }

  Future<void> _handleSavePresetPressed() async {
    final DateTime? start = _rangeStart;
    final DateTime? end = _rangeEnd;
    if (start == null || end == null || !end.isAfter(start)) {
      FeedbackSystem.showError(
        context,
        context.l10n.calendarAvailabilityShareInvalidRange,
      );
      return;
    }
    final String? name = await _promptPresetName();
    if (!mounted) {
      return;
    }
    final String trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      if (name != null) {
        FeedbackSystem.showError(
          context,
          context.l10n.calendarAvailabilitySharePresetNameMissing,
        );
      }
      return;
    }
    final String ownerJid = widget.ownerJid.trim().isNotEmpty
        ? widget.ownerJid.trim()
        : context.l10n.commonOwnerFallback;
    final String? tzid = _resolveTimeZone(_localModel);
    final CalendarAvailabilityOverlay overlay = CalendarAvailabilityOverlay(
      owner: ownerJid,
      rangeStart: CalendarDateTime(value: start, tzid: tzid),
      rangeEnd: CalendarDateTime(value: end, tzid: tzid),
      intervals: _draftIntervals,
      isRedacted: false,
    );
    await _savePreset(overlay, name: trimmed);
  }

  Future<String?> _promptPresetName() async {
    final TextEditingController controller = TextEditingController();
    try {
      return await showFadeScaleDialog<String>(
        context: context,
        useRootNavigator: _calendarUseRootNavigator,
        builder: (dialogContext) => AxiInputDialog(
          title: Text(context.l10n.calendarAvailabilitySharePresetNameTitle),
          callbackText: context.l10n.commonSave,
          callback: () => Navigator.of(dialogContext).pop(controller.text),
          content: AxiTextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: context.l10n.calendarAvailabilitySharePresetNameLabel,
              hintText: context.l10n.calendarAvailabilitySharePresetNameHint,
            ),
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  void _handleRecipientAdded(FanOutTarget target) {
    final Chat? chat = target.chat;
    if (chat == null) {
      return;
    }
    setState(() {
      final existingIndex =
          _recipients.indexWhere((recipient) => recipient.key == target.key);
      if (existingIndex >= 0) {
        _recipients[existingIndex] = _recipients[existingIndex].copyWith(
          target: target,
          included: true,
        );
      } else {
        _recipients = <ComposerRecipient>[
          ..._recipients,
          ComposerRecipient(target: target),
        ];
      }
      _selectedChat ??= chat;
    });
  }

  void _handleRecipientRemoved(String key) {
    setState(() {
      _recipients =
          _recipients.where((recipient) => recipient.key != key).toList();
    });
  }

  void _handleRecipientToggled(String key) {
    setState(() {
      final index = _recipients.indexWhere((recipient) => recipient.key == key);
      if (index == -1) return;
      final recipient = _recipients[index];
      _recipients[index] = recipient.copyWith(included: !recipient.included);
    });
  }

  List<Chat> _includedRecipientChats() {
    final List<Chat> chats = <Chat>[];
    for (final recipient in _recipients) {
      if (!recipient.included) {
        continue;
      }
      final chat = recipient.target.chat;
      if (chat != null) {
        chats.add(chat);
      }
    }
    return chats;
  }

  Future<void> _handleSendPressed() async {
    if (_isSending) {
      return;
    }
    final DateTime? start = _rangeStart;
    final DateTime? end = _rangeEnd;
    if (start == null || end == null || !end.isAfter(start)) {
      FeedbackSystem.showError(
        context,
        context.l10n.calendarAvailabilityShareInvalidRange,
      );
      return;
    }
    final String ownerJid = widget.ownerJid.trim();
    if (ownerJid.isEmpty) {
      FeedbackSystem.showError(
        context,
        context.l10n.calendarAvailabilityShareMissingJid,
      );
      return;
    }
    final List<Chat> recipients = widget.lockToChat
        ? (_selectedChat == null ? const <Chat>[] : <Chat>[_selectedChat!])
        : _includedRecipientChats();
    if (recipients.isEmpty) {
      FeedbackSystem.showError(
        context,
        context.l10n.calendarAvailabilityShareRecipientsRequired,
      );
      return;
    }
    setState(() {
      _isSending = true;
    });
    final String? tzid = _resolveTimeZone(_localModel);
    final CalendarAvailabilityOverlay? customOverlay =
        _hasCustomDraft ? _buildCustomOverlay(ownerJid, tzid) : null;
    final CalendarAvailabilityOverlay recentOverlay = _buildRecentOverlay(
      ownerJid,
      tzid,
    );
    try {
      final completer = Completer<CalendarShareResult>();
      context.read<CalendarBloc>().add(
            CalendarEvent.availabilityShareRequested(
              source: widget.source,
              model: _localModel,
              ownerJid: ownerJid,
              recipients: recipients,
              rangeStart: CalendarDateTime(value: start, tzid: tzid),
              rangeEnd: CalendarDateTime(value: end, tzid: tzid),
              overrideOverlay: customOverlay,
              lockOverlay: _hasCustomDraft,
              completer: completer,
            ),
          );
      final result = await completer.future;
      if (!mounted) {
        return;
      }
      if (!result.isSuccess) {
        FeedbackSystem.showError(
          context,
          context.l10n.calendarAvailabilityShareFailed,
        );
        return;
      }
      if (result.partialFailure) {
        FeedbackSystem.showInfo(
          context,
          context.l10n.calendarAvailabilitySharePartialFailure,
        );
      }
      await _saveRecentPreset(recentOverlay);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result.record);
    } catch (_) {
      if (!mounted) {
        return;
      }
      FeedbackSystem.showError(
        context,
        context.l10n.calendarAvailabilityShareFailed,
      );
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
        ownerJid.isEmpty ? context.l10n.commonOwnerFallback : ownerJid;
    return CalendarAvailabilityOverlay(
      owner: resolvedOwner,
      rangeStart: CalendarDateTime(value: start, tzid: tzid),
      rangeEnd: CalendarDateTime(value: end, tzid: tzid),
      intervals: _draftIntervals,
      isRedacted: false,
    );
  }

  CalendarAvailabilityOverlay _buildRecentOverlay(
    String ownerJid,
    String? tzid,
  ) {
    final DateTime start = _rangeStart ?? DateTime.now();
    final DateTime end = _rangeEnd ?? start;
    final String resolvedOwner =
        ownerJid.isEmpty ? context.l10n.commonOwnerFallback : ownerJid;
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
      owner: context.l10n.commonOwnerFallback,
      rangeStart: CalendarDateTime(value: start, tzid: tzid),
      rangeEnd: CalendarDateTime(value: end, tzid: tzid),
      isRedacted: false,
    );
    final CalendarAvailabilityOverlay overlay = deriveAvailabilityOverlay(
      model: _localModel,
      base: base,
    );
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
    final List<CalendarAvailabilityPreset> presets = records.values
        .where((preset) => preset.name?.trim().isNotEmpty == true)
        .toList(growable: false);
    presets.sort(
      (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return presets.take(_availabilityPresetMaxCount).toList(growable: false);
  }

  Future<void> _savePreset(
    CalendarAvailabilityOverlay overlay, {
    required String name,
  }) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }
    final CalendarAvailabilityPreset preset = CalendarAvailabilityPreset(
      id: _availabilityPresetIdGenerator.v4(),
      overlay: overlay,
      name: trimmedName,
      updatedAt: DateTime.now(),
    );
    final records = _presetStore.readAll()..[preset.id] = preset;
    final List<CalendarAvailabilityPreset> sorted = records.values
        .where((preset) => preset.name?.trim().isNotEmpty == true)
        .toList(growable: false)
      ..sort(
        (a, b) =>
            (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
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

  Future<void> _saveRecentPreset(CalendarAvailabilityOverlay overlay) async {
    final DateTime start = overlay.rangeStart.value;
    final DateTime end = overlay.rangeEnd.value;
    if (!end.isAfter(start)) {
      return;
    }
    final String name = _autoPresetName(start, end);
    await _savePreset(overlay, name: name);
  }

  String _autoPresetName(DateTime start, DateTime end) {
    final String startLabel = TimeFormatter.formatShortDate(start);
    final String endLabel = TimeFormatter.formatShortDate(end);
    final String rangeLabel = startLabel == endLabel
        ? startLabel
        : context.l10n.commonRangeLabel(startLabel, endLabel);
    return context.l10n.calendarAvailabilityShareRecentPreset(rangeLabel);
  }
}

class _AvailabilityEditorStep extends StatelessWidget {
  const _AvailabilityEditorStep({
    required this.rangeStart,
    required this.rangeEnd,
    required this.presets,
    required this.editor,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onPresetSelected,
    required this.onSavePreset,
    required this.onSharePressed,
  });

  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final List<CalendarAvailabilityPreset> presets;
  final Widget editor;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final ValueChanged<CalendarAvailabilityPreset> onPresetSelected;
  final VoidCallback onSavePreset;
  final VoidCallback onSharePressed;

  @override
  Widget build(BuildContext context) {
    final CalendarResponsiveSpec spec = ResponsiveHelper.spec(context);
    final Widget panel = _AvailabilityEditorPanel(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      presets: presets,
      onStartChanged: onStartChanged,
      onEndChanged: onEndChanged,
      onPresetSelected: onPresetSelected,
      onSavePreset: onSavePreset,
      onSharePressed: onSharePressed,
    );
    return spec.sizeClass == CalendarSizeClass.expanded
        ? _AvailabilityEditorWideLayout(panel: panel, editor: editor)
        : _AvailabilityEditorCompactLayout(panel: panel, editor: editor);
  }
}

class _AvailabilityEditorCompactLayout extends StatelessWidget {
  const _AvailabilityEditorCompactLayout({
    required this.panel,
    required this.editor,
  });

  final Widget panel;
  final Widget editor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        panel,
        const SizedBox(height: _availabilitySheetSectionSpacing),
        Expanded(child: editor),
      ],
    );
  }
}

class _AvailabilityEditorWideLayout extends StatelessWidget {
  const _AvailabilityEditorWideLayout({
    required this.panel,
    required this.editor,
  });

  final Widget panel;
  final Widget editor;

  @override
  Widget build(BuildContext context) {
    final CalendarSidebarDimensions sidebar =
        ResponsiveHelper.sidebarDimensions(context);
    final double panelWidth = sidebar.defaultWidth
        .clamp(0, _availabilityEditorPanelMaxWidth)
        .toDouble();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: panelWidth,
          child: SingleChildScrollView(child: panel),
        ),
        const SizedBox(width: _availabilityEditorPanelGap),
        Expanded(child: editor),
      ],
    );
  }
}

class _AvailabilityEditorPanel extends StatelessWidget {
  const _AvailabilityEditorPanel({
    required this.rangeStart,
    required this.rangeEnd,
    required this.presets,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onPresetSelected,
    required this.onSavePreset,
    required this.onSharePressed,
  });

  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final List<CalendarAvailabilityPreset> presets;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final ValueChanged<CalendarAvailabilityPreset> onPresetSelected;
  final VoidCallback onSavePreset;
  final VoidCallback onSharePressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final TextStyle hintStyle = context.textTheme.small.copyWith(
      color: context.colorScheme.mutedForeground,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AvailabilitySheetSectionLabel(
          text: l10n.calendarAvailabilityShareRangeLabel,
        ),
        ScheduleRangeFields(
          start: rangeStart,
          end: rangeEnd,
          onStartChanged: onStartChanged,
          onEndChanged: onEndChanged,
        ),
        const SizedBox(height: _availabilitySheetSectionGap),
        Text(l10n.calendarAvailabilityShareEditHint, style: hintStyle),
        const SizedBox(height: _availabilitySheetSectionSpacing),
        _AvailabilityPresetSection(
          presets: presets,
          onPresetSelected: onPresetSelected,
        ),
        const SizedBox(height: _availabilitySheetSectionSpacing),
        _AvailabilityDualActionRow(
          primaryLabel: l10n.calendarAvailabilityShareSavePreset,
          secondaryLabel: l10n.commonShare,
          onPrimaryPressed: onSavePreset,
          onSecondaryPressed: onSharePressed,
        ),
      ],
    );
  }
}

class _AvailabilityEditorGrid extends StatelessWidget {
  const _AvailabilityEditorGrid({
    required this.rangeStart,
    required this.rangeEnd,
    required this.intervals,
    required this.tzid,
    required this.onIntervalsChanged,
  });

  final DateTime rangeStart;
  final DateTime rangeEnd;
  final List<CalendarFreeBusyInterval> intervals;
  final String? tzid;
  final ValueChanged<List<CalendarFreeBusyInterval>> onIntervalsChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : _availabilityShareEditorFallbackHeight;
        return CalendarFreeBusyEditor(
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          intervals: intervals,
          tzid: tzid,
          onIntervalsChanged: onIntervalsChanged,
          viewportHeight: height,
        );
      },
    );
  }
}

class _AvailabilityShareHeader extends StatelessWidget {
  const _AvailabilityShareHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = context.textTheme.h4.strong;
    final TextStyle subtitleStyle = context.textTheme.small.copyWith(
      color: context.colorScheme.mutedForeground,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colorScheme.border)),
      ),
      child: Padding(
        padding: calendarMarginLarge,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AxiIconButton.ghost(
              iconData: LucideIcons.arrowLeft,
              tooltip: context.l10n.commonBack,
              onPressed: onClose,
            ),
            const SizedBox(width: _availabilityShareHeaderSpacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
                  const SizedBox(height: _availabilityShareHeaderGap),
                  Text(subtitle, style: subtitleStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityRecipientsStep extends StatelessWidget {
  const _AvailabilityRecipientsStep({
    required this.rangeLabel,
    required this.recipients,
    required this.availableChats,
    required this.isBusy,
    required this.onRecipientAdded,
    required this.onRecipientRemoved,
    required this.onRecipientToggled,
    required this.onBack,
    required this.onSend,
  });

  final String rangeLabel;
  final List<ComposerRecipient> recipients;
  final List<Chat> availableChats;
  final bool isBusy;
  final ValueChanged<FanOutTarget> onRecipientAdded;
  final ValueChanged<String> onRecipientRemoved;
  final ValueChanged<String> onRecipientToggled;
  final VoidCallback onBack;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final rosterItems =
        context.watch<RosterCubit>().state.items ?? const <RosterItem>[];
    final locate = context.read;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: _availabilityRecipientsContentPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvailabilitySheetSectionLabel(
                text: context.l10n.commonRecipients,
              ),
              Text(
                rangeLabel,
                style: context.textTheme.small.copyWith(
                  color: context.colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: _availabilitySheetSectionGap),
            ],
          ),
        ),
        RecipientChipsBar(
          recipients: recipients,
          availableChats: availableChats,
          rosterItems: rosterItems,
          recipientSuggestionsStream:
              locate<ChatsCubit>().recipientAddressSuggestionsStream(),
          selfJid: locate<ChatsCubit>().selfJid,
          latestStatuses: const {},
          collapsedByDefault: false,
          allowAddressTargets: false,
          showSuggestionsWhenEmpty: true,
          onRecipientAdded: onRecipientAdded,
          onRecipientRemoved: onRecipientRemoved,
          onRecipientToggled: onRecipientToggled,
        ),
        const SizedBox(height: _availabilitySheetSectionSpacing),
        Padding(
          padding: _availabilityRecipientsContentPadding,
          child: _AvailabilityActionRow(
            isBusy: isBusy,
            label: context.l10n.commonSend,
            onBack: onBack,
            onPressed: onSend,
          ),
        ),
      ],
    );
  }
}

class _AvailabilityEditorContent extends StatelessWidget {
  const _AvailabilityEditorContent({
    required this.rangeStart,
    required this.rangeEnd,
    required this.intervals,
    required this.tzid,
    required this.invalidMessage,
    required this.onIntervalsChanged,
  });

  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final List<CalendarFreeBusyInterval> intervals;
  final String? tzid;
  final String invalidMessage;
  final ValueChanged<List<CalendarFreeBusyInterval>> onIntervalsChanged;

  @override
  Widget build(BuildContext context) {
    final DateTime? start = rangeStart;
    final DateTime? end = rangeEnd;
    if (start == null || end == null || !end.isAfter(start)) {
      return _AvailabilitySheetEmptyMessage(message: invalidMessage);
    }
    return _AvailabilityEditorGrid(
      rangeStart: start,
      rangeEnd: end,
      intervals: intervals,
      tzid: tzid,
      onIntervalsChanged: onIntervalsChanged,
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
        style: context.textTheme.sectionLabelM,
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
    final List<Widget> chipRow = <Widget>[];
    for (final chip in chips) {
      if (chipRow.isNotEmpty) {
        chipRow.add(const SizedBox(width: _availabilityPresetChipSpacing));
      }
      chipRow.add(chip);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AvailabilitySheetSectionLabel(
          text: context.l10n.calendarAvailabilitySharePresetLabel,
        ),
        if (chips.isEmpty)
          _AvailabilitySheetEmptyMessage(
            message: context.l10n.calendarAvailabilitySharePresetEmpty,
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: chipRow),
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
    final String label =
        preset.name?.trim() ?? _presetRangeLabel(context, preset);
    return AxiButton.ghost(
      size: AxiButtonSize.sm,
      onPressed: onPressed,
      child: Text(label),
    );
  }

  String _presetRangeLabel(
    BuildContext context,
    CalendarAvailabilityPreset preset,
  ) {
    final DateTime start = preset.overlay.rangeStart.value;
    final DateTime end = preset.overlay.rangeEnd.value;
    return context.l10n.commonRangeLabel(
      DateFormat.Md().format(start),
      DateFormat.Md().format(end),
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
        AxiButton.ghost(
          size: AxiButtonSize.sm,
          onPressed: onPrimaryPressed,
          child: Text(primaryLabel),
        ),
        const SizedBox(width: _availabilityRecipientChipSpacing),
        AxiButton.primary(
          size: AxiButtonSize.sm,
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
        AxiButton.ghost(
          size: AxiButtonSize.sm,
          onPressed: onBack,
          child: Text(context.l10n.commonBack),
        ),
        const SizedBox(width: _availabilityRecipientChipSpacing),
        AxiButton.primary(
          size: AxiButtonSize.sm,
          onPressed: isBusy ? null : onPressed,
          loading: isBusy,
          widthBehavior: AxiButtonWidth.fit,
          leading: Icon(
            LucideIcons.send,
            size: context.sizing.iconButtonIconSize,
          ),
          child: Text(label),
        ),
      ],
    );
  }
}

DateTime _normalizeRangeStart(DateTime now) {
  return DateTime(now.year, now.month, now.day, now.hour, now.minute);
}

String? _resolveTimeZone(CalendarModel model) {
  final raw = model.collection?.timeZone?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return raw;
}

Color _availabilityShareBackgroundColor(BuildContext context) {
  final scheme = context.colorScheme;
  return context.brightness == Brightness.dark
      ? scheme.card
      : calendarSidebarBackgroundColor;
}
