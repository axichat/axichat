// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/avatar/bloc/signup_avatar_cubit.dart';
import 'package:axichat/src/localization/app_localizations.dart';

extension SignupAvatarErrorLocalization on SignupAvatarError {
  String localizedMessage({
    required AppLocalizations l10n,
    required bool hasSourceBytes,
    required int fallbackMaxKilobytes,
  }) {
    return switch (type) {
      SignupAvatarErrorType.openFailed => l10n.signupAvatarOpenError,
      SignupAvatarErrorType.readFailed => l10n.signupAvatarReadError,
      SignupAvatarErrorType.invalidImage => l10n.signupAvatarInvalidImage,
      SignupAvatarErrorType.sizeExceeded => l10n.signupAvatarSizeError(
          maxKilobytes ?? fallbackMaxKilobytes,
        ),
      SignupAvatarErrorType.processingFailed => hasSourceBytes
          ? l10n.signupAvatarProcessError
          : l10n.signupAvatarRenderError,
    };
  }
}

String? signupAvatarErrorText({
  required SignupAvatarState avatarState,
  required AppLocalizations l10n,
}) {
  final error = avatarState.error;
  if (error == null) return null;
  return error.localizedMessage(
    l10n: l10n,
    hasSourceBytes: avatarState.sourceBytes != null,
    fallbackMaxKilobytes: SignupAvatarCubit.avatarMaxKilobytes,
  );
}
