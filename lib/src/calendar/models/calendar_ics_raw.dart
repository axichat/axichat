import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'calendar_ics_raw.freezed.dart';
part 'calendar_ics_raw.g.dart';

const int _calendarPropertyParameterTypeId = 45;
const int _calendarPropertyParameterNameField = 0;
const int _calendarPropertyParameterValuesField = 1;

const int _calendarRawPropertyTypeId = 46;
const int _calendarRawPropertyNameField = 0;
const int _calendarRawPropertyValueField = 1;
const int _calendarRawPropertyParametersField = 2;

const int _calendarRawComponentTypeId = 47;
const int _calendarRawComponentNameField = 0;
const int _calendarRawComponentPropertiesField = 1;
const int _calendarRawComponentComponentsField = 2;

const int _calendarTimeZoneDefinitionTypeId = 48;
const int _calendarTimeZoneDefinitionTzidField = 0;
const int _calendarTimeZoneDefinitionComponentField = 1;

const List<String> _emptyStringList = <String>[];
const List<CalendarPropertyParameter> _emptyCalendarPropertyParameters =
    <CalendarPropertyParameter>[];
const List<CalendarRawProperty> _emptyCalendarRawProperties =
    <CalendarRawProperty>[];
const List<CalendarRawComponent> _emptyCalendarRawComponents =
    <CalendarRawComponent>[];

@freezed
@HiveType(typeId: _calendarPropertyParameterTypeId)
class CalendarPropertyParameter with _$CalendarPropertyParameter {
  const factory CalendarPropertyParameter({
    @HiveField(_calendarPropertyParameterNameField) required String name,
    @HiveField(_calendarPropertyParameterValuesField)
    @Default(_emptyStringList)
    List<String> values,
  }) = _CalendarPropertyParameter;

  factory CalendarPropertyParameter.fromJson(Map<String, dynamic> json) =>
      _$CalendarPropertyParameterFromJson(json);
}

@freezed
@HiveType(typeId: _calendarRawPropertyTypeId)
class CalendarRawProperty with _$CalendarRawProperty {
  const factory CalendarRawProperty({
    @HiveField(_calendarRawPropertyNameField) required String name,
    @HiveField(_calendarRawPropertyValueField) required String value,
    @HiveField(_calendarRawPropertyParametersField)
    @Default(_emptyCalendarPropertyParameters)
    List<CalendarPropertyParameter> parameters,
  }) = _CalendarRawProperty;

  factory CalendarRawProperty.fromJson(Map<String, dynamic> json) =>
      _$CalendarRawPropertyFromJson(json);
}

@freezed
@HiveType(typeId: _calendarRawComponentTypeId)
class CalendarRawComponent with _$CalendarRawComponent {
  const factory CalendarRawComponent({
    @HiveField(_calendarRawComponentNameField) required String name,
    @HiveField(_calendarRawComponentPropertiesField)
    @Default(_emptyCalendarRawProperties)
    List<CalendarRawProperty> properties,
    @HiveField(_calendarRawComponentComponentsField)
    @Default(_emptyCalendarRawComponents)
    List<CalendarRawComponent> components,
  }) = _CalendarRawComponent;

  factory CalendarRawComponent.fromJson(Map<String, dynamic> json) =>
      _$CalendarRawComponentFromJson(json);
}

@freezed
@HiveType(typeId: _calendarTimeZoneDefinitionTypeId)
class CalendarTimeZoneDefinition with _$CalendarTimeZoneDefinition {
  const factory CalendarTimeZoneDefinition({
    @HiveField(_calendarTimeZoneDefinitionTzidField) required String tzid,
    @HiveField(_calendarTimeZoneDefinitionComponentField)
    required CalendarRawComponent component,
  }) = _CalendarTimeZoneDefinition;

  factory CalendarTimeZoneDefinition.fromJson(Map<String, dynamic> json) =>
      _$CalendarTimeZoneDefinitionFromJson(json);
}
