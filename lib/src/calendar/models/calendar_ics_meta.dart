// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

import 'calendar_alarm.dart';
import 'calendar_attachment.dart';
import 'calendar_checklist_item.dart';
import 'calendar_ics_raw.dart';
import 'calendar_participant.dart';

part 'calendar_ics_meta.freezed.dart';
part 'calendar_ics_meta.g.dart';

const int _calendarGeoTypeId = 50;
const int _calendarGeoLatitudeField = 0;
const int _calendarGeoLongitudeField = 1;

const int _calendarIcsStatusTypeId = 51;
const int _calendarIcsStatusTentativeField = 0;
const int _calendarIcsStatusConfirmedField = 1;
const int _calendarIcsStatusCancelledField = 2;
const int _calendarIcsStatusNeedsActionField = 3;
const int _calendarIcsStatusCompletedField = 4;
const int _calendarIcsStatusInProcessField = 5;
const int _calendarIcsStatusDraftField = 6;
const int _calendarIcsStatusFinalField = 7;

const int _calendarPrivacyClassTypeId = 52;
const int _calendarPrivacyClassPublicField = 0;
const int _calendarPrivacyClassPrivateField = 1;
const int _calendarPrivacyClassConfidentialField = 2;

const int _calendarTransparencyTypeId = 53;
const int _calendarTransparencyOpaqueField = 0;
const int _calendarTransparencyTransparentField = 1;

const int _calendarIcsComponentTypeTypeId = 81;
const int _calendarIcsComponentTypeTodoField = 0;
const int _calendarIcsComponentTypeEventField = 1;
const int _calendarIcsComponentTypeJournalField = 2;
const int _calendarIcsComponentTypeAvailabilityField = 3;
const int _calendarIcsComponentTypeFreeBusyField = 4;

const int _calendarCriticalPathLinkTypeId = 66;
const int _calendarCriticalPathLinkPathIdField = 0;
const int _calendarCriticalPathLinkOrderField = 1;

const int _calendarAxiExtensionsTypeId = 67;
const int _calendarAxiExtensionsCriticalPathsField = 0;
const int _calendarAxiExtensionsChecklistField = 1;

const int _calendarIcsMetaTypeId = 68;
const int _calendarIcsMetaUidField = 0;
const int _calendarIcsMetaDtStampField = 1;
const int _calendarIcsMetaCreatedField = 2;
const int _calendarIcsMetaLastModifiedField = 3;
const int _calendarIcsMetaSequenceField = 4;
const int _calendarIcsMetaStatusField = 5;
const int _calendarIcsMetaPrivacyClassField = 6;
const int _calendarIcsMetaTransparencyField = 7;
const int _calendarIcsMetaCategoriesField = 8;
const int _calendarIcsMetaUrlField = 9;
const int _calendarIcsMetaGeoField = 10;
const int _calendarIcsMetaAttachmentsField = 11;
const int _calendarIcsMetaOrganizerField = 12;
const int _calendarIcsMetaAttendeesField = 13;
const int _calendarIcsMetaAlarmsField = 14;
const int _calendarIcsMetaAxiField = 15;
const int _calendarIcsMetaRawPropertiesField = 16;
const int _calendarIcsMetaRawComponentsField = 17;
const int _calendarIcsMetaComponentTypeField = 18;

const List<String> _emptyCalendarCategories = <String>[];
const List<CalendarAttachment> _emptyCalendarAttachments =
    <CalendarAttachment>[];
const List<CalendarAttendee> _emptyCalendarAttendees = <CalendarAttendee>[];
const List<CalendarAlarm> _emptyCalendarAlarms = <CalendarAlarm>[];
const List<CalendarRawProperty> _emptyCalendarRawProperties =
    <CalendarRawProperty>[];
const List<CalendarRawComponent> _emptyCalendarRawComponents =
    <CalendarRawComponent>[];
const List<CalendarCriticalPathLink> _emptyCalendarCriticalPathLinks =
    <CalendarCriticalPathLink>[];
const List<TaskChecklistItem> _emptyTaskChecklistItems = <TaskChecklistItem>[];

const String _calendarIcsStatusTentativeIcs = 'TENTATIVE';
const String _calendarIcsStatusConfirmedIcs = 'CONFIRMED';
const String _calendarIcsStatusCancelledIcs = 'CANCELLED';
const String _calendarIcsStatusNeedsActionIcs = 'NEEDS-ACTION';
const String _calendarIcsStatusCompletedIcs = 'COMPLETED';
const String _calendarIcsStatusInProcessIcs = 'IN-PROCESS';
const String _calendarIcsStatusDraftIcs = 'DRAFT';
const String _calendarIcsStatusFinalIcs = 'FINAL';

const String _calendarIcsStatusTentativeLabel = 'Tentative';
const String _calendarIcsStatusConfirmedLabel = 'Confirmed';
const String _calendarIcsStatusCancelledLabel = 'Cancelled';
const String _calendarIcsStatusNeedsActionLabel = 'Needs action';
const String _calendarIcsStatusCompletedLabel = 'Completed';
const String _calendarIcsStatusInProcessLabel = 'In process';
const String _calendarIcsStatusDraftLabel = 'Draft';
const String _calendarIcsStatusFinalLabel = 'Final';

const String _calendarPrivacyClassPublicIcs = 'PUBLIC';
const String _calendarPrivacyClassPrivateIcs = 'PRIVATE';
const String _calendarPrivacyClassConfidentialIcs = 'CONFIDENTIAL';

const String _calendarTransparencyOpaqueIcs = 'OPAQUE';
const String _calendarTransparencyTransparentIcs = 'TRANSPARENT';

const String _calendarTransparencyOpaqueLabel = 'Busy';
const String _calendarTransparencyTransparentLabel = 'Free';

@freezed
@HiveType(typeId: _calendarGeoTypeId)
class CalendarGeo with _$CalendarGeo {
  const factory CalendarGeo({
    @HiveField(_calendarGeoLatitudeField) required double latitude,
    @HiveField(_calendarGeoLongitudeField) required double longitude,
  }) = _CalendarGeo;

  factory CalendarGeo.fromJson(Map<String, dynamic> json) =>
      _$CalendarGeoFromJson(json);
}

@HiveType(typeId: _calendarIcsStatusTypeId)
enum CalendarIcsStatus {
  @HiveField(_calendarIcsStatusTentativeField)
  tentative,
  @HiveField(_calendarIcsStatusConfirmedField)
  confirmed,
  @HiveField(_calendarIcsStatusCancelledField)
  cancelled,
  @HiveField(_calendarIcsStatusNeedsActionField)
  needsAction,
  @HiveField(_calendarIcsStatusCompletedField)
  completed,
  @HiveField(_calendarIcsStatusInProcessField)
  inProcess,
  @HiveField(_calendarIcsStatusDraftField)
  draft,
  @HiveField(_calendarIcsStatusFinalField)
  finalState;

  bool get isTentative => this == CalendarIcsStatus.tentative;
  bool get isConfirmed => this == CalendarIcsStatus.confirmed;
  bool get isCancelled => this == CalendarIcsStatus.cancelled;
  bool get isNeedsAction => this == CalendarIcsStatus.needsAction;
  bool get isCompleted => this == CalendarIcsStatus.completed;
  bool get isInProcess => this == CalendarIcsStatus.inProcess;
  bool get isDraft => this == CalendarIcsStatus.draft;
  bool get isFinalState => this == CalendarIcsStatus.finalState;

  String get icsValue => switch (this) {
        CalendarIcsStatus.tentative => _calendarIcsStatusTentativeIcs,
        CalendarIcsStatus.confirmed => _calendarIcsStatusConfirmedIcs,
        CalendarIcsStatus.cancelled => _calendarIcsStatusCancelledIcs,
        CalendarIcsStatus.needsAction => _calendarIcsStatusNeedsActionIcs,
        CalendarIcsStatus.completed => _calendarIcsStatusCompletedIcs,
        CalendarIcsStatus.inProcess => _calendarIcsStatusInProcessIcs,
        CalendarIcsStatus.draft => _calendarIcsStatusDraftIcs,
        CalendarIcsStatus.finalState => _calendarIcsStatusFinalIcs,
      };

  static CalendarIcsStatus? fromIcsValue(String? value) => switch (value) {
        _calendarIcsStatusTentativeIcs => CalendarIcsStatus.tentative,
        _calendarIcsStatusConfirmedIcs => CalendarIcsStatus.confirmed,
        _calendarIcsStatusCancelledIcs => CalendarIcsStatus.cancelled,
        _calendarIcsStatusNeedsActionIcs => CalendarIcsStatus.needsAction,
        _calendarIcsStatusCompletedIcs => CalendarIcsStatus.completed,
        _calendarIcsStatusInProcessIcs => CalendarIcsStatus.inProcess,
        _calendarIcsStatusDraftIcs => CalendarIcsStatus.draft,
        _calendarIcsStatusFinalIcs => CalendarIcsStatus.finalState,
        _ => null,
      };
}

@HiveType(typeId: _calendarPrivacyClassTypeId)
enum CalendarPrivacyClass {
  @HiveField(_calendarPrivacyClassPublicField)
  public,
  @HiveField(_calendarPrivacyClassPrivateField)
  private,
  @HiveField(_calendarPrivacyClassConfidentialField)
  confidential;

  bool get isPublic => this == CalendarPrivacyClass.public;
  bool get isPrivate => this == CalendarPrivacyClass.private;
  bool get isConfidential => this == CalendarPrivacyClass.confidential;

  String get icsValue => switch (this) {
        CalendarPrivacyClass.public => _calendarPrivacyClassPublicIcs,
        CalendarPrivacyClass.private => _calendarPrivacyClassPrivateIcs,
        CalendarPrivacyClass.confidential =>
          _calendarPrivacyClassConfidentialIcs,
      };

  static CalendarPrivacyClass? fromIcsValue(String? value) => switch (value) {
        _calendarPrivacyClassPublicIcs => CalendarPrivacyClass.public,
        _calendarPrivacyClassPrivateIcs => CalendarPrivacyClass.private,
        _calendarPrivacyClassConfidentialIcs =>
          CalendarPrivacyClass.confidential,
        _ => null,
      };
}

@HiveType(typeId: _calendarTransparencyTypeId)
enum CalendarTransparency {
  @HiveField(_calendarTransparencyOpaqueField)
  opaque,
  @HiveField(_calendarTransparencyTransparentField)
  transparent;

  bool get isOpaque => this == CalendarTransparency.opaque;
  bool get isTransparent => this == CalendarTransparency.transparent;

  String get icsValue => switch (this) {
        CalendarTransparency.opaque => _calendarTransparencyOpaqueIcs,
        CalendarTransparency.transparent => _calendarTransparencyTransparentIcs,
      };

  static CalendarTransparency? fromIcsValue(String? value) => switch (value) {
        _calendarTransparencyOpaqueIcs => CalendarTransparency.opaque,
        _calendarTransparencyTransparentIcs => CalendarTransparency.transparent,
        _ => null,
      };
}

extension CalendarIcsStatusLabel on CalendarIcsStatus {
  String get label => switch (this) {
        CalendarIcsStatus.tentative => _calendarIcsStatusTentativeLabel,
        CalendarIcsStatus.confirmed => _calendarIcsStatusConfirmedLabel,
        CalendarIcsStatus.cancelled => _calendarIcsStatusCancelledLabel,
        CalendarIcsStatus.needsAction => _calendarIcsStatusNeedsActionLabel,
        CalendarIcsStatus.completed => _calendarIcsStatusCompletedLabel,
        CalendarIcsStatus.inProcess => _calendarIcsStatusInProcessLabel,
        CalendarIcsStatus.draft => _calendarIcsStatusDraftLabel,
        CalendarIcsStatus.finalState => _calendarIcsStatusFinalLabel,
      };
}

extension CalendarTransparencyLabel on CalendarTransparency {
  String get label => switch (this) {
        CalendarTransparency.opaque => _calendarTransparencyOpaqueLabel,
        CalendarTransparency.transparent =>
          _calendarTransparencyTransparentLabel,
      };
}

extension CalendarIcsMetaJson on CalendarIcsMeta {
  Map<String, dynamic> toJson() =>
      _$$CalendarIcsMetaImplToJson(this as _$CalendarIcsMetaImpl);
}

@HiveType(typeId: _calendarIcsComponentTypeTypeId)
enum CalendarIcsComponentType {
  @HiveField(_calendarIcsComponentTypeTodoField)
  todo,
  @HiveField(_calendarIcsComponentTypeEventField)
  event,
  @HiveField(_calendarIcsComponentTypeJournalField)
  journal,
  @HiveField(_calendarIcsComponentTypeAvailabilityField)
  availability,
  @HiveField(_calendarIcsComponentTypeFreeBusyField)
  freeBusy;

  bool get isTodo => this == CalendarIcsComponentType.todo;
  bool get isEvent => this == CalendarIcsComponentType.event;
  bool get isJournal => this == CalendarIcsComponentType.journal;
  bool get isAvailability => this == CalendarIcsComponentType.availability;
  bool get isFreeBusy => this == CalendarIcsComponentType.freeBusy;
}

@freezed
@HiveType(typeId: _calendarCriticalPathLinkTypeId)
class CalendarCriticalPathLink with _$CalendarCriticalPathLink {
  const factory CalendarCriticalPathLink({
    @HiveField(_calendarCriticalPathLinkPathIdField) required String pathId,
    @HiveField(_calendarCriticalPathLinkOrderField) int? order,
  }) = _CalendarCriticalPathLink;

  factory CalendarCriticalPathLink.fromJson(Map<String, dynamic> json) =>
      _$CalendarCriticalPathLinkFromJson(json);
}

@freezed
@HiveType(typeId: _calendarAxiExtensionsTypeId)
class CalendarAxiExtensions with _$CalendarAxiExtensions {
  const factory CalendarAxiExtensions({
    @HiveField(_calendarAxiExtensionsCriticalPathsField)
    @Default(_emptyCalendarCriticalPathLinks)
    List<CalendarCriticalPathLink> criticalPaths,
    @HiveField(_calendarAxiExtensionsChecklistField)
    @Default(_emptyTaskChecklistItems)
    List<TaskChecklistItem> checklist,
  }) = _CalendarAxiExtensions;

  factory CalendarAxiExtensions.fromJson(Map<String, dynamic> json) =>
      _$CalendarAxiExtensionsFromJson(json);
}

@freezed
@HiveType(typeId: _calendarIcsMetaTypeId)
class CalendarIcsMeta with _$CalendarIcsMeta {
  const factory CalendarIcsMeta({
    @HiveField(_calendarIcsMetaUidField) String? uid,
    @HiveField(_calendarIcsMetaDtStampField) DateTime? dtStamp,
    @HiveField(_calendarIcsMetaCreatedField) DateTime? created,
    @HiveField(_calendarIcsMetaLastModifiedField) DateTime? lastModified,
    @HiveField(_calendarIcsMetaSequenceField) int? sequence,
    @HiveField(_calendarIcsMetaStatusField) CalendarIcsStatus? status,
    @HiveField(_calendarIcsMetaPrivacyClassField)
    CalendarPrivacyClass? privacyClass,
    @HiveField(_calendarIcsMetaTransparencyField)
    CalendarTransparency? transparency,
    @HiveField(_calendarIcsMetaComponentTypeField)
    CalendarIcsComponentType? componentType,
    @HiveField(_calendarIcsMetaCategoriesField)
    @Default(_emptyCalendarCategories)
    List<String> categories,
    @HiveField(_calendarIcsMetaUrlField) String? url,
    @HiveField(_calendarIcsMetaGeoField) CalendarGeo? geo,
    @HiveField(_calendarIcsMetaAttachmentsField)
    @Default(_emptyCalendarAttachments)
    List<CalendarAttachment> attachments,
    @HiveField(_calendarIcsMetaOrganizerField) CalendarOrganizer? organizer,
    @HiveField(_calendarIcsMetaAttendeesField)
    @Default(_emptyCalendarAttendees)
    List<CalendarAttendee> attendees,
    @HiveField(_calendarIcsMetaAlarmsField)
    @Default(_emptyCalendarAlarms)
    List<CalendarAlarm> alarms,
    @HiveField(_calendarIcsMetaAxiField) CalendarAxiExtensions? axi,
    @HiveField(_calendarIcsMetaRawPropertiesField)
    @Default(_emptyCalendarRawProperties)
    List<CalendarRawProperty> rawProperties,
    @HiveField(_calendarIcsMetaRawComponentsField)
    @Default(_emptyCalendarRawComponents)
    List<CalendarRawComponent> rawComponents,
  }) = _CalendarIcsMeta;

  factory CalendarIcsMeta.fromJson(Map<String, dynamic> json) =>
      _$CalendarIcsMetaFromJson(json);
}
