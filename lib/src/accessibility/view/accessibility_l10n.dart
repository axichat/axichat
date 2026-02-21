// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/accessibility/models/accessibility_action_models.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:intl/intl.dart';

extension AccessibilityActionStatusL10n on AccessibilityActionStatus {
  String label(AppLocalizations l10n) => switch (this) {
    AccessibilityActionStatus.discardWarning =>
      l10n.accessibilityDiscardWarning,
    AccessibilityActionStatus.draftLoaded => l10n.accessibilityDraftLoaded,
    AccessibilityActionStatus.inviteAccepted =>
      l10n.accessibilityInviteAccepted,
    AccessibilityActionStatus.inviteDismissed =>
      l10n.accessibilityInviteDismissed,
  };
}

extension AccessibilityActionErrorL10n on AccessibilityActionError {
  String label(AppLocalizations l10n) => switch (this) {
    AccessibilityActionError.jidInputInvalid => l10n.jidInputInvalid,
    AccessibilityActionError.inviteUpdateFailed =>
      l10n.accessibilityInviteUpdateFailed,
  };
}

extension AccessibilityChatStatusL10n on AccessibilityChatStatus {
  String label(AppLocalizations l10n) => switch (this) {
    AccessibilityChatStatusMessageSent() => l10n.accessibilityMessageSent,
    AccessibilityChatStatusDraftSaved() => l10n.chatDraftSaved,
    AccessibilityChatStatusIncomingMessage(
      :final senderDisplayName,
      :final isSelf,
      :final timestamp,
    ) =>
      l10n.accessibilityIncomingMessageStatus(
        isSelf ? l10n.chatSenderYou : senderDisplayName,
        _formatTimestamp(l10n, timestamp),
      ),
  };
}

extension AccessibilityChatErrorL10n on AccessibilityChatError {
  String label(AppLocalizations l10n) => switch (this) {
    AccessibilityChatErrorMissingContent() => l10n.chatDraftMissingContent,
    AccessibilityChatErrorSendFailures(:final failureCount, :final failures) =>
      _fanOutFailureLabel(l10n, failureCount, failures),
  };
}

String _fanOutFailureLabel(
  AppLocalizations l10n,
  int failureCount,
  List<String> failures,
) {
  if (failureCount <= 0) return '';
  final recipientLabel = l10n.chatFanOutRecipientLabel(failureCount);
  final summary = l10n.chatFanOutFailure(failureCount, recipientLabel);
  return '$summary: ${failures.join(', ')}';
}

String _formatTimestamp(AppLocalizations l10n, DateTime? timestamp) {
  final safe = timestamp ?? DateTime.now();
  return DateFormat.yMMMd(l10n.localeName).add_jm().format(safe);
}
