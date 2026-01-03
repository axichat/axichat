// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'calendar_participant.freezed.dart';
part 'calendar_participant.g.dart';

const int _calendarParticipantRoleTypeId = 61;
const int _calendarParticipantRoleChairField = 0;
const int _calendarParticipantRoleRequiredField = 1;
const int _calendarParticipantRoleOptionalField = 2;
const int _calendarParticipantRoleNonParticipantField = 3;

const int _calendarParticipantStatusTypeId = 62;
const int _calendarParticipantStatusNeedsActionField = 0;
const int _calendarParticipantStatusAcceptedField = 1;
const int _calendarParticipantStatusDeclinedField = 2;
const int _calendarParticipantStatusTentativeField = 3;
const int _calendarParticipantStatusDelegatedField = 4;
const int _calendarParticipantStatusCompletedField = 5;
const int _calendarParticipantStatusInProcessField = 6;

const int _calendarParticipantTypeTypeId = 63;
const int _calendarParticipantTypeIndividualField = 0;
const int _calendarParticipantTypeGroupField = 1;
const int _calendarParticipantTypeResourceField = 2;
const int _calendarParticipantTypeRoomField = 3;
const int _calendarParticipantTypeUnknownField = 4;

const int _calendarOrganizerTypeId = 64;
const int _calendarAttendeeTypeId = 65;

const int _calendarParticipantAddressField = 0;
const int _calendarParticipantCommonNameField = 1;
const int _calendarParticipantDirectoryField = 2;
const int _calendarParticipantSentByField = 3;
const int _calendarParticipantRoleField = 4;
const int _calendarParticipantStatusField = 5;
const int _calendarParticipantTypeField = 6;
const int _calendarParticipantRsvpField = 7;
const int _calendarParticipantDelegatedToField = 8;
const int _calendarParticipantDelegatedFromField = 9;
const int _calendarParticipantMembersField = 10;

const String _participantRoleChairIcs = 'CHAIR';
const String _participantRoleRequiredIcs = 'REQ-PARTICIPANT';
const String _participantRoleOptionalIcs = 'OPT-PARTICIPANT';
const String _participantRoleNonParticipantIcs = 'NON-PARTICIPANT';
const String _participantRoleChairLabel = 'Chair';
const String _participantRoleRequiredLabel = 'Required';
const String _participantRoleOptionalLabel = 'Optional';
const String _participantRoleNonParticipantLabel = 'Non-participant';

const String _participantStatusNeedsActionIcs = 'NEEDS-ACTION';
const String _participantStatusAcceptedIcs = 'ACCEPTED';
const String _participantStatusDeclinedIcs = 'DECLINED';
const String _participantStatusTentativeIcs = 'TENTATIVE';
const String _participantStatusDelegatedIcs = 'DELEGATED';
const String _participantStatusCompletedIcs = 'COMPLETED';
const String _participantStatusInProcessIcs = 'IN-PROCESS';
const String _participantStatusNeedsActionLabel = 'Needs action';
const String _participantStatusAcceptedLabel = 'Accepted';
const String _participantStatusDeclinedLabel = 'Declined';
const String _participantStatusTentativeLabel = 'Tentative';
const String _participantStatusDelegatedLabel = 'Delegated';
const String _participantStatusCompletedLabel = 'Completed';
const String _participantStatusInProcessLabel = 'In process';

const String _participantTypeIndividualIcs = 'INDIVIDUAL';
const String _participantTypeGroupIcs = 'GROUP';
const String _participantTypeResourceIcs = 'RESOURCE';
const String _participantTypeRoomIcs = 'ROOM';
const String _participantTypeUnknownIcs = 'UNKNOWN';
const String _participantTypeIndividualLabel = 'Individual';
const String _participantTypeGroupLabel = 'Group';
const String _participantTypeResourceLabel = 'Resource';
const String _participantTypeRoomLabel = 'Room';
const String _participantTypeUnknownLabel = 'Unknown';

const List<String> _emptyParticipantAddresses = <String>[];
const bool _calendarParticipantDefaultRsvp = false;

@HiveType(typeId: _calendarParticipantRoleTypeId)
enum CalendarParticipantRole {
  @HiveField(_calendarParticipantRoleChairField)
  chair,
  @HiveField(_calendarParticipantRoleRequiredField)
  requiredParticipant,
  @HiveField(_calendarParticipantRoleOptionalField)
  optionalParticipant,
  @HiveField(_calendarParticipantRoleNonParticipantField)
  nonParticipant;

  bool get isChair => this == CalendarParticipantRole.chair;
  bool get isRequired => this == CalendarParticipantRole.requiredParticipant;
  bool get isOptional => this == CalendarParticipantRole.optionalParticipant;
  bool get isNonParticipant => this == CalendarParticipantRole.nonParticipant;

  String get icsValue => switch (this) {
        CalendarParticipantRole.chair => _participantRoleChairIcs,
        CalendarParticipantRole.requiredParticipant =>
          _participantRoleRequiredIcs,
        CalendarParticipantRole.optionalParticipant =>
          _participantRoleOptionalIcs,
        CalendarParticipantRole.nonParticipant =>
          _participantRoleNonParticipantIcs,
      };

  static CalendarParticipantRole? fromIcsValue(String? value) =>
      switch (value) {
        _participantRoleChairIcs => CalendarParticipantRole.chair,
        _participantRoleRequiredIcs =>
          CalendarParticipantRole.requiredParticipant,
        _participantRoleOptionalIcs =>
          CalendarParticipantRole.optionalParticipant,
        _participantRoleNonParticipantIcs =>
          CalendarParticipantRole.nonParticipant,
        _ => null,
      };
}

extension CalendarParticipantRoleLabelX on CalendarParticipantRole {
  String get label => switch (this) {
        CalendarParticipantRole.chair => _participantRoleChairLabel,
        CalendarParticipantRole.requiredParticipant =>
          _participantRoleRequiredLabel,
        CalendarParticipantRole.optionalParticipant =>
          _participantRoleOptionalLabel,
        CalendarParticipantRole.nonParticipant =>
          _participantRoleNonParticipantLabel,
      };
}

@HiveType(typeId: _calendarParticipantStatusTypeId)
enum CalendarParticipantStatus {
  @HiveField(_calendarParticipantStatusNeedsActionField)
  needsAction,
  @HiveField(_calendarParticipantStatusAcceptedField)
  accepted,
  @HiveField(_calendarParticipantStatusDeclinedField)
  declined,
  @HiveField(_calendarParticipantStatusTentativeField)
  tentative,
  @HiveField(_calendarParticipantStatusDelegatedField)
  delegated,
  @HiveField(_calendarParticipantStatusCompletedField)
  completed,
  @HiveField(_calendarParticipantStatusInProcessField)
  inProcess;

  bool get isNeedsAction => this == CalendarParticipantStatus.needsAction;
  bool get isAccepted => this == CalendarParticipantStatus.accepted;
  bool get isDeclined => this == CalendarParticipantStatus.declined;
  bool get isTentative => this == CalendarParticipantStatus.tentative;
  bool get isDelegated => this == CalendarParticipantStatus.delegated;
  bool get isCompleted => this == CalendarParticipantStatus.completed;
  bool get isInProcess => this == CalendarParticipantStatus.inProcess;

  String get icsValue => switch (this) {
        CalendarParticipantStatus.needsAction =>
          _participantStatusNeedsActionIcs,
        CalendarParticipantStatus.accepted => _participantStatusAcceptedIcs,
        CalendarParticipantStatus.declined => _participantStatusDeclinedIcs,
        CalendarParticipantStatus.tentative => _participantStatusTentativeIcs,
        CalendarParticipantStatus.delegated => _participantStatusDelegatedIcs,
        CalendarParticipantStatus.completed => _participantStatusCompletedIcs,
        CalendarParticipantStatus.inProcess => _participantStatusInProcessIcs,
      };

  static CalendarParticipantStatus? fromIcsValue(String? value) =>
      switch (value) {
        _participantStatusNeedsActionIcs =>
          CalendarParticipantStatus.needsAction,
        _participantStatusAcceptedIcs => CalendarParticipantStatus.accepted,
        _participantStatusDeclinedIcs => CalendarParticipantStatus.declined,
        _participantStatusTentativeIcs => CalendarParticipantStatus.tentative,
        _participantStatusDelegatedIcs => CalendarParticipantStatus.delegated,
        _participantStatusCompletedIcs => CalendarParticipantStatus.completed,
        _participantStatusInProcessIcs => CalendarParticipantStatus.inProcess,
        _ => null,
      };
}

extension CalendarParticipantStatusLabelX on CalendarParticipantStatus {
  String get label => switch (this) {
        CalendarParticipantStatus.needsAction =>
          _participantStatusNeedsActionLabel,
        CalendarParticipantStatus.accepted => _participantStatusAcceptedLabel,
        CalendarParticipantStatus.declined => _participantStatusDeclinedLabel,
        CalendarParticipantStatus.tentative => _participantStatusTentativeLabel,
        CalendarParticipantStatus.delegated => _participantStatusDelegatedLabel,
        CalendarParticipantStatus.completed => _participantStatusCompletedLabel,
        CalendarParticipantStatus.inProcess => _participantStatusInProcessLabel,
      };
}

@HiveType(typeId: _calendarParticipantTypeTypeId)
enum CalendarParticipantType {
  @HiveField(_calendarParticipantTypeIndividualField)
  individual,
  @HiveField(_calendarParticipantTypeGroupField)
  group,
  @HiveField(_calendarParticipantTypeResourceField)
  resource,
  @HiveField(_calendarParticipantTypeRoomField)
  room,
  @HiveField(_calendarParticipantTypeUnknownField)
  unknown;

  bool get isIndividual => this == CalendarParticipantType.individual;
  bool get isGroup => this == CalendarParticipantType.group;
  bool get isResource => this == CalendarParticipantType.resource;
  bool get isRoom => this == CalendarParticipantType.room;
  bool get isUnknown => this == CalendarParticipantType.unknown;

  String get icsValue => switch (this) {
        CalendarParticipantType.individual => _participantTypeIndividualIcs,
        CalendarParticipantType.group => _participantTypeGroupIcs,
        CalendarParticipantType.resource => _participantTypeResourceIcs,
        CalendarParticipantType.room => _participantTypeRoomIcs,
        CalendarParticipantType.unknown => _participantTypeUnknownIcs,
      };

  static CalendarParticipantType? fromIcsValue(String? value) =>
      switch (value) {
        _participantTypeIndividualIcs => CalendarParticipantType.individual,
        _participantTypeGroupIcs => CalendarParticipantType.group,
        _participantTypeResourceIcs => CalendarParticipantType.resource,
        _participantTypeRoomIcs => CalendarParticipantType.room,
        _participantTypeUnknownIcs => CalendarParticipantType.unknown,
        _ => null,
      };
}

extension CalendarParticipantTypeLabelX on CalendarParticipantType {
  String get label => switch (this) {
        CalendarParticipantType.individual => _participantTypeIndividualLabel,
        CalendarParticipantType.group => _participantTypeGroupLabel,
        CalendarParticipantType.resource => _participantTypeResourceLabel,
        CalendarParticipantType.room => _participantTypeRoomLabel,
        CalendarParticipantType.unknown => _participantTypeUnknownLabel,
      };
}

extension CalendarOrganizerDisplayX on CalendarOrganizer {
  String get displayName => commonName != null && commonName!.trim().isNotEmpty
      ? commonName!.trim()
      : address;
}

extension CalendarAttendeeDisplayX on CalendarAttendee {
  String get displayName => commonName != null && commonName!.trim().isNotEmpty
      ? commonName!.trim()
      : address;
}

@freezed
@HiveType(typeId: _calendarOrganizerTypeId)
class CalendarOrganizer with _$CalendarOrganizer {
  const factory CalendarOrganizer({
    @HiveField(_calendarParticipantAddressField) required String address,
    @HiveField(_calendarParticipantCommonNameField) String? commonName,
    @HiveField(_calendarParticipantDirectoryField) String? directory,
    @HiveField(_calendarParticipantSentByField) String? sentBy,
    @HiveField(_calendarParticipantRoleField) CalendarParticipantRole? role,
    @HiveField(_calendarParticipantStatusField)
    CalendarParticipantStatus? status,
    @HiveField(_calendarParticipantTypeField) CalendarParticipantType? type,
    @HiveField(_calendarParticipantRsvpField)
    @Default(_calendarParticipantDefaultRsvp)
    bool rsvp,
    @HiveField(_calendarParticipantDelegatedToField)
    @Default(_emptyParticipantAddresses)
    List<String> delegatedTo,
    @HiveField(_calendarParticipantDelegatedFromField)
    @Default(_emptyParticipantAddresses)
    List<String> delegatedFrom,
    @HiveField(_calendarParticipantMembersField)
    @Default(_emptyParticipantAddresses)
    List<String> members,
  }) = _CalendarOrganizer;

  factory CalendarOrganizer.fromJson(Map<String, dynamic> json) =>
      _$CalendarOrganizerFromJson(json);
}

@freezed
@HiveType(typeId: _calendarAttendeeTypeId)
class CalendarAttendee with _$CalendarAttendee {
  const factory CalendarAttendee({
    @HiveField(_calendarParticipantAddressField) required String address,
    @HiveField(_calendarParticipantCommonNameField) String? commonName,
    @HiveField(_calendarParticipantDirectoryField) String? directory,
    @HiveField(_calendarParticipantSentByField) String? sentBy,
    @HiveField(_calendarParticipantRoleField) CalendarParticipantRole? role,
    @HiveField(_calendarParticipantStatusField)
    CalendarParticipantStatus? status,
    @HiveField(_calendarParticipantTypeField) CalendarParticipantType? type,
    @HiveField(_calendarParticipantRsvpField)
    @Default(_calendarParticipantDefaultRsvp)
    bool rsvp,
    @HiveField(_calendarParticipantDelegatedToField)
    @Default(_emptyParticipantAddresses)
    List<String> delegatedTo,
    @HiveField(_calendarParticipantDelegatedFromField)
    @Default(_emptyParticipantAddresses)
    List<String> delegatedFrom,
    @HiveField(_calendarParticipantMembersField)
    @Default(_emptyParticipantAddresses)
    List<String> members,
  }) = _CalendarAttendee;

  factory CalendarAttendee.fromJson(Map<String, dynamic> json) =>
      _$CalendarAttendeeFromJson(json);
}
