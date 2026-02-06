// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/localization/app_localizations.dart';

extension AuthMessageLocalization on AuthMessage {
  String resolve(AppLocalizations l10n) {
    return switch (this) {
      AuthKeyMessage(:final key) => key.resolve(l10n),
      AuthBackoffMessage(:final remainingSeconds) =>
        l10n.authLoginBackoff(remainingSeconds),
      AuthRawMessage(:final text) => text,
    };
  }
}

extension AuthMessageKeyLocalization on AuthMessageKey {
  String resolve(AppLocalizations l10n) => switch (this) {
        AuthMessageKey.enableXmppOrSmtp => l10n.authEnableXmppOrSmtp,
        AuthMessageKey.usernamePasswordMismatch =>
          l10n.authUsernamePasswordMismatch,
        AuthMessageKey.storedCredentialsOutdated =>
          l10n.authStoredCredentialsOutdated,
        AuthMessageKey.missingDatabaseSecrets =>
          l10n.authMissingDatabaseSecrets,
        AuthMessageKey.invalidCredentials => l10n.authInvalidCredentials,
        AuthMessageKey.genericError => l10n.authGenericError,
        AuthMessageKey.storageLocked => l10n.authStorageLocked,
        AuthMessageKey.emailServerUnreachable =>
          l10n.authEmailServerUnreachable,
        AuthMessageKey.emailSetupFailed => l10n.authEmailSetupFailed,
        AuthMessageKey.emailPasswordMissing => l10n.authEmailPasswordMissing,
        AuthMessageKey.emailAuthFailed => l10n.authEmailAuthFailed,
        AuthMessageKey.signupCleanupInProgress => l10n.signupCleanupInProgress,
        AuthMessageKey.signupFailedTryAgain => l10n.signupFailedTryAgain,
        AuthMessageKey.passwordMismatch => l10n.authPasswordMismatch,
        AuthMessageKey.passwordChangeDisabled =>
          l10n.authPasswordChangeDisabled,
        AuthMessageKey.passwordChangeRejected =>
          l10n.authPasswordChangeRejected,
        AuthMessageKey.passwordChangeFailed => l10n.authPasswordChangeFailed,
        AuthMessageKey.passwordChangeSuccess => l10n.authPasswordChangeSuccess,
        AuthMessageKey.passwordIncorrect => l10n.authPasswordIncorrect,
        AuthMessageKey.accountNotFound => l10n.authAccountNotFound,
        AuthMessageKey.accountDeletionDisabled =>
          l10n.authAccountDeletionDisabled,
        AuthMessageKey.accountDeletionFailed => l10n.authAccountDeletionFailed,
        AuthMessageKey.demoModeFailed => l10n.authDemoModeFailed,
      };
}
