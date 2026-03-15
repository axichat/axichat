// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/bloc/avatar_editor_cubit.dart';
import 'package:axichat/src/avatar/models/avatar_models.dart';

extension AvatarEditorStateView on AvatarEditorState {
  Uint8List? get displayedBytes => draftAvatar?.bytes ?? carouselAvatar?.bytes;

  bool get hasCarouselPreview => carouselAvatar != null;

  AvatarEditorMode get editorMode {
    final draftAvatar = this.draftAvatar;
    if (draftAvatar?.source == AvatarSource.upload &&
        draftAvatar?.sourceBytes != null) {
      return AvatarEditorMode.cropOnly;
    }
    final templateValue = draftAvatar?.template;
    if (templateValue == null) return AvatarEditorMode.none;
    if (templateValue.category == AvatarTemplateCategory.abstract) {
      return AvatarEditorMode.none;
    }
    return AvatarEditorMode.colorOnly;
  }

  bool get canShuffleBackground {
    final templateValue = draftAvatar?.template ?? carouselAvatar?.template;
    if (templateValue == null) return false;
    if (templateValue.category == AvatarTemplateCategory.abstract) return false;
    return templateValue.hasAlphaBackground;
  }

  bool get isBusy => processing || shuffling || publishing;

  bool get hasUserSelectedAvatar => draftAvatar != null;

  bool get canUseCarouselAvatar =>
      hasCarouselPreview && !hasUserSelectedAvatar && !isBusy;
}
