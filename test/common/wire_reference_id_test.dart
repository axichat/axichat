// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/wire_reference_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WireReferenceId.tryFrom', () {
    test('rejects every device-local identifier shape', () {
      for (final local in [
        'dc-msg-42',
        'dc-local-msg-0-7-42',
        'dc-pending-abc',
        'gen_generated123',
        'axi-drv-deadbeef',
        '',
        '   ',
        null,
      ]) {
        expect(WireReferenceId.tryFrom(local), isNull, reason: '$local');
      }
    });

    test('keeps wire-safe identifiers trimmed', () {
      expect(WireReferenceId.tryFrom('ref-1')?.value, 'ref-1');
      expect(
        WireReferenceId.tryFrom(' origin@example.com ')?.value,
        'origin@example.com',
      );
      expect(
        WireReferenceId.tryFrom('thread-1234@mail.example.com')?.value,
        'thread-1234@mail.example.com',
      );
    });

    test('rejects case-variant device-local identifier shapes', () {
      for (final local in [
        'DC-MSG-42',
        'Dc-Local-Msg-1-7-42',
        'GEN_abcdef',
        'AXI-DRV-deadbeef',
      ]) {
        expect(WireReferenceId.tryFrom(local), isNull, reason: local);
      }
    });

    test('rejects values beyond the wire byte limit', () {
      final oversized = 'a' * (wireReferenceIdMaxBytes + 1);
      expect(WireReferenceId.tryFrom(oversized), isNull);
      final atLimit = 'a' * wireReferenceIdMaxBytes;
      expect(WireReferenceId.tryFrom(atLimit)?.value, atLimit);
    });
  });
}
