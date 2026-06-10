// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/email/util/email_message_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeEmailMessageId', () {
    test('canonical form is frozen for clean ids', () {
      expect(
        normalizeEmailMessageId('<AbC123@Example.org>'),
        'abc123@example.org',
      );
    });

    test('accepts ids without angle brackets', () {
      expect(normalizeEmailMessageId('abc@example.org'), 'abc@example.org');
    });

    test('takes the first id when multiple are present', () {
      expect(
        normalizeEmailMessageId('<first@x.org> <second@x.org>'),
        'first@x.org',
      );
    });

    test('strips folded whitespace inside the value', () {
      expect(
        normalizeEmailMessageId('<abc\r\n def@example.org>'),
        'abcdef@example.org',
      );
      expect(normalizeEmailMessageId('  <a b\tc@x.org> '), 'abc@x.org');
    });

    test('returns null for empty and whitespace-only input', () {
      expect(normalizeEmailMessageId(null), isNull);
      expect(normalizeEmailMessageId(''), isNull);
      expect(normalizeEmailMessageId('   '), isNull);
      expect(normalizeEmailMessageId('<>'), isNull);
    });

    test('identical bytes always normalize identically', () {
      const dirty = ' <MiXeD\r\n Case@Host.TLD> ';
      expect(normalizeEmailMessageId(dirty), normalizeEmailMessageId(dirty));
    });
  });

  group('isDeltaGeneratedMessageId', () {
    test('detects delta GEN_ ids case-insensitively', () {
      expect(isDeltaGeneratedMessageId('GEN_abCD1234efgh'), isTrue);
      expect(isDeltaGeneratedMessageId('gen_abcd1234efgh'), isTrue);
      expect(isDeltaGeneratedMessageId('<GEN_abcd1234efgh>'), isTrue);
    });

    test('does not flag real Message-IDs', () {
      expect(isDeltaGeneratedMessageId('<abc@example.org>'), isFalse);
      expect(isDeltaGeneratedMessageId('genuine@example.org'), isFalse);
      expect(isDeltaGeneratedMessageId(null), isFalse);
    });
  });

  group('derivedEmailMessageKey', () {
    final timestamp = DateTime.utc(2026, 6, 10, 8, 30);

    test('is deterministic: same server-held fields yield the same key', () {
      final first = derivedEmailMessageKey(
        subject: 'Hello',
        timestamp: timestamp,
        bodyText: 'body',
      );
      final second = derivedEmailMessageKey(
        subject: 'Hello',
        timestamp: timestamp,
        bodyText: 'body',
      );
      expect(first, second);
      expect(isDerivedEmailMessageKey(first), isTrue);
    });

    test('differs when any field differs', () {
      final base = derivedEmailMessageKey(
        subject: 'Hello',
        timestamp: timestamp,
        bodyText: 'body',
      );
      expect(
        derivedEmailMessageKey(
          subject: 'Hello!',
          timestamp: timestamp,
          bodyText: 'body',
        ),
        isNot(base),
      );
      expect(
        derivedEmailMessageKey(
          subject: 'Hello',
          timestamp: timestamp.add(const Duration(seconds: 1)),
          bodyText: 'body',
        ),
        isNot(base),
      );
    });

    test('local timestamps convert to UTC before hashing', () {
      final utc = DateTime.utc(2026, 6, 10, 8, 30);
      final local = utc.toLocal();
      expect(
        derivedEmailMessageKey(subject: 's', timestamp: local, bodyText: 'b'),
        derivedEmailMessageKey(subject: 's', timestamp: utc, bodyText: 'b'),
      );
    });
  });

  group('canonicalEmailOriginId', () {
    test('prefers a real Message-ID', () {
      expect(
        canonicalEmailOriginId(
          rfc724Mid: '<Real@Example.org>',
          subject: 's',
          timestamp: DateTime.utc(2026),
          bodyText: 'b',
        ),
        'real@example.org',
      );
    });

    test('falls back to derived key for GEN_ and missing ids', () {
      final fromGen = canonicalEmailOriginId(
        rfc724Mid: 'GEN_abcd1234efgh',
        subject: 's',
        timestamp: DateTime.utc(2026),
        bodyText: 'b',
      );
      final fromNull = canonicalEmailOriginId(
        rfc724Mid: null,
        subject: 's',
        timestamp: DateTime.utc(2026),
        bodyText: 'b',
      );
      expect(isDerivedEmailMessageKey(fromGen), isTrue);
      expect(fromGen, fromNull);
    });
  });
}
