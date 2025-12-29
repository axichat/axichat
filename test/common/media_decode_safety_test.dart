import 'dart:convert';
import 'dart:typed_data';

import 'package:axichat/src/common/media_decode_safety.dart';
import 'package:flutter_test/flutter_test.dart';

const String _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';
const List<int> _invalidImageBytes = <int>[0, 1, 2, 3, 4];
const int _maxImageBytes = 1024;
const int _maxImagePixels = 2048;
const int _maxImageFrames = 1;
const int _minImageDimension = 1;
const int _decodeTimeoutMs = 250;
const Duration _decodeTimeout = Duration(milliseconds: _decodeTimeoutMs);
const int _maxFailureAttempts = 3;
const String _decodeGuardKey = 'decode-guard-key';

const ImageDecodeLimits _decodeLimits = ImageDecodeLimits(
  maxBytes: _maxImageBytes,
  maxPixels: _maxImagePixels,
  maxFrames: _maxImageFrames,
  minDimension: _minImageDimension,
  decodeTimeout: _decodeTimeout,
);

void main() {
  group('isSafeImageBytes', () {
    test('accepts a tiny valid png', () async {
      final Uint8List bytes = base64Decode(_tinyPngBase64);
      final isSafe = await isSafeImageBytes(bytes, _decodeLimits);
      expect(isSafe, isTrue);
    });

    test('rejects invalid bytes', () async {
      final Uint8List bytes = Uint8List.fromList(_invalidImageBytes);
      final isSafe = await isSafeImageBytes(bytes, _decodeLimits);
      expect(isSafe, isFalse);
    });
  });

  group('MediaDecodeGuard', () {
    test('blocks after repeated failures and clears on success', () {
      final guard = MediaDecodeGuard.instance;
      expect(guard.allowAttempt(_decodeGuardKey), isTrue);
      for (var attempt = 0; attempt < _maxFailureAttempts; attempt += 1) {
        guard.registerFailure(_decodeGuardKey);
      }
      expect(guard.allowAttempt(_decodeGuardKey), isFalse);
      guard.registerSuccess(_decodeGuardKey);
      expect(guard.allowAttempt(_decodeGuardKey), isTrue);
    });
  });
}
