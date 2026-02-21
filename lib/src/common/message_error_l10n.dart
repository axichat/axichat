// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/storage/models/message_models.dart';

extension MessageErrorLocalization on MessageError {
  String? tooltip(AppLocalizations l10n) {
    if (this == MessageError.serviceUnavailable) {
      return l10n.messageErrorServiceUnavailableTooltip;
    }
    return null;
  }

  String label(AppLocalizations l10n) => switch (this) {
    MessageError.serviceUnavailable => l10n.messageErrorServiceUnavailable,
    MessageError.serverNotFound => l10n.messageErrorServerNotFound,
    MessageError.serverTimeout => l10n.messageErrorServerTimeout,
    MessageError.unknown => l10n.messageErrorUnknown,
    MessageError.notEncryptedForDevice =>
      l10n.messageErrorNotEncryptedForDevice,
    MessageError.malformedKey => l10n.messageErrorMalformedKey,
    MessageError.unknownSPK => l10n.messageErrorUnknownSignedPrekey,
    MessageError.noDeviceSession => l10n.messageErrorNoDeviceSession,
    MessageError.skippingTooManyKeys => l10n.messageErrorSkippingTooManyKeys,
    MessageError.invalidHMAC => l10n.messageErrorInvalidHmac,
    MessageError.malformedCiphertext => l10n.messageErrorMalformedCiphertext,
    MessageError.noKeyMaterial => l10n.messageErrorNoKeyMaterial,
    MessageError.noDecryptionKey => l10n.messageErrorNoDecryptionKey,
    MessageError.invalidKEX => l10n.messageErrorInvalidKex,
    MessageError.unknownOmemoError => l10n.messageErrorUnknownOmemo,
    MessageError.invalidAffixElements => l10n.messageErrorInvalidAffixElements,
    MessageError.emptyDeviceList => l10n.messageErrorEmptyDeviceList,
    MessageError.omemoUnsupported => l10n.messageErrorOmemoUnsupported,
    MessageError.encryptionFailure => l10n.messageErrorEncryptionFailure,
    MessageError.invalidEnvelope => l10n.messageErrorInvalidEnvelope,
    MessageError.fileDownloadFailure => l10n.messageErrorFileDownloadFailure,
    MessageError.fileUploadFailure => l10n.messageErrorFileUploadFailure,
    MessageError.fileDecryptionFailure =>
      l10n.messageErrorFileDecryptionFailure,
    MessageError.fileEncryptionFailure =>
      l10n.messageErrorFileEncryptionFailure,
    MessageError.plaintextFileInOmemo => l10n.messageErrorPlaintextFileInOmemo,
    MessageError.emailSendFailure => l10n.messageErrorEmailSendFailure,
    MessageError.emailAttachmentTooLarge =>
      l10n.messageErrorEmailAttachmentTooLarge,
    MessageError.emailRecipientRejected =>
      l10n.messageErrorEmailRecipientRejected,
    MessageError.emailAuthenticationFailed =>
      l10n.messageErrorEmailAuthenticationFailed,
    MessageError.emailBounced => l10n.messageErrorEmailBounced,
    MessageError.emailThrottled => l10n.messageErrorEmailThrottled,
    _ => l10n.messageErrorUnknown,
  };
}
