// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/transport/email_delta_transport.dart';
import 'package:axichat/src/email/transport/email_delta_worker_runtime.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:flutter_test/flutter_test.dart';

Object? _roundTrip(Object? value) => decodeEmailDeltaRpcValueForTesting(
  encodeEmailDeltaRpcValueForTesting(value),
);

void main() {
  group('Delta RPC value codec', () {
    group('primitives', () {
      test('pass through unchanged', () {
        expect(_roundTrip(null), isNull);
        expect(_roundTrip(true), isTrue);
        expect(_roundTrip(42), 42);
        expect(_roundTrip(3.5), 3.5);
        expect(_roundTrip('hello'), 'hello');
      });
    });

    group('temporal values', () {
      test('Duration round-trips', () {
        const duration = Duration(seconds: 15, microseconds: 250);
        expect(_roundTrip(duration), duration);
      });

      test('UTC DateTime round-trips with flag preserved', () {
        final timestamp = DateTime.utc(2026, 6, 10, 12, 30, 45, 123, 456);
        final decoded = _roundTrip(timestamp) as DateTime;
        expect(decoded, timestamp);
        expect(decoded.isUtc, isTrue);
      });

      test('local DateTime round-trips with flag preserved', () {
        final timestamp = DateTime(2026, 6, 10, 12, 30, 45);
        final decoded = _roundTrip(timestamp) as DateTime;
        expect(decoded, timestamp);
        expect(decoded.isUtc, isFalse);
      });
    });

    group('enums', () {
      test('every MessageTimelineFilter value round-trips', () {
        for (final filter in MessageTimelineFilter.values) {
          expect(_roundTrip(filter), filter);
        }
      });

      test('every DeltaOpenPgpKeyKind value round-trips', () {
        for (final kind in DeltaOpenPgpKeyKind.values) {
          expect(_roundTrip(kind), kind);
        }
      });
    });

    group('typed payloads', () {
      test('EmailAttachment round-trips with all fields', () {
        const attachment = EmailAttachment(
          path: '/tmp/photo.jpg',
          fileName: 'photo.jpg',
          sizeBytes: 2048,
          mimeType: 'image/jpeg',
          width: 800,
          height: 600,
          caption: 'A photo',
          metadataId: 'meta-1',
        );
        final decoded = _roundTrip(attachment) as EmailAttachment;
        expect(decoded.path, attachment.path);
        expect(decoded.fileName, attachment.fileName);
        expect(decoded.sizeBytes, attachment.sizeBytes);
        expect(decoded.mimeType, attachment.mimeType);
        expect(decoded.width, attachment.width);
        expect(decoded.height, attachment.height);
        expect(decoded.caption, attachment.caption);
        expect(decoded.metadataId, attachment.metadataId);
      });

      test('EmailAttachment round-trips with null optionals', () {
        const attachment = EmailAttachment(
          path: '/tmp/file.bin',
          fileName: 'file.bin',
          sizeBytes: 1,
        );
        final decoded = _roundTrip(attachment) as EmailAttachment;
        expect(decoded.mimeType, isNull);
        expect(decoded.width, isNull);
        expect(decoded.caption, isNull);
        expect(decoded.metadataId, isNull);
      });

      test('DeltaCoreEvent round-trips', () {
        const event = DeltaCoreEvent(
          type: 2005,
          data1: 7,
          data2: 42,
          data1Text: 'one',
          data2Text: 'two',
          accountId: 3,
        );
        final decoded = _roundTrip(event) as DeltaCoreEvent;
        expect(decoded.type, event.type);
        expect(decoded.data1, event.data1);
        expect(decoded.data2, event.data2);
        expect(decoded.data1Text, event.data1Text);
        expect(decoded.data2Text, event.data2Text);
        expect(decoded.accountId, event.accountId);
      });

      test('DeltaCoreEvent round-trips with null account id', () {
        const event = DeltaCoreEvent(type: 100, data1: 0, data2: 0);
        final decoded = _roundTrip(event) as DeltaCoreEvent;
        expect(decoded.accountId, isNull);
        expect(decoded.data1Text, isNull);
      });

      test('DeltaMessage round-trips including nested timestamp', () {
        final message = DeltaMessage(
          id: 42,
          chatId: 7,
          text: 'body',
          html: '<p>body</p>',
          subject: 'subject',
          viewType: 10,
          infoType: 0,
          state: 26,
          filePath: '/tmp/a.png',
          fileName: 'a.png',
          fileMime: 'image/png',
          fileSize: 512,
          width: 10,
          height: 20,
          timestamp: DateTime.utc(2026, 6, 10, 8),
          isOutgoing: true,
          downloadState: 0,
          error: null,
          showPadlock: true,
        );
        final decoded = _roundTrip(message) as DeltaMessage;
        expect(decoded.id, message.id);
        expect(decoded.chatId, message.chatId);
        expect(decoded.text, message.text);
        expect(decoded.html, message.html);
        expect(decoded.subject, message.subject);
        expect(decoded.viewType, message.viewType);
        expect(decoded.state, message.state);
        expect(decoded.filePath, message.filePath);
        expect(decoded.fileName, message.fileName);
        expect(decoded.fileMime, message.fileMime);
        expect(decoded.fileSize, message.fileSize);
        expect(decoded.timestamp, message.timestamp);
        expect(decoded.timestamp?.isUtc, isTrue);
        expect(decoded.isOutgoing, isTrue);
        expect(decoded.showPadlock, isTrue);
        expect(decoded.error, isNull);
      });

      test('DeltaChat round-trips', () {
        const chat = DeltaChat(
          id: 7,
          name: 'Alice',
          contactAddress: 'alice@example.org',
          contactId: 11,
          contactName: 'Alice A',
          type: 100,
        );
        final decoded = _roundTrip(chat) as DeltaChat;
        expect(decoded.id, chat.id);
        expect(decoded.name, chat.name);
        expect(decoded.contactAddress, chat.contactAddress);
        expect(decoded.contactId, chat.contactId);
        expect(decoded.contactName, chat.contactName);
        expect(decoded.type, chat.type);
      });

      test('DeltaContact round-trips', () {
        const contact = DeltaContact(
          id: 11,
          address: 'alice@example.org',
          name: 'Alice',
        );
        final decoded = _roundTrip(contact) as DeltaContact;
        expect(decoded.id, contact.id);
        expect(decoded.address, contact.address);
        expect(decoded.name, contact.name);
      });

      test('DeltaChatlistEntry round-trips', () {
        const entry = DeltaChatlistEntry(chatId: 7, msgId: 42);
        final decoded = _roundTrip(entry) as DeltaChatlistEntry;
        expect(decoded.chatId, entry.chatId);
        expect(decoded.msgId, entry.msgId);
      });

      test('DeltaFreshMessageCount round-trips', () {
        const count = DeltaFreshMessageCount(count: 3, supported: true);
        final decoded = _roundTrip(count) as DeltaFreshMessageCount;
        expect(decoded.count, count.count);
        expect(decoded.supported, count.supported);
      });

      test('DeltaChatSendCapabilities round-trips nullable flags', () {
        const capabilities = DeltaChatSendCapabilities(
          exists: true,
          canSend: null,
          isEncrypted: false,
        );
        final decoded = _roundTrip(capabilities) as DeltaChatSendCapabilities;
        expect(decoded.exists, isTrue);
        expect(decoded.canSend, isNull);
        expect(decoded.isEncrypted, isFalse);
      });

      test('DeltaMessageRfc822Body round-trips', () {
        const body = DeltaMessageRfc822Body(
          plainText: 'plain',
          htmlBody: '<p>html</p>',
        );
        final decoded = _roundTrip(body) as DeltaMessageRfc822Body;
        expect(decoded.plainText, body.plainText);
        expect(decoded.htmlBody, body.htmlBody);
      });

      test('DeltaQuotedMessage round-trips', () {
        const quoted = DeltaQuotedMessage(id: 9, text: 'quoted');
        final decoded = _roundTrip(quoted) as DeltaQuotedMessage;
        expect(decoded.id, quoted.id);
        expect(decoded.text, quoted.text);
      });

      test('EmailDeltaImexResult round-trips', () {
        const result = EmailDeltaImexResult(
          accountId: 2,
          exportedPaths: ['/tmp/export-1', '/tmp/export-2'],
        );
        final decoded = _roundTrip(result) as EmailDeltaImexResult;
        expect(decoded.accountId, result.accountId);
        expect(decoded.exportedPaths, result.exportedPaths);
      });

      test('DeltaOpenPgpKeyMetadata and key import round-trip', () {
        final metadata = DeltaOpenPgpKeyMetadata(
          kind: DeltaOpenPgpKeyKind.values.first,
          fingerprint: 'ABCDEF',
          userIds: const ['alice@example.org'],
          hasExpectedAddress: true,
          hasEncryptionCapability: true,
        );
        final import = DeltaContactPublicKeyImport(
          metadata: metadata,
          contactId: 11,
          chatId: 7,
        );
        final decoded = _roundTrip(import) as DeltaContactPublicKeyImport;
        expect(decoded.contactId, import.contactId);
        expect(decoded.chatId, import.chatId);
        expect(decoded.metadata.kind, metadata.kind);
        expect(decoded.metadata.fingerprint, metadata.fingerprint);
        expect(decoded.metadata.userIds, metadata.userIds);
        expect(decoded.metadata.hasExpectedAddress, isTrue);
        expect(decoded.metadata.hasEncryptionCapability, isTrue);
      });

      test('DeltaContactPublicKeyRemoval round-trips', () {
        const removal = DeltaContactPublicKeyRemoval(
          contactId: 11,
          chatId: 7,
          fallbackContactId: 12,
          fingerprint: 'ABCDEF',
        );
        final decoded = _roundTrip(removal) as DeltaContactPublicKeyRemoval;
        expect(decoded.contactId, removal.contactId);
        expect(decoded.chatId, removal.chatId);
        expect(decoded.fallbackContactId, removal.fallbackContactId);
        expect(decoded.fingerprint, removal.fingerprint);
      });
    });

    group('collections', () {
      test('typed payload lists round-trip element-wise', () {
        const entries = [
          DeltaChatlistEntry(chatId: 1, msgId: 10),
          DeltaChatlistEntry(chatId: 2, msgId: 20),
        ];
        final decoded = _roundTrip(entries) as List<Object?>;
        expect(decoded, hasLength(2));
        expect((decoded[0] as DeltaChatlistEntry).chatId, 1);
        expect((decoded[1] as DeltaChatlistEntry).msgId, 20);
      });

      test('int and string lists keep their element types', () {
        expect(_roundTrip(<int>[1, 2, 3]), isA<List<int>>());
        expect(_roundTrip(<String>['a', 'b']), isA<List<String>>());
      });

      test('maps round-trip with nested typed values', () {
        final decoded =
            _roundTrip({'duration': const Duration(seconds: 1), 'count': 5})
                as Map<String, Object?>;
        expect(decoded['duration'], const Duration(seconds: 1));
        expect(decoded['count'], 5);
      });
    });

    group('protocol safety', () {
      test('unsendable types throw instead of corrupting the channel', () {
        expect(
          () => encodeEmailDeltaRpcValueForTesting(Object()),
          throwsA(isA<EmailDeltaWorkerRuntimeException>()),
        );
      });

      test('unknown type tags decode as plain maps, not crashes', () {
        final typeKey =
            (encodeEmailDeltaRpcValueForTesting(Duration.zero)
                    as Map<String, Object?>)
                .entries
                .firstWhere((entry) => entry.value == 'Duration')
                .key;
        final decoded =
            decodeEmailDeltaRpcValueForTesting({
                  typeKey: 'NotARealType',
                  'field': 1,
                })
                as Map<String, Object?>;
        expect(decoded['field'], 1);
      });
    });
  });
}
