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
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

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

const Duration _alarmDefaultOffset = Duration(
  minutes: _alarmDefaultOffsetMinutes,
);

const List<CalendarAlarmRecipient> _emptyRecipients =
    <CalendarAlarmRecipient>[];
const List<CalendarAttachment> _emptyAlarmAttachments = <CalendarAttachment>[];
final List<TextInputFormatter> _digitsOnlyInputFormatters =
    List<TextInputFormatter>.unmodifiable(<TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
    ]);

enum AlarmOffsetUnit { minutes, hours, days, weeks }

extension AlarmOffsetUnitX on AlarmOffsetUnit {
  String label(AppLocalizations l10n) => switch (this) {
    AlarmOffsetUnit.minutes => l10n.calendarAlarmUnitMinutes,
    AlarmOffsetUnit.hours => l10n.calendarAlarmUnitHours,
    AlarmOffsetUnit.days => l10n.calendarAlarmUnitDays,
    AlarmOffsetUnit.weeks => l10n.calendarAlarmUnitWeeks,
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
  String label(AppLocalizations l10n) => switch (this) {
    CalendarAlarmAction.display => l10n.calendarAlarmActionDisplay,
    CalendarAlarmAction.audio => l10n.calendarAlarmActionAudio,
    CalendarAlarmAction.email => l10n.calendarAlarmActionEmail,
    CalendarAlarmAction.procedure => l10n.calendarAlarmActionProcedure,
  };
}

extension CalendarAlarmTriggerTypeLabelX on CalendarAlarmTriggerType {
  String label(AppLocalizations l10n) => switch (this) {
    CalendarAlarmTriggerType.relative => l10n.calendarAlarmTriggerRelative,
    CalendarAlarmTriggerType.absolute => l10n.calendarAlarmTriggerAbsolute,
  };
}

extension CalendarAlarmRelativeToLabelX on CalendarAlarmRelativeTo {
  String label(AppLocalizations l10n) => switch (this) {
    CalendarAlarmRelativeTo.start => l10n.calendarAlarmRelativeToStart,
    CalendarAlarmRelativeTo.end => l10n.calendarAlarmRelativeToEnd,
  };
}

extension CalendarAlarmOffsetDirectionLabelX on CalendarAlarmOffsetDirection {
  String label(AppLocalizations l10n) => switch (this) {
    CalendarAlarmOffsetDirection.before => l10n.calendarAlarmDirectionBefore,
    CalendarAlarmOffsetDirection.after => l10n.calendarAlarmDirectionAfter,
  };
}

class CalendarAlarmsField extends StatelessWidget {
  const CalendarAlarmsField({
    super.key,
    required this.alarms,
    required this.onChanged,
    this.title,
    this.referenceStart,
    this.showReminderNote = true,
    this.showHeader = true,
  });

  final List<CalendarAlarm> alarms;
  final ValueChanged<List<CalendarAlarm>> onChanged;
  final String? title;
  final DateTime? referenceStart;
  final bool showReminderNote;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final List<CalendarAlarm> items = alarms;
    final String titleLabel = title ?? context.l10n.calendarAlarmsTitle;
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
          TaskSectionHeader(title: titleLabel, trailing: addButton)
        else
          Align(alignment: Alignment.centerRight, child: addButton),
        if (showReminderNote) ...[
          SizedBox(height: context.spacing.xxs),
          Text(
            context.l10n.calendarAlarmsHelper,
            style: context.textTheme.muted,
          ),
        ],
        SizedBox(height: context.spacing.s),
        if (items.isEmpty)
          const _AlarmEmptyState()
        else
          Column(
            children: items
                .asMap()
                .entries
                .map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(bottom: context.spacing.m),
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
      context.l10n.calendarAlarmsEmpty,
      style: context.textTheme.muted,
    );
  }
}

class _AlarmAddButton extends StatelessWidget {
  const _AlarmAddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiIconButton(
      iconData: Icons.add,
      tooltip: context.l10n.calendarAlarmAddTooltip,
      onPressed: onPressed,
      color: calendarPrimaryColor,
      backgroundColor: calendarContainerColor,
      borderColor: calendarBorderColor,
      iconSize: context.spacing.m,
    );
  }
}

class _AlarmFieldLabel extends StatelessWidget {
  const _AlarmFieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.textTheme.label.strong.copyWith(
        color: calendarSubtitleColor,
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
          SizedBox(height: context.spacing.m),
          trailing,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: leading),
        SizedBox(width: context.spacing.m),
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
    final TextStyle titleStyle = context.textTheme.small.strong.copyWith(
      color: calendarTitleColor,
    );
    final TextStyle helperStyle = context.textTheme.muted;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth <= _alarmCompactWidth;
        final Widget actionField = _AlarmActionField(
          action: alarm.action,
          enabled: !isProcedure,
          helper: isProcedure
              ? Text(
                  context.l10n.calendarAlarmActionProcedureHelper,
                  style: helperStyle,
                )
              : null,
          onChanged: (next) {
            widget.onChanged(alarm.copyWith(action: next));
          },
        );
        final Widget triggerField = _AlarmTriggerTypeField(
          trigger: trigger,
          referenceStart: widget.referenceStart,
          onChanged: (next) => widget.onChanged(alarm.copyWith(trigger: next)),
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
                    alarm.copyWith(trigger: trigger.copyWith(absolute: next)),
                  );
                },
              )
            : _AlarmRelativeTriggerField(
                trigger: trigger,
                isCompact: isCompact,
                onChanged: (next) =>
                    widget.onChanged(alarm.copyWith(trigger: next)),
              );

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.m,
            vertical: context.spacing.m,
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
                    context.l10n.calendarAlarmItemLabel(
                      widget.index + _alarmIndexOffset,
                    ),
                    style: titleStyle,
                  ),
                  const Spacer(),
                  AxiIconButton(
                    iconData: Icons.close,
                    tooltip: context.l10n.calendarAlarmRemoveTooltip,
                    onPressed: widget.onRemove,
                    color: calendarSubtitleColor,
                    backgroundColor: calendarContainerColor,
                    borderColor: calendarBorderColor,
                    iconSize: context.spacing.m,
                    buttonSize: _alarmRemoveButtonSize,
                    tapTargetSize: _alarmRemoveTapTargetSize,
                  ),
                ],
              ),
              SizedBox(height: context.spacing.xs),
              actionTriggerRow,
              SizedBox(height: context.spacing.m),
              triggerDetails,
              SizedBox(height: context.spacing.m),
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
                SizedBox(height: context.spacing.m),
                _AlarmRecipientsField(
                  recipients: alarm.recipients,
                  isCompact: isCompact,
                  onChanged: (next) =>
                      widget.onChanged(alarm.copyWith(recipients: next)),
                ),
              ],
              if (alarm.acknowledged != null) ...[
                SizedBox(height: context.spacing.m),
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
    final TextStyle valueStyle = context.textTheme.small.strong.copyWith(
      color: calendarTitleColor,
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
                    child: Text(option.label(context.l10n)),
                  ),
                )
                .toList(growable: false),
            selectedOptionBuilder: (context, selected) =>
                Text(selected.label(context.l10n)),
            decoration: ShadDecoration(
              color: calendarContainerColor,
              border: ShadBorder.all(
                color: calendarBorderColor,
                radius: BorderRadius.circular(calendarBorderRadius),
                width: calendarBorderStroke,
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.m,
              vertical: context.spacing.s,
            ),
            trailing: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: context.spacing.m,
              color: calendarSubtitleColor,
            ),
          )
        : Text(action.label(context.l10n), style: valueStyle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AlarmFieldLabel(text: context.l10n.calendarAlarmActionLabel),
        SizedBox(height: context.spacing.xxs),
        content,
        if (helperWidget != null) ...[
          SizedBox(height: context.spacing.xxs),
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
        _AlarmFieldLabel(text: context.l10n.calendarAlarmTriggerLabel),
        SizedBox(height: context.spacing.xxs),
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
                  child: Text(option.label(context.l10n)),
                ),
              )
              .toList(growable: false),
          selectedOptionBuilder: (context, selected) =>
              Text(selected.label(context.l10n)),
          decoration: ShadDecoration(
            color: calendarContainerColor,
            border: ShadBorder.all(
              color: calendarBorderColor,
              radius: BorderRadius.circular(calendarBorderRadius),
              width: calendarBorderStroke,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.m,
            vertical: context.spacing.s,
          ),
          trailing: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: context.spacing.m,
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
      placeholder: context.l10n.calendarAlarmAbsolutePlaceholder,
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
        label: context.l10n.calendarAlarmRelativeToLabel,
        value: relativeTo,
        onChanged: (next) => onChanged(trigger.copyWith(relativeTo: next)),
      ),
      trailing: _AlarmOffsetDirectionRow(
        label: context.l10n.calendarAlarmDirectionLabel,
        value: direction,
        onChanged: (next) => onChanged(trigger.copyWith(offsetDirection: next)),
      ),
      isCompact: isCompact,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        relativeRow,
        SizedBox(height: context.spacing.xs),
        _AlarmDurationRow(
          label: context.l10n.calendarAlarmOffsetLabel,
          hintText: context.l10n.calendarAlarmOffsetHint,
          value: offset,
          allowZero: true,
          onChanged: (next) => onChanged(trigger.copyWith(offset: next)),
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
      labelFor: (value) => value.label(context.l10n),
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
      labelFor: (value) => value.label(context.l10n),
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
        SizedBox(height: context.spacing.xxs),
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
                (option) =>
                    ShadOption<T>(value: option, child: Text(labelFor(option))),
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
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.m,
            vertical: context.spacing.s,
          ),
          trailing: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: context.spacing.m,
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
      label: context.l10n.calendarAlarmRepeatEveryLabel,
      hintText: context.l10n.calendarAlarmOffsetHint,
      value: duration,
      allowZero: false,
      onChanged: onDurationChanged,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AlarmFieldLabel(text: context.l10n.calendarAlarmRepeatLabel),
        SizedBox(height: context.spacing.xxs),
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
        _AlarmFieldLabel(text: context.l10n.calendarAlarmRepeatCountHint),
        SizedBox(height: context.spacing.xxs),
        TaskTextField(
          controller: controller,
          hintText: context.l10n.calendarAlarmRepeatCountHint,
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
        SizedBox(height: context.spacing.xxs),
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
        SizedBox(width: context.spacing.s),
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
                    child: Text(option.label(context.l10n)),
                  ),
                )
                .toList(growable: false),
            selectedOptionBuilder: (context, selected) =>
                Text(selected.label(context.l10n)),
            decoration: ShadDecoration(
              color: calendarContainerColor,
              border: ShadBorder.all(
                color: calendarBorderColor,
                radius: BorderRadius.circular(calendarBorderRadius),
                width: calendarBorderStroke,
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.m,
              vertical: context.spacing.s,
            ),
            trailing: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: context.spacing.m,
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
      hintText: context.l10n.calendarAlarmRecipientAddressHint,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.emailAddress,
    );
    final Widget nameField = TaskTextField(
      controller: _nameController,
      hintText: context.l10n.calendarAlarmRecipientNameHint,
      textInputAction: TextInputAction.done,
    );
    final Widget addButton = AxiIconButton(
      iconData: Icons.add,
      tooltip: context.l10n.calendarAlarmAddTooltip,
      onPressed: _addRecipient,
      color: calendarPrimaryColor,
      backgroundColor: calendarContainerColor,
      borderColor: calendarBorderColor,
      iconSize: context.spacing.m,
    );
    final Widget inputRow = widget.isCompact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              addressField,
              SizedBox(height: context.spacing.s),
              nameField,
              SizedBox(height: context.spacing.s),
              Align(alignment: Alignment.centerRight, child: addButton),
            ],
          )
        : Row(
            children: [
              Expanded(child: addressField),
              SizedBox(width: context.spacing.s),
              Expanded(child: nameField),
              SizedBox(width: context.spacing.s),
              addButton,
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AlarmFieldLabel(text: context.l10n.calendarAlarmRecipientsLabel),
        SizedBox(height: context.spacing.xxs),
        inputRow,
        if (widget.recipients.isNotEmpty) ...[
          SizedBox(height: context.spacing.xs),
          Wrap(
            spacing: context.spacing.s,
            runSpacing: context.spacing.xxs,
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
    final List<CalendarAlarmRecipient> next = List<CalendarAlarmRecipient>.from(
      widget.recipients,
    );
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
    next.add(CalendarAlarmRecipient(address: address, commonName: name));
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
    final List<CalendarAlarmRecipient> next = List<CalendarAlarmRecipient>.from(
      widget.recipients,
    )..remove(recipient);
    widget.onChanged(next);
  }
}

class _AlarmRecipientChip extends StatelessWidget {
  const _AlarmRecipientChip({required this.recipient, required this.onRemove});

  final CalendarAlarmRecipient recipient;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.small.strong.copyWith(
      color: calendarTitleColor,
    );
    final String display = recipient.commonName?.trim().isNotEmpty == true
        ? context.l10n.calendarAlarmRecipientDisplay(
            recipient.commonName!,
            recipient.address,
          )
        : recipient.address;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.s,
        vertical: context.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: context.radius,
        border: Border.all(color: calendarBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(display, style: labelStyle),
          SizedBox(width: context.spacing.xxs),
          AxiIconButton(
            iconData: Icons.close,
            tooltip: context.l10n.calendarAlarmRecipientRemoveTooltip,
            onPressed: onRemove,
            color: calendarSubtitleColor,
            backgroundColor: calendarContainerColor,
            borderColor: calendarBorderColor,
            iconSize: context.spacing.m,
            buttonSize: _alarmRecipientButtonSize,
            tapTargetSize: _alarmRecipientTapTargetSize,
          ),
        ],
      ),
    );
  }
}

class _AlarmAcknowledgedRow extends StatelessWidget {
  const _AlarmAcknowledgedRow({required this.value});

  final DateTime value;

  @override
  Widget build(BuildContext context) {
    final String formatted = TimeFormatter.formatFriendlyDateTime(
      context.l10n,
      value,
    );
    return Row(
      children: [
        _AlarmFieldLabel(text: context.l10n.calendarAlarmAcknowledgedLabel),
        SizedBox(width: context.spacing.s),
        Expanded(child: Text(formatted, style: context.textTheme.muted)),
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
  final bool isFloating =
      resolvedTemplate.isFloating ||
      (!value.isUtc && resolvedTemplate.tzid == null);
  return CalendarDateTime(
    value: value,
    tzid: resolvedTemplate.tzid,
    isAllDay: resolvedTemplate.isAllDay,
    isFloating: isFloating,
  );
}
