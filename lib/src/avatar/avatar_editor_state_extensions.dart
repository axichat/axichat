// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_editor_mode.dart';
import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/bloc/avatar_editor_cubit.dart';
import 'package:axichat/src/localization/app_localizations.dart';

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

extension AvatarEditorStateLocalization on AvatarEditorState {
  String? localizedErrorText(AppLocalizations l10n) {
    final errorValue = error;
    if (errorValue == null) return null;
    final rawMessage = errorValue.message?.trim();
    return switch (errorValue.type) {
      AvatarEditorErrorType.openFailed => l10n.avatarOpenError,
      AvatarEditorErrorType.readFailed => l10n.avatarReadError,
      AvatarEditorErrorType.invalidImage => l10n.avatarInvalidImageError,
      AvatarEditorErrorType.processingFailed => l10n.avatarProcessError,
      AvatarEditorErrorType.templateLoadFailed => l10n.avatarTemplateLoadError,
      AvatarEditorErrorType.missingDraft => l10n.avatarMissingDraftError,
      AvatarEditorErrorType.xmppDisconnected =>
        l10n.avatarXmppDisconnectedError,
      AvatarEditorErrorType.publishRejected => l10n.avatarPublishRejectedError,
      AvatarEditorErrorType.publishTimeout => l10n.avatarPublishTimeoutError,
      AvatarEditorErrorType.publishGeneric => l10n.avatarPublishGenericError,
      AvatarEditorErrorType.publishUnexpected =>
        l10n.avatarPublishUnexpectedError,
      AvatarEditorErrorType.publishServerMessage =>
        rawMessage == null || rawMessage.isEmpty
            ? l10n.avatarPublishGenericError
            : rawMessage,
    };
  }
}
