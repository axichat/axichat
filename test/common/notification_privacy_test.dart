import 'package:axichat/src/common/notification_privacy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const String linkPlaceholder = '[link]';
  const String redactedPlaceholder = '[redacted]';
  const String truncationSuffix = '...';
  const int maxPreviewLength = 160;
  const int extraLength = 12;
  const String longToken = 'abcdefghijklmnopqrstuv';
  const String hexToken = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6';
  const String numericToken = '123456';

  group('sanitizeNotificationPreview', () {
    test('returns null for empty content', () {
      expect(sanitizeNotificationPreview(null), isNull);
      expect(sanitizeNotificationPreview('   '), isNull);
    });

    test('redacts links', () {
      final preview = sanitizeNotificationPreview(
        'See https://example.com/path?token=abc',
      );
      expect(preview, 'See $linkPlaceholder');
    });

    test('redacts long tokens', () {
      final preview = sanitizeNotificationPreview('Token $longToken');
      expect(preview, 'Token $redactedPlaceholder');
    });

    test('redacts long hex tokens', () {
      final preview = sanitizeNotificationPreview('Hash $hexToken');
      expect(preview, 'Hash $redactedPlaceholder');
    });

    test('redacts numeric tokens', () {
      final preview = sanitizeNotificationPreview('Code $numericToken');
      expect(preview, 'Code $redactedPlaceholder');
    });

    test('collapses whitespace', () {
      final preview = sanitizeNotificationPreview('Hello\n\nworld   ');
      expect(preview, 'Hello world');
    });

    test('truncates long previews', () {
      final longText = List.filled(maxPreviewLength + extraLength, 'a').join();
      final preview = sanitizeNotificationPreview(longText);
      expect(preview, isNotNull);
      expect(preview!.length, maxPreviewLength + truncationSuffix.length);
      expect(
        preview,
        '${longText.substring(0, maxPreviewLength)}$truncationSuffix',
      );
    });
  });
}
