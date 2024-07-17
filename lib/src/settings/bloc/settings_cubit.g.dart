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
          shadColor: $checkedConvert(
              'shad_color',
              (v) =>
                  $enumDecodeNullable(_$ShadColorEnumMap, v) ??
                  ShadColor.neutral),
          indicateTyping:
              $checkedConvert('indicate_typing', (v) => v as bool? ?? true),
          lowMotion: $checkedConvert('low_motion', (v) => v as bool? ?? false),
        );
        return val;
      },
      fieldKeyMap: const {
        'themeMode': 'theme_mode',
        'shadColor': 'shad_color',
        'indicateTyping': 'indicate_typing',
        'lowMotion': 'low_motion'
      },
    );

Map<String, dynamic> _$$SettingsStateImplToJson(_$SettingsStateImpl instance) =>
    <String, dynamic>{
      'theme_mode': _$ThemeModeEnumMap[instance.themeMode]!,
      'shad_color': _$ShadColorEnumMap[instance.shadColor]!,
      'indicate_typing': instance.indicateTyping,
      'low_motion': instance.lowMotion,
    };

const _$ThemeModeEnumMap = {
  ThemeMode.system: 'system',
  ThemeMode.light: 'light',
  ThemeMode.dark: 'dark',
};

const _$ShadColorEnumMap = {
  ShadColor.blue: 'blue',
  ShadColor.gray: 'gray',
  ShadColor.green: 'green',
  ShadColor.neutral: 'neutral',
  ShadColor.orange: 'orange',
  ShadColor.red: 'red',
  ShadColor.rose: 'rose',
  ShadColor.slate: 'slate',
  ShadColor.stone: 'stone',
  ShadColor.violet: 'violet',
  ShadColor.yellow: 'yellow',
  ShadColor.zinc: 'zinc',
};
