// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/share/bloc/share_intent_cubit.dart';
import 'package:axichat/src/share/share_handoff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_handler/share_handler.dart';

void main() {
  group('ShareComposerSeedQueue', () {
    test('keeps FIFO order per JID and ignores other JIDs', () {
      final queue = ShareComposerSeedQueue();
      addTearDown(queue.dispose);

      final first = queue.enqueue(
        jid: 'alice@example.com',
        body: 'first',
        attachments: const <Attachment>[],
      );
      final second = queue.enqueue(
        jid: 'alice@example.com',
        body: 'second',
        attachments: const <Attachment>[],
      );
      queue.enqueue(
        jid: 'bob@example.com',
        body: 'bob',
        attachments: const <Attachment>[],
      );

      expect(queue.pendingFor('alice@example.com'), [first, second]);
      expect(queue.pendingFor('carol@example.com'), isEmpty);
    });

    test('takes a seed once and leaves later seeds pending', () {
      final queue = ShareComposerSeedQueue();
      addTearDown(queue.dispose);

      final first = queue.enqueue(
        jid: 'alice@example.com',
        body: 'first',
        attachments: const <Attachment>[],
      );
      final second = queue.enqueue(
        jid: 'alice@example.com',
        body: 'second',
        attachments: const <Attachment>[],
      );

      expect(queue.take(first), isTrue);
      expect(queue.take(first), isFalse);
      expect(queue.pendingFor('alice@example.com'), [second]);
    });

    test('keeps a seed pending until the consumer takes it', () {
      final queue = ShareComposerSeedQueue();
      addTearDown(queue.dispose);

      final seed = queue.enqueue(
        jid: 'alice@example.com',
        body: 'share',
        attachments: const <Attachment>[],
      );

      expect(queue.pendingFor('alice@example.com'), [seed]);
      expect(queue.pendingFor('bob@example.com'), isEmpty);
      expect(queue.pendingFor('alice@example.com'), [seed]);
    });
  });

  group('prepareSharedAttachments', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('axichat-share-test-');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'normalizes file URIs and resolves filename, size, and MIME',
      () async {
        final file = File('${tempDir.path}/shared.txt');
        await file.writeAsString('hello');

        final attachments = await prepareSharedAttachments(
          attachments: [
            ShareAttachmentPayload(
              path: Uri.file(file.path).toString(),
              type: SharedAttachmentType.file,
            ),
          ],
          optimize: false,
        );

        expect(attachments, hasLength(1));
        expect(attachments.single.path, file.path);
        expect(attachments.single.fileName, 'shared.txt');
        expect(attachments.single.sizeBytes, 5);
        expect(attachments.single.mimeType, 'application/octet-stream');
      },
    );

    test('skips invalid paths and falls back to declared MIME type', () async {
      final file = File('${tempDir.path}/shared.unknown');
      await file.writeAsBytes(const <int>[]);

      final attachments = await prepareSharedAttachments(
        attachments: [
          ShareAttachmentPayload(
            path: '${tempDir.path}/missing.bin',
            type: SharedAttachmentType.file,
          ),
          ShareAttachmentPayload(
            path: file.path,
            type: SharedAttachmentType.audio,
          ),
        ],
        optimize: false,
      );

      expect(attachments, hasLength(1));
      expect(attachments.single.path, file.path);
      expect(attachments.single.sizeBytes, 0);
      expect(attachments.single.mimeType, 'audio/*');
    });
  });
}
