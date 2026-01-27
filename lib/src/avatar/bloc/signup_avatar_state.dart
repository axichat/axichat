// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'signup_avatar_cubit.dart';

class SignupAvatarState extends Equatable {
  const SignupAvatarState({
    required this.backgroundColor,
    this.avatar,
    this.avatarPreviewBytes,
    this.carouselPreviewBytes,
    this.processing = false,
    this.errorType,
    this.errorMaxKilobytes,
    this.backgroundLocked = false,
    this.lockedBackgroundColor,
    this.activeTemplate,
    this.activeCategory,
    this.sourceBytes,
    this.imageWidth,
    this.imageHeight,
    this.cropRect,
  });

  final AvatarUploadPayload? avatar;
  final Uint8List? avatarPreviewBytes;
  final Uint8List? carouselPreviewBytes;
  final bool processing;
  final SignupAvatarErrorType? errorType;
  final int? errorMaxKilobytes;
  final Color backgroundColor;
  final bool backgroundLocked;
  final Color? lockedBackgroundColor;
  final AvatarTemplate? activeTemplate;
  final AvatarTemplateCategory? activeCategory;
  final Uint8List? sourceBytes;
  final double? imageWidth;
  final double? imageHeight;
  final Rect? cropRect;

  Uint8List? get displayedBytes => avatarPreviewBytes ?? carouselPreviewBytes;

  bool get hasCarouselPreview => carouselPreviewBytes != null;

  bool get hasUserSelectedAvatar => avatar != null;

  bool get canUseCarouselAvatar =>
      !processing && avatar == null && carouselPreviewBytes != null;

  bool get canShuffleBackground {
    final template = activeTemplate;
    if (template == null) return false;
    if (template.category == AvatarTemplateCategory.abstract) return false;
    return template.hasAlphaBackground;
  }

  AvatarEditorMode get editorMode {
    final category = activeCategory;
    if (category == null) {
      return activeTemplate == null && sourceBytes != null
          ? AvatarEditorMode.cropOnly
          : AvatarEditorMode.none;
    }
    if (category == AvatarTemplateCategory.abstract) {
      return AvatarEditorMode.none;
    }
    return AvatarEditorMode.colorOnly;
  }

  SignupAvatarState copyWith({
    AvatarUploadPayload? avatar,
    Uint8List? avatarPreviewBytes,
    Uint8List? carouselPreviewBytes,
    bool? processing,
    SignupAvatarErrorType? errorType,
    int? errorMaxKilobytes,
    Color? backgroundColor,
    bool? backgroundLocked,
    Color? lockedBackgroundColor,
    AvatarTemplate? activeTemplate,
    AvatarTemplateCategory? activeCategory,
    Uint8List? sourceBytes,
    double? imageWidth,
    double? imageHeight,
    Rect? cropRect,
    bool clearError = false,
    bool clearCrop = false,
  }) {
    return SignupAvatarState(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      avatar: avatar ?? this.avatar,
      avatarPreviewBytes: avatarPreviewBytes ?? this.avatarPreviewBytes,
      carouselPreviewBytes: carouselPreviewBytes ?? this.carouselPreviewBytes,
      processing: processing ?? this.processing,
      errorType: clearError ? null : errorType ?? this.errorType,
      errorMaxKilobytes:
          clearError ? null : errorMaxKilobytes ?? this.errorMaxKilobytes,
      backgroundLocked: backgroundLocked ?? this.backgroundLocked,
      lockedBackgroundColor:
          lockedBackgroundColor ?? this.lockedBackgroundColor,
      activeTemplate: activeTemplate ?? this.activeTemplate,
      activeCategory: activeCategory ?? this.activeCategory,
      sourceBytes: clearCrop ? null : sourceBytes ?? this.sourceBytes,
      imageWidth: clearCrop ? null : imageWidth ?? this.imageWidth,
      imageHeight: clearCrop ? null : imageHeight ?? this.imageHeight,
      cropRect: clearCrop ? null : cropRect ?? this.cropRect,
    );
  }

  @override
  List<Object?> get props => [
        avatar?.hash,
        avatarPreviewBytes,
        carouselPreviewBytes,
        processing,
        errorType,
        errorMaxKilobytes,
        backgroundColor,
        backgroundLocked,
        lockedBackgroundColor,
        activeTemplate,
        activeCategory,
        sourceBytes,
        imageWidth,
        imageHeight,
        cropRect,
      ];
}
