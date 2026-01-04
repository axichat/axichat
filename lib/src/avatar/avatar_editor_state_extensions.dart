// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_editor_mode.dart';
import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/bloc/avatar_editor_cubit.dart';

extension AvatarEditorStateView on AvatarEditorState {
  Uint8List? get displayedBytes => previewBytes ?? sourceBytes;

  AvatarEditorMode get editorMode {
    if (source == AvatarSource.upload && sourceBytes != null) {
      return AvatarEditorMode.cropOnly;
    }
    final templateValue = template;
    if (templateValue == null) return AvatarEditorMode.none;
    if (templateValue.category == AvatarTemplateCategory.abstract) {
      return AvatarEditorMode.none;
    }
    return AvatarEditorMode.colorOnly;
  }

  bool get canShuffleBackground {
    final templateValue = template;
    if (templateValue == null) return false;
    if (templateValue.category == AvatarTemplateCategory.abstract) return false;
    return templateValue.hasAlphaBackground;
  }

  bool get isBusy => processing || shuffling || publishing;
}
