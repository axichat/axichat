// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:equatable/equatable.dart';

const int composeRecipientLimit = 12;

extension type const ComposerRecipientKey(String value) {
  bool get isEmpty => value.isEmpty;
}

enum SendRecipientOutcome { completed, failed, notAttempted }

enum ComposerSendOutcomeStatus { completed, blocked, incomplete }

final class ComposerSendProgress {
  ComposerSendProgress(Iterable<ComposerRecipientKey> rawSubmittedKeys)
    : this._(_uniqueSubmittedKeys(rawSubmittedKeys));

  ComposerSendProgress._(List<ComposerRecipientKey> submittedKeys)
    : submittedKeys = List<ComposerRecipientKey>.unmodifiable(submittedKeys),
      _submittedKeySet = Set<ComposerRecipientKey>.unmodifiable(submittedKeys);

  final List<ComposerRecipientKey> submittedKeys;
  final Set<ComposerRecipientKey> _submittedKeySet;
  final Map<ComposerRecipientKey, SendRecipientOutcome> _outcomes =
      <ComposerRecipientKey, SendRecipientOutcome>{};

  bool get hasSubmittedRecipients => submittedKeys.isNotEmpty;

  bool get allCompleted =>
      hasSubmittedRecipients &&
      submittedKeys.every(
        (key) => _outcomes[key] == SendRecipientOutcome.completed,
      );

  Map<ComposerRecipientKey, SendRecipientOutcome> get outcomes {
    return Map<ComposerRecipientKey, SendRecipientOutcome>.unmodifiable({
      for (final key in submittedKeys)
        key: _outcomes[key] ?? SendRecipientOutcome.notAttempted,
    });
  }

  Set<ComposerRecipientKey> get incompleteKeys {
    return Set<ComposerRecipientKey>.unmodifiable(
      submittedKeys.where(
        (key) => _outcomes[key] != SendRecipientOutcome.completed,
      ),
    );
  }

  Set<ComposerRecipientKey> get completedKeys {
    return Set<ComposerRecipientKey>.unmodifiable(
      submittedKeys.where(
        (key) => _outcomes[key] == SendRecipientOutcome.completed,
      ),
    );
  }

  void markCompleted(ComposerRecipientKey key) {
    _mark(key, SendRecipientOutcome.completed);
  }

  void markFailed(ComposerRecipientKey key) {
    _mark(key, SendRecipientOutcome.failed);
  }

  void markNotAttempted(ComposerRecipientKey key) {
    _mark(key, SendRecipientOutcome.notAttempted);
  }

  void markCompletedAll(Iterable<ComposerRecipientKey> keys) {
    for (final key in keys) {
      markCompleted(key);
    }
  }

  void markFailedAll(Iterable<ComposerRecipientKey> keys) {
    for (final key in keys) {
      markFailed(key);
    }
  }

  void markNotAttemptedAll(Iterable<ComposerRecipientKey> keys) {
    for (final key in keys) {
      markNotAttempted(key);
    }
  }

  void applyOutcomes(Map<ComposerRecipientKey, SendRecipientOutcome> outcomes) {
    for (final entry in outcomes.entries) {
      _mark(entry.key, entry.value);
    }
  }

  void markMissingAs(
    Iterable<ComposerRecipientKey> keys,
    SendRecipientOutcome outcome,
  ) {
    for (final key in keys) {
      if (_outcomes.containsKey(key)) {
        continue;
      }
      _mark(key, outcome);
    }
  }

  List<ComposerRecipient> incompleteRecipientsFor(
    Iterable<ComposerRecipient> submittedRecipients,
  ) {
    final keys = incompleteKeys;
    return submittedRecipients
        .where((recipient) => keys.contains(recipient.recipientKey))
        .toList(growable: false);
  }

  void _mark(ComposerRecipientKey key, SendRecipientOutcome outcome) {
    if (!_submittedKeySet.contains(key)) {
      return;
    }
    _outcomes[key] = outcome;
  }

  static List<ComposerRecipientKey> _uniqueSubmittedKeys(
    Iterable<ComposerRecipientKey> rawSubmittedKeys,
  ) {
    final keys = <ComposerRecipientKey>[];
    final seen = <ComposerRecipientKey>{};
    for (final key in rawSubmittedKeys) {
      if (key.isEmpty) {
        continue;
      }
      if (seen.add(key)) {
        keys.add(key);
      }
    }
    return keys;
  }
}

bool isAxiImServerAnnouncementRecipientTarget(Contact target) {
  for (final address in target.identityAddresses) {
    if (isAxiImServerAnnouncementJid(address)) {
      return true;
    }
  }
  return false;
}

bool exceedsComposeRecipientLimit({
  required Iterable<ComposerRecipient> recipients,
  required Contact target,
  int maxRecipients = composeRecipientLimit,
  String? forceEmailDomain,
}) {
  if (recipients.any((recipient) => recipient.key == target.key)) {
    return false;
  }
  if (forceEmailDomain != null) {
    final targetIntent = ComposerRecipient(
      target: target,
    ).forcedEmailIntent(emailDomain: forceEmailDomain);
    if (targetIntent == null) {
      return false;
    }
    final emailSlots = recipients
        .where(
          (recipient) =>
              recipient.forcedEmailIntent(emailDomain: forceEmailDomain) !=
              null,
        )
        .length;
    return emailSlots >= maxRecipients;
  }
  final targetIntent = ComposerRecipient(target: target).intent;
  if (targetIntent is XmppRecipientIntent ||
      targetIntent is UnresolvedRecipient) {
    return false;
  }
  var emailSlots = 0;
  for (final recipient in recipients) {
    switch (recipient.intent) {
      case EmailRecipientIntent() || PendingTransportRecipient():
        emailSlots += 1;
      case XmppRecipientIntent() || UnresolvedRecipient():
        break;
    }
  }
  return emailSlots >= maxRecipients;
}

enum UnresolvedRecipientReason { missingAddress, missingEmailAddress }

sealed class RecipientIntent extends Equatable {
  const RecipientIntent();
}

final class XmppRecipientIntent extends RecipientIntent {
  const XmppRecipientIntent({
    required this.jid,
    required this.encryptionProtocol,
    required this.chatType,
    required this.recipientKey,
  });

  final String jid;
  final EncryptionProtocol encryptionProtocol;
  final ChatType chatType;
  final ComposerRecipientKey recipientKey;

  @override
  List<Object?> get props => [jid, encryptionProtocol, chatType, recipientKey];
}

final class EmailRecipientIntent extends RecipientIntent {
  const EmailRecipientIntent({
    required this.address,
    required this.displayName,
    required this.shareSignatureEnabled,
    required this.recipientKey,
    this.sourceChatJid,
    this.fromAddress,
    this.nativeID,
  });

  final String address;
  final String displayName;
  final bool shareSignatureEnabled;
  final ComposerRecipientKey recipientKey;
  final String? sourceChatJid;
  final String? fromAddress;
  final String? nativeID;

  @override
  List<Object?> get props => [
    address,
    displayName,
    shareSignatureEnabled,
    recipientKey,
    sourceChatJid,
    fromAddress,
    nativeID,
  ];
}

final class PendingTransportRecipient extends RecipientIntent {
  const PendingTransportRecipient();

  @override
  List<Object?> get props => const [];
}

final class UnresolvedRecipient extends RecipientIntent {
  const UnresolvedRecipient({required this.reason});

  final UnresolvedRecipientReason reason;

  @override
  List<Object?> get props => [reason];
}

class ComposerRecipient extends Equatable {
  ComposerRecipient({
    required this.target,
    ComposerRecipientKey? recipientKey,
    this.included = true,
    this.pinned = false,
  }) : recipientKey = recipientKey ?? ComposerRecipientKey(target.key);

  final Contact target;
  final ComposerRecipientKey recipientKey;
  final bool included;
  final bool pinned;

  String get key => recipientKey.value;

  bool get isPinned => pinned;

  String? get recipientId => target.recipientId;

  bool get needsTransportSelection => target.needsTransportSelection;

  RecipientIntent get intent {
    if (target.needsTransportSelection) {
      return const PendingTransportRecipient();
    }
    final transport = target.configuredTransport;
    if (transport == null) {
      return const UnresolvedRecipient(
        reason: UnresolvedRecipientReason.missingAddress,
      );
    }
    if (transport.isEmail) {
      return _emailIntent() ??
          const UnresolvedRecipient(
            reason: UnresolvedRecipientReason.missingEmailAddress,
          );
    }
    final jid = target.chat?.jid ?? target.normalizedOrResolvedAddress;
    if (jid == null || jid.isEmpty) {
      return const UnresolvedRecipient(
        reason: UnresolvedRecipientReason.missingAddress,
      );
    }
    return XmppRecipientIntent(
      jid: jid,
      encryptionProtocol: target.encryptionProtocol,
      chatType: target.chatType,
      recipientKey: recipientKey,
    );
  }

  EmailRecipientIntent? forcedEmailIntent({required String? emailDomain}) {
    final resolved = intent;
    if (resolved is EmailRecipientIntent) {
      return resolved;
    }
    if (resolved is UnresolvedRecipient) {
      return null;
    }
    final chat = target.chat;
    if (chat != null &&
        !chat.supportsEmail &&
        !chat.supportsEmailOutboundOverrideForDomain(emailDomain)) {
      return null;
    }
    return _emailIntent();
  }

  EmailRecipientIntent? _emailIntent() {
    final address = target.preferredEmailAddress?.trim();
    if (address == null || normalizedAddressValue(address) == null) {
      return null;
    }
    return EmailRecipientIntent(
      address: address,
      displayName: target.displayName,
      shareSignatureEnabled: target.shareSignatureEnabled,
      recipientKey: recipientKey,
      sourceChatJid: target.chat?.jid,
      fromAddress: target.chat?.emailFromAddress,
      nativeID: target.nativeID,
    );
  }

  bool get hasEmailComposeHint => switch (intent) {
    EmailRecipientIntent() => true,
    PendingTransportRecipient() => target.hintedTransport?.isEmail ?? false,
    _ => false,
  };

  ComposerRecipient withIncluded(bool included) => copyWith(included: included);

  ComposerRecipient withTarget(Contact target) => copyWith(target: target);

  ComposerRecipient copyWith({
    Contact? target,
    ComposerRecipientKey? recipientKey,
    bool? included,
    bool? pinned,
  }) => ComposerRecipient(
    target: target ?? this.target,
    recipientKey: recipientKey ?? this.recipientKey,
    included: included ?? this.included,
    pinned: pinned ?? this.pinned,
  );

  @override
  List<Object?> get props => [target, recipientKey, included, pinned];
}

final class SendIntentPartition {
  const SendIntentPartition({
    required this.xmpp,
    required this.email,
    required this.pending,
    required this.unresolved,
  });

  final List<XmppRecipientIntent> xmpp;
  final List<EmailRecipientIntent> email;
  final List<ComposerRecipient> pending;
  final List<ComposerRecipient> unresolved;

  bool get isSendable =>
      pending.isEmpty &&
      unresolved.isEmpty &&
      (xmpp.isNotEmpty || email.isNotEmpty);
}

extension ComposerRecipients on Iterable<ComposerRecipient> {
  List<ComposerRecipient> get includedRecipients =>
      where((recipient) => recipient.included).toList(growable: false);

  SendIntentPartition get sendPartition {
    final xmpp = <XmppRecipientIntent>[];
    final email = <EmailRecipientIntent>[];
    final pending = <ComposerRecipient>[];
    final unresolved = <ComposerRecipient>[];
    for (final recipient in this) {
      switch (recipient.intent) {
        case final XmppRecipientIntent intent:
          xmpp.add(intent);
        case final EmailRecipientIntent intent:
          email.add(intent);
        case PendingTransportRecipient():
          pending.add(recipient);
        case UnresolvedRecipient():
          unresolved.add(recipient);
      }
    }
    return SendIntentPartition(
      xmpp: xmpp,
      email: email,
      pending: pending,
      unresolved: unresolved,
    );
  }

  SendIntentPartition? forcedEmailPartition({required String? emailDomain}) {
    final email = <EmailRecipientIntent>[];
    for (final recipient in this) {
      final forced = recipient.forcedEmailIntent(emailDomain: emailDomain);
      if (forced == null) {
        return null;
      }
      email.add(forced);
    }
    return SendIntentPartition(
      xmpp: const [],
      email: email,
      pending: const [],
      unresolved: const [],
    );
  }

  bool get hasEmailRecipients =>
      any((recipient) => recipient.intent is EmailRecipientIntent);

  bool get hasXmppRecipients =>
      any((recipient) => recipient.intent is XmppRecipientIntent);

  bool get hasEmailComposeHint =>
      any((recipient) => recipient.hasEmailComposeHint);

  int get emailComposeHintCount =>
      where((recipient) => recipient.hasEmailComposeHint).length;

  List<ComposerRecipient> get emailRecipients => where(
    (recipient) => recipient.intent is EmailRecipientIntent,
  ).toList(growable: false);

  List<ComposerRecipient> get xmppRecipients => where(
    (recipient) => recipient.intent is XmppRecipientIntent,
  ).toList(growable: false);

  List<String> get recipientAddresses {
    final resolved = <String>[];
    for (final recipient in this) {
      final chatJid = recipient.target.chatJid;
      if (chatJid != null && chatJid.isNotEmpty) {
        resolved.add(chatJid);
        continue;
      }
      final address = recipient.target.normalizedOrResolvedAddress;
      if (address != null && address.isNotEmpty) {
        resolved.add(address);
      }
    }
    return resolved;
  }

  List<String> recipientIds({String? fallbackJid}) {
    final resolved = <String>{};
    for (final recipient in this) {
      final recipientId = recipient.recipientId;
      if (recipientId != null && recipientId.isNotEmpty) {
        resolved.add(recipientId);
      }
    }
    final trimmedFallback = fallbackJid?.trim();
    if (resolved.isEmpty &&
        trimmedFallback != null &&
        trimmedFallback.isNotEmpty) {
      resolved.add(trimmedFallback);
    }
    return resolved.toList(growable: false);
  }

  bool shouldFanOut(Chat chat) {
    final recipients = toList(growable: false);
    if (recipients.isEmpty) {
      return false;
    }
    if (recipients.length == 1 &&
        recipients.single.target.matchesChatJid(chat.jid)) {
      return false;
    }
    return true;
  }
}
