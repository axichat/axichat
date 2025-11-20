part of 'settings_cubit.dart';

enum ShadColor {
  blue,
  gray,
  green,
  neutral,
  orange,
  red,
  rose,
  slate,
  stone,
  violet,
  yellow,
  zinc,
}

@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default(ThemeMode.light) ThemeMode themeMode,
    @Default(ShadColor.blue) ShadColor shadColor,
    @Default(false) bool mute,
    @Default(true) bool readReceipts,
    @Default(true) bool indicateTyping,
    @Default(false) bool lowMotion,
    @Default(true) bool colorfulAvatars,
    @Default(MessageStorageMode.local) MessageStorageMode messageStorageMode,
  }) = _SettingsState;

  factory SettingsState.fromJson(Map<String, Object?> json) =>
      _$SettingsStateFromJson(json);
}
