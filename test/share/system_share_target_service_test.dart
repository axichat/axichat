// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:typed_data';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/share/system_share_target_service.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('orders recent eligible chats first and caps to the max count', () {
    final chats = [
      _chat('old@example.com', lastChangeTimestamp: DateTime.utc(2025, 1, 1)),
      _chat('new@example.com', lastChangeTimestamp: DateTime.utc(2025, 1, 3)),
      _chat(
        'middle@example.com',
        lastChangeTimestamp: DateTime.utc(2025, 1, 2),
      ),
    ];

    final targets = SystemShareTargetService.deriveTargets(
      chats: chats,
      smtpEnabled: false,
      maxCount: 2,
    );

    expect(targets.map((target) => target.jid), [
      'new@example.com',
      'middle@example.com',
    ]);
    expect(targets.map((target) => target.rank), [0, 1]);
  });

  test('includes XMPP direct chats and group chats', () {
    final targets = SystemShareTargetService.deriveTargets(
      chats: [
        _chat('direct@example.com'),
        _chat('room@example.com', type: ChatType.groupChat),
      ],
      smtpEnabled: false,
      maxCount: 8,
    );

    expect(targets.map((target) => target.jid), [
      'direct@example.com',
      'room@example.com',
    ]);
  });

  test('excludes hidden, archived, spam, note, and welcome chats', () {
    final targets = SystemShareTargetService.deriveTargets(
      chats: [
        _chat('visible@example.com'),
        _chat('hidden@example.com', hidden: true),
        _chat('archived@example.com', archived: true),
        _chat('spam@example.com', spam: true),
        _chat('note@example.com', type: ChatType.note),
        _chat('axichat@welcome.axichat.invalid'),
      ],
      smtpEnabled: true,
      maxCount: 8,
    );

    expect(targets.map((target) => target.jid), ['visible@example.com']);
  });

  test('requires SMTP for email-backed chats', () {
    final emailChat = _chat(
      'mail@example.com',
      transport: MessageTransport.email,
      emailAddress: 'mail@example.com',
    );

    expect(
      SystemShareTargetService.deriveTargets(
        chats: [emailChat],
        smtpEnabled: false,
        maxCount: 8,
      ),
      isEmpty,
    );
    expect(
      SystemShareTargetService.deriveTargets(
        chats: [emailChat],
        smtpEnabled: true,
        maxCount: 8,
      ).map((target) => target.jid),
      ['mail@example.com'],
    );
  });

  test('resolves exact eligible direct targets and falls back otherwise', () {
    final chats = [
      _chat('target@example.com'),
      _chat('archived@example.com', archived: true),
    ];

    expect(
      SystemShareTargetService.resolveConversationTargetJid(
        conversationIdentifier: 'target@example.com',
        chats: chats,
        smtpEnabled: false,
      ),
      'target@example.com',
    );
    expect(
      SystemShareTargetService.resolveConversationTargetJid(
        conversationIdentifier: 'stale@example.com',
        chats: chats,
        smtpEnabled: false,
      ),
      isNull,
    );
    expect(
      SystemShareTargetService.resolveConversationTargetJid(
        conversationIdentifier: 'archived@example.com',
        chats: chats,
        smtpEnabled: false,
      ),
      isNull,
    );
    expect(
      SystemShareTargetService.resolveConversationTargetJid(
        conversationIdentifier: null,
        chats: chats,
        smtpEnabled: false,
      ),
      isNull,
    );
  });

  test('Contact.chat seeds email-backed chats with email transport', () {
    final chat = _chat(
      'mail@example.com',
      transport: MessageTransport.email,
      emailAddress: 'real@example.com',
    );

    final contact = Contact.chat(chat: chat, shareSignatureEnabled: true);

    expect(contact.hasBackingChat, isTrue);
    expect(contact.configuredTransport, MessageTransport.email);
    expect(contact.preferredEmailAddress, 'real@example.com');
  });

  test('channel payload includes resolved avatar bytes', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    const target = SystemShareTarget(
      jid: 'avatar@example.com',
      label: 'Avatar',
      avatarPath: '/avatars/avatar.enc',
      rank: 0,
    );

    final values = await SystemShareTargetService.channelValuesForTargets(
      [target],
      loadAvatarBytes: (path) async {
        expect(path, '/avatars/avatar.enc');
        return bytes;
      },
    );

    expect(values.single['avatarBytes'], bytes);
  });
}

Chat _chat(
  String jid, {
  DateTime? lastChangeTimestamp,
  MessageTransport transport = MessageTransport.xmpp,
  ChatType type = ChatType.chat,
  bool hidden = false,
  bool archived = false,
  bool spam = false,
  String? emailAddress,
}) {
  return Chat(
    jid: jid,
    title: jid,
    type: type,
    lastChangeTimestamp: lastChangeTimestamp ?? DateTime.utc(2025, 1, 1),
    transport: transport,
    hidden: hidden,
    archived: archived,
    spam: spam,
    emailAddress: emailAddress,
  );
}
