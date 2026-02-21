// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_participant.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/calendar/view/widgets/task_text_field.dart';
import 'package:axichat/src/common/ui/ui.dart';

const String _participantsSectionTitle = 'People';
const String _organizerSectionLabel = 'Organizer';
const String _attendeesSectionLabel = 'Attendees';
const String _organizerNameLabel = 'Name';
const String _organizerAddressLabel = 'Address';
const String _organizerNameHint = 'Organizer name';
const String _organizerAddressHint = 'Organizer address';
const String _attendeeAddressHint = 'Add attendee';
const String _attendeeNameHint = 'Name (optional)';
const String _attendeeAddTooltip = 'Add attendee';
const String _attendeeRemoveTooltip = 'Remove attendee';
const String _attendeeRoleLabel = 'Role';
const String _attendeeStatusLabel = 'Status';
const String _attendeeRsvpLabel = 'RSVP';
const String _attendeeDefaultLabel = 'Default';
const String _attendeeActionAcceptLabel = 'Accept';
const String _attendeeActionDeclineLabel = 'Decline';
const String _attendeeActionTentativeLabel = 'Tentative';
const double _participantSelectIconSize = 16;
const int _participantTextSelectionOffset = 0;
const List<CalendarAttendee> _emptyAttendees = <CalendarAttendee>[];

class CalendarParticipantsField extends StatefulWidget {
  const CalendarParticipantsField({
    super.key,
    required this.organizer,
    required this.attendees,
    required this.onOrganizerChanged,
    required this.onAttendeesChanged,
    this.title = _participantsSectionTitle,
    this.enabled = true,
  });

  final CalendarOrganizer? organizer;
  final List<CalendarAttendee> attendees;
  final ValueChanged<CalendarOrganizer?> onOrganizerChanged;
  final ValueChanged<List<CalendarAttendee>> onAttendeesChanged;
  final String title;
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
        ),
        SizedBox(height: context.spacing.m),
        _AttendeesField(
          attendees: widget.attendees,
          onChanged: widget.onAttendeesChanged,
          enabled: widget.enabled,
        ),
      ],
    );
    return TaskSectionExpander(
      title: widget.title,
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
  });

  final CalendarOrganizer? organizer;
  final ValueChanged<CalendarOrganizer?> onChanged;
  final bool enabled;

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
    final bool enabled = widget.enabled;
    final TextStyle labelStyle = context.textTheme.sectionLabelM;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_organizerSectionLabel.toUpperCase(), style: labelStyle),
        SizedBox(height: context.spacing.xxs),
        Row(
          children: [
            Expanded(
              child: TaskTextField(
                controller: _addressController,
                labelText: _organizerAddressLabel,
                hintText: _organizerAddressHint,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.none,
                onChanged: (_) => _handleChange(),
                enabled: enabled,
              ),
            ),
            SizedBox(width: context.spacing.s),
            Expanded(
              child: TaskTextField(
                controller: _nameController,
                labelText: _organizerNameLabel,
                hintText: _organizerNameHint,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => _handleChange(),
                enabled: enabled,
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
  });

  final List<CalendarAttendee> attendees;
  final ValueChanged<List<CalendarAttendee>> onChanged;
  final bool enabled;

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
    final bool enabled = widget.enabled;
    final TextStyle labelStyle = context.textTheme.sectionLabelM;
    final List<CalendarAttendee> attendees = widget.attendees.isEmpty
        ? _emptyAttendees
        : widget.attendees;
    final List<ShadOption<CalendarParticipantRole?>> roleOptions = [
      const ShadOption<CalendarParticipantRole?>(
        value: null,
        child: Text(_attendeeDefaultLabel),
      ),
      ...CalendarParticipantRole.values.map(
        (role) => ShadOption<CalendarParticipantRole?>(
          value: role,
          child: Text(role.label),
        ),
      ),
    ];
    final List<ShadOption<CalendarParticipantStatus?>> statusOptions = [
      const ShadOption<CalendarParticipantStatus?>(
        value: null,
        child: Text(_attendeeDefaultLabel),
      ),
      ...CalendarParticipantStatus.values.map(
        (status) => ShadOption<CalendarParticipantStatus?>(
          value: status,
          child: Text(status.label),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_attendeesSectionLabel.toUpperCase(), style: labelStyle),
        SizedBox(height: context.spacing.xxs),
        Row(
          children: [
            Expanded(
              child: TaskTextField(
                controller: _addressController,
                focusNode: _addressFocusNode,
                hintText: _attendeeAddressHint,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
                enabled: enabled,
              ),
            ),
            SizedBox(width: context.spacing.s),
            Expanded(
              child: TaskTextField(
                controller: _nameController,
                hintText: _attendeeNameHint,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                enabled: enabled,
              ),
            ),
            SizedBox(width: context.spacing.s),
            AxiIconButton(
              iconData: Icons.add,
              tooltip: _attendeeAddTooltip,
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
  final List<ShadOption<CalendarParticipantRole?>> roleOptions;
  final List<ShadOption<CalendarParticipantStatus?>> statusOptions;
  final ValueChanged<CalendarAttendee> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
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
                  label: _attendeeRoleLabel,
                  value: attendee.role,
                  options: roleOptions,
                  selectedLabel: (role) => role?.label ?? _attendeeDefaultLabel,
                  onChanged: (value) =>
                      onChanged(attendee.copyWith(role: value)),
                ),
              ),
              SizedBox(width: context.spacing.s),
              Expanded(
                child: _ParticipantSelectField<CalendarParticipantStatus?>(
                  label: _attendeeStatusLabel,
                  value: attendee.status,
                  options: statusOptions,
                  selectedLabel: (status) =>
                      status?.label ?? _attendeeDefaultLabel,
                  onChanged: (value) =>
                      onChanged(attendee.copyWith(status: value)),
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.xxs),
          ShadSwitch(
            label: const Text(_attendeeRsvpLabel),
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
    required this.selectedLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<ShadOption<T>> options;
  final String Function(T value) selectedLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.sectionLabelM;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: labelStyle),
        SizedBox(height: context.spacing.xxs),
        AxiSelect<T>(
          initialValue: value,
          onChanged: onChanged,
          options: options,
          selectedOptionBuilder: (context, selected) => Text(
            selected == null ? _attendeeDefaultLabel : selectedLabel(selected),
          ),
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
          child: const Text(_attendeeActionAcceptLabel),
        ),
        AxiButton.outline(
          onPressed: onDecline,
          child: const Text(_attendeeActionDeclineLabel),
        ),
        AxiButton.outline(
          onPressed: onTentative,
          child: const Text(_attendeeActionTentativeLabel),
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
      tooltip: _attendeeRemoveTooltip,
      onPressed: onPressed,
      color: calendarSubtitleColor,
      backgroundColor: calendarContainerColor,
      borderColor: calendarBorderColor,
      iconSize: context.spacing.m,
    );
  }
}
