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
const double _participantLabelLetterSpacing = 0.2;
const double _participantLabelFontSize = 12;
const double _participantSelectIconSize = 16;
const int _participantTextSelectionOffset = 0;
const List<CalendarAttendee> _emptyAttendees = <CalendarAttendee>[];

class CalendarParticipantsField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskSectionHeader(title: title),
        const SizedBox(height: calendarGutterSm),
        _OrganizerField(
          organizer: organizer,
          onChanged: onOrganizerChanged,
          enabled: enabled,
        ),
        const SizedBox(height: calendarGutterMd),
        _AttendeesField(
          attendees: attendees,
          onChanged: onAttendeesChanged,
          enabled: enabled,
        ),
      ],
    );
    if (enabled) {
      return content;
    }
    return IgnorePointer(child: content);
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
    _addressController =
        TextEditingController(text: widget.organizer?.address ?? '');
    _nameController =
        TextEditingController(text: widget.organizer?.commonName ?? '');
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
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      color: calendarSubtitleColor,
      fontWeight: FontWeight.w600,
      letterSpacing: _participantLabelLetterSpacing,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_organizerSectionLabel.toUpperCase(), style: labelStyle),
        const SizedBox(height: calendarInsetSm),
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
                enabled: widget.enabled,
              ),
            ),
            const SizedBox(width: calendarGutterSm),
            Expanded(
              child: TaskTextField(
                controller: _nameController,
                labelText: _organizerNameLabel,
                hintText: _organizerNameHint,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => _handleChange(),
                enabled: widget.enabled,
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

    final List<CalendarAttendee> next =
        List<CalendarAttendee>.from(widget.attendees);
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

    next.add(
      CalendarAttendee(
        address: address,
        commonName: commonName,
      ),
    );
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
    final List<CalendarAttendee> next =
        List<CalendarAttendee>.from(widget.attendees)..remove(attendee);
    widget.onChanged(next);
  }

  void _updateAttendee(CalendarAttendee attendee, CalendarAttendee next) {
    final int index = widget.attendees.indexOf(attendee);
    if (index == -1) {
      return;
    }
    final List<CalendarAttendee> updated =
        List<CalendarAttendee>.from(widget.attendees);
    updated[index] = next;
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      color: calendarSubtitleColor,
      fontWeight: FontWeight.w600,
      letterSpacing: _participantLabelLetterSpacing,
    );
    final List<CalendarAttendee> attendees =
        widget.attendees.isEmpty ? _emptyAttendees : widget.attendees;
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
        const SizedBox(height: calendarInsetSm),
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
            const SizedBox(width: calendarGutterSm),
            Expanded(
              child: TaskTextField(
                controller: _nameController,
                hintText: _attendeeNameHint,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                enabled: enabled,
              ),
            ),
            const SizedBox(width: calendarGutterSm),
            AxiIconButton(
              iconData: Icons.add,
              tooltip: _attendeeAddTooltip,
              onPressed: enabled ? _addAttendee : null,
              color: enabled ? calendarPrimaryColor : calendarSubtitleColor,
              backgroundColor: calendarContainerColor,
              borderColor: calendarBorderColor,
              iconSize: calendarGutterLg,
              buttonSize: AxiIconButton.kDefaultSize,
              tapTargetSize: AxiIconButton.kTapTargetSize,
            ),
          ],
        ),
        if (attendees.isNotEmpty) ...[
          const SizedBox(height: calendarInsetMd),
          Column(
            children: attendees
                .map(
                  (attendee) => Padding(
                    padding: const EdgeInsets.only(bottom: calendarInsetMd),
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
    final TextStyle titleStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterSm,
        vertical: calendarInsetMd,
      ),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
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
                      const SizedBox(height: calendarInsetSm),
                      Text(secondary, style: subtitleStyle),
                    ],
                  ],
                ),
              ),
              _AttendeeRemoveButton(onPressed: onRemove),
            ],
          ),
          const SizedBox(height: calendarInsetMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ParticipantSelectField<CalendarParticipantRole?>(
                  label: _attendeeRoleLabel,
                  value: attendee.role,
                  options: roleOptions,
                  selectedLabel: (role) => role?.label ?? _attendeeDefaultLabel,
                  onChanged: (value) => onChanged(
                    attendee.copyWith(role: value),
                  ),
                ),
              ),
              const SizedBox(width: calendarGutterSm),
              Expanded(
                child: _ParticipantSelectField<CalendarParticipantStatus?>(
                  label: _attendeeStatusLabel,
                  value: attendee.status,
                  options: statusOptions,
                  selectedLabel: (status) =>
                      status?.label ?? _attendeeDefaultLabel,
                  onChanged: (value) => onChanged(
                    attendee.copyWith(status: value),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: calendarInsetSm),
          ShadSwitch(
            label: const Text(_attendeeRsvpLabel),
            value: attendee.rsvp,
            onChanged: (value) => onChanged(
              attendee.copyWith(rsvp: value),
            ),
          ),
          const SizedBox(height: calendarInsetSm),
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
    final TextStyle labelStyle = TextStyle(
      fontSize: _participantLabelFontSize,
      fontWeight: FontWeight.w600,
      color: calendarSubtitleColor,
      letterSpacing: _participantLabelLetterSpacing,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: labelStyle),
        const SizedBox(height: calendarInsetSm),
        ShadSelect<T>(
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
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: calendarGutterMd,
            vertical: calendarGutterSm,
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
    final Color baseColor = calendarSubtitleColor;
    final Color acceptColor =
        status?.isAccepted == true ? calendarSuccessColor : baseColor;
    final Color declineColor =
        status?.isDeclined == true ? calendarDangerColor : baseColor;
    final Color tentativeColor =
        status?.isTentative == true ? calendarWarningColor : baseColor;

    return Wrap(
      spacing: calendarGutterSm,
      runSpacing: calendarInsetSm,
      children: [
        TaskSecondaryButton(
          label: _attendeeActionAcceptLabel,
          onPressed: onAccept,
          foregroundColor: acceptColor,
        ),
        TaskSecondaryButton(
          label: _attendeeActionDeclineLabel,
          onPressed: onDecline,
          foregroundColor: declineColor,
        ),
        TaskSecondaryButton(
          label: _attendeeActionTentativeLabel,
          onPressed: onTentative,
          foregroundColor: tentativeColor,
        ),
      ],
    );
  }
}

class _AttendeeRemoveButton extends StatelessWidget {
  const _AttendeeRemoveButton({
    required this.onPressed,
  });

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
      iconSize: calendarGutterMd,
      buttonSize: AxiIconButton.kDefaultSize,
      tapTargetSize: AxiIconButton.kTapTargetSize,
    );
  }
}
