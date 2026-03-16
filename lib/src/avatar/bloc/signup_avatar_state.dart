// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'signup_avatar_cubit.dart';

class SignupAvatarState extends Equatable {
  const SignupAvatarState({
    required this.backgroundColor,
    this.avatar,
    this.carouselAvatar,
    this.processing = false,
    this.errorType,
    this.errorMaxKilobytes,
    this.backgroundLocked = false,
    this.lockedBackgroundColor,
  });

  static const Object _unset = Object();

  final EditableAvatar? avatar;
  final EditableAvatar? carouselAvatar;
  final bool processing;
  final SignupAvatarErrorType? errorType;
  final int? errorMaxKilobytes;
  final Color backgroundColor;
  final bool backgroundLocked;
  final Color? lockedBackgroundColor;

  Uint8List? get displayedBytes => avatar?.bytes ?? carouselAvatar?.bytes;

  bool get hasCarouselPreview => carouselAvatar != null;

  bool get hasUserSelectedAvatar => avatar != null;

  bool get canUseCarouselAvatar =>
      !processing && avatar == null && carouselAvatar != null;

  bool get canShuffleBackground {
    final template = avatar?.template ?? carouselAvatar?.template;
    if (template == null) return false;
    if (template.category == AvatarTemplateCategory.abstract) return false;
    return template.hasAlphaBackground;
  }

  AvatarEditorMode get editorMode {
    final currentAvatar = avatar;
    if (currentAvatar?.source == AvatarSource.upload &&
        currentAvatar?.sourceBytes != null) {
      return AvatarEditorMode.cropOnly;
    }
    final template = currentAvatar?.template;
    if (template == null) return AvatarEditorMode.none;
    if (template.category == AvatarTemplateCategory.abstract) {
      return AvatarEditorMode.none;
    }
    return AvatarEditorMode.colorOnly;
  }

  SignupAvatarState copyWith({
    Object? avatar = _unset,
    Object? carouselAvatar = _unset,
    bool? processing,
    SignupAvatarErrorType? errorType,
    int? errorMaxKilobytes,
    Color? backgroundColor,
    bool? backgroundLocked,
    Object? lockedBackgroundColor = _unset,
    bool clearError = false,
  }) {
    return SignupAvatarState(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      avatar: identical(avatar, _unset)
          ? this.avatar
          : avatar as EditableAvatar?,
      carouselAvatar: identical(carouselAvatar, _unset)
          ? this.carouselAvatar
          : carouselAvatar as EditableAvatar?,
      processing: processing ?? this.processing,
      errorType: clearError ? null : errorType ?? this.errorType,
      errorMaxKilobytes: clearError
          ? null
          : errorMaxKilobytes ?? this.errorMaxKilobytes,
      backgroundLocked: backgroundLocked ?? this.backgroundLocked,
      lockedBackgroundColor: identical(lockedBackgroundColor, _unset)
          ? this.lockedBackgroundColor
          : lockedBackgroundColor as Color?,
    );
  }

  @override
  List<Object?> get props => [
    avatar,
    carouselAvatar,
    processing,
    errorType,
    errorMaxKilobytes,
    backgroundColor,
    backgroundLocked,
    lockedBackgroundColor,
  ];
}
