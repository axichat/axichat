// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/chat/models/chat_message.dart';
import 'package:axichat/src/localization/app_localizations.dart';

extension ChatMessageKeyL10n on ChatMessageKey {
  String label(
    AppLocalizations l10n, {
    String? moderationAction,
    String? moderationTarget,
  }) => switch (this) {
    ChatMessageKey.messageErrorServiceUnavailable =>
      l10n.messageErrorServiceUnavailable,
    ChatMessageKey.messageErrorServerNotFound =>
      l10n.messageErrorServerNotFound,
    ChatMessageKey.messageErrorServerTimeout => l10n.messageErrorServerTimeout,
    ChatMessageKey.messageErrorUnknown => l10n.messageErrorUnknown,
    ChatMessageKey.messageErrorNotEncryptedForDevice =>
      l10n.messageErrorNotEncryptedForDevice,
    ChatMessageKey.messageErrorMalformedKey => l10n.messageErrorMalformedKey,
    ChatMessageKey.messageErrorUnknownSignedPrekey =>
      l10n.messageErrorUnknownSignedPrekey,
    ChatMessageKey.messageErrorNoDeviceSession =>
      l10n.messageErrorNoDeviceSession,
    ChatMessageKey.messageErrorSkippingTooManyKeys =>
      l10n.messageErrorSkippingTooManyKeys,
    ChatMessageKey.messageErrorInvalidHmac => l10n.messageErrorInvalidHmac,
    ChatMessageKey.messageErrorMalformedCiphertext =>
      l10n.messageErrorMalformedCiphertext,
    ChatMessageKey.messageErrorNoKeyMaterial => l10n.messageErrorNoKeyMaterial,
    ChatMessageKey.messageErrorNoDecryptionKey =>
      l10n.messageErrorNoDecryptionKey,
    ChatMessageKey.messageErrorInvalidKex => l10n.messageErrorInvalidKex,
    ChatMessageKey.messageErrorUnknownOmemo => l10n.messageErrorUnknownOmemo,
    ChatMessageKey.messageErrorInvalidAffixElements =>
      l10n.messageErrorInvalidAffixElements,
    ChatMessageKey.messageErrorEmptyDeviceList =>
      l10n.messageErrorEmptyDeviceList,
    ChatMessageKey.messageErrorOmemoUnsupported =>
      l10n.messageErrorOmemoUnsupported,
    ChatMessageKey.messageErrorEncryptionFailure =>
      l10n.messageErrorEncryptionFailure,
    ChatMessageKey.messageErrorInvalidEnvelope =>
      l10n.messageErrorInvalidEnvelope,
    ChatMessageKey.messageErrorFileDownloadFailure =>
      l10n.messageErrorFileDownloadFailure,
    ChatMessageKey.messageErrorFileUploadFailure =>
      l10n.messageErrorFileUploadFailure,
    ChatMessageKey.messageErrorFileDecryptionFailure =>
      l10n.messageErrorFileDecryptionFailure,
    ChatMessageKey.messageErrorFileEncryptionFailure =>
      l10n.messageErrorFileEncryptionFailure,
    ChatMessageKey.messageErrorPlaintextFileInOmemo =>
      l10n.messageErrorPlaintextFileInOmemo,
    ChatMessageKey.messageErrorEmailSendFailure =>
      l10n.messageErrorEmailSendFailure,
    ChatMessageKey.messageErrorEmailAttachmentTooLarge =>
      l10n.messageErrorEmailAttachmentTooLarge,
    ChatMessageKey.messageErrorEmailRecipientRejected =>
      l10n.messageErrorEmailRecipientRejected,
    ChatMessageKey.messageErrorEmailAuthenticationFailed =>
      l10n.messageErrorEmailAuthenticationFailed,
    ChatMessageKey.messageErrorEmailBounced => l10n.messageErrorEmailBounced,
    ChatMessageKey.messageErrorEmailThrottled =>
      l10n.messageErrorEmailThrottled,
    ChatMessageKey.chatComposerEmptyMessage => l10n.chatComposerEmptyMessage,
    ChatMessageKey.chatComposerEmailUnavailable =>
      l10n.chatComposerEmailUnavailable,
    ChatMessageKey.chatComposerFileUploadUnavailable =>
      l10n.chatComposerFileUploadUnavailable,
    ChatMessageKey.chatComposerSelectRecipient =>
      l10n.chatComposerSelectRecipient,
    ChatMessageKey.chatComposerEmailRecipientUnavailable =>
      l10n.chatComposerEmailRecipientUnavailable,
    ChatMessageKey.chatComposerAttachmentBundleFailed =>
      l10n.chatComposerAttachmentBundleFailed,
    ChatMessageKey.chatComposerEmailAttachmentRecipientRequired =>
      l10n.chatComposerEmailAttachmentRecipientRequired,
    ChatMessageKey.chatEmailOfflineRetryMessage =>
      l10n.chatEmailOfflineRetryMessage,
    ChatMessageKey.chatAttachmentSendFailed => l10n.chatAttachmentSendFailed,
    ChatMessageKey.chatComposerSendFailed => l10n.chatComposerSendFailed,
    ChatMessageKey.chatEmailResendFailedDetails =>
      l10n.chatEmailResendFailedDetails,
    ChatMessageKey.chatDraftSaved => l10n.chatDraftSaved,
    ChatMessageKey.chatMembersLoading => l10n.chatMembersLoading,
    ChatMessageKey.chatInvitePermissionDenied =>
      l10n.chatInvitePermissionDenied,
    ChatMessageKey.chatInviteDomainRestricted =>
      l10n.chatInviteDomainRestricted,
    ChatMessageKey.chatInviteAlreadyMember => l10n.chatInviteAlreadyMember,
    ChatMessageKey.chatInviteSent => l10n.chatInviteSent,
    ChatMessageKey.chatInviteSendFailed => l10n.chatInviteSendFailed,
    ChatMessageKey.chatInviteRevoked => l10n.chatInviteRevoked,
    ChatMessageKey.chatInviteRevokeFailed => l10n.chatInviteRevokeFailed,
    ChatMessageKey.chatInviteJoinSuccess => l10n.chatInviteJoinSuccess,
    ChatMessageKey.chatInviteJoinFailed => l10n.chatInviteJoinFailed,
    ChatMessageKey.chatNicknameUpdated => l10n.chatNicknameUpdated,
    ChatMessageKey.chatNicknameUpdateFailed => l10n.chatNicknameUpdateFailed,
    ChatMessageKey.chatLeaveRoomFailed => l10n.chatLeaveRoomFailed,
    ChatMessageKey.chatDestroyRoomFailed => l10n.chatDestroyRoomFailed,
    ChatMessageKey.chatRoomAvatarPermissionDenied =>
      l10n.chatRoomAvatarPermissionDenied,
    ChatMessageKey.chatRoomAvatarUpdated => l10n.chatRoomAvatarUpdated,
    ChatMessageKey.chatRoomAvatarUpdateFailed =>
      l10n.chatRoomAvatarUpdateFailed,
    ChatMessageKey.chatPinPermissionDenied => l10n.chatPinPermissionDenied,
    ChatMessageKey.chatMessageForwarded => l10n.chatMessageForwarded,
    ChatMessageKey.chatMessageForwardFailed => l10n.chatMessageForwardFailed,
    ChatMessageKey.chatModerationRequested => l10n.chatModerationRequested(
      moderationAction ?? '',
      moderationTarget ?? '',
    ),
    ChatMessageKey.chatModerationFailed => l10n.chatModerationFailed,
    ChatMessageKey.fanOutErrorNoRecipients => l10n.fanOutErrorNoRecipients,
    ChatMessageKey.fanOutErrorResolveFailed => l10n.fanOutErrorResolveFailed,
    ChatMessageKey.fanOutErrorTooManyRecipients =>
      l10n.fanOutErrorTooManyRecipients(20),
    ChatMessageKey.fanOutErrorEmptyMessage => l10n.fanOutErrorEmptyMessage,
    ChatMessageKey.fanOutErrorInvalidShareToken =>
      l10n.fanOutErrorInvalidShareToken,
    ChatMessageKey.calendarTaskShareSendFailed =>
      l10n.calendarTaskShareSendFailed,
  };
}
