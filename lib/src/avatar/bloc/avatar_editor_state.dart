// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'avatar_editor_cubit.dart';

@freezed
abstract class AvatarEditorState with _$AvatarEditorState {
  const factory AvatarEditorState({
    EditableAvatar? draftAvatar,
    EditableAvatar? carouselAvatar,
    @Default(false) bool shuffling,
    @Default(false) bool processing,
    @Default(false) bool publishing,
    AvatarEditorErrorType? errorType,
    @Default(Colors.transparent) Color backgroundColor,
    String? lastSavedPath,
    String? lastSavedHash,
  }) = _AvatarEditorState;
}
