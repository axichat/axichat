import 'package:axichat/src/common/url_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const int safeLinkMaxLength = 2048;
  const int safeAttachmentMaxLength = 2048;
  const String httpsBase = 'https://example.com/';
  const String bidiOverride = '\u202e';
  const String zeroWidthSpace = '\u200b';
  const String punycodeHost = 'https://xn--example.com';
  const String bidiTestUrl = '$httpsBase${bidiOverride}txt';
  const String zeroWidthTestUrl = '$httpsBase$zeroWidthSpace';

  group('isSafeLinkUri', () {
    test('allows https links without credentials', () {
      expect(isSafeLinkUri(Uri.parse('https://example.com')), isTrue);
    });

    test('rejects links that include credentials', () {
      expect(
        isSafeLinkUri(Uri.parse('https://user:pass@example.com')),
        isFalse,
      );
    });

    test('rejects links with encoded control characters', () {
      expect(
        isSafeLinkUri(Uri.parse('mailto:test@example.com?body=hi%0d%0a')),
        isFalse,
      );
      expect(isSafeLinkUri(Uri.parse('https://example.com/%0a')), isFalse);
      expect(isSafeLinkUri(Uri.parse('https://example.com/%00')), isFalse);
    });

    test('rejects links that exceed the length cap', () {
      const int overflowLength = safeLinkMaxLength - httpsBase.length + 1;
      final longPath = List.filled(overflowLength, 'a').join();
      expect(isSafeLinkUri(Uri.parse('$httpsBase$longPath')), isFalse);
    });
  });

  group('isSafeAttachmentUri', () {
    test('allows https attachment links', () {
      expect(
          isSafeAttachmentUri(Uri.parse('https://example.com/file')), isTrue);
    });

    test('rejects attachments with credentials', () {
      expect(
        isSafeAttachmentUri(Uri.parse('https://user:pass@example.com/file')),
        isFalse,
      );
    });

    test('rejects attachments with encoded control characters', () {
      expect(
        isSafeAttachmentUri(Uri.parse('https://example.com/%0d')),
        isFalse,
      );
    });

    test('rejects attachments that exceed the length cap', () {
      const int overflowLength = safeAttachmentMaxLength - httpsBase.length + 1;
      final longPath = List.filled(overflowLength, 'a').join();
      expect(isSafeAttachmentUri(Uri.parse('$httpsBase$longPath')), isFalse);
    });
  });

  group('assessLinkSafety', () {
    test('flags bidi control characters for warnings', () {
      final report = assessLinkSafety(
        raw: bidiTestUrl,
        kind: LinkSafetyKind.message,
      );
      expect(report, isNotNull);
      expect(report!.needsWarning, isTrue);
      expect(report.isSafe, isTrue);
    });

    test('flags zero-width characters for warnings', () {
      final report = assessLinkSafety(
        raw: zeroWidthTestUrl,
        kind: LinkSafetyKind.message,
      );
      expect(report, isNotNull);
      expect(report!.needsWarning, isTrue);
    });

    test('flags punycode hosts for warnings', () {
      final report = assessLinkSafety(
        raw: punycodeHost,
        kind: LinkSafetyKind.message,
      );
      expect(report, isNotNull);
      expect(report!.needsWarning, isTrue);
    });
  });
}
