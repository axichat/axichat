// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:equatable/equatable.dart';

final class FanOutRecipientTargetSnapshot extends Equatable {
  const FanOutRecipientTargetSnapshot({
    required this.address,
    required this.displayName,
    required this.shareSignatureEnabled,
    this.sourceChatJid,
    this.fromAddress,
    this.nativeID,
  });

  factory FanOutRecipientTargetSnapshot.fromIntent(
    EmailRecipientIntent intent,
  ) {
    return FanOutRecipientTargetSnapshot(
      address: intent.address,
      displayName: intent.displayName,
      shareSignatureEnabled: intent.shareSignatureEnabled,
      sourceChatJid: intent.sourceChatJid,
      fromAddress: intent.fromAddress,
      nativeID: intent.nativeID,
    );
  }

  final String address;
  final String displayName;
  final bool shareSignatureEnabled;
  final String? sourceChatJid;
  final String? fromAddress;
  final String? nativeID;

  Chat get syntheticChat => Chat.fromJid(
    address,
  ).copyWith(transport: MessageTransport.email, emailAddress: address);

  Contact toContact() {
    final sourceJid = sourceChatJid?.trim();
    if (sourceJid != null && sourceJid.isNotEmpty) {
      final label = displayName.trim();
      final chat = Chat.fromJid(sourceJid).copyWith(
        title: label.isNotEmpty ? label : sourceJid,
        contactDisplayName: label.isNotEmpty ? label : null,
        emailAddress: address,
        emailFromAddress: fromAddress,
        transport: MessageTransport.email,
      );
      return Contact.chat(
        chat: chat,
        shareSignatureEnabled: shareSignatureEnabled,
      );
    }
    return Contact.address(
      nativeID: nativeID,
      address: address,
      displayName: displayName,
      shareSignatureEnabled: shareSignatureEnabled,
      transport: MessageTransport.email,
    );
  }

  @override
  List<Object?> get props => [
    address,
    displayName,
    shareSignatureEnabled,
    sourceChatJid,
    fromAddress,
    nativeID,
  ];
}

class FanOutRecipientStatus extends Equatable {
  const FanOutRecipientStatus({
    required this.recipientKey,
    required this.requestedTarget,
    required this.state,
    this.resolvedChat,
    this.deltaMsgId,
    this.error,
  });

  final ComposerRecipientKey recipientKey;
  final FanOutRecipientTargetSnapshot requestedTarget;
  final Chat? resolvedChat;
  final FanOutRecipientState state;
  final int? deltaMsgId;
  final Object? error;

  Chat get chat => resolvedChat ?? requestedTarget.syntheticChat;

  bool get isFailure => state == FanOutRecipientState.failed;

  @override
  List<Object?> get props => [
    recipientKey,
    requestedTarget,
    resolvedChat,
    state,
    deltaMsgId,
    error,
  ];
}
