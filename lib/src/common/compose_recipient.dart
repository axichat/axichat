// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/models.dart';
import 'package:equatable/equatable.dart';

class ComposerRecipient extends Equatable {
  const ComposerRecipient({
    required this.target,
    this.included = true,
    this.pinned = false,
  });

  final Contact target;
  final bool included;
  final bool pinned;

  String get key => target.key;

  bool get isIncluded => included;

  bool get isPinned => pinned;

  String? get recipientId => target.recipientId;

  bool get needsTransportSelection => target.needsTransportSelection;

  bool usesEmailTransport({bool allowHint = false}) =>
      target.usesEmailTransport(allowHint: allowHint);

  String? xmppJid({bool allowHint = false}) =>
      target.xmppJid(allowHint: allowHint);

  ComposerRecipient withIncluded(bool included) => copyWith(included: included);

  ComposerRecipient toggledIncluded() => copyWith(included: !included);

  ComposerRecipient withTarget(Contact target) => copyWith(target: target);

  ComposerRecipient copyWith({Contact? target, bool? included, bool? pinned}) =>
      ComposerRecipient(
        target: target ?? this.target,
        included: included ?? this.included,
        pinned: pinned ?? this.pinned,
      );

  @override
  List<Object?> get props => [target, included, pinned];
}

extension ComposerRecipients on Iterable<ComposerRecipient> {
  List<ComposerRecipient> get includedRecipients =>
      where((recipient) => recipient.isIncluded).toList(growable: false);

  bool hasEmailRecipients({bool allowHint = false}) {
    for (final recipient in this) {
      if (recipient.usesEmailTransport(allowHint: allowHint)) {
        return true;
      }
    }
    return false;
  }

  bool hasXmppRecipients({bool allowHint = false}) {
    for (final recipient in this) {
      final xmppJid = recipient.xmppJid(allowHint: allowHint);
      if (xmppJid != null && xmppJid.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  List<ComposerRecipient> emailRecipients({bool allowHint = false}) => where(
    (recipient) => recipient.usesEmailTransport(allowHint: allowHint),
  ).toList(growable: false);

  List<ComposerRecipient> xmppRecipients({bool allowHint = false}) =>
      where((recipient) {
        final xmppJid = recipient.xmppJid(allowHint: allowHint);
        return xmppJid != null && xmppJid.isNotEmpty;
      }).toList(growable: false);

  List<String> recipientAddresses({bool allowHint = false}) {
    final resolved = <String>[];
    for (final recipient in this) {
      final chatJid = recipient.target.chatJid;
      if (chatJid != null && chatJid.isNotEmpty) {
        resolved.add(chatJid);
        continue;
      }
      final xmppJid = recipient.xmppJid(allowHint: allowHint);
      if (xmppJid != null && xmppJid.isNotEmpty) {
        resolved.add(xmppJid);
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
