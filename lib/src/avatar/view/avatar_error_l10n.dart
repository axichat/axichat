// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/avatar/bloc/avatar_editor_cubit.dart';
import 'package:axichat/src/avatar/bloc/signup_avatar_cubit.dart';
import 'package:axichat/src/localization/app_localizations.dart';

extension AvatarEditorErrorLocalization on AvatarEditorErrorType {
  String resolve(AppLocalizations l10n) => switch (this) {
    AvatarEditorErrorType.openFailed => l10n.avatarOpenError,
    AvatarEditorErrorType.readFailed => l10n.avatarReadError,
    AvatarEditorErrorType.invalidImage => l10n.avatarInvalidImageError,
    AvatarEditorErrorType.processingFailed => l10n.avatarProcessError,
    AvatarEditorErrorType.templateLoadFailed => l10n.avatarTemplateLoadError,
    AvatarEditorErrorType.missingDraft => l10n.avatarMissingDraftError,
    AvatarEditorErrorType.xmppDisconnected => l10n.avatarXmppDisconnectedError,
    AvatarEditorErrorType.publishRejected => l10n.avatarPublishRejectedError,
    AvatarEditorErrorType.publishTimeout => l10n.avatarPublishTimeoutError,
    AvatarEditorErrorType.publishGeneric => l10n.avatarPublishGenericError,
  };
}

extension SignupAvatarErrorLocalization on SignupAvatarErrorType {
  String resolve(
    AppLocalizations l10n, {
    required bool hasSourceBytes,
    int? maxKilobytes,
    required int fallbackMaxKilobytes,
  }) {
    return switch (this) {
      SignupAvatarErrorType.openFailed => l10n.signupAvatarOpenError,
      SignupAvatarErrorType.readFailed => l10n.signupAvatarReadError,
      SignupAvatarErrorType.invalidImage => l10n.signupAvatarInvalidImage,
      SignupAvatarErrorType.sizeExceeded => l10n.signupAvatarSizeError(
        maxKilobytes ?? fallbackMaxKilobytes,
      ),
      SignupAvatarErrorType.processingFailed =>
        hasSourceBytes
            ? l10n.signupAvatarProcessError
            : l10n.signupAvatarRenderError,
    };
  }
}
