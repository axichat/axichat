// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'avatar_editor_cubit.dart';

@freezed
class AvatarEditorState with _$AvatarEditorState {
  const factory AvatarEditorState({
    Avatar? draftAvatar,
    Avatar? carouselAvatar,
    @Default(false) bool shuffling,
    @Default(false) bool processing,
    @Default(false) bool publishing,
    AvatarEditorErrorType? errorType,
    @Default(Colors.transparent) Color backgroundColor,
    String? lastSavedPath,
    String? lastSavedHash,
  }) = _AvatarEditorState;
}
