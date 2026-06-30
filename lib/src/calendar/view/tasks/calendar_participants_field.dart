// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_participant.dart';
import 'package:axichat/src/calendar/view/tasks/task_form_section.dart';
import 'package:axichat/src/calendar/view/tasks/task_text_field.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

const double _participantSelectIconSize = 16;
const int _participantTextSelectionOffset = 0;
const List<CalendarAttendee> _emptyAttendees = <CalendarAttendee>[];

String _participantRoleLabel(
  AppLocalizations l10n,
  CalendarParticipantRole role,
) => switch (role) {
  CalendarParticipantRole.chair => l10n.calendarParticipantRoleChair,
  CalendarParticipantRole.requiredParticipant =>
    l10n.calendarParticipantRoleRequired,
  CalendarParticipantRole.optionalParticipant =>
    l10n.calendarParticipantRoleOptional,
  CalendarParticipantRole.nonParticipant =>
    l10n.calendarParticipantRoleNonParticipant,
};

String _participantStatusLabel(
  AppLocalizations l10n,
  CalendarParticipantStatus status,
) => switch (status) {
  CalendarParticipantStatus.needsAction =>
    l10n.calendarParticipantStatusNeedsAction,
  CalendarParticipantStatus.accepted => l10n.calendarParticipantStatusAccepted,
  CalendarParticipantStatus.declined => l10n.calendarParticipantStatusDeclined,
  CalendarParticipantStatus.tentative =>
    l10n.calendarParticipantStatusTentative,
  CalendarParticipantStatus.delegated =>
    l10n.calendarParticipantStatusDelegated,
  CalendarParticipantStatus.completed =>
    l10n.calendarParticipantStatusCompleted,
  CalendarParticipantStatus.inProcess =>
    l10n.calendarParticipantStatusInProcess,
};

class CalendarParticipantsField extends StatefulWidget {
  const CalendarParticipantsField({
    super.key,
    required this.organizer,
    required this.attendees,
    required this.onOrganizerChanged,
    required this.onAttendeesChanged,
    this.title,
    this.headerSize = TaskSectionLabelSize.medium,
    this.inputVariant = AxiInputVariant.ghost,
    this.enabled = true,
  });

  final CalendarOrganizer? organizer;
  final List<CalendarAttendee> attendees;
  final ValueChanged<CalendarOrganizer?> onOrganizerChanged;
  final ValueChanged<List<CalendarAttendee>> onAttendeesChanged;
  final String? title;
  final TaskSectionLabelSize headerSize;
  final AxiInputVariant inputVariant;
  final bool enabled;

  @override
  State<CalendarParticipantsField> createState() =>
      _CalendarParticipantsFieldState();
}

class _CalendarParticipantsFieldState extends State<CalendarParticipantsField> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = _shouldStartExpanded(widget);
  }

  @override
  void didUpdateWidget(covariant CalendarParticipantsField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_expanded && _shouldStartExpanded(widget)) {
      setState(() => _expanded = true);
    }
  }

  bool _shouldStartExpanded(CalendarParticipantsField widget) {
    final String? address = widget.organizer?.address.trim();
    final String? name = widget.organizer?.commonName?.trim();
    final bool hasOrganizer =
        (address != null && address.isNotEmpty) ||
        (name != null && name.isNotEmpty);
    return hasOrganizer || widget.attendees.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OrganizerField(
          organizer: widget.organizer,
          onChanged: widget.onOrganizerChanged,
          enabled: widget.enabled,
          inputVariant: widget.inputVariant,
        ),
        SizedBox(height: context.spacing.m),
        _AttendeesField(
          attendees: widget.attendees,
          onChanged: widget.onAttendeesChanged,
          enabled: widget.enabled,
          inputVariant: widget.inputVariant,
        ),
      ],
    );
    return TaskSectionExpander(
      title: widget.title ?? context.l10n.calendarParticipantsSectionTitle,
      headerSize: widget.headerSize,
      isExpanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
      enabled: widget.enabled,
      child: content,
    );
  }
}

class _OrganizerField extends StatefulWidget {
  const _OrganizerField({
    required this.organizer,
    required this.onChanged,
    required this.enabled,
    required this.inputVariant,
  });

  final CalendarOrganizer? organizer;
  final ValueChanged<CalendarOrganizer?> onChanged;
  final bool enabled;
  final AxiInputVariant inputVariant;

  @override
  State<_OrganizerField> createState() => _OrganizerFieldState();
}

class _OrganizerFieldState extends State<_OrganizerField> {
  late final TextEditingController _addressController;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(
      text: widget.organizer?.address ?? '',
    );
    _nameController = TextEditingController(
      text: widget.organizer?.commonName ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _OrganizerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextAddress = widget.organizer?.address ?? '';
    _syncController(_addressController, nextAddress);
    final String nextName = widget.organizer?.commonName ?? '';
    _syncController(_nameController, nextName);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _handleChange() {
    final String address = _addressController.text.trim();
    final String name = _nameController.text.trim();
    final String? commonName = name.isEmpty ? null : name;

    if (address.isEmpty) {
      widget.onChanged(null);
      return;
    }

    final CalendarOrganizer base =
        widget.organizer ?? CalendarOrganizer(address: address);
    final CalendarOrganizer next = base.copyWith(
      address: address,
      commonName: commonName,
    );
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool enabled = widget.enabled;
    final TextStyle labelStyle = context.textTheme.labelSm.strong;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.calendarParticipantsOrganizerLabel.toUpperCase(),
          style: labelStyle,
        ),
        SizedBox(height: context.spacing.xxs),
        Row(
          children: [
            Expanded(
              child: TaskTextField(
                controller: _addressController,
                hintText: l10n.calendarParticipantsOrganizerAddressHint,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.none,
                onChanged: (_) => _handleChange(),
                enabled: enabled,
                variant: widget.inputVariant,
              ),
            ),
            SizedBox(width: context.spacing.s),
            Expanded(
              child: TaskTextField(
                controller: _nameController,
                hintText: l10n.calendarParticipantsOrganizerNameHint,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => _handleChange(),
                enabled: enabled,
                variant: widget.inputVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AttendeesField extends StatefulWidget {
  const _AttendeesField({
    required this.attendees,
    required this.onChanged,
    required this.enabled,
    required this.inputVariant,
  });

  final List<CalendarAttendee> attendees;
  final ValueChanged<List<CalendarAttendee>> onChanged;
  final bool enabled;
  final AxiInputVariant inputVariant;

  @override
  State<_AttendeesField> createState() => _AttendeesFieldState();
}

class _AttendeesFieldState extends State<_AttendeesField> {
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

  void _addAttendee() {
    final String address = _addressController.text.trim();
    if (address.isEmpty) {
      return;
    }
    final String name = _nameController.text.trim();
    final String? commonName = name.isEmpty ? null : name;

    final List<CalendarAttendee> next = List<CalendarAttendee>.from(
      widget.attendees,
    );
    final bool exists = next.any(
      (attendee) => attendee.address.toLowerCase() == address.toLowerCase(),
    );
    if (exists) {
      _addressController
        ..clear()
        ..selection = const TextSelection.collapsed(
          offset: _participantTextSelectionOffset,
        );
      _nameController.clear();
      _addressFocusNode.requestFocus();
      return;
    }

    next.add(CalendarAttendee(address: address, commonName: commonName));
    widget.onChanged(next);
    _addressController
      ..clear()
      ..selection = const TextSelection.collapsed(
        offset: _participantTextSelectionOffset,
      );
    _nameController.clear();
    _addressFocusNode.requestFocus();
  }

  void _removeAttendee(CalendarAttendee attendee) {
    final List<CalendarAttendee> next = List<CalendarAttendee>.from(
      widget.attendees,
    )..remove(attendee);
    widget.onChanged(next);
  }

  void _updateAttendee(CalendarAttendee attendee, CalendarAttendee next) {
    final int index = widget.attendees.indexOf(attendee);
    if (index == -1) {
      return;
    }
    final List<CalendarAttendee> updated = List<CalendarAttendee>.from(
      widget.attendees,
    );
    updated[index] = next;
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool enabled = widget.enabled;
    final TextStyle labelStyle = context.textTheme.labelSm.strong;
    final List<CalendarAttendee> attendees = widget.attendees.isEmpty
        ? _emptyAttendees
        : widget.attendees;
    final List<AxiDropdownOption<CalendarParticipantRole?>> roleOptions = [
      AxiDropdownOption<CalendarParticipantRole?>(
        value: null,
        label: l10n.calendarParticipantsDefaultLabel,
        child: Text(l10n.calendarParticipantsDefaultLabel),
      ),
      ...CalendarParticipantRole.values.map(
        (role) => AxiDropdownOption<CalendarParticipantRole?>(
          value: role,
          label: _participantRoleLabel(l10n, role),
          child: Text(_participantRoleLabel(l10n, role)),
        ),
      ),
    ];
    final List<AxiDropdownOption<CalendarParticipantStatus?>> statusOptions = [
      AxiDropdownOption<CalendarParticipantStatus?>(
        value: null,
        label: l10n.calendarParticipantsDefaultLabel,
        child: Text(l10n.calendarParticipantsDefaultLabel),
      ),
      ...CalendarParticipantStatus.values.map(
        (status) => AxiDropdownOption<CalendarParticipantStatus?>(
          value: status,
          label: _participantStatusLabel(l10n, status),
          child: Text(_participantStatusLabel(l10n, status)),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.calendarParticipantsAttendeesLabel.toUpperCase(),
          style: labelStyle,
        ),
        SizedBox(height: context.spacing.xxs),
        Row(
          children: [
            Expanded(
              child: TaskTextField(
                controller: _addressController,
                focusNode: _addressFocusNode,
                hintText: l10n.calendarParticipantsAttendeeAddressHint,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
                enabled: enabled,
                variant: widget.inputVariant,
              ),
            ),
            SizedBox(width: context.spacing.s),
            Expanded(
              child: TaskTextField(
                controller: _nameController,
                hintText: l10n.calendarParticipantsAttendeeNameHint,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                enabled: enabled,
                variant: widget.inputVariant,
              ),
            ),
            SizedBox(width: context.spacing.s),
            AxiIconButton(
              iconData: Icons.add,
              tooltip: l10n.calendarParticipantsAddAttendeeTooltip,
              onPressed: enabled ? _addAttendee : null,
              color: enabled ? calendarPrimaryColor : calendarSubtitleColor,
              backgroundColor: calendarContainerColor,
              borderColor: calendarBorderColor,
              iconSize: context.spacing.m,
            ),
          ],
        ),
        if (attendees.isNotEmpty) ...[
          SizedBox(height: context.spacing.xs),
          Column(
            children: attendees
                .map(
                  (attendee) => Padding(
                    padding: EdgeInsets.only(bottom: context.spacing.xs),
                    child: _AttendeeCard(
                      attendee: attendee,
                      roleOptions: roleOptions,
                      statusOptions: statusOptions,
                      onChanged: (next) => _updateAttendee(attendee, next),
                      onRemove: () => _removeAttendee(attendee),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _AttendeeCard extends StatelessWidget {
  const _AttendeeCard({
    required this.attendee,
    required this.roleOptions,
    required this.statusOptions,
    required this.onChanged,
    required this.onRemove,
  });

  final CalendarAttendee attendee;
  final List<AxiDropdownOption<CalendarParticipantRole?>> roleOptions;
  final List<AxiDropdownOption<CalendarParticipantStatus?>> statusOptions;
  final ValueChanged<CalendarAttendee> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final TextStyle titleStyle = context.textTheme.small.strong.copyWith(
      color: calendarTitleColor,
    );
    final TextStyle subtitleStyle = context.textTheme.muted.copyWith(
      color: calendarSubtitleColor,
    );
    final String displayName = attendee.displayName;
    final String? secondary =
        attendee.commonName != null && attendee.commonName!.trim().isNotEmpty
        ? attendee.address
        : null;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: titleStyle),
                    if (secondary != null) ...[
                      SizedBox(height: context.spacing.xxs),
                      Text(secondary, style: subtitleStyle),
                    ],
                  ],
                ),
              ),
              _AttendeeRemoveButton(onPressed: onRemove),
            ],
          ),
          SizedBox(height: context.spacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ParticipantSelectField<CalendarParticipantRole?>(
                  label: l10n.calendarParticipantsRoleLabel,
                  value: attendee.role,
                  options: roleOptions,
                  defaultLabel: l10n.calendarParticipantsDefaultLabel,
                  selectedLabel: (role) => role == null
                      ? l10n.calendarParticipantsDefaultLabel
                      : _participantRoleLabel(l10n, role),
                  onChanged: (value) =>
                      onChanged(attendee.copyWith(role: value)),
                ),
              ),
              SizedBox(width: context.spacing.s),
              Expanded(
                child: _ParticipantSelectField<CalendarParticipantStatus?>(
                  label: l10n.calendarParticipantsStatusLabel,
                  value: attendee.status,
                  options: statusOptions,
                  defaultLabel: l10n.calendarParticipantsDefaultLabel,
                  selectedLabel: (status) => status == null
                      ? l10n.calendarParticipantsDefaultLabel
                      : _participantStatusLabel(l10n, status),
                  onChanged: (value) =>
                      onChanged(attendee.copyWith(status: value)),
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.xxs),
          ShadSwitch(
            label: Text(l10n.calendarParticipantsRsvpLabel),
            value: attendee.rsvp,
            onChanged: (value) => onChanged(attendee.copyWith(rsvp: value)),
          ),
          SizedBox(height: context.spacing.xxs),
          _ParticipantActionsRow(
            status: attendee.status,
            onAccept: () => onChanged(
              attendee.copyWith(status: CalendarParticipantStatus.accepted),
            ),
            onDecline: () => onChanged(
              attendee.copyWith(status: CalendarParticipantStatus.declined),
            ),
            onTentative: () => onChanged(
              attendee.copyWith(status: CalendarParticipantStatus.tentative),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantSelectField<T> extends StatelessWidget {
  const _ParticipantSelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.defaultLabel,
    required this.selectedLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<AxiDropdownOption<T>> options;
  final String defaultLabel;
  final String Function(T value) selectedLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.labelSm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: labelStyle),
        SizedBox(height: context.spacing.xxs),
        AxiDropdown<T>(
          value: value,
          widthBehavior: AxiButtonWidth.expand,
          onChanged: onChanged,
          options: options,
          selectedBuilder: (context, selected) =>
              Text(selected == null ? defaultLabel : selectedLabel(selected)),
          decoration: ShadDecoration(
            color: calendarContainerColor,
            border: ShadBorder.all(
              color: calendarBorderColor,
              radius: BorderRadius.circular(calendarBorderRadius),
              width: context.borderSide.width,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.m,
            vertical: context.spacing.s,
          ),
          trailing: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: _participantSelectIconSize,
            color: calendarSubtitleColor,
          ),
        ),
      ],
    );
  }
}

class _ParticipantActionsRow extends StatelessWidget {
  const _ParticipantActionsRow({
    required this.status,
    required this.onAccept,
    required this.onDecline,
    required this.onTentative,
  });

  final CalendarParticipantStatus? status;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onTentative;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.spacing.s,
      runSpacing: context.spacing.xxs,
      children: [
        AxiButton.outline(
          onPressed: onAccept,
          child: Text(context.l10n.calendarParticipantsAcceptAction),
        ),
        AxiButton.outline(
          onPressed: onDecline,
          child: Text(context.l10n.calendarParticipantsDeclineAction),
        ),
        AxiButton.outline(
          onPressed: onTentative,
          child: Text(context.l10n.calendarParticipantsTentativeAction),
        ),
      ],
    );
  }
}

class _AttendeeRemoveButton extends StatelessWidget {
  const _AttendeeRemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiIconButton(
      iconData: Icons.close,
      tooltip: context.l10n.calendarParticipantsRemoveAttendeeTooltip,
      onPressed: onPressed,
      color: calendarSubtitleColor,
      backgroundColor: calendarContainerColor,
      borderColor: calendarBorderColor,
      iconSize: context.spacing.m,
    );
  }
}
