// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: implicit_dynamic_parameter

part of 'settings_cubit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SettingsStateImpl _$$SettingsStateImplFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      r'_$SettingsStateImpl',
      json,
      ($checkedConvert) {
        final val = _$SettingsStateImpl(
          themeMode: $checkedConvert(
              'theme_mode',
              (v) =>
                  $enumDecodeNullable(_$ThemeModeEnumMap, v) ??
                  ThemeMode.system),
          lowMotion: $checkedConvert('low_motion', (v) => v as bool? ?? false),
        );
        return val;
      },
      fieldKeyMap: const {'themeMode': 'theme_mode', 'lowMotion': 'low_motion'},
    );

Map<String, dynamic> _$$SettingsStateImplToJson(_$SettingsStateImpl instance) =>
    <String, dynamic>{
      'theme_mode': _$ThemeModeEnumMap[instance.themeMode]!,
      'low_motion': instance.lowMotion,
    };

const _$ThemeModeEnumMap = {
  ThemeMode.system: 'system',
  ThemeMode.light: 'light',
  ThemeMode.dark: 'dark',
};
