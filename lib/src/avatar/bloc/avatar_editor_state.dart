// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'avatar_editor_cubit.dart';

@freezed
class AvatarEditorState with _$AvatarEditorState {
  const factory AvatarEditorState({
    @Default(AvatarSource.template) AvatarSource source,
    Uint8List? sourceBytes,
    Uint8List? previewBytes,
    Uint8List? carouselPreviewBytes,
    AvatarTemplate? template,
    AvatarUploadPayload? draft,
    @Default(false) bool shuffling,
    @Default(false) bool processing,
    @Default(false) bool publishing,
    AvatarEditorErrorType? errorType,
    Rect? cropRect,
    int? imageWidth,
    int? imageHeight,
    @Default(Colors.transparent) Color backgroundColor,
    String? lastSavedPath,
    String? lastSavedHash,
    int? estimatedBytes,
  }) = _AvatarEditorState;
}
