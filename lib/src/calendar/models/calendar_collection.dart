import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

import 'calendar_ics_raw.dart';

part 'calendar_collection.freezed.dart';
part 'calendar_collection.g.dart';

const int _calendarMethodTypeId = 69;
const int _calendarMethodPublishField = 0;
const int _calendarMethodRequestField = 1;
const int _calendarMethodReplyField = 2;
const int _calendarMethodCancelField = 3;
const int _calendarMethodAddField = 4;
const int _calendarMethodRefreshField = 5;
const int _calendarMethodCounterField = 6;
const int _calendarMethodDeclineCounterField = 7;

const int _calendarSharingPolicyTypeId = 70;
const int _calendarSharingPolicyValueField = 0;

const int _calendarCollectionTypeId = 71;
const int _calendarCollectionIdField = 0;
const int _calendarCollectionNameField = 1;
const int _calendarCollectionDescriptionField = 2;
const int _calendarCollectionColorField = 3;
const int _calendarCollectionOwnerField = 4;
const int _calendarCollectionTimeZoneField = 5;
const int _calendarCollectionVersionField = 6;
const int _calendarCollectionSharingPolicyField = 7;
const int _calendarCollectionMethodField = 8;
const int _calendarCollectionTimeZonesField = 9;
const int _calendarCollectionRawPropertiesField = 10;
const int _calendarCollectionRawComponentsField = 11;

const List<CalendarTimeZoneDefinition> _emptyTimeZones =
    <CalendarTimeZoneDefinition>[];
const List<CalendarRawProperty> _emptyCalendarRawProperties =
    <CalendarRawProperty>[];
const List<CalendarRawComponent> _emptyCalendarRawComponents =
    <CalendarRawComponent>[];

const String _calendarMethodPublishIcs = 'PUBLISH';
const String _calendarMethodRequestIcs = 'REQUEST';
const String _calendarMethodReplyIcs = 'REPLY';
const String _calendarMethodCancelIcs = 'CANCEL';
const String _calendarMethodAddIcs = 'ADD';
const String _calendarMethodRefreshIcs = 'REFRESH';
const String _calendarMethodCounterIcs = 'COUNTER';
const String _calendarMethodDeclineCounterIcs = 'DECLINECOUNTER';

@HiveType(typeId: _calendarMethodTypeId)
enum CalendarMethod {
  @HiveField(_calendarMethodPublishField)
  publish,
  @HiveField(_calendarMethodRequestField)
  request,
  @HiveField(_calendarMethodReplyField)
  reply,
  @HiveField(_calendarMethodCancelField)
  cancel,
  @HiveField(_calendarMethodAddField)
  add,
  @HiveField(_calendarMethodRefreshField)
  refresh,
  @HiveField(_calendarMethodCounterField)
  counter,
  @HiveField(_calendarMethodDeclineCounterField)
  declineCounter;

  bool get isPublish => this == CalendarMethod.publish;
  bool get isRequest => this == CalendarMethod.request;
  bool get isReply => this == CalendarMethod.reply;
  bool get isCancel => this == CalendarMethod.cancel;
  bool get isAdd => this == CalendarMethod.add;
  bool get isRefresh => this == CalendarMethod.refresh;
  bool get isCounter => this == CalendarMethod.counter;
  bool get isDeclineCounter => this == CalendarMethod.declineCounter;

  String get icsValue => switch (this) {
        CalendarMethod.publish => _calendarMethodPublishIcs,
        CalendarMethod.request => _calendarMethodRequestIcs,
        CalendarMethod.reply => _calendarMethodReplyIcs,
        CalendarMethod.cancel => _calendarMethodCancelIcs,
        CalendarMethod.add => _calendarMethodAddIcs,
        CalendarMethod.refresh => _calendarMethodRefreshIcs,
        CalendarMethod.counter => _calendarMethodCounterIcs,
        CalendarMethod.declineCounter => _calendarMethodDeclineCounterIcs,
      };

  static CalendarMethod? fromIcsValue(String? value) => switch (value) {
        _calendarMethodPublishIcs => CalendarMethod.publish,
        _calendarMethodRequestIcs => CalendarMethod.request,
        _calendarMethodReplyIcs => CalendarMethod.reply,
        _calendarMethodCancelIcs => CalendarMethod.cancel,
        _calendarMethodAddIcs => CalendarMethod.add,
        _calendarMethodRefreshIcs => CalendarMethod.refresh,
        _calendarMethodCounterIcs => CalendarMethod.counter,
        _calendarMethodDeclineCounterIcs => CalendarMethod.declineCounter,
        _ => null,
      };
}

@freezed
@HiveType(typeId: _calendarSharingPolicyTypeId)
class CalendarSharingPolicy with _$CalendarSharingPolicy {
  const factory CalendarSharingPolicy({
    @HiveField(_calendarSharingPolicyValueField) required String value,
  }) = _CalendarSharingPolicy;

  factory CalendarSharingPolicy.fromJson(Map<String, dynamic> json) =>
      _$CalendarSharingPolicyFromJson(json);
}

@freezed
@HiveType(typeId: _calendarCollectionTypeId)
class CalendarCollection with _$CalendarCollection {
  const factory CalendarCollection({
    @HiveField(_calendarCollectionIdField) required String id,
    @HiveField(_calendarCollectionNameField) required String name,
    @HiveField(_calendarCollectionDescriptionField) String? description,
    @HiveField(_calendarCollectionColorField) String? color,
    @HiveField(_calendarCollectionOwnerField) String? owner,
    @HiveField(_calendarCollectionTimeZoneField) String? timeZone,
    @HiveField(_calendarCollectionVersionField) String? version,
    @HiveField(_calendarCollectionSharingPolicyField)
    CalendarSharingPolicy? sharingPolicy,
    @HiveField(_calendarCollectionMethodField) CalendarMethod? method,
    @HiveField(_calendarCollectionTimeZonesField)
    @Default(_emptyTimeZones)
    List<CalendarTimeZoneDefinition> timeZones,
    @HiveField(_calendarCollectionRawPropertiesField)
    @Default(_emptyCalendarRawProperties)
    List<CalendarRawProperty> rawProperties,
    @HiveField(_calendarCollectionRawComponentsField)
    @Default(_emptyCalendarRawComponents)
    List<CalendarRawComponent> rawComponents,
  }) = _CalendarCollection;

  factory CalendarCollection.fromJson(Map<String, dynamic> json) =>
      _$CalendarCollectionFromJson(json);
}
