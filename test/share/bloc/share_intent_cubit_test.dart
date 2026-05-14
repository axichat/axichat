// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/share/bloc/share_intent_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_handler/share_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('preserves a sanitized conversation identifier', () async {
    final handler = _FakeShareHandler(
      initialMedia: SharedMedia(
        content: ' hello ',
        conversationIdentifier: ' alice@example.com ',
      ),
    );
    final cubit = ShareIntentCubit(handler: handler);
    addTearDown(cubit.close);
    addTearDown(handler.close);

    await cubit.initialize();

    final payload = cubit.state.payload;
    expect(payload?.text, 'hello');
    expect(payload?.conversationIdentifier, 'alice@example.com');
  });

  test('rejects empty payloads and NUL-only identifiers', () async {
    final handler = _FakeShareHandler(
      initialMedia: SharedMedia(
        content: ' \u0000 ',
        conversationIdentifier: 'bad\u0000target',
      ),
    );
    final cubit = ShareIntentCubit(handler: handler);
    addTearDown(cubit.close);
    addTearDown(handler.close);

    await cubit.initialize();

    expect(cubit.state.hasPayload, isFalse);
  });

  test('keeps existing text and attachment sanitization behavior', () async {
    final handler = _FakeShareHandler(
      initialMedia: SharedMedia(
        content: ' shared text ',
        conversationIdentifier: 'target@example.com',
        attachments: [
          SharedAttachment(
            path: ' /tmp/a.png ',
            type: SharedAttachmentType.image,
          ),
          SharedAttachment(
            path: '/tmp/a.png',
            type: SharedAttachmentType.image,
          ),
          SharedAttachment(
            path: '/tmp/b\u0000.png',
            type: SharedAttachmentType.file,
          ),
          SharedAttachment(path: '', type: SharedAttachmentType.file),
        ],
      ),
    );
    final cubit = ShareIntentCubit(handler: handler);
    addTearDown(cubit.close);
    addTearDown(handler.close);

    await cubit.initialize();

    final payload = cubit.state.payload;
    expect(payload?.text, 'shared text');
    expect(payload?.conversationIdentifier, 'target@example.com');
    expect(payload?.attachments, hasLength(1));
    expect(payload?.attachments.single.path, '/tmp/a.png');
    expect(payload?.attachments.single.type, SharedAttachmentType.image);
  });
}

final class _FakeShareHandler extends ShareHandlerPlatform {
  _FakeShareHandler({this.initialMedia});

  final SharedMedia? initialMedia;
  final StreamController<SharedMedia> _mediaController =
      StreamController<SharedMedia>.broadcast(sync: true);
  bool resetInitialSharedMediaCalled = false;

  @override
  Future<SharedMedia?> getInitialSharedMedia() async {
    return initialMedia;
  }

  @override
  Future<void> recordSentMessage({
    required String conversationIdentifier,
    required String conversationName,
    String? conversationImageFilePath,
    String? serviceName,
  }) async {}

  @override
  Future<void> resetInitialSharedMedia() async {
    resetInitialSharedMediaCalled = true;
  }

  @override
  Stream<SharedMedia> get sharedMediaStream => _mediaController.stream;

  Future<void> close() async {
    await _mediaController.close();
  }
}
