import 'package:axichat/src/common/html_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HtmlContentCodec.prepareEmailHtmlForWebView', () {
    test('strips active tags and event handlers', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<p onclick="evil()">ok</p><iframe src="https://example.com"></iframe>',
        allowRemoteImages: true,
      );
      expect(prepared.contains('onclick'), isFalse);
      expect(prepared.contains('<iframe'), isFalse);
      expect(prepared.contains('<p>ok</p>'), isTrue);
    });

    test('strips dangerous css constructs but keeps safe declarations', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<style>@import url(https://evil.test/x.css); '
        '.note { background-image: url(https://evil.test/x.png); color: red; }'
        '</style>'
        '<p class="note" style="background-image:url(https://evil.test/x.png); color:red; width: 999px;">ok</p>',
        allowRemoteImages: true,
      );
      expect(prepared.contains('@import'), isFalse);
      expect(prepared.contains('url('), isFalse);
      expect(prepared.contains('color: red'), isTrue);
      expect(prepared.contains('width:'), isFalse);
    });

    test('blocks remote images when disabled but keeps data images', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<img src="https://example.com/x.png" />'
        '<img src="data:image/png;base64,AAAA" />',
        allowRemoteImages: false,
      );
      expect(prepared.contains('https://example.com/x.png'), isFalse);
      expect(prepared.contains('data:image/png;base64,AAAA'), isTrue);
    });

    test('strips inline svg and namespaced href content', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink">'
        '<image xlink:href="https://evil.test/track.png" />'
        '<a xlink:href="javascript:alert(1)"><text>bad</text></a>'
        '</svg><p>ok</p>',
        allowRemoteImages: true,
      );
      expect(prepared.contains('<svg'), isFalse);
      expect(prepared.contains('xlink:href'), isFalse);
      expect(prepared.contains('evil.test'), isFalse);
      expect(prepared.contains('<p>ok</p>'), isTrue);
    });
  });

  group('HtmlContentCodec.prepareEmailHtmlForFlutterHtml', () {
    test('returns a stripped fragment with image sizing metadata', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForFlutterHtml(
        '<style>.lead { font-size: 22px; color: #123456; }</style>'
        '<p class="lead" style="font-size:18px; line-height:1.6;">ok</p>'
        '<img src="https://example.com/x.png" width="320" height="160" />',
        allowRemoteImages: true,
      );
      expect(prepared.contains('<style'), isFalse);
      expect(prepared.contains('style='), isFalse);
      expect(prepared.contains('<p>ok</p>'), isTrue);
      expect(prepared.contains('width="320"'), isTrue);
      expect(prepared.contains('height="160"'), isTrue);
    });
  });

  group('HtmlContentCodec.containsRemoteImages', () {
    test('treats cleartext and https images as remote', () {
      expect(
        HtmlContentCodec.containsRemoteImages(
          '<img src="http://example.com/x.png" />',
        ),
        isTrue,
      );
      expect(
        HtmlContentCodec.containsRemoteImages(
          '<img src="https://example.com/x.png" />',
        ),
        isTrue,
      );
    });
  });

  group('HtmlContentCodec.containsBlockedWebViewContent', () {
    test('detects blocked active tags and event handlers', () {
      expect(
        HtmlContentCodec.containsBlockedWebViewContent(
          '<p onclick="evil()">ok</p><script>alert(1)</script>',
        ),
        isTrue,
      );
    });

    test('detects unsafe links and css but ignores ordinary remote images', () {
      expect(
        HtmlContentCodec.containsBlockedWebViewContent(
          '<a href="javascript:alert(1)">bad</a>',
        ),
        isTrue,
      );
      expect(
        HtmlContentCodec.containsBlockedWebViewContent(
          '<p style="background-image:url(https://evil.test/x.png)">bad</p>',
        ),
        isTrue,
      );
      expect(
        HtmlContentCodec.containsBlockedWebViewContent(
          '<img src="https://example.com/x.png" />',
        ),
        isFalse,
      );
      expect(
        HtmlContentCodec.containsBlockedWebViewContent(
          '<svg xmlns="http://www.w3.org/2000/svg">'
          '<image xlink:href="https://evil.test/track.png" />'
          '</svg>',
        ),
        isTrue,
      );
    });
  });
}
