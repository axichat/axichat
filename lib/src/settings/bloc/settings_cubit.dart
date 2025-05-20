import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

part 'settings_cubit.freezed.dart';
part 'settings_cubit.g.dart';
part 'settings_state.dart';

class SettingsCubit extends HydratedCubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  Duration get animationDuration =>
      state.lowMotion ? Duration.zero : baseAnimationDuration;

  void updateThemeMode(ThemeMode? themeMode) {
    if (themeMode == null) return;
    emit(state.copyWith(themeMode: themeMode));
  }

  void updateColorScheme(ShadColor? shadColor) {
    if (shadColor == null) return;
    emit(state.copyWith(shadColor: shadColor));
  }

  void toggleMute(bool mute) {
    emit(state.copyWith(mute: mute));
  }

  void toggleReadReceipts(bool readReceipts) {
    emit(state.copyWith(readReceipts: readReceipts));
  }

  void toggleColorfulAvatars(bool colorfulAvatars) {
    emit(state.copyWith(colorfulAvatars: colorfulAvatars));
  }

  void toggleLowMotion(bool lowMotion) {
    emit(state.copyWith(lowMotion: lowMotion));
  }

  void toggleIndicateTyping(bool indicateTyping) {
    emit(state.copyWith(indicateTyping: indicateTyping));
  }

  @override
  SettingsState? fromJson(Map<String, dynamic> json) =>
      SettingsState.fromJson(json);

  @override
  Map<String, dynamic>? toJson(SettingsState state) => state.toJson();
}
