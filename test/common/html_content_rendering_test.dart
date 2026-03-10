import 'package:axichat/src/common/html_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HtmlContentCodec.shouldRenderRichEmailHtml', () {
    test(
      'does not render html when plain text already matches rich html text',
      () {
        const html = '<div><strong>Ok</strong></div>';
        final normalizedHtmlBody = HtmlContentCodec.normalizeHtml(html);
        final normalizedHtmlText = HtmlContentCodec.toPlainText(html).trim();

        final shouldRender = HtmlContentCodec.shouldRenderRichEmailHtml(
          normalizedHtmlBody: normalizedHtmlBody,
          normalizedHtmlText: normalizedHtmlText,
          renderedText: 'Ok',
        );

        expect(shouldRender, isFalse);
      },
    );

    test('renders html when rich markup has no plain text body to show', () {
      const html = '<table><tr><td><strong>Ok</strong></td></tr></table>';
      final normalizedHtmlBody = HtmlContentCodec.normalizeHtml(html);
      final normalizedHtmlText = HtmlContentCodec.toPlainText(html).trim();

      final shouldRender = HtmlContentCodec.shouldRenderRichEmailHtml(
        normalizedHtmlBody: normalizedHtmlBody,
        normalizedHtmlText: normalizedHtmlText,
        renderedText: '',
      );

      expect(shouldRender, isTrue);
    });

    test('does not render html for plain-text html bodies', () {
      const html = '<div>Ok</div>';
      final normalizedHtmlBody = HtmlContentCodec.normalizeHtml(html);
      final normalizedHtmlText = HtmlContentCodec.toPlainText(html).trim();

      final shouldRender = HtmlContentCodec.shouldRenderRichEmailHtml(
        normalizedHtmlBody: normalizedHtmlBody,
        normalizedHtmlText: normalizedHtmlText,
        renderedText: 'Ok',
      );

      expect(shouldRender, isFalse);
    });

    test('does not render html for lightweight document wrappers', () {
      const html =
          '<html><head><meta charset="utf-8"><title>ignored</title></head>'
          '<body><div class="gmail_default">Hi</div></body></html>';
      final normalizedHtmlBody = HtmlContentCodec.normalizeHtml(html);
      final normalizedHtmlText = HtmlContentCodec.toPlainText(html).trim();

      final shouldRender = HtmlContentCodec.shouldRenderRichEmailHtml(
        normalizedHtmlBody: normalizedHtmlBody,
        normalizedHtmlText: normalizedHtmlText,
        renderedText: 'metadata placeholder',
      );

      expect(shouldRender, isFalse);
    });

    test('does not render html for lightweight inline formatting', () {
      const html = '<p class="note"><strong>Hi</strong></p>';
      final normalizedHtmlBody = HtmlContentCodec.normalizeHtml(html);
      final normalizedHtmlText = HtmlContentCodec.toPlainText(html).trim();

      final shouldRender = HtmlContentCodec.shouldRenderRichEmailHtml(
        normalizedHtmlBody: normalizedHtmlBody,
        normalizedHtmlText: normalizedHtmlText,
        renderedText: 'metadata placeholder',
      );

      expect(shouldRender, isFalse);
    });
  });
}
