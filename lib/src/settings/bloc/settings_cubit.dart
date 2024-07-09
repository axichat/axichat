import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

part 'settings_cubit.freezed.dart';
part 'settings_cubit.g.dart';
part 'settings_state.dart';

class SettingsCubit extends HydratedCubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  void updateThemeMode(ThemeMode? themeMode) {
    if (themeMode == null) return;
    emit(state.copyWith(themeMode: themeMode));
  }

  void updateColorScheme(ShadColor? shadColor) {
    if (shadColor == null) return;
    emit(state.copyWith(shadColor: shadColor));
  }

  void toggleLowMotion(bool lowMotion) {
    emit(state.copyWith(lowMotion: lowMotion));
  }

  @override
  SettingsState? fromJson(Map<String, dynamic> json) =>
      SettingsState.fromJson(json);

  @override
  Map<String, dynamic>? toJson(SettingsState state) => state.toJson();
}
