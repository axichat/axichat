// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/share/system_share_target_service.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('channel payload tolerates failed avatar hydration', () async {
    const target = SystemShareTarget(
      jid: 'avatar@example.com',
      label: 'Avatar',
      avatarPath: '/avatars/avatar.enc',
      rank: 0,
    );

    final values = await SystemShareTargetService.channelValuesForTargets([
      target,
    ], loadAvatarBytes: (_) async => throw Exception('bad avatar'));

    expect(values.single['avatarBytes'], isNull);
  });

  test('channel payload loads each avatar path once', () async {
    const targets = [
      SystemShareTarget(
        jid: 'one@example.com',
        label: 'One',
        avatarPath: '/avatars/shared.enc',
        rank: 0,
      ),
      SystemShareTarget(
        jid: 'two@example.com',
        label: 'Two',
        avatarPath: '/avatars/shared.enc',
        rank: 1,
      ),
    ];
    final bytes = Uint8List.fromList([1, 2, 3]);
    var loadCount = 0;

    final values = await SystemShareTargetService.channelValuesForTargets(
      targets,
      loadAvatarBytes: (_) async {
        loadCount += 1;
        return bytes;
      },
    );

    expect(loadCount, 1);
    expect(values.map((value) => value['avatarBytes']), [bytes, bytes]);
  });

  group('publishing pipeline', () {
    const channel = MethodChannel('test/system_share_targets');

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('newer publish supersedes older delayed avatar publish', () async {
      final nativeSetJids = <List<String>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'getMaxShareTargetCount':
                return 4;
              case 'setShareTargets':
                nativeSetJids.add(_targetJids(call.arguments));
                return null;
              case 'clearShareTargets':
                return null;
            }
            fail('Unexpected method call: ${call.method}');
          });
      final service = SystemShareTargetService(channel: channel);
      final avatarLoadStarted = Completer<void>();
      final avatarLoad = Completer<Uint8List?>();

      final olderPublish = service.publishTargets(
        chats: [_chat('old@example.com', avatarPath: '/avatars/old.png')],
        smtpEnabled: false,
        loadAvatarBytes: (path) {
          expect(path, '/avatars/old.png');
          avatarLoadStarted.complete();
          return avatarLoad.future;
        },
      );
      await avatarLoadStarted.future;

      final newerPublish = service.publishTargets(
        chats: [_chat('new@example.com')],
        smtpEnabled: false,
      );
      avatarLoad.complete(Uint8List.fromList([1, 2, 3]));
      await Future.wait([olderPublish, newerPublish]);

      expect(nativeSetJids, [
        ['new@example.com'],
      ]);
    });

    test('clear supersedes in-flight publish before native set', () async {
      final nativeSetJids = <List<String>>[];
      var clearCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'getMaxShareTargetCount':
                return 4;
              case 'setShareTargets':
                nativeSetJids.add(_targetJids(call.arguments));
                return null;
              case 'clearShareTargets':
                clearCount += 1;
                return null;
            }
            fail('Unexpected method call: ${call.method}');
          });
      final service = SystemShareTargetService(channel: channel);
      final avatarLoadStarted = Completer<void>();
      final avatarLoad = Completer<Uint8List?>();

      final publish = service.publishTargets(
        chats: [_chat('old@example.com', avatarPath: '/avatars/old.png')],
        smtpEnabled: false,
        loadAvatarBytes: (path) {
          avatarLoadStarted.complete();
          return avatarLoad.future;
        },
      );
      await avatarLoadStarted.future;

      final clear = service.clearShareTargets();
      avatarLoad.complete(Uint8List.fromList([1, 2, 3]));
      await Future.wait([publish, clear]);

      expect(nativeSetJids, isEmpty);
      expect(clearCount, 1);
    });

    test(
      'queued clear runs before later publish after stale publish',
      () async {
        final nativeCalls = <String>[];
        final nativeSetJids = <List<String>>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              switch (call.method) {
                case 'getMaxShareTargetCount':
                  return 4;
                case 'setShareTargets':
                  nativeCalls.add('setShareTargets');
                  nativeSetJids.add(_targetJids(call.arguments));
                  throw PlatformException(
                    code: 'share_targets_rejected',
                    message: 'Android rejected share target shortcut update.',
                  );
                case 'clearShareTargets':
                  nativeCalls.add('clearShareTargets');
                  return null;
              }
              fail('Unexpected method call: ${call.method}');
            });
        final service = SystemShareTargetService(channel: channel);
        final avatarLoadStarted = Completer<void>();
        final avatarLoad = Completer<Uint8List?>();

        final olderPublish = service.publishTargets(
          chats: [_chat('old@example.com', avatarPath: '/avatars/old.png')],
          smtpEnabled: false,
          loadAvatarBytes: (path) {
            avatarLoadStarted.complete();
            return avatarLoad.future;
          },
        );
        await avatarLoadStarted.future;

        final clear = service.clearShareTargets();
        final newerPublish = service.publishTargets(
          chats: [_chat('new@example.com')],
          smtpEnabled: false,
        );
        avatarLoad.complete(Uint8List.fromList([1, 2, 3]));
        await Future.wait([olderPublish, clear, newerPublish]);

        expect(nativeCalls, ['clearShareTargets', 'setShareTargets']);
        expect(nativeSetJids, [
          ['new@example.com'],
        ]);
      },
    );

    test('failed clear drops queued publish without retrying', () async {
      final nativeCalls = <String>[];
      final clearStarted = Completer<void>();
      final finishClear = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'getMaxShareTargetCount':
                return 4;
              case 'clearShareTargets':
                nativeCalls.add('clearShareTargets');
                clearStarted.complete();
                await finishClear.future;
                throw PlatformException(
                  code: 'share_targets_unavailable',
                  message: 'Android share targets are unavailable.',
                );
              case 'setShareTargets':
                nativeCalls.add('setShareTargets');
                return null;
            }
            fail('Unexpected method call: ${call.method}');
          });
      final service = SystemShareTargetService(channel: channel);

      final clear = service.clearShareTargets();
      await clearStarted.future;
      final publish = service.publishTargets(
        chats: [_chat('new@example.com')],
        smtpEnabled: false,
      );
      finishClear.complete();
      await Future.wait([clear, publish]).timeout(const Duration(seconds: 1));

      expect(nativeCalls, ['clearShareTargets']);
    });

    test('failed clear preserves a later queued clear and publish', () async {
      final nativeCalls = <String>[];
      final nativeSetJids = <List<String>>[];
      final firstClearStarted = Completer<void>();
      final finishFirstClear = Completer<void>();
      var clearCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'getMaxShareTargetCount':
                return 4;
              case 'clearShareTargets':
                nativeCalls.add('clearShareTargets');
                clearCount += 1;
                if (clearCount == 1) {
                  firstClearStarted.complete();
                  await finishFirstClear.future;
                  throw PlatformException(
                    code: 'share_targets_unavailable',
                    message: 'Android share targets are unavailable.',
                  );
                }
                return null;
              case 'setShareTargets':
                nativeCalls.add('setShareTargets');
                nativeSetJids.add(_targetJids(call.arguments));
                return null;
            }
            fail('Unexpected method call: ${call.method}');
          });
      final service = SystemShareTargetService(channel: channel);

      final firstClear = service.clearShareTargets();
      await firstClearStarted.future;
      final secondClear = service.clearShareTargets();
      final publish = service.publishTargets(
        chats: [_chat('new@example.com')],
        smtpEnabled: false,
      );
      finishFirstClear.complete();
      await Future.wait([
        firstClear,
        secondClear,
        publish,
      ]).timeout(const Duration(seconds: 1));

      expect(nativeCalls, [
        'clearShareTargets',
        'clearShareTargets',
        'setShareTargets',
      ]);
      expect(nativeSetJids, [
        ['new@example.com'],
      ]);
    });

    test('native rejection does not cache fingerprint', () async {
      var setCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'getMaxShareTargetCount':
                return 4;
              case 'setShareTargets':
                setCount += 1;
                if (setCount == 1) {
                  throw PlatformException(
                    code: 'share_targets_rejected',
                    message: 'Android rejected share target shortcut update.',
                  );
                }
                return null;
              case 'clearShareTargets':
                return null;
            }
            fail('Unexpected method call: ${call.method}');
          });
      final service = SystemShareTargetService(channel: channel);
      final chats = [_chat('retry@example.com')];

      await service.publishTargets(chats: chats, smtpEnabled: false);
      await service.publishTargets(chats: chats, smtpEnabled: false);

      expect(setCount, 2);
    });

    test('successful clear dedupes repeated clear requests', () async {
      var clearCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'getMaxShareTargetCount':
                return 4;
              case 'clearShareTargets':
                clearCount += 1;
                return null;
              case 'setShareTargets':
                return null;
            }
            fail('Unexpected method call: ${call.method}');
          });
      final service = SystemShareTargetService(channel: channel);

      await service.clearShareTargets();
      await service.clearShareTargets();

      expect(clearCount, 1);
    });

    test('non-Android publish and clear do not call the channel', () async {
      final calls = <String>[];
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return null;
          });
      final service = SystemShareTargetService(channel: channel);

      await service.publishTargets(
        chats: [_chat('ios@example.com')],
        smtpEnabled: false,
      );
      await service.clearShareTargets();

      expect(calls, isEmpty);
    });
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
  String? avatarPath,
  String? emailAddress,
}) {
  return Chat(
    jid: jid,
    title: jid,
    type: type,
    lastChangeTimestamp: lastChangeTimestamp ?? DateTime.utc(2025, 1, 1),
    transport: transport,
    avatarPath: avatarPath,
    hidden: hidden,
    archived: archived,
    spam: spam,
    emailAddress: emailAddress,
  );
}

List<String> _targetJids(Object? arguments) {
  return (arguments as List<Object?>)
      .map((value) {
        final target = value! as Map<Object?, Object?>;
        return target['jid']! as String;
      })
      .toList(growable: false);
}
