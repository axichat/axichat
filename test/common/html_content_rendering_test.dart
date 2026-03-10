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

    test('renders html when there is no plain text body to show instead', () {
      const html = '<div><strong>Ok</strong></div>';
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
  });
}
