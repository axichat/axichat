import 'package:axichat/src/common/notification_privacy.dart';
import 'package:flutter/foundation.dart';
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
      final longText = List.filled(
        maxPreviewLength + extraLength,
        'abcde',
      ).join(' ');
      final preview = sanitizeNotificationPreview(longText);
      expect(preview, isNotNull);
      expect(preview!.length, maxPreviewLength + truncationSuffix.length);
      expect(
        preview,
        '${longText.substring(0, maxPreviewLength)}$truncationSuffix',
      );
    });
  });

  group('NotificationPreviewPlatformPolicy', () {
    test('supports controls only on non-Apple notification platforms', () {
      expect(
        TargetPlatform.android.supportsNotificationPreviewControls,
        isTrue,
      );
      expect(TargetPlatform.linux.supportsNotificationPreviewControls, isTrue);
      expect(
        TargetPlatform.windows.supportsNotificationPreviewControls,
        isTrue,
      );
      expect(TargetPlatform.iOS.supportsNotificationPreviewControls, isFalse);
      expect(TargetPlatform.macOS.supportsNotificationPreviewControls, isFalse);
    });

    test('forces previews off on Apple platforms', () {
      expect(
        resolveNotificationPreviewEnabled(
          platform: TargetPlatform.iOS,
          globalPreviewsEnabled: true,
          previewOverride: true,
        ),
        isFalse,
      );
      expect(
        resolveNotificationPreviewEnabled(
          platform: TargetPlatform.macOS,
          globalPreviewsEnabled: true,
          previewOverride: true,
        ),
        isFalse,
      );
    });

    test('honors global setting and overrides on supported platforms', () {
      expect(
        resolveNotificationPreviewEnabled(
          platform: TargetPlatform.android,
          globalPreviewsEnabled: true,
        ),
        isTrue,
      );
      expect(
        resolveNotificationPreviewEnabled(
          platform: TargetPlatform.linux,
          globalPreviewsEnabled: true,
          previewOverride: false,
        ),
        isFalse,
      );
      expect(
        resolveNotificationPreviewEnabled(
          platform: TargetPlatform.windows,
          globalPreviewsEnabled: false,
          previewOverride: true,
        ),
        isTrue,
      );
    });
  });
}
