import 'package:axichat/src/common/html_content.dart';
import 'package:flutter_test/flutter_test.dart';

const int _glyphRepeatCount = 5000;
const int _nestedMarkupDepth = 60;
const int _whitespaceRepeatCount = 1000;
const int _combiningRepeatCount = 2000;
const String _nestedTextToken = 'ok';

void main() {
  group('HtmlContentCodec.sanitizeHtml', () {
    test('strips script tags', () {
      final sanitized = HtmlContentCodec.sanitizeHtml(
        '<script>alert(1)</script><p>ok</p>',
      );
      expect(sanitized.contains('<script'), isFalse);
      expect(sanitized.contains('</script'), isFalse);
      expect(sanitized.contains('<p>ok</p>'), isTrue);
    });

    test('strips event handlers and javascript urls', () {
      final sanitized = HtmlContentCodec.sanitizeHtml(
        '<a href="javascript:alert(1)" onclick="evil()">link</a>',
      );
      expect(sanitized.contains('javascript:'), isFalse);
      expect(sanitized.contains('onclick'), isFalse);
    });

    test('drops non-https image sources', () {
      final sanitized = HtmlContentCodec.sanitizeHtml(
        '<img src="http://example.com/x.png" />',
      );
      expect(sanitized.contains('http://'), isFalse);
    });

    test('keeps https image sources but strips other attrs', () {
      final sanitized = HtmlContentCodec.sanitizeHtml(
        '<img src="https://example.com/x.png" onerror="alert(1)" />',
      );
      expect(sanitized.contains('https://example.com/x.png'), isTrue);
      expect(sanitized.contains('onerror'), isFalse);
    });
  });

  group('Pathological input handling', () {
    test('handles large repeated glyph sequences', () {
      final input = List.filled(_glyphRepeatCount, ':) ').join();
      final sanitized = HtmlContentCodec.sanitizeHtml(input);
      expect(sanitized.isNotEmpty, isTrue);
    });

    test('handles deeply nested markup', () {
      final openTags = List.filled(_nestedMarkupDepth, '<div>').join();
      final closeTags = List.filled(_nestedMarkupDepth, '</div>').join();
      final sanitized = HtmlContentCodec.sanitizeHtml(
        '$openTags$_nestedTextToken$closeTags',
      );
      expect(sanitized.contains(_nestedTextToken), isTrue);
    });

    test('handles repeated whitespace folds', () {
      final input = List.filled(_whitespaceRepeatCount, 'word').join(' \n\n');
      final sanitized = HtmlContentCodec.sanitizeHtml(input);
      expect(sanitized.isNotEmpty, isTrue);
    });

    test('handles repeated combining characters', () {
      const combining = 'a\u0301';
      final input = List.filled(_combiningRepeatCount, combining).join();
      final sanitized = HtmlContentCodec.sanitizeHtml(input);
      expect(sanitized.isNotEmpty, isTrue);
    });
  });
}
