// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/calendar_attachment.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/widgets/deadline_picker_field.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/calendar/view/widgets/task_text_field.dart';
import 'package:axichat/src/common/ui/ui.dart';

const String _alarmsSectionTitle = 'Alarms';
const String _alarmsSectionHelper = 'Reminders are exported as display alarms.';
const String _alarmsEmptyLabel = 'No alarms yet';
const String _alarmsAddTooltip = 'Add alarm';
const String _alarmRemoveTooltip = 'Remove alarm';
const String _alarmItemLabel = 'Alarm';
const String _alarmActionLabel = 'Action';
const String _alarmActionDisplayLabel = 'Display';
const String _alarmActionAudioLabel = 'Audio';
const String _alarmActionEmailLabel = 'Email';
const String _alarmActionProcedureLabel = 'Procedure';
const String _alarmActionProcedureHelper =
    'Procedure alarms are imported read-only.';
const String _alarmTriggerTypeLabel = 'Trigger';
const String _alarmTriggerRelativeLabel = 'Relative';
const String _alarmTriggerAbsoluteLabel = 'Absolute';
const String _alarmAbsolutePlaceholder = 'Pick date and time';
const String _alarmRelativeToLabel = 'Relative to';
const String _alarmRelativeToStartLabel = 'Start';
const String _alarmRelativeToEndLabel = 'End';
const String _alarmDirectionLabel = 'Direction';
const String _alarmDirectionBeforeLabel = 'Before';
const String _alarmDirectionAfterLabel = 'After';
const String _alarmOffsetLabel = 'Offset';
const String _alarmOffsetHint = 'Amount';
const String _alarmRepeatLabel = 'Repeat';
const String _alarmRepeatCountHint = 'Times';
const String _alarmRepeatEveryLabel = 'Every';
const String _alarmRecipientsLabel = 'Recipients';
const String _alarmRecipientAddressHint = 'Add email';
const String _alarmRecipientNameHint = 'Name (optional)';
const String _alarmRecipientRemoveTooltip = 'Remove recipient';
const String _alarmAcknowledgedLabel = 'Acknowledged';
const String _alarmUnitMinutesLabel = 'Minutes';
const String _alarmUnitHoursLabel = 'Hours';
const String _alarmUnitDaysLabel = 'Days';
const String _alarmUnitWeeksLabel = 'Weeks';
const String _emptyText = '';

const int _alarmIndexOffset = 1;
const int _alarmDefaultOffsetMinutes = 15;
const int _alarmMinRepeatValue = 1;
const int _alarmMinNumericValue = 0;
const int _alarmMinutesPerHour = 60;
const int _alarmHoursPerDay = 24;
const int _alarmDaysPerWeek = 7;
const int _alarmTextSelectionOffset = 0;

const double _alarmCompactWidth = calendarQuickAddModalCompactMaxWidth;

const double _alarmRemoveButtonSize = 26;
const double _alarmRemoveTapTargetSize = 34;
const double _alarmRecipientButtonSize = 24;
const double _alarmRecipientTapTargetSize = 32;

const Duration _alarmDefaultOffset =
    Duration(minutes: _alarmDefaultOffsetMinutes);

const List<CalendarAlarmRecipient> _emptyRecipients =
    <CalendarAlarmRecipient>[];
const List<CalendarAttachment> _emptyAlarmAttachments = <CalendarAttachment>[];
final List<TextInputFormatter> _digitsOnlyInputFormatters =
    List<TextInputFormatter>.unmodifiable(
  <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
);

enum AlarmOffsetUnit {
  minutes,
  hours,
  days,
  weeks;
}

extension AlarmOffsetUnitX on AlarmOffsetUnit {
  String get label => switch (this) {
        AlarmOffsetUnit.minutes => _alarmUnitMinutesLabel,
        AlarmOffsetUnit.hours => _alarmUnitHoursLabel,
        AlarmOffsetUnit.days => _alarmUnitDaysLabel,
        AlarmOffsetUnit.weeks => _alarmUnitWeeksLabel,
      };

  Duration toDuration(int value) => switch (this) {
        AlarmOffsetUnit.minutes => Duration(minutes: value),
        AlarmOffsetUnit.hours => Duration(hours: value),
        AlarmOffsetUnit.days => Duration(days: value),
        AlarmOffsetUnit.weeks => Duration(days: value * _alarmDaysPerWeek),
      };

  int valueFrom(Duration duration) => switch (this) {
        AlarmOffsetUnit.minutes => duration.inMinutes,
        AlarmOffsetUnit.hours => duration.inMinutes ~/ _alarmMinutesPerHour,
        AlarmOffsetUnit.days => duration.inHours ~/ _alarmHoursPerDay,
        AlarmOffsetUnit.weeks => duration.inDays ~/ _alarmDaysPerWeek,
      };

  bool canRepresent(Duration duration) => switch (this) {
        AlarmOffsetUnit.minutes => true,
        AlarmOffsetUnit.hours => duration.inMinutes % _alarmMinutesPerHour == 0,
        AlarmOffsetUnit.days => duration.inHours % _alarmHoursPerDay == 0,
        AlarmOffsetUnit.weeks => duration.inDays % _alarmDaysPerWeek == 0,
      };
}

extension CalendarAlarmActionLabelX on CalendarAlarmAction {
  String get label => switch (this) {
        CalendarAlarmAction.display => _alarmActionDisplayLabel,
        CalendarAlarmAction.audio => _alarmActionAudioLabel,
        CalendarAlarmAction.email => _alarmActionEmailLabel,
        CalendarAlarmAction.procedure => _alarmActionProcedureLabel,
      };
}

extension CalendarAlarmTriggerTypeLabelX on CalendarAlarmTriggerType {
  String get label => switch (this) {
        CalendarAlarmTriggerType.relative => _alarmTriggerRelativeLabel,
        CalendarAlarmTriggerType.absolute => _alarmTriggerAbsoluteLabel,
      };
}

extension CalendarAlarmRelativeToLabelX on CalendarAlarmRelativeTo {
  String get label => switch (this) {
        CalendarAlarmRelativeTo.start => _alarmRelativeToStartLabel,
        CalendarAlarmRelativeTo.end => _alarmRelativeToEndLabel,
      };
}

extension CalendarAlarmOffsetDirectionLabelX on CalendarAlarmOffsetDirection {
  String get label => switch (this) {
        CalendarAlarmOffsetDirection.before => _alarmDirectionBeforeLabel,
        CalendarAlarmOffsetDirection.after => _alarmDirectionAfterLabel,
      };
}

class CalendarAlarmsField extends StatelessWidget {
  const CalendarAlarmsField({
    super.key,
    required this.alarms,
    required this.onChanged,
    this.title = _alarmsSectionTitle,
    this.referenceStart,
    this.showReminderNote = true,
    this.showHeader = true,
  });

  final List<CalendarAlarm> alarms;
  final ValueChanged<List<CalendarAlarm>> onChanged;
  final String title;
  final DateTime? referenceStart;
  final bool showReminderNote;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final List<CalendarAlarm> items = alarms;
    final Widget addButton = _AlarmAddButton(
      onPressed: () {
        final List<CalendarAlarm> next = List<CalendarAlarm>.from(items)
          ..add(_defaultAlarm());
        onChanged(next);
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          TaskSectionHeader(
            title: title,
            trailing: addButton,
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: addButton,
          ),
        if (showReminderNote) ...[
          const SizedBox(height: calendarInsetSm),
          Text(
            _alarmsSectionHelper,
            style: context.textTheme.muted.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: calendarGutterSm),
        if (items.isEmpty)
          const _AlarmEmptyState()
        else
          Column(
            children: items
                .asMap()
                .entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: calendarGutterMd),
                    child: _AlarmCard(
                      index: entry.key,
                      alarm: entry.value,
                      referenceStart: referenceStart,
                      onChanged: (updated) {
                        final List<CalendarAlarm> next =
                            List<CalendarAlarm>.from(items)
                              ..[entry.key] = updated;
                        onChanged(next);
                      },
                      onRemove: () {
                        final List<CalendarAlarm> next =
                            List<CalendarAlarm>.from(items)
                              ..removeAt(entry.key);
                        onChanged(next);
                      },
                    ),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _AlarmEmptyState extends StatelessWidget {
  const _AlarmEmptyState();

  @override
  Widget build(BuildContext context) {
    return Text(
      _alarmsEmptyLabel,
      style: context.textTheme.muted.copyWith(
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _AlarmAddButton extends StatelessWidget {
  const _AlarmAddButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiIconButton(
      iconData: Icons.add,
      tooltip: _alarmsAddTooltip,
      onPressed: onPressed,
      color: calendarPrimaryColor,
      backgroundColor: calendarContainerColor,
      borderColor: calendarBorderColor,
      iconSize: calendarGutterLg,
      buttonSize: AxiIconButton.kDefaultSize,
      tapTargetSize: AxiIconButton.kTapTargetSize,
    );
  }
}

class _AlarmFieldLabel extends StatelessWidget {
  const _AlarmFieldLabel({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.textTheme.small.copyWith(
        color: calendarSubtitleColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _AlarmAdaptiveRow extends StatelessWidget {
  const _AlarmAdaptiveRow({
    required this.leading,
    required this.trailing,
    required this.isCompact,
  });

  final Widget leading;
  final Widget trailing;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(height: calendarGutterMd),
          trailing,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: leading),
        const SizedBox(width: calendarGutterMd),
        Expanded(child: trailing),
      ],
    );
  }
}

class _AlarmCard extends StatefulWidget {
  const _AlarmCard({
    required this.index,
    required this.alarm,
    required this.referenceStart,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final CalendarAlarm alarm;
  final DateTime? referenceStart;
  final ValueChanged<CalendarAlarm> onChanged;
  final VoidCallback onRemove;

  @override
  State<_AlarmCard> createState() => _AlarmCardState();
}

class _AlarmCardState extends State<_AlarmCard> {
  late final TextEditingController _repeatController;

  @override
  void initState() {
    super.initState();
    _repeatController = TextEditingController(
      text: widget.alarm.repeat?.toString() ?? _emptyText,
    );
  }

  @override
  void didUpdateWidget(covariant _AlarmCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextText = widget.alarm.repeat?.toString() ?? _emptyText;
    if (_repeatController.text != nextText) {
      _repeatController
        ..text = nextText
        ..selection = TextSelection.collapsed(offset: nextText.length);
    }
  }

  @override
  void dispose() {
    _repeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CalendarAlarm alarm = widget.alarm;
    final CalendarAlarmTrigger trigger = _normalizedTrigger(alarm);
    final bool isProcedure = alarm.action == CalendarAlarmAction.procedure;
    final bool isEmail = alarm.action == CalendarAlarmAction.email;
    final TextStyle titleStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w700,
    );
    final TextStyle helperStyle = context.textTheme.muted.copyWith(
      fontWeight: FontWeight.w500,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth <= _alarmCompactWidth;
        final Widget actionField = _AlarmActionField(
          action: alarm.action,
          enabled: !isProcedure,
          helper: isProcedure
              ? Text(
                  _alarmActionProcedureHelper,
                  style: helperStyle,
                )
              : null,
          onChanged: (next) {
            widget.onChanged(
              alarm.copyWith(
                action: next,
              ),
            );
          },
        );
        final Widget triggerField = _AlarmTriggerTypeField(
          trigger: trigger,
          referenceStart: widget.referenceStart,
          onChanged: (next) => widget.onChanged(
            alarm.copyWith(trigger: next),
          ),
        );
        final Widget actionTriggerRow = _AlarmAdaptiveRow(
          leading: actionField,
          trailing: triggerField,
          isCompact: isCompact,
        );
        final Widget triggerDetails =
            trigger.type == CalendarAlarmTriggerType.absolute
                ? _AlarmAbsoluteTriggerField(
                    value: trigger.absolute,
                    referenceStart: widget.referenceStart,
                    onChanged: (next) {
                      widget.onChanged(
                        alarm.copyWith(
                          trigger: trigger.copyWith(absolute: next),
                        ),
                      );
                    },
                  )
                : _AlarmRelativeTriggerField(
                    trigger: trigger,
                    isCompact: isCompact,
                    onChanged: (next) => widget.onChanged(
                      alarm.copyWith(trigger: next),
                    ),
                  );

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: calendarGutterMd,
            vertical: calendarGutterMd,
          ),
          decoration: BoxDecoration(
            color: calendarContainerColor,
            borderRadius: BorderRadius.circular(calendarBorderRadius),
            border: Border.all(
              color: calendarBorderColor,
              width: calendarBorderStroke,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$_alarmItemLabel ${widget.index + _alarmIndexOffset}',
                    style: titleStyle,
                  ),
                  const Spacer(),
                  AxiIconButton(
                    iconData: Icons.close,
                    tooltip: _alarmRemoveTooltip,
                    onPressed: widget.onRemove,
                    color: calendarSubtitleColor,
                    backgroundColor: calendarContainerColor,
                    borderColor: calendarBorderColor,
                    iconSize: calendarGutterMd,
                    buttonSize: _alarmRemoveButtonSize,
                    tapTargetSize: _alarmRemoveTapTargetSize,
                  ),
                ],
              ),
              const SizedBox(height: calendarInsetMd),
              actionTriggerRow,
              const SizedBox(height: calendarGutterMd),
              triggerDetails,
              const SizedBox(height: calendarGutterMd),
              _AlarmRepeatField(
                repeatController: _repeatController,
                repeat: alarm.repeat,
                duration: alarm.duration,
                isCompact: isCompact,
                onRepeatChanged: (next) {
                  widget.onChanged(alarm.copyWith(repeat: next));
                },
                onDurationChanged: (next) {
                  widget.onChanged(alarm.copyWith(duration: next));
                },
              ),
              if (isEmail) ...[
                const SizedBox(height: calendarGutterMd),
                _AlarmRecipientsField(
                  recipients: alarm.recipients,
                  isCompact: isCompact,
                  onChanged: (next) => widget.onChanged(
                    alarm.copyWith(recipients: next),
                  ),
                ),
              ],
              if (alarm.acknowledged != null) ...[
                const SizedBox(height: calendarGutterMd),
                _AlarmAcknowledgedRow(value: alarm.acknowledged!),
              ],
            ],
          ),
        );
      },
    );
  }

  CalendarAlarmTrigger _normalizedTrigger(CalendarAlarm alarm) {
    final CalendarAlarmTrigger trigger = alarm.trigger;
    if (trigger.type == CalendarAlarmTriggerType.relative) {
      return CalendarAlarmTrigger(
        type: CalendarAlarmTriggerType.relative,
        absolute: null,
        offset: trigger.offset ?? _alarmDefaultOffset,
        relativeTo: trigger.relativeTo ?? CalendarAlarmRelativeTo.start,
        offsetDirection:
            trigger.offsetDirection ?? CalendarAlarmOffsetDirection.before,
      );
    }
    if (trigger.absolute != null) {
      return trigger;
    }
    return CalendarAlarmTrigger(
      type: CalendarAlarmTriggerType.absolute,
      absolute: _defaultAbsoluteDateTime(widget.referenceStart),
      offset: null,
      relativeTo: null,
      offsetDirection: null,
    );
  }
}

class _AlarmActionField extends StatelessWidget {
  const _AlarmActionField({
    required this.action,
    required this.enabled,
    required this.onChanged,
    this.helper,
  });

  final CalendarAlarmAction action;
  final bool enabled;
  final ValueChanged<CalendarAlarmAction> onChanged;
  final Widget? helper;

  @override
  Widget build(BuildContext context) {
    final List<CalendarAlarmAction> options = <CalendarAlarmAction>[
      CalendarAlarmAction.display,
      CalendarAlarmAction.audio,
      CalendarAlarmAction.email,
    ];
    final TextStyle valueStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w600,
    );
    final Widget? helperWidget = helper;
    final Widget content = enabled
        ? AxiSelect<CalendarAlarmAction>(
            enabled: enabled,
            initialValue: action,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              onChanged(value);
            },
            options: options
                .map(
                  (option) => ShadOption<CalendarAlarmAction>(
                    value: option,
                    child: Text(option.label),
                  ),
                )
                .toList(growable: false),
            selectedOptionBuilder: (context, selected) => Text(
              selected.label,
            ),
            decoration: ShadDecoration(
              color: calendarContainerColor,
              border: ShadBorder.all(
                color: calendarBorderColor,
                radius: BorderRadius.circular(calendarBorderRadius),
                width: calendarBorderStroke,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: calendarGutterMd,
              vertical: calendarGutterSm,
            ),
            trailing: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: calendarGutterMd,
              color: calendarSubtitleColor,
            ),
          )
        : Text(action.label, style: valueStyle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AlarmFieldLabel(text: _alarmActionLabel),
        const SizedBox(height: calendarInsetSm),
        content,
        if (helperWidget != null) ...[
          const SizedBox(height: calendarInsetSm),
          helperWidget,
        ],
      ],
    );
  }
}

class _AlarmTriggerTypeField extends StatelessWidget {
  const _AlarmTriggerTypeField({
    required this.trigger,
    required this.referenceStart,
    required this.onChanged,
  });

  final CalendarAlarmTrigger trigger;
  final DateTime? referenceStart;
  final ValueChanged<CalendarAlarmTrigger> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AlarmFieldLabel(text: _alarmTriggerTypeLabel),
        const SizedBox(height: calendarInsetSm),
        AxiSelect<CalendarAlarmTriggerType>(
          initialValue: trigger.type,
          onChanged: (value) {
            if (value == null || value == trigger.type) {
              return;
            }
            if (value == CalendarAlarmTriggerType.absolute) {
              onChanged(
                CalendarAlarmTrigger(
                  type: CalendarAlarmTriggerType.absolute,
                  absolute: _defaultAbsoluteDateTime(referenceStart),
                  offset: null,
                  relativeTo: null,
                  offsetDirection: null,
                ),
              );
              return;
            }
            onChanged(
              const CalendarAlarmTrigger(
                type: CalendarAlarmTriggerType.relative,
                absolute: null,
                offset: _alarmDefaultOffset,
                relativeTo: CalendarAlarmRelativeTo.start,
                offsetDirection: CalendarAlarmOffsetDirection.before,
              ),
            );
          },
          options: CalendarAlarmTriggerType.values
              .map(
                (option) => ShadOption<CalendarAlarmTriggerType>(
                  value: option,
                  child: Text(option.label),
                ),
              )
              .toList(growable: false),
          selectedOptionBuilder: (context, selected) => Text(selected.label),
          decoration: ShadDecoration(
            color: calendarContainerColor,
            border: ShadBorder.all(
              color: calendarBorderColor,
              radius: BorderRadius.circular(calendarBorderRadius),
              width: calendarBorderStroke,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: calendarGutterMd,
            vertical: calendarGutterSm,
          ),
          trailing: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: calendarGutterMd,
            color: calendarSubtitleColor,
          ),
        ),
      ],
    );
  }
}

class _AlarmAbsoluteTriggerField extends StatelessWidget {
  const _AlarmAbsoluteTriggerField({
    required this.value,
    required this.referenceStart,
    required this.onChanged,
  });

  final CalendarDateTime? value;
  final DateTime? referenceStart;
  final ValueChanged<CalendarDateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DeadlinePickerField(
      value: value?.value,
      placeholder: _alarmAbsolutePlaceholder,
      showStatusColors: false,
      showTimeSelectors: true,
      onChanged: (selected) {
        if (selected == null) {
          onChanged(null);
          return;
        }
        final CalendarDateTime next = _calendarDateTimeFrom(
          selected,
          template: value,
          referenceStart: referenceStart,
        );
        onChanged(next);
      },
    );
  }
}

class _AlarmRelativeTriggerField extends StatelessWidget {
  const _AlarmRelativeTriggerField({
    required this.trigger,
    required this.isCompact,
    required this.onChanged,
  });

  final CalendarAlarmTrigger trigger;
  final bool isCompact;
  final ValueChanged<CalendarAlarmTrigger> onChanged;

  @override
  Widget build(BuildContext context) {
    final CalendarAlarmRelativeTo relativeTo =
        trigger.relativeTo ?? CalendarAlarmRelativeTo.start;
    final CalendarAlarmOffsetDirection direction =
        trigger.offsetDirection ?? CalendarAlarmOffsetDirection.before;
    final Duration? offset = trigger.offset;

    final Widget relativeRow = _AlarmAdaptiveRow(
      leading: _AlarmRelativeSelectRow(
        label: _alarmRelativeToLabel,
        value: relativeTo,
        onChanged: (next) => onChanged(
          trigger.copyWith(relativeTo: next),
        ),
      ),
      trailing: _AlarmOffsetDirectionRow(
        label: _alarmDirectionLabel,
        value: direction,
        onChanged: (next) => onChanged(
          trigger.copyWith(offsetDirection: next),
        ),
      ),
      isCompact: isCompact,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        relativeRow,
        const SizedBox(height: calendarInsetMd),
        _AlarmDurationRow(
          label: _alarmOffsetLabel,
          hintText: _alarmOffsetHint,
          value: offset,
          allowZero: true,
          onChanged: (next) => onChanged(
            trigger.copyWith(offset: next),
          ),
        ),
      ],
    );
  }
}

class _AlarmRelativeSelectRow extends StatelessWidget {
  const _AlarmRelativeSelectRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final CalendarAlarmRelativeTo value;
  final ValueChanged<CalendarAlarmRelativeTo> onChanged;

  @override
  Widget build(BuildContext context) {
    return _AlarmSelectRow<CalendarAlarmRelativeTo>(
      label: label,
      value: value,
      options: CalendarAlarmRelativeTo.values,
      labelFor: (value) => value.label,
      onChanged: onChanged,
    );
  }
}

class _AlarmOffsetDirectionRow extends StatelessWidget {
  const _AlarmOffsetDirectionRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final CalendarAlarmOffsetDirection value;
  final ValueChanged<CalendarAlarmOffsetDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    return _AlarmSelectRow<CalendarAlarmOffsetDirection>(
      label: label,
      value: value,
      options: CalendarAlarmOffsetDirection.values,
      labelFor: (value) => value.label,
      onChanged: onChanged,
    );
  }
}

class _AlarmSelectRow<T> extends StatelessWidget {
  const _AlarmSelectRow({
    required this.label,
    required this.value,
    required this.options,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AlarmFieldLabel(text: label),
        const SizedBox(height: calendarInsetSm),
        AxiSelect<T>(
          initialValue: value,
          onChanged: (selected) {
            if (selected == null) {
              return;
            }
            onChanged(selected);
          },
          options: options
              .map(
                (option) => ShadOption<T>(
                  value: option,
                  child: Text(labelFor(option)),
                ),
              )
              .toList(growable: false),
          selectedOptionBuilder: (context, selected) =>
              Text(labelFor(selected)),
          decoration: ShadDecoration(
            color: calendarContainerColor,
            border: ShadBorder.all(
              color: calendarBorderColor,
              radius: BorderRadius.circular(calendarBorderRadius),
              width: calendarBorderStroke,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: calendarGutterMd,
            vertical: calendarGutterSm,
          ),
          trailing: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: calendarGutterMd,
            color: calendarSubtitleColor,
          ),
        ),
      ],
    );
  }
}

class _AlarmRepeatField extends StatelessWidget {
  const _AlarmRepeatField({
    required this.repeatController,
    required this.repeat,
    required this.duration,
    required this.isCompact,
    required this.onRepeatChanged,
    required this.onDurationChanged,
  });

  final TextEditingController repeatController;
  final int? repeat;
  final Duration? duration;
  final bool isCompact;
  final ValueChanged<int?> onRepeatChanged;
  final ValueChanged<Duration?> onDurationChanged;

  @override
  Widget build(BuildContext context) {
    final Widget repeatCountField = _AlarmRepeatCountField(
      controller: repeatController,
      onChanged: onRepeatChanged,
    );
    final Widget repeatEveryField = _AlarmDurationRow(
      label: _alarmRepeatEveryLabel,
      hintText: _alarmOffsetHint,
      value: duration,
      allowZero: false,
      onChanged: onDurationChanged,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AlarmFieldLabel(text: _alarmRepeatLabel),
        const SizedBox(height: calendarInsetSm),
        _AlarmAdaptiveRow(
          leading: repeatCountField,
          trailing: repeatEveryField,
          isCompact: isCompact,
        ),
      ],
    );
  }
}

class _AlarmRepeatCountField extends StatelessWidget {
  const _AlarmRepeatCountField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AlarmFieldLabel(text: _alarmRepeatCountHint),
        const SizedBox(height: calendarInsetSm),
        TaskTextField(
          controller: controller,
          hintText: _alarmRepeatCountHint,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onChanged: (value) {
            final int? parsed = int.tryParse(value);
            onChanged(
              parsed != null && parsed >= _alarmMinRepeatValue ? parsed : null,
            );
          },
          inputFormatters: _digitsOnlyInputFormatters,
        ),
      ],
    );
  }
}

class _AlarmDurationRow extends StatelessWidget {
  const _AlarmDurationRow({
    required this.label,
    required this.hintText,
    required this.value,
    required this.allowZero,
    required this.onChanged,
  });

  final String label;
  final String hintText;
  final Duration? value;
  final bool allowZero;
  final ValueChanged<Duration?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AlarmFieldLabel(text: label),
        const SizedBox(height: calendarInsetSm),
        AlarmDurationField(
          value: value,
          hintText: hintText,
          allowZero: allowZero,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class AlarmDurationField extends StatefulWidget {
  const AlarmDurationField({
    super.key,
    required this.value,
    required this.hintText,
    required this.onChanged,
    required this.allowZero,
  });

  final Duration? value;
  final String hintText;
  final ValueChanged<Duration?> onChanged;
  final bool allowZero;

  @override
  State<AlarmDurationField> createState() => _AlarmDurationFieldState();
}

class _AlarmDurationFieldState extends State<AlarmDurationField> {
  late final TextEditingController _controller;
  AlarmOffsetUnit _unit = AlarmOffsetUnit.minutes;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _syncFromValue(widget.value);
  }

  @override
  void didUpdateWidget(covariant AlarmDurationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _syncFromValue(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TaskTextField(
            controller: _controller,
            hintText: widget.hintText,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onChanged: _handleValueChanged,
            inputFormatters: _digitsOnlyInputFormatters,
          ),
        ),
        const SizedBox(width: calendarGutterSm),
        Expanded(
          child: AxiSelect<AlarmOffsetUnit>(
            initialValue: _unit,
            onChanged: (next) {
              if (next == null) {
                return;
              }
              setState(() => _unit = next);
              _handleValueChanged(_controller.text);
            },
            options: AlarmOffsetUnit.values
                .map(
                  (option) => ShadOption<AlarmOffsetUnit>(
                    value: option,
                    child: Text(option.label),
                  ),
                )
                .toList(growable: false),
            selectedOptionBuilder: (context, selected) => Text(selected.label),
            decoration: ShadDecoration(
              color: calendarContainerColor,
              border: ShadBorder.all(
                color: calendarBorderColor,
                radius: BorderRadius.circular(calendarBorderRadius),
                width: calendarBorderStroke,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: calendarGutterMd,
              vertical: calendarGutterSm,
            ),
            trailing: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: calendarGutterMd,
              color: calendarSubtitleColor,
            ),
          ),
        ),
      ],
    );
  }

  void _syncFromValue(Duration? value) {
    if (value == null) {
      _controller
        ..text = _emptyText
        ..selection = const TextSelection.collapsed(
          offset: _alarmTextSelectionOffset,
        );
      return;
    }
    final AlarmOffsetUnit resolvedUnit = _unitForDuration(value);
    final int amount = resolvedUnit.valueFrom(value);
    final String text = amount.toString();
    setState(() => _unit = resolvedUnit);
    _controller
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
  }

  AlarmOffsetUnit _unitForDuration(Duration duration) {
    for (final AlarmOffsetUnit unit in AlarmOffsetUnit.values.reversed) {
      if (unit.canRepresent(duration)) {
        return unit;
      }
    }
    return AlarmOffsetUnit.minutes;
  }

  void _handleValueChanged(String raw) {
    final int? parsed = int.tryParse(raw);
    if (parsed == null) {
      widget.onChanged(null);
      return;
    }
    if (parsed == _alarmMinNumericValue && !widget.allowZero) {
      widget.onChanged(null);
      return;
    }
    if (parsed < _alarmMinNumericValue) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(_unit.toDuration(parsed));
  }
}

class _AlarmRecipientsField extends StatefulWidget {
  const _AlarmRecipientsField({
    required this.recipients,
    required this.isCompact,
    required this.onChanged,
  });

  final List<CalendarAlarmRecipient> recipients;
  final bool isCompact;
  final ValueChanged<List<CalendarAlarmRecipient>> onChanged;

  @override
  State<_AlarmRecipientsField> createState() => _AlarmRecipientsFieldState();
}

class _AlarmRecipientsFieldState extends State<_AlarmRecipientsField> {
  late final TextEditingController _addressController;
  late final TextEditingController _nameController;
  final FocusNode _addressFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _nameController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget addressField = TaskTextField(
      controller: _addressController,
      focusNode: _addressFocusNode,
      hintText: _alarmRecipientAddressHint,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.emailAddress,
    );
    final Widget nameField = TaskTextField(
      controller: _nameController,
      hintText: _alarmRecipientNameHint,
      textInputAction: TextInputAction.done,
    );
    final Widget addButton = AxiIconButton(
      iconData: Icons.add,
      tooltip: _alarmsAddTooltip,
      onPressed: _addRecipient,
      color: calendarPrimaryColor,
      backgroundColor: calendarContainerColor,
      borderColor: calendarBorderColor,
      iconSize: calendarGutterLg,
      buttonSize: AxiIconButton.kDefaultSize,
      tapTargetSize: AxiIconButton.kTapTargetSize,
    );
    final Widget inputRow = widget.isCompact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              addressField,
              const SizedBox(height: calendarGutterSm),
              nameField,
              const SizedBox(height: calendarGutterSm),
              Align(
                alignment: Alignment.centerRight,
                child: addButton,
              ),
            ],
          )
        : Row(
            children: [
              Expanded(child: addressField),
              const SizedBox(width: calendarGutterSm),
              Expanded(child: nameField),
              const SizedBox(width: calendarGutterSm),
              addButton,
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AlarmFieldLabel(text: _alarmRecipientsLabel),
        const SizedBox(height: calendarInsetSm),
        inputRow,
        if (widget.recipients.isNotEmpty) ...[
          const SizedBox(height: calendarInsetMd),
          Wrap(
            spacing: calendarGutterSm,
            runSpacing: calendarInsetSm,
            children: widget.recipients
                .map(
                  (recipient) => _AlarmRecipientChip(
                    recipient: recipient,
                    onRemove: () => _removeRecipient(recipient),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }

  void _addRecipient() {
    final String address = _addressController.text.trim();
    if (address.isEmpty) {
      return;
    }
    final String? name = _nameController.text.trim().isEmpty
        ? null
        : _nameController.text.trim();
    final List<CalendarAlarmRecipient> next =
        List<CalendarAlarmRecipient>.from(widget.recipients);
    final bool exists = next.any(
      (recipient) => recipient.address.toLowerCase() == address.toLowerCase(),
    );
    if (exists) {
      _addressController
        ..clear()
        ..selection = const TextSelection.collapsed(
          offset: _alarmTextSelectionOffset,
        );
      _nameController.clear();
      _addressFocusNode.requestFocus();
      return;
    }
    next.add(
      CalendarAlarmRecipient(
        address: address,
        commonName: name,
      ),
    );
    widget.onChanged(next);
    _addressController
      ..clear()
      ..selection = const TextSelection.collapsed(
        offset: _alarmTextSelectionOffset,
      );
    _nameController.clear();
    _addressFocusNode.requestFocus();
  }

  void _removeRecipient(CalendarAlarmRecipient recipient) {
    final List<CalendarAlarmRecipient> next =
        List<CalendarAlarmRecipient>.from(widget.recipients)..remove(recipient);
    widget.onChanged(next);
  }
}

class _AlarmRecipientChip extends StatelessWidget {
  const _AlarmRecipientChip({
    required this.recipient,
    required this.onRemove,
  });

  final CalendarAlarmRecipient recipient;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w600,
    );
    final String display = recipient.commonName?.trim().isNotEmpty == true
        ? '${recipient.commonName} <${recipient.address}>'
        : recipient.address;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterSm,
        vertical: calendarInsetMd,
      ),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: calendarBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            display,
            style: labelStyle,
          ),
          const SizedBox(width: calendarInsetSm),
          AxiIconButton(
            iconData: Icons.close,
            tooltip: _alarmRecipientRemoveTooltip,
            onPressed: onRemove,
            color: calendarSubtitleColor,
            backgroundColor: calendarContainerColor,
            borderColor: calendarBorderColor,
            iconSize: calendarGutterMd,
            buttonSize: _alarmRecipientButtonSize,
            tapTargetSize: _alarmRecipientTapTargetSize,
          ),
        ],
      ),
    );
  }
}

class _AlarmAcknowledgedRow extends StatelessWidget {
  const _AlarmAcknowledgedRow({
    required this.value,
  });

  final DateTime value;

  @override
  Widget build(BuildContext context) {
    final String formatted = TimeFormatter.formatFriendlyDateTime(value);
    return Row(
      children: [
        const _AlarmFieldLabel(text: _alarmAcknowledgedLabel),
        const SizedBox(width: calendarGutterSm),
        Expanded(
          child: Text(
            formatted,
            style: context.textTheme.muted.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

const CalendarAlarm _defaultAlarmTemplate = CalendarAlarm(
  action: CalendarAlarmAction.display,
  trigger: CalendarAlarmTrigger(
    type: CalendarAlarmTriggerType.relative,
    absolute: null,
    offset: _alarmDefaultOffset,
    relativeTo: CalendarAlarmRelativeTo.start,
    offsetDirection: CalendarAlarmOffsetDirection.before,
  ),
  repeat: null,
  duration: null,
  description: null,
  summary: null,
  attachments: _emptyAlarmAttachments,
  acknowledged: null,
  recipients: _emptyRecipients,
);

CalendarAlarm _defaultAlarm() => _defaultAlarmTemplate;

CalendarDateTime _defaultAbsoluteDateTime(DateTime? referenceStart) {
  final DateTime base = referenceStart ?? DateTime.now();
  return CalendarDateTime(
    value: base,
    tzid: null,
    isAllDay: false,
    isFloating: !base.isUtc,
  );
}

CalendarDateTime _calendarDateTimeFrom(
  DateTime value, {
  required CalendarDateTime? template,
  required DateTime? referenceStart,
}) {
  final CalendarDateTime resolvedTemplate =
      template ?? _defaultAbsoluteDateTime(referenceStart);
  final bool isFloating = resolvedTemplate.isFloating ||
      (!value.isUtc && resolvedTemplate.tzid == null);
  return CalendarDateTime(
    value: value,
    tzid: resolvedTemplate.tzid,
    isAllDay: resolvedTemplate.isAllDay,
    isFloating: isFloating,
  );
}
