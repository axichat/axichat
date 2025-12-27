import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_availability_share_state.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/utils/calendar_fragment_policy.dart';
import 'package:axichat/src/calendar/view/calendar_availability_editor_sheet.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_availability_preview.dart';
import 'package:axichat/src/calendar/view/widgets/schedule_range_fields.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const int _availabilityDefaultRangeMonths = 1;
const int _availabilityMonthsInYear = 12;
const int _availabilityMonthIndexOffset = 1;

const double _availabilitySheetSectionSpacing = 16.0;
const double _availabilitySheetSectionGap = 8.0;
const double _availabilitySheetTileGap = 12.0;
const double _availabilitySheetHeaderIconSize = 18.0;
const double _availabilityChatAvatarSize = 36.0;
const double _availabilitySheetProgressStrokeWidth = 2.0;
const double _availabilitySheetLabelLetterSpacing = 0.4;
const double _availabilityChatTilePaddingHorizontal = 16.0;
const double _availabilityChatTilePaddingVertical = 8.0;

const String _availabilityShareTitle = 'Share availability';
const String _availabilityShareSubtitle =
    'Pick a range and choose who can view it.';
const String _availabilityShareTargetLabel = 'Share with';
const String _availabilityShareRangeLabel = 'Range';
const String _availabilityShareWindowsLabel = 'Availability windows';
const String _availabilityShareWindowsEmptyLabel = 'No windows defined yet.';
const String _availabilityShareWindowsCountPrefix = 'Windows: ';
const String _availabilityShareWindowSingularLabel = 'window';
const String _availabilityShareWindowPluralLabel = 'windows';
const String _availabilityShareEditWindowsLabel = 'Edit windows';
const String _availabilitySharePreviewLabel = 'Preview';
const String _availabilitySharePreviewEmptyLabel = 'Select a range to preview.';
const String _availabilityShareRedactionLabel = 'Share free slots only';
const String _availabilityShareRedactionHint =
    'Busy and tentative slots stay hidden.';
const String _availabilityShareButtonLabel = 'Share';
const String _availabilityShareMissingChatsMessage =
    'No eligible chats available.';
const String _availabilityShareMissingJidMessage =
    'Calendar sharing is unavailable.';
const String _availabilityShareInvalidRangeMessage =
    'Select a valid range to share.';
const String _availabilityShareTargetRequiredMessage =
    'Select a chat to share with.';
const String _availabilityShareSuccessMessage = 'Availability shared.';
const String _availabilityShareFailureMessage = 'Failed to share availability.';
const String _availabilityShareOwnerFallback = 'owner';
const String _availabilityChatTypeDirectLabel = 'Direct chat';
const String _availabilityChatTypeGroupLabel = 'Group chat';
const String _availabilityChatTypeNoteLabel = 'Notes';

const EdgeInsets _availabilityChatTilePadding = EdgeInsets.symmetric(
  horizontal: _availabilityChatTilePaddingHorizontal,
  vertical: _availabilityChatTilePaddingVertical,
);

Future<void> showCalendarAvailabilityShareSheet({
  required BuildContext context,
  required CalendarAvailabilityShareCoordinator coordinator,
  required CalendarAvailabilityShareSource source,
  required CalendarModel model,
  required String ownerJid,
  ValueChanged<CalendarAvailability>? onAvailabilitySaved,
  Chat? initialChat,
}) async {
  final List<Chat> chats =
      context.read<ChatsCubit?>()?.state.items ?? const <Chat>[];
  final List<Chat> available =
      chats.where((chat) => chat.supportsChatCalendar).toList(growable: false);
  if (available.isEmpty) {
    FeedbackSystem.showInfo(context, _availabilityShareMissingChatsMessage);
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
      onAvailabilitySaved: onAvailabilitySaved,
      initialChat: initialChat,
    ),
  );
  if (record == null || !context.mounted) {
    return;
  }
  FeedbackSystem.showSuccess(context, _availabilityShareSuccessMessage);
}

class CalendarAvailabilityShareSheet extends StatefulWidget {
  const CalendarAvailabilityShareSheet({
    super.key,
    required this.coordinator,
    required this.source,
    required this.model,
    required this.ownerJid,
    required this.availableChats,
    this.onAvailabilitySaved,
    this.initialChat,
  });

  final CalendarAvailabilityShareCoordinator coordinator;
  final CalendarAvailabilityShareSource source;
  final CalendarModel model;
  final String ownerJid;
  final List<Chat> availableChats;
  final ValueChanged<CalendarAvailability>? onAvailabilitySaved;
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
  Chat? _selectedChat;
  bool _isSending = false;
  bool _isRedacted = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = _normalizeRangeStart(now);
    _rangeStart = start;
    _rangeEnd = _addMonths(start, _availabilityDefaultRangeMonths);
    _localModel = widget.model;
    _selectedChat = widget.initialChat ??
        (widget.availableChats.isEmpty ? null : widget.availableChats.first);
  }

  @override
  void didUpdateWidget(covariant CalendarAvailabilityShareSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) {
      _localModel = widget.model;
    }
  }

  @override
  Widget build(BuildContext context) {
    final CalendarAvailabilityOverlay? previewOverlay =
        _resolvePreviewOverlay();
    final int windowCount = _availabilityWindowCount(_localModel.availability);
    final header = AxiSheetHeader(
      title: const Text(_availabilityShareTitle),
      subtitle: const Text(_availabilityShareSubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    final body = AxiSheetScaffold.scroll(
      header: header,
      children: [
        const _AvailabilitySheetSectionLabel(
            text: _availabilityShareRangeLabel),
        ScheduleRangeFields(
          start: _rangeStart,
          end: _rangeEnd,
          onStartChanged: _handleRangeStartChanged,
          onEndChanged: _handleRangeEndChanged,
        ),
        const SizedBox(height: _availabilitySheetSectionSpacing),
        const _AvailabilitySheetSectionLabel(
          text: _availabilityShareWindowsLabel,
        ),
        _AvailabilityWindowsSection(
          windowCount: windowCount,
          onEditPressed: _handleEditAvailabilityPressed,
        ),
        const SizedBox(height: _availabilitySheetSectionSpacing),
        const _AvailabilitySheetSectionLabel(
          text: _availabilitySharePreviewLabel,
        ),
        _AvailabilityPreviewSection(
          overlay: previewOverlay,
          isRedacted: _isRedacted,
          onRedactionChanged: _handleRedactionChanged,
        ),
        const SizedBox(height: _availabilitySheetSectionSpacing),
        const _AvailabilitySheetSectionLabel(
          text: _availabilityShareTargetLabel,
        ),
        if (widget.availableChats.isEmpty)
          const _AvailabilitySheetEmptyMessage(
            message: _availabilityShareMissingChatsMessage,
          )
        else
          _AvailabilityChatPicker(
            chats: widget.availableChats,
            selected: _selectedChat,
            onSelected: _handleChatSelected,
          ),
        const SizedBox(height: _availabilitySheetSectionSpacing),
        _AvailabilitySheetActionRow(
          isBusy: _isSending,
          onPressed: _handleSharePressed,
          label: _availabilityShareButtonLabel,
        ),
      ],
    );
    return body;
  }

  void _handleRangeStartChanged(DateTime? value) {
    setState(() {
      _rangeStart = value;
      final end = _rangeEnd;
      if (value != null && end != null && !end.isAfter(value)) {
        _rangeEnd = _addMonths(value, _availabilityDefaultRangeMonths);
      }
    });
  }

  void _handleRangeEndChanged(DateTime? value) {
    setState(() {
      _rangeEnd = value;
    });
  }

  void _handleChatSelected(Chat chat) {
    setState(() {
      _selectedChat = chat;
    });
  }

  void _handleRedactionChanged(bool value) {
    setState(() {
      _isRedacted = value;
    });
  }

  Future<void> _handleEditAvailabilityPressed() async {
    final CalendarAvailability? availability =
        await showCalendarAvailabilityEditorSheet(
      context: context,
      model: _localModel,
    );
    if (availability == null || !mounted) {
      return;
    }
    widget.onAvailabilitySaved?.call(availability);
    setState(() {
      _localModel = _localModel.upsertAvailability(availability);
    });
  }

  Future<void> _handleSharePressed() async {
    if (_isSending) {
      return;
    }
    final ownerJid = widget.ownerJid.trim();
    if (ownerJid.isEmpty) {
      FeedbackSystem.showError(context, _availabilityShareMissingJidMessage);
      return;
    }
    final start = _rangeStart;
    final end = _rangeEnd;
    if (start == null || end == null || !end.isAfter(start)) {
      FeedbackSystem.showError(context, _availabilityShareInvalidRangeMessage);
      return;
    }
    final targetChat = _selectedChat;
    if (targetChat == null) {
      FeedbackSystem.showError(
          context, _availabilityShareTargetRequiredMessage);
      return;
    }
    setState(() {
      _isSending = true;
    });
    try {
      final tzid = _resolveTimeZone(_localModel);
      final CalendarDateTime rangeStart = CalendarDateTime(
        value: start,
        tzid: tzid,
      );
      final CalendarDateTime rangeEnd = CalendarDateTime(
        value: end,
        tzid: tzid,
      );
      final record = await widget.coordinator.createShare(
        source: widget.source,
        model: _localModel,
        ownerJid: ownerJid,
        chatJid: targetChat.jid,
        chatType: targetChat.type,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        isRedacted: _isRedacted,
      );
      if (!mounted) {
        return;
      }
      if (record == null) {
        FeedbackSystem.showError(context, _availabilityShareFailureMessage);
        return;
      }
      Navigator.of(context).pop(record);
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

  CalendarAvailabilityOverlay? _resolvePreviewOverlay() {
    final DateTime? start = _rangeStart;
    final DateTime? end = _rangeEnd;
    if (start == null || end == null || !end.isAfter(start)) {
      return null;
    }
    final String ownerJid = widget.ownerJid.trim();
    final String resolvedOwner =
        ownerJid.isEmpty ? _availabilityShareOwnerFallback : ownerJid;
    final String? tzid = _resolveTimeZone(_localModel);
    final CalendarAvailabilityOverlay base = CalendarAvailabilityOverlay(
      owner: resolvedOwner,
      rangeStart: CalendarDateTime(value: start, tzid: tzid),
      rangeEnd: CalendarDateTime(value: end, tzid: tzid),
      isRedacted: _isRedacted,
    );
    return deriveAvailabilityOverlay(model: _localModel, base: base);
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

class _AvailabilityWindowsSection extends StatelessWidget {
  const _AvailabilityWindowsSection({
    required this.windowCount,
    required this.onEditPressed,
  });

  final int windowCount;
  final VoidCallback onEditPressed;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      color: context.colorScheme.mutedForeground,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            _availabilityWindowCountLabel(windowCount),
            style: labelStyle,
          ),
        ),
        ShadButton.ghost(
          size: ShadButtonSize.sm,
          onPressed: onEditPressed,
          child: const Text(_availabilityShareEditWindowsLabel),
        ),
      ],
    );
  }
}

class _AvailabilityPreviewSection extends StatelessWidget {
  const _AvailabilityPreviewSection({
    required this.overlay,
    required this.isRedacted,
    required this.onRedactionChanged,
  });

  final CalendarAvailabilityOverlay? overlay;
  final bool isRedacted;
  final ValueChanged<bool> onRedactionChanged;

  @override
  Widget build(BuildContext context) {
    final TextStyle hintStyle = context.textTheme.small.copyWith(
      color: context.colorScheme.mutedForeground,
    );
    final CalendarAvailabilityOverlay? previewOverlay = overlay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShadSwitch(
          label: const Text(_availabilityShareRedactionLabel),
          value: isRedacted,
          onChanged: onRedactionChanged,
        ),
        const SizedBox(height: _availabilitySheetSectionGap),
        Text(_availabilityShareRedactionHint, style: hintStyle),
        const SizedBox(height: _availabilitySheetSectionGap),
        if (previewOverlay == null)
          const _AvailabilitySheetEmptyMessage(
            message: _availabilitySharePreviewEmptyLabel,
          )
        else
          CalendarAvailabilityPreview(overlay: previewOverlay),
      ],
    );
  }
}

class _AvailabilityChatPicker extends StatelessWidget {
  const _AvailabilityChatPicker({
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
              size: _availabilityChatAvatarSize,
              avatarPath: chat.avatarPath,
              shape: AxiAvatarShape.circle,
            ),
            title: chat.displayName,
            subtitle: chat.type.label,
            selected: selected?.jid == chat.jid,
            onTap: () => onSelected(chat),
            contentPadding: _availabilityChatTilePadding,
          ),
          const SizedBox(height: _availabilitySheetTileGap),
        ],
      ],
    );
  }
}

class _AvailabilitySheetActionRow extends StatelessWidget {
  const _AvailabilitySheetActionRow({
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
                width: _availabilitySheetHeaderIconSize,
                height: _availabilitySheetHeaderIconSize,
                child: CircularProgressIndicator(
                  strokeWidth: _availabilitySheetProgressStrokeWidth,
                ),
              )
            else
              const Icon(
                LucideIcons.share2,
                size: _availabilitySheetHeaderIconSize,
              ),
            const SizedBox(width: _availabilitySheetSectionGap),
            Text(label),
          ],
        ),
      ),
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

int _availabilityWindowCount(
  Map<String, CalendarAvailability> availability,
) {
  var count = 0;
  for (final CalendarAvailability entry in availability.values) {
    if (entry.windows.isEmpty) {
      count += 1;
    } else {
      count += entry.windows.length;
    }
  }
  return count;
}

String _availabilityWindowCountLabel(int count) {
  if (count == 0) {
    return _availabilityShareWindowsEmptyLabel;
  }
  final String unit = count == 1
      ? _availabilityShareWindowSingularLabel
      : _availabilityShareWindowPluralLabel;
  return '$_availabilityShareWindowsCountPrefix$count $unit';
}

DateTime _addMonths(DateTime start, int months) {
  final totalMonths = start.month - _availabilityMonthIndexOffset + months;
  final year = start.year + totalMonths ~/ _availabilityMonthsInYear;
  final month =
      totalMonths % _availabilityMonthsInYear + _availabilityMonthIndexOffset;
  final lastDay = DateUtils.getDaysInMonth(year, month);
  final day = math.min(start.day, lastDay);
  return DateTime(
    year,
    month,
    day,
    start.hour,
    start.minute,
    start.second,
    start.millisecond,
    start.microsecond,
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
