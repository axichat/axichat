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
      expect(prepared.contains('width: 999px'), isFalse);
    });

    test('blocks remote images when disabled but keeps data images', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<img src="https://example.com/x.png" />'
        '<img src="data:image/png;base64,AAAA" />',
        allowRemoteImages: false,
      );
      expect(prepared.contains('https://example.com/x.png'), isFalse);
      expect(prepared.contains('data:image/png;base64,AAAA'), isTrue);
      expect(RegExp(r'<img\b').allMatches(prepared), hasLength(1));
    });

    test('keeps remote images when explicitly allowed', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<img src="http://example.com/x.png" />'
        '<img src="data:image/png;base64,AAAA" />',
        allowRemoteImages: true,
      );
      expect(prepared.contains('http://example.com/x.png'), isTrue);
      expect(prepared.contains('data:image/png;base64,AAAA'), isTrue);
      expect(RegExp(r'<img\b').allMatches(prepared), hasLength(2));
    });

    test('keeps visible linked images as images', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<a href="https://example.com/dashboard">'
        '<img src="https://example.com/logo.png" alt="Open dashboard" />'
        '</a>',
        allowRemoteImages: true,
      );

      expect(prepared.contains('href="https://example.com/dashboard"'), isTrue);
      expect(prepared.contains('src="https://example.com/logo.png"'), isTrue);
      expect(RegExp(r'<img\b').allMatches(prepared), hasLength(1));
      expect(prepared.contains('>Open dashboard</a>'), isFalse);
    });

    test('drops blocked css but keeps readable formatting', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<style>.note { position: absolute; top: 0; z-index: 9999; '
        'color: red; margin: 8px; }</style>'
        '<p class="note" style="left:0; pointer-events:auto; '
        'transform:translateY(-12px); color:red; margin:8px; width:999px;">ok</p>',
        allowRemoteImages: true,
      );
      expect(prepared.contains('position: absolute'), isFalse);
      expect(prepared.contains('top: 0'), isFalse);
      expect(prepared.contains('left: 0'), isFalse);
      expect(prepared.contains('z-index'), isFalse);
      expect(prepared.contains('pointer-events'), isFalse);
      expect(prepared.contains('transform'), isFalse);
      expect(prepared.contains('display:none'), isFalse);
      expect(prepared.contains('width:999px'), isFalse);
      expect(prepared.contains('color: red'), isTrue);
      expect(prepared.contains('margin: 8px'), isTrue);
    });

    test(
      'injects readable WebView CSS without forcing footer table layout',
      () {
        final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
          '<table width="640"><tbody><tr>'
          '<td width="320"><span>Footer</span></td>'
          '<td><font>Legal</font></td>'
          '</tr></tbody></table>',
          allowRemoteImages: true,
        );

        expect(prepared.contains('axichat-email-webview-style'), isTrue);
        expect(prepared.contains('font-size: 16px !important;'), isTrue);
        expect(prepared.contains('line-height: 1.5 !important;'), isTrue);
        expect(
          prepared.contains('-webkit-text-size-adjust: 100% !important;'),
          isTrue,
        );
        expect(prepared.contains('text-size-adjust: 100% !important;'), isTrue);
        expect(
          prepared.contains('overflow-wrap: break-word !important;'),
          isTrue,
        );
        expect(
          prepared.contains('overflow-wrap: anywhere !important;'),
          isFalse,
        );
        expect(prepared.contains('table-layout: fixed !important;'), isFalse);
        expect(prepared.contains('table[width]'), isFalse);
        expect(prepared.contains('td[width], th[width]'), isFalse);
        expect(prepared.contains('td, th {\n  width:'), isFalse);
        expect(prepared.contains('span, a, li, td, th'), isFalse);
        expect(prepared.contains('font, center'), isFalse);
      },
    );

    test('standard mode restores hidden nodes in their original order', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<p style="display:none">123456</p>'
        '<p style="visibility:hidden">234567</p>'
        '<p hidden>345678</p>'
        '<p aria-hidden="true">456789</p>'
        '<p style="mso-hide:all">567890</p>'
        '<p style="opacity:0">678901</p>'
        '<p style="height:0; overflow:hidden">789012</p>'
        '<p style="position:absolute; left:-9999px">890123</p>'
        '<p>visible</p>',
        allowRemoteImages: true,
      );
      expect(prepared.contains('123456'), isTrue);
      expect(prepared.contains('234567'), isTrue);
      expect(prepared.contains('345678'), isTrue);
      expect(prepared.contains('456789'), isTrue);
      expect(prepared.contains('567890'), isTrue);
      expect(prepared.contains('678901'), isTrue);
      expect(prepared.contains('789012'), isTrue);
      expect(prepared.contains('890123'), isTrue);
      expect(prepared.contains('visible'), isTrue);
      expect(prepared.indexOf('123456'), lessThan(prepared.indexOf('visible')));
      expect(
        prepared.contains('data-axichat-recovered-email-content'),
        isFalse,
      );
      expect(prepared.contains('display:none'), isFalse);
      expect(prepared.contains('visibility:hidden'), isFalse);
      expect(prepared.contains('mso-hide'), isFalse);
    });

    test('keeps hidden OTPs in place without injecting a recovered block', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<table><tbody><tr><td>Before</td></tr>'
        '<tr hidden><td>123456</td></tr>'
        '<tr><td>After</td></tr></tbody></table>',
        allowRemoteImages: true,
      );

      expect(
        prepared.contains('data-axichat-recovered-email-content'),
        isFalse,
      );
      expect(prepared.contains('Additional email content'), isFalse);
      expect(prepared.contains('123456'), isTrue);
      expect(prepared.indexOf('Before'), lessThan(prepared.indexOf('123456')));
      expect(prepared.indexOf('123456'), lessThan(prepared.indexOf('After')));
    });

    test('keeps hidden content only once at its source position', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<p hidden>123456</p>'
        '<p hidden>654321</p>'
        '<p>123456</p>',
        allowRemoteImages: true,
      );

      expect(
        prepared.contains('data-axichat-recovered-email-content'),
        isFalse,
      );
      expect(prepared.contains('654321'), isTrue);
      expect('123456'.allMatches(prepared), hasLength(2));
    });

    test('restores safe hidden action links as sanitized anchors in place', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<p>Before</p><div hidden>'
        '<a href="https://example.com/confirm" aria-label="Confirm account"></a>'
        '<a href="javascript:alert(1)">Bad link</a>'
        '</div><p>After</p>',
        allowRemoteImages: true,
      );

      expect(
        prepared.contains('data-axichat-recovered-email-content'),
        isFalse,
      );
      expect(prepared.contains('href="https://example.com/confirm"'), isTrue);
      expect(prepared.contains('Confirm account'), isTrue);
      expect(prepared.contains('javascript:'), isFalse);
      expect(prepared.contains('Bad link'), isFalse);
      expect(
        prepared.indexOf('Before'),
        lessThan(prepared.indexOf('Confirm account')),
      );
      expect(
        prepared.indexOf('Confirm account'),
        lessThan(prepared.indexOf('After')),
      );
    });

    test('restores useful image-only hidden link labels in place', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<p>Before</p>'
        '<a hidden href="https://example.com/dashboard">'
        '<img src="data:image/png;base64,AAAA" alt="Open dashboard" />'
        '</a>'
        '<p>After</p>',
        allowRemoteImages: true,
      );

      expect(prepared.contains('href="https://example.com/dashboard"'), isTrue);
      expect(prepared.contains('Open dashboard'), isTrue);
      expect(
        prepared.indexOf('Before'),
        lessThan(prepared.indexOf('Open dashboard')),
      );
      expect(
        prepared.indexOf('Open dashboard'),
        lessThan(prepared.indexOf('After')),
      );
    });

    test('converts useful hidden controls to static content in place', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<p>Before</p>'
        '<form><button title="Approve sign in"></button></form>'
        '<input type="hidden" value="567890" />'
        '<select><option>Use code 246810</option></select>'
        '<p>After</p>',
        allowRemoteImages: true,
      );

      expect(prepared.contains('<form'), isFalse);
      expect(prepared.contains('<button'), isFalse);
      expect(prepared.contains('<input'), isFalse);
      expect(prepared.contains('<select'), isFalse);
      expect(prepared.contains('Approve sign in'), isTrue);
      expect(prepared.contains('567890'), isTrue);
      expect(prepared.contains('Use code 246810'), isTrue);
      expect(
        prepared.indexOf('Before'),
        lessThan(prepared.indexOf('Approve sign in')),
      );
      expect(
        prepared.indexOf('Use code 246810'),
        lessThan(prepared.indexOf('After')),
      );
    });

    test('does not restore unsafe hidden content', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<script>123456</script>'
        '<style>.code::before { content: "234567"; }</style>'
        '<svg><text>345678</text></svg>'
        '<iframe>456789</iframe>'
        '<input type="hidden" value="do-not-show" />'
        '<a hidden href="javascript:alert(1)">678901</a>'
        '<a hidden href="https://example.com/track">'
        '<img width="1" height="1" alt="tracking pixel" />'
        '</a>'
        '<p>visible</p>',
        allowRemoteImages: true,
      );

      expect(prepared.contains('123456'), isFalse);
      expect(prepared.contains('345678'), isFalse);
      expect(prepared.contains('456789'), isFalse);
      expect(prepared.contains('do-not-show'), isFalse);
      expect(prepared.contains('678901'), isFalse);
      expect(prepared.contains('tracking pixel'), isFalse);
      expect(prepared.contains('visible'), isTrue);
    });

    test('does not restore arbitrary hidden preheader content', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<div style="display:none">'
        'Preview text for the inbox. '
        '<a href="https://example.com/browser">View in browser</a>'
        '</div>'
        '<p hidden>Here is our latest newsletter</p>'
        '<p>visible</p>',
        allowRemoteImages: true,
      );

      expect(prepared.contains('Preview text'), isFalse);
      expect(prepared.contains('View in browser'), isFalse);
      expect(prepared.contains('latest newsletter'), isFalse);
      expect(prepared.contains('visible'), isTrue);
    });

    test('keeps safe @media rules while stripping blocked declarations', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<style>@media only screen and (max-width: 600px) { '
        '.note { color: red; position: absolute; transform: translateY(-12px); } '
        '} .base { margin: 8px; }</style>'
        '<p class="note base">ok</p>',
        allowRemoteImages: true,
      );
      expect(
        prepared.contains('@media only screen and (max-width: 600px)'),
        isTrue,
      );
      expect(prepared.contains('color: red'), isTrue);
      expect(prepared.contains('margin: 8px'), isTrue);
      expect(prepared.contains('position: absolute'), isFalse);
      expect(prepared.contains('transform'), isFalse);
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
    test('returns a stripped fragment without inline styling', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForFlutterHtml(
        '<style>.lead { font-size: 22px; color: #123456; }</style>'
        '<p class="lead" style="font-size:18px; line-height:1.6;">ok</p>'
        '<img src="https://example.com/x.png" width="320" height="160" />',
        allowRemoteImages: true,
      );
      expect(prepared.contains('<style'), isFalse);
      expect(prepared.contains('style='), isFalse);
      expect(prepared.contains('<p>ok</p>'), isTrue);
      expect(prepared.contains('src="https://example.com/x.png"'), isTrue);
    });

    test('restores hidden content in Flutter HTML output', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForFlutterHtml(
        '<p hidden>123456</p><p>visible</p>',
        allowRemoteImages: true,
      );

      expect(
        prepared.contains('data-axichat-recovered-email-content'),
        isFalse,
      );
      expect(prepared.contains('Additional email content'), isFalse);
      expect(prepared.contains('123456'), isTrue);
      expect(prepared.contains('visible'), isTrue);
    });

    test('does not add WebView CSS chrome to Flutter HTML output', () {
      final prepared = HtmlContentCodec.prepareEmailHtmlForFlutterHtml(
        '<table width="640"><tbody><tr>'
        '<td width="320">Footer</td>'
        '<td><span>Legal</span></td>'
        '</tr></tbody></table>'
        '<p>After</p>',
        allowRemoteImages: true,
      );

      expect(prepared.contains('Footer'), isTrue);
      expect(prepared.contains('Legal'), isTrue);
      expect(prepared.contains('After'), isTrue);
      expect(prepared.contains('<table'), isFalse);
      expect(prepared.contains('axichat-email-webview-style'), isFalse);
      expect(prepared.contains('text-size-adjust: 100% !important;'), isFalse);
      expect(prepared.contains('font-size: 16px !important;'), isFalse);
      expect(prepared.contains('table-layout: fixed !important;'), isFalse);
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

  group('HtmlContentCodec.containsRenderableRemoteImages', () {
    test('detects remote images that survive safe email rendering', () {
      expect(
        HtmlContentCodec.containsRenderableRemoteImages(
          '<p>Logo</p><img src="https://example.com/logo.png" />',
        ),
        isTrue,
      );
    });

    test('ignores hidden tracker images removed from safe rendering', () {
      const html =
          '<div style="display:none">'
          '<img src="https://tracker.example.com/pixel.png" />'
          '</div><p>Hello</p>';

      expect(HtmlContentCodec.containsRemoteImages(html), isTrue);
      expect(HtmlContentCodec.containsRenderableRemoteImages(html), isFalse);
    });
  });

  group('HtmlContentCodec.containsCidImages', () {
    test('detects unsupported cid images', () {
      expect(
        HtmlContentCodec.containsCidImages('<img src="cid:abc123" />'),
        isTrue,
      );
      expect(
        HtmlContentCodec.containsCidImages(
          '<img src="https://example.com/x.png" />',
        ),
        isFalse,
      );
      final prepared = HtmlContentCodec.prepareEmailHtmlForWebView(
        '<img src="cid:abc123" />',
        allowRemoteImages: true,
      );
      expect(prepared.contains('cid:abc123'), isFalse);
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
          '<img src="cid:abc123" />',
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
      expect(
        HtmlContentCodec.containsBlockedWebViewContent(
          '<p style="position:fixed; color:red">bad</p>',
        ),
        isTrue,
      );
      expect(
        HtmlContentCodec.containsBlockedWebViewContent(
          '<p style="position:absolute; top:0; z-index:9999; color:red">bad</p>',
        ),
        isTrue,
      );
      expect(
        HtmlContentCodec.containsBlockedWebViewContent(
          '<p style="width:999px; color:red">ok</p>',
        ),
        isFalse,
      );
      expect(
        HtmlContentCodec.containsBlockedWebViewContent(
          '<div style=url(https://evil.test/x.png)>bad</div',
        ),
        isTrue,
      );
      expect(
        HtmlContentCodec.containsBlockedWebViewContent(
          '<a href=javascript:alert(1)>bad',
        ),
        isTrue,
      );
    });

    test('detects active form content', () {
      expect(
        HtmlContentCodec.containsBlockedWebViewContent(
          '<form><button>Confirm</button></form>',
        ),
        isTrue,
      );
    });
  });
}
