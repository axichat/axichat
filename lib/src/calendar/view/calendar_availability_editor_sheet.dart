import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/widgets/schedule_range_fields.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/calendar/view/widgets/task_text_field.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';

const double _availabilityEditorSpacing = 16.0;
const double _availabilityEditorGap = 8.0;
const double _availabilityEditorCardSpacing = 12.0;
const double _availabilityEditorCardRadius = 12.0;
const double _availabilityEditorCardBorderWidth = 1.0;
const double _availabilityEditorHeaderIconSize = 18.0;
const double _availabilityEditorProgressStrokeWidth = 2.0;
const double _availabilityEditorRemoveIconSize = 16.0;
const double _availabilityEditorRemoveButtonSize = 32.0;
const double _availabilityEditorRemoveTapTargetSize = 36.0;
const double _availabilityEditorRemoveCornerRadius = 12.0;
const int _availabilityEditorDescriptionMinLines = 3;
const int _availabilityEditorDescriptionMaxLines = 4;

const String _availabilityEditorTitle = 'Availability windows';
const String _availabilityEditorSubtitle =
    'Define the time ranges you want to share.';
const String _availabilityEditorWindowsLabel = 'Windows';
const String _availabilityEditorWindowLabel = 'Window';
const String _availabilityEditorAddWindowLabel = 'Add window';
const String _availabilityEditorEmptyLabel = 'No windows yet.';
const String _availabilityEditorSummaryLabel = 'Summary';
const String _availabilityEditorSummaryHint = 'Optional label';
const String _availabilityEditorDescriptionLabel = 'Notes';
const String _availabilityEditorDescriptionHint = 'Optional details';
const String _availabilityEditorSaveLabel = 'Save windows';
const String _availabilityEditorInvalidRangeMessage =
    'Check the window ranges before saving.';
const String _availabilityEditorEmptyWindowsMessage =
    'Add at least one availability window.';

const EdgeInsets _availabilityEditorCardPadding =
    EdgeInsets.symmetric(horizontal: 16, vertical: 12);

const Uuid _availabilityEditorIdGenerator = Uuid();

Future<CalendarAvailability?> showCalendarAvailabilityEditorSheet({
  required BuildContext context,
  required CalendarModel model,
  CalendarAvailability? availability,
}) {
  return showAdaptiveBottomSheet<CalendarAvailability>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => CalendarAvailabilityEditorSheet(
      model: model,
      availability: availability,
    ),
  );
}

class CalendarAvailabilityEditorSheet extends StatefulWidget {
  const CalendarAvailabilityEditorSheet({
    super.key,
    required this.model,
    this.availability,
  });

  final CalendarModel model;
  final CalendarAvailability? availability;

  @override
  State<CalendarAvailabilityEditorSheet> createState() =>
      _CalendarAvailabilityEditorSheetState();
}

class _CalendarAvailabilityEditorSheetState
    extends State<CalendarAvailabilityEditorSheet> {
  late CalendarAvailability? _baseAvailability;
  late String _availabilityId;
  late List<_AvailabilityWindowDraft> _windowDrafts;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _baseAvailability = widget.availability ??
        _resolvePrimaryAvailability(widget.model.availability);
    _availabilityId =
        _baseAvailability?.id ?? _availabilityEditorIdGenerator.v4();
    _windowDrafts = _seedWindowDrafts(_baseAvailability);
  }

  @override
  void dispose() {
    for (final draft in _windowDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final header = AxiSheetHeader(
      title: const Text(_availabilityEditorTitle),
      subtitle: const Text(_availabilityEditorSubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    final body = AxiSheetScaffold.scroll(
      header: header,
      children: [
        TaskSectionHeader(
          title: _availabilityEditorWindowsLabel,
          trailing: _AvailabilityEditorAddButton(onPressed: _handleAddWindow),
        ),
        const SizedBox(height: calendarGutterSm),
        if (_windowDrafts.isEmpty)
          Text(
            _availabilityEditorEmptyLabel,
            style: context.textTheme.small.copyWith(
              color: context.colorScheme.mutedForeground,
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final _AvailabilityWindowDraft draft in _windowDrafts)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: _availabilityEditorCardSpacing,
                  ),
                  child: _AvailabilityWindowCard(
                    key: ValueKey<String>(draft.id),
                    draft: draft,
                    label: _availabilityEditorWindowLabel,
                    onStartChanged: (value) =>
                        _handleWindowStartChanged(draft, value),
                    onEndChanged: (value) =>
                        _handleWindowEndChanged(draft, value),
                    onRemove: () => _handleWindowRemoved(draft),
                  ),
                ),
            ],
          ),
        const SizedBox(height: _availabilityEditorSpacing),
        _AvailabilityEditorActionRow(
          isBusy: _isSaving,
          onPressed: _handleSavePressed,
        ),
      ],
    );
    return body;
  }

  void _handleAddWindow() {
    setState(() {
      _windowDrafts.add(_AvailabilityWindowDraft.create());
    });
  }

  void _handleWindowRemoved(_AvailabilityWindowDraft draft) {
    setState(() {
      _windowDrafts.remove(draft);
      draft.dispose();
    });
  }

  void _handleWindowStartChanged(
    _AvailabilityWindowDraft draft,
    DateTime? value,
  ) {
    setState(() {
      draft.start = value;
      final DateTime? end = draft.end;
      if (value != null && end != null && !end.isAfter(value)) {
        draft.end = value.add(calendarDefaultTaskDuration);
      }
    });
  }

  void _handleWindowEndChanged(
    _AvailabilityWindowDraft draft,
    DateTime? value,
  ) {
    setState(() {
      draft.end = value;
    });
  }

  Future<void> _handleSavePressed() async {
    if (_isSaving) {
      return;
    }
    if (_windowDrafts.isEmpty) {
      FeedbackSystem.showError(context, _availabilityEditorEmptyWindowsMessage);
      return;
    }
    final List<_AvailabilityWindowDraft> drafts = List.from(_windowDrafts);
    final bool hasInvalid = drafts.any(
      (draft) =>
          draft.start == null ||
          draft.end == null ||
          !draft.end!.isAfter(draft.start!),
    );
    if (hasInvalid) {
      FeedbackSystem.showError(
        context,
        _availabilityEditorInvalidRangeMessage,
      );
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final CalendarAvailability availability =
          _buildAvailabilityFromDrafts(drafts);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(availability);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  CalendarAvailability _buildAvailabilityFromDrafts(
    List<_AvailabilityWindowDraft> drafts,
  ) {
    final String? tzid = _resolveTimeZone(widget.model);
    final List<CalendarAvailabilityWindow> windows = drafts
        .map(
          (draft) => CalendarAvailabilityWindow(
            start: _wrapDateTime(draft.start!, tzid),
            end: _wrapDateTime(draft.end!, tzid),
            summary: draft.summary,
            description: draft.description,
          ),
        )
        .toList(growable: false);
    final List<DateTime> starts = drafts.map((draft) => draft.start!).toList();
    final List<DateTime> ends = drafts.map((draft) => draft.end!).toList();
    starts.sort();
    ends.sort();
    final DateTime rangeStart = starts.first;
    final DateTime rangeEnd = ends.last;
    final CalendarIcsMeta nextMeta =
        _updatedAvailabilityMeta(_baseAvailability?.icsMeta);
    return CalendarAvailability(
      id: _availabilityId,
      start: _wrapDateTime(rangeStart, tzid),
      end: _wrapDateTime(rangeEnd, tzid),
      summary: _baseAvailability?.summary,
      description: _baseAvailability?.description,
      windows: windows,
      icsMeta: nextMeta,
    );
  }

  CalendarIcsMeta _updatedAvailabilityMeta(CalendarIcsMeta? meta) {
    final now = DateTime.now();
    final CalendarIcsMeta base = meta ??
        CalendarIcsMeta(
          uid: _availabilityId,
          created: now,
          componentType: CalendarIcsComponentType.availability,
        );
    return base.copyWith(
      uid: base.uid ?? _availabilityId,
      created: base.created ?? now,
      dtStamp: now,
      lastModified: now,
      componentType:
          base.componentType ?? CalendarIcsComponentType.availability,
    );
  }
}

class _AvailabilityWindowCard extends StatelessWidget {
  const _AvailabilityWindowCard({
    super.key,
    required this.draft,
    required this.label,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onRemove,
  });

  final _AvailabilityWindowDraft draft;
  final String label;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _availabilityEditorCardPadding,
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(_availabilityEditorCardRadius),
        border: Border.all(
          color: calendarBorderColor,
          width: _availabilityEditorCardBorderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaskSectionHeader(
            title: label,
            trailing: _AvailabilityWindowRemoveButton(onPressed: onRemove),
          ),
          const SizedBox(height: _availabilityEditorGap),
          ScheduleRangeFields(
            start: draft.start,
            end: draft.end,
            onStartChanged: onStartChanged,
            onEndChanged: onEndChanged,
          ),
          const SizedBox(height: _availabilityEditorSpacing),
          TaskTextField(
            controller: draft.summaryController,
            labelText: _availabilityEditorSummaryLabel,
            hintText: _availabilityEditorSummaryHint,
          ),
          const SizedBox(height: _availabilityEditorGap),
          TaskTextField(
            controller: draft.descriptionController,
            labelText: _availabilityEditorDescriptionLabel,
            hintText: _availabilityEditorDescriptionHint,
            minLines: _availabilityEditorDescriptionMinLines,
            maxLines: _availabilityEditorDescriptionMaxLines,
          ),
        ],
      ),
    );
  }
}

class _AvailabilityWindowRemoveButton extends StatelessWidget {
  const _AvailabilityWindowRemoveButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiIconButton(
      iconData: Icons.delete_outline,
      tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
      onPressed: onPressed,
      color: calendarDangerColor,
      backgroundColor: calendarContainerColor,
      borderColor: calendarBorderColor,
      iconSize: _availabilityEditorRemoveIconSize,
      buttonSize: _availabilityEditorRemoveButtonSize,
      tapTargetSize: _availabilityEditorRemoveTapTargetSize,
      cornerRadius: _availabilityEditorRemoveCornerRadius,
    );
  }
}

class _AvailabilityEditorAddButton extends StatelessWidget {
  const _AvailabilityEditorAddButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ShadButton.ghost(
      size: ShadButtonSize.sm,
      onPressed: onPressed,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.plus,
            size: _availabilityEditorHeaderIconSize,
          ),
          SizedBox(width: calendarInsetSm),
          Text(_availabilityEditorAddWindowLabel),
        ],
      ),
    );
  }
}

class _AvailabilityEditorActionRow extends StatelessWidget {
  const _AvailabilityEditorActionRow({
    required this.isBusy,
    required this.onPressed,
  });

  final bool isBusy;
  final VoidCallback onPressed;

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
                width: _availabilityEditorHeaderIconSize,
                height: _availabilityEditorHeaderIconSize,
                child: CircularProgressIndicator(
                  strokeWidth: _availabilityEditorProgressStrokeWidth,
                ),
              )
            else
              const Icon(
                LucideIcons.check,
                size: _availabilityEditorHeaderIconSize,
              ),
            const SizedBox(width: _availabilityEditorGap),
            const Text(_availabilityEditorSaveLabel),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityWindowDraft {
  _AvailabilityWindowDraft({
    required this.id,
    required this.start,
    required this.end,
    required this.summaryController,
    required this.descriptionController,
  });

  factory _AvailabilityWindowDraft.create() {
    final DateTime now = DateTime.now();
    final DateTime normalized = _normalizeDateTime(now);
    return _AvailabilityWindowDraft(
      id: _availabilityEditorIdGenerator.v4(),
      start: normalized,
      end: normalized.add(calendarDefaultTaskDuration),
      summaryController: TextEditingController(),
      descriptionController: TextEditingController(),
    );
  }

  factory _AvailabilityWindowDraft.fromWindow(
      CalendarAvailabilityWindow window) {
    return _AvailabilityWindowDraft(
      id: _availabilityEditorIdGenerator.v4(),
      start: window.start.value,
      end: window.end.value,
      summaryController: TextEditingController(text: window.summary ?? ''),
      descriptionController:
          TextEditingController(text: window.description ?? ''),
    );
  }

  final String id;
  DateTime? start;
  DateTime? end;
  final TextEditingController summaryController;
  final TextEditingController descriptionController;

  String? get summary {
    final String value = summaryController.text.trim();
    return value.isEmpty ? null : value;
  }

  String? get description {
    final String value = descriptionController.text.trim();
    return value.isEmpty ? null : value;
  }

  void dispose() {
    summaryController.dispose();
    descriptionController.dispose();
  }
}

CalendarAvailability? _resolvePrimaryAvailability(
  Map<String, CalendarAvailability> availability,
) {
  if (availability.isEmpty) {
    return null;
  }
  final List<String> ids = availability.keys.toList()..sort();
  return availability[ids.first];
}

List<_AvailabilityWindowDraft> _seedWindowDrafts(
  CalendarAvailability? availability,
) {
  if (availability == null) {
    return <_AvailabilityWindowDraft>[];
  }
  final List<CalendarAvailabilityWindow> windows =
      _availabilityWindowsFor(availability);
  return windows
      .map(_AvailabilityWindowDraft.fromWindow)
      .toList(growable: false);
}

List<CalendarAvailabilityWindow> _availabilityWindowsFor(
  CalendarAvailability availability,
) {
  if (availability.windows.isNotEmpty) {
    return availability.windows;
  }
  return <CalendarAvailabilityWindow>[
    CalendarAvailabilityWindow(
      start: availability.start,
      end: availability.end,
      summary: availability.summary,
      description: availability.description,
    ),
  ];
}

CalendarDateTime _wrapDateTime(DateTime value, String? tzid) {
  return CalendarDateTime(
    value: value,
    tzid: tzid,
  );
}

DateTime _normalizeDateTime(DateTime now) {
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
