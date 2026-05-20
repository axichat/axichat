import 'dart:ui';

import 'package:axichat/src/chat/view/timeline/message/email_html_web_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('prepareEmailHtmlDataForWebView', () {
    test('safe mode injects layout css after sanitizing content', () {
      const themeStyle =
          '<meta name="viewport" content="width=device-width">'
          '<style id="axichat-email-webview-theme">'
          'img{max-width:100%}'
          '</style>';

      final prepared = prepareEmailHtmlDataForWebView(
        html:
            '<html><head></head><body>'
            '<script>window.axichatUnsafe = true;</script>'
            '<p onclick="evil()">ok</p>'
            '<img src="https://example.com/pixel.png">'
            '</body></html>',
        allowRemoteImages: false,
        themeStyle: themeStyle,
        contentMode: EmailHtmlContentMode.safe,
      );

      expect(prepared.contains('axichat-email-webview-theme'), isTrue);
      expect(prepared.contains('axichatUnsafe'), isFalse);
      expect(prepared.contains('<script'), isFalse);
      expect(prepared.contains('onclick'), isFalse);
      expect(prepared.contains('https://example.com/pixel.png'), isFalse);
      expect(prepared.contains('<p>ok</p>'), isTrue);
    });

    test('original passive mode wraps raw markup in a passive shell', () {
      const themeStyle =
          '<meta name="viewport" content="width=device-width">'
          '<style id="axichat-email-webview-theme">'
          'img{max-width:100%}'
          '</style>';

      final prepared = prepareEmailHtmlDataForWebView(
        html:
            '<html><head><title>Example</title></head><body>'
            '<script>window.axichatTest = true;</script>'
            '<img src="https://example.com/pixel.png">'
            '</body></html>',
        allowRemoteImages: false,
        themeStyle: themeStyle,
        contentMode: EmailHtmlContentMode.originalPassive,
      );

      expect(prepared.contains('axichat-original-email-frame'), isTrue);
      expect(prepared.contains('sandbox="allow-same-origin"'), isTrue);
      expect(prepared.contains('allow-scripts'), isFalse);
      expect(prepared.contains("callHandler('axichatEmailHeight'"), isTrue);
      expect(prepared.contains("callHandler('axichatEmailLink'"), isTrue);
      expect(prepared.contains('lastReportedMetricsKey'), isTrue);
      expect(
        prepared.contains('metricsKey === lastReportedMetricsKey'),
        isTrue,
      );
      expect(prepared.contains('axichat-email-webview-theme'), isTrue);
      expect(prepared.contains('window.axichatTest = true'), isTrue);
      expect(prepared.contains('https://example.com/pixel.png'), isTrue);
    });

    test('original passive mode routes iframe links through a safe bridge', () {
      const themeStyle =
          '<meta name="viewport" content="width=device-width">'
          '<style id="axichat-email-webview-theme">'
          'img{max-width:100%}'
          '</style>';

      final prepared = prepareEmailHtmlDataForWebView(
        html:
            '<html><body>'
            '<a href="https://example.com">outer <span>inner</span></a>'
            '<a href="javascript:alert(1)">bad</a>'
            '</body></html>',
        allowRemoteImages: true,
        themeStyle: themeStyle,
        contentMode: EmailHtmlContentMode.originalPassive,
      );

      expect(prepared.contains('const findAnchor = (target) =>'), isTrue);
      expect(
        prepared.contains('current.nodeType !== Node.ELEMENT_NODE'),
        isTrue,
      );
      expect(
        prepared.contains("typeof current.closest !== 'function'"),
        isTrue,
      );
      expect(prepared.contains('event.preventDefault();'), isTrue);
      expect(prepared.contains('event.stopPropagation();'), isTrue);
      expect(
        prepared.contains("allowedLinkProtocols.has(url.protocol)"),
        isTrue,
      );
      expect(
        prepared.contains("callHandler('axichatEmailLink', url.href)"),
        isTrue,
      );
      expect(prepared.contains('window.location.href = href'), isFalse);
      expect(prepared.contains('event.target instanceof Element'), isFalse);
      expect(prepared.contains('mutation.target instanceof Element'), isFalse);
      expect(
        prepared.contains('mutation.target.nodeType === Node.ELEMENT_NODE'),
        isTrue,
      );
    });

    test('original passive link bridge uses app link safety rules', () {
      expect(
        safeEmailLinkUrlForTesting('https://example.com/a'),
        'https://example.com/a',
      );
      expect(
        safeEmailLinkUrlForTesting('mailto:test@example.com'),
        'mailto:test@example.com',
      );
      expect(
        safeEmailLinkUrlForTesting('xmpp:test@example.com'),
        'xmpp:test@example.com',
      );
      expect(safeEmailLinkUrlForTesting('javascript:alert(1)'), isNull);
      expect(safeEmailLinkUrlForTesting('data:text/html,hi'), isNull);
      expect(safeEmailLinkUrlForTesting('file:///tmp/message.html'), isNull);
    });

    test('original passive mode installs iframe width fitting', () {
      const themeStyle =
          '<meta name="viewport" content="width=device-width">'
          '<style id="axichat-email-webview-theme">'
          'img{max-width:100%}'
          '</style>';

      final prepared = prepareEmailHtmlDataForWebView(
        html:
            '<html><body>'
            '<table width="1200"><tr><td>wide</td></tr></table>'
            '</body></html>',
        allowRemoteImages: true,
        themeStyle: themeStyle,
        contentMode: EmailHtmlContentMode.originalPassive,
      );

      expect(prepared.contains('axichat-original-email-scale-root'), isTrue);
      expect(prepared.contains('contentWidth'), isTrue);
      expect(prepared.contains('viewportWidth'), isTrue);
      expect(prepared.contains('widthScale'), isTrue);
      expect(
        prepared.contains(
          "setProperty('width', contentWidth + 'px', 'important')",
        ),
        isTrue,
      );
      expect(
        prepared.contains("style.transform = 'scale(' + widthScale + ')'"),
        isTrue,
      );
      expect(prepared.contains('observeImages();'), isTrue);
      expect(prepared.contains('doc.fonts.ready.then(scheduleHeight)'), isTrue);
      expect(prepared.contains("window.addEventListener('resize'"), isTrue);
      expect(prepared.contains('new MutationObserver((mutations) =>'), isTrue);
      expect(prepared.contains('isWidthFitStyleMutation'), isTrue);
      expect(
        prepared.contains('mutations.every(isWidthFitStyleMutation)'),
        isTrue,
      );
    });

    test('original passive height bridge dedupes width fit metrics', () {
      const themeStyle =
          '<meta name="viewport" content="width=device-width">'
          '<style id="axichat-email-webview-theme">'
          'img{max-width:100%}'
          '</style>';

      final prepared = prepareEmailHtmlDataForWebView(
        html: '<html><body><p>ok</p></body></html>',
        allowRemoteImages: true,
        themeStyle: themeStyle,
        contentMode: EmailHtmlContentMode.originalPassive,
      );

      final metricsKeyExpression =
          RegExp(
            r'const metricsKey = \[[\s\S]*?\]\.join',
          ).firstMatch(prepared)?.group(0) ??
          '';

      expect(metricsKeyExpression.contains('metrics.measuredHeight'), isTrue);
      expect(metricsKeyExpression.contains('metrics.scrollHeight'), isTrue);
      expect(metricsKeyExpression.contains('metrics.viewportHeight'), isTrue);
      expect(metricsKeyExpression.contains('metrics.contentWidth'), isTrue);
      expect(metricsKeyExpression.contains('metrics.viewportWidth'), isTrue);
      expect(metricsKeyExpression.contains('metrics.widthScale'), isTrue);
      expect(metricsKeyExpression.contains('metrics.pendingImages'), isTrue);
      expect(metricsKeyExpression.contains('metrics.documentReady'), isTrue);
      expect(metricsKeyExpression.contains('metrics.imagesReady'), isTrue);
      expect(metricsKeyExpression.contains('metrics.fontsReady'), isTrue);
      expect(metricsKeyExpression.contains('metrics.widthFitReady'), isTrue);
      expect(metricsKeyExpression.contains('metrics.layoutStable'), isTrue);
      expect(metricsKeyExpression.contains('metrics.layoutSequence'), isTrue);
    });

    test(
      'original passive mode normalizes iframe viewport before measuring',
      () {
        const themeStyle =
            '<meta name="viewport" content="width=device-width">'
            '<style id="axichat-email-webview-theme">'
            'img{max-width:100%}'
            '</style>';

        final prepared = prepareEmailHtmlDataForWebView(
          html:
              '<html><head>'
              '<meta name="viewport" content="width=1200">'
              '</head><body><p>ok</p></body></html>',
          allowRemoteImages: true,
          themeStyle: themeStyle,
          contentMode: EmailHtmlContentMode.originalPassive,
        );

        expect(prepared.contains('normalizeFrameDocument'), isTrue);
        expect(
          prepared.contains('querySelectorAll(\'meta[name="viewport"]\')'),
          isTrue,
        );
        expect(
          prepared.contains('template.innerHTML = themeStyleHtml'),
          isTrue,
        );
        expect(prepared.contains('head.appendChild(viewport)'), isTrue);
        expect(prepared.contains('head.appendChild(style)'), isTrue);
        expect(
          prepared.contains("querySelectorAll('#axichat-email-webview-theme')"),
          isTrue,
        );
        expect(prepared.contains('__axichatViewportNormalized = true'), isTrue);
      },
    );

    test('height script measures original iframe content', () {
      final script = emailDomHeightMetricsExpressionForTesting();
      final measuredHeightExpression =
          RegExp(
            r'const measuredHeight = Math\.ceil\([\s\S]*?\);\n  if \(frame',
          ).firstMatch(script)?.group(0) ??
          '';

      expect(
        script.contains("getElementById('axichat-original-email-frame')"),
        isTrue,
      );
      expect(script.contains('frame.contentDocument'), isTrue);
      expect(script.contains('sourceDocument.body'), isTrue);
      expect(script.contains('contentWidth: contentWidth'), isTrue);
      expect(script.contains('viewportWidth: viewportWidth'), isTrue);
      expect(script.contains('widthScale: widthScale'), isTrue);
      expect(script.contains('pendingImages: pendingImages'), isTrue);
      expect(script.contains('documentReady: documentReady'), isTrue);
      expect(script.contains('imagesReady: imagesReady'), isTrue);
      expect(script.contains('fontsReady: fontsReady'), isTrue);
      expect(script.contains('widthFitReady: widthFitReady'), isTrue);
      expect(script.contains('layoutStable: layoutStable'), isTrue);
      expect(script.contains('layoutSequence: layoutSequence'), isTrue);
      expect(
        script.contains("sourceDocument.readyState === 'complete'"),
        isTrue,
      );
      expect(
        script.contains("sourceDocument.readyState !== 'loading'"),
        isFalse,
      );
      expect(script.contains('!image.complete'), isTrue);
      expect(script.contains('layoutBlockingPendingImages'), isTrue);
      expect(script.contains('hasReservedImageLayout'), isTrue);
      expect(script.contains("getAttribute('loading') || ''"), isTrue);
      expect(script.contains("toLowerCase() !== 'lazy'"), isTrue);
      expect(
        script.contains("sourceDocument.fonts.status === 'loaded'"),
        isTrue,
      );
      expect(script.contains('__axichatWidthFitApplied = true'), isTrue);
      expect(
        script.contains("widthFitRoot.style.transform = 'scale('"),
        isTrue,
      );
      expect(script.contains('range.selectNodeContents(body)'), isTrue);
      expect(script.contains('sourceDocument.createTreeWalker'), isTrue);
      expect(script.contains('NodeFilter.SHOW_TEXT'), isTrue);
      expect(script.contains('range.getClientRects()'), isTrue);
      expect(script.contains("frame.style.height = '';"), isTrue);
      expect(script.contains("document.body.style.minHeight = '';"), isTrue);
      expect(script.contains('document.body.style.minHeight'), isTrue);
      expect(script.contains('__axichatViewportNormalized'), isTrue);
      expect(script.contains('!frame.contentDocument'), isTrue);
      expect(script.contains('Number.parseFloat(style.opacity'), isTrue);
      expect(script.contains('current = current.parentElement'), isTrue);
      expect(script.contains('rect.width <= 0'), isTrue);
      expect(script.contains('rect.height <= 0'), isTrue);
      expect(
        script.contains('hasVisibleBounds ? maxBottom : fallbackHeight'),
        isTrue,
      );
      expect(script.contains('style.marginBottom'), isTrue);
      expect(script.contains('__axichatEmailLastStabilityKey'), isTrue);
      expect(script.contains('__axichatEmailLastStabilitySequence'), isTrue);
      expect(
        script.contains('__axichatEmailLastStabilitySequence || -1'),
        isFalse,
      );
      expect(
        script.contains("__axichatEmailLastStabilitySequence === undefined"),
        isTrue,
      );
      expect(measuredHeightExpression.contains('scrollHeight'), isFalse);
      expect(measuredHeightExpression.contains('offsetHeight'), isFalse);
    });

    test('safe document observer reports DOM height after late layout', () {
      final script = emailDocumentHeightObserverExpressionForTesting();

      expect(
        script.contains("callHandler('axichatEmailHeight', metrics)"),
        isTrue,
      );
      expect(script.contains('lastReportedMetricsKey'), isTrue);
      expect(script.contains('metrics.contentWidth'), isTrue);
      expect(script.contains('metrics.viewportWidth'), isTrue);
      expect(script.contains('metrics.widthScale'), isTrue);
      expect(script.contains('metrics.pendingImages'), isTrue);
      expect(script.contains('metrics.documentReady'), isTrue);
      expect(script.contains('metrics.imagesReady'), isTrue);
      expect(script.contains('metrics.fontsReady'), isTrue);
      expect(script.contains('metrics.widthFitReady'), isTrue);
      expect(script.contains('metrics.layoutStable'), isTrue);
      expect(script.contains('metrics.layoutSequence'), isTrue);
      expect(script.contains('noteLayoutChanged'), isTrue);
      expect(script.contains('document.__axichatEmailLayoutSequence'), isTrue);
      expect(script.contains('reportUntilStable'), isTrue);
      expect(script.contains("window.addEventListener('load'"), isTrue);
      expect(script.contains("window.addEventListener('resize'"), isTrue);
      expect(script.contains('document.fonts.ready.then(schedule)'), isTrue);
      expect(script.contains('new MutationObserver(() =>'), isTrue);
      expect(script.contains('observeImages();'), isTrue);
      expect(script.contains("window.setTimeout(schedule, 100)"), isTrue);
      expect(script.contains("window.setTimeout(schedule, 300)"), isTrue);
      expect(script.contains("window.setTimeout(schedule, 1000)"), isTrue);
    });

    test('height script ignores nonblocking pending images', () {
      final script = emailDomHeightMetricsExpressionForTesting();

      expect(
        script.contains(
          'const imagesReady = layoutBlockingPendingImages === 0',
        ),
        isTrue,
      );
      expect(script.contains("toLowerCase() !== 'lazy'"), isTrue);
      expect(script.contains('!hasReservedImageLayout(image)'), isTrue);
      expect(script.contains("image.getAttribute('width')"), isTrue);
      expect(script.contains("image.getAttribute('height')"), isTrue);
      expect(script.contains('rect.width > 0'), isTrue);
      expect(script.contains('rect.height > 0'), isTrue);
    });

    test('email theme css is injected after raw head styles', () {
      const themeStyle =
          '<style id="axichat-email-webview-theme">'
          'html, body { min-height: 0 !important; height: auto !important; }'
          '</style>';

      final prepared = prepareEmailHtmlDataForWebView(
        html:
            '<html><head>'
            '<style>html, body { min-height: 9999px !important; }</style>'
            '</head><body><p>ok</p></body></html>',
        allowRemoteImages: false,
        themeStyle: themeStyle,
        contentMode: EmailHtmlContentMode.originalPassive,
      );

      expect(
        prepared.indexOf('min-height: 0 !important'),
        greaterThan(prepared.indexOf('min-height: 9999px !important')),
      );
    });

    test(
      'email theme css carries readable text and responsive media rules',
      () {
        final themeStyle = buildEmailWebViewThemeStyleForTesting(
          brightness: Brightness.light,
          backgroundColor: const Color(0xFFFFFFFF),
        );

        expect(themeStyle.contains('font-size: 16px !important;'), isTrue);
        expect(themeStyle.contains('line-height: 1.5 !important;'), isTrue);
        expect(
          themeStyle.contains('-webkit-text-size-adjust: 100% !important;'),
          isTrue,
        );
        expect(
          themeStyle.contains('text-size-adjust: 100% !important;'),
          isTrue,
        );
        expect(
          themeStyle.contains('overflow-wrap: break-word !important;'),
          isTrue,
        );
        expect(
          themeStyle.contains('img, table, iframe, pre, blockquote'),
          isTrue,
        );
        expect(
          themeStyle.contains('overflow-wrap: anywhere !important;'),
          isFalse,
        );
        expect(themeStyle.contains('table-layout: fixed !important;'), isFalse);
        expect(themeStyle.contains('table[width]'), isFalse);
        expect(themeStyle.contains('td[width], th[width]'), isFalse);
        expect(themeStyle.contains('td > *, th > *'), isFalse);
        expect(themeStyle.contains('td, th {\n  width:'), isFalse);
        expect(themeStyle.contains('font, center'), isFalse);
        expect(themeStyle.contains('min-width: 0 !important;'), isFalse);
        expect(themeStyle.contains('font-size: 1.5em !important;'), isTrue);
        expect(themeStyle.contains('overflow-x: hidden'), isFalse);
      },
    );
  });

  group('EmailHtmlContentMode', () {
    test('separates safe image loading from original content approval', () {
      expect(
        EmailHtmlContentMode.safe.allowsRemoteImages(
          shouldLoadSafeRemoteImages: false,
        ),
        isFalse,
      );
      expect(
        EmailHtmlContentMode.originalPassive.allowsRemoteImages(
          shouldLoadSafeRemoteImages: false,
        ),
        isTrue,
      );
    });
  });

  group('loading layout', () {
    test('keeps fallback and spinner visible while WebView is loading', () {
      final layout = emailHtmlWebViewLoadingLayoutForTesting(
        hasLoadingFallback: true,
        hasWebView: true,
        hasPreparedHtmlData: true,
        hasContentHeight: false,
        isLoading: true,
      );

      expect(layout.phase, 'loading');
      expect(layout.showLoadingOverlay, isTrue);
      expect(layout.paintLoadingFallback, isTrue);
      expect(layout.preserveLoadingFallback, isFalse);
      expect(layout.paintWebView, isFalse);
      expect(layout.preserveWebView, isTrue);
      expect(layout.useFixedHeight, isFalse);
      expect(layout.preserveMeasuredHeight, isFalse);
    });

    test('preserves measured height while reloading fallback', () {
      final layout = emailHtmlWebViewLoadingLayoutForTesting(
        hasLoadingFallback: true,
        hasWebView: true,
        hasPreparedHtmlData: true,
        hasContentHeight: true,
        isLoading: true,
      );

      expect(layout.phase, 'loading');
      expect(layout.showLoadingOverlay, isTrue);
      expect(layout.paintLoadingFallback, isTrue);
      expect(layout.paintWebView, isFalse);
      expect(layout.useFixedHeight, isFalse);
      expect(layout.preserveMeasuredHeight, isTrue);
    });

    test('reveals WebView at fixed measured height without fallback', () {
      final layout = emailHtmlWebViewLoadingLayoutForTesting(
        hasLoadingFallback: true,
        hasWebView: true,
        hasPreparedHtmlData: true,
        hasContentHeight: true,
        isLoading: false,
      );

      expect(layout.phase, 'fixedHeight');
      expect(layout.showLoadingOverlay, isFalse);
      expect(layout.paintLoadingFallback, isFalse);
      expect(layout.preserveLoadingFallback, isFalse);
      expect(layout.paintWebView, isTrue);
      expect(layout.preserveWebView, isFalse);
      expect(layout.useFixedHeight, isTrue);
      expect(layout.preserveMeasuredHeight, isFalse);
    });

    test('reveals WebView while preserving fallback size before height', () {
      final layout = emailHtmlWebViewLoadingLayoutForTesting(
        hasLoadingFallback: true,
        hasWebView: true,
        hasPreparedHtmlData: true,
        hasContentHeight: false,
        isLoading: false,
      );

      expect(layout.phase, 'preservingFallback');
      expect(layout.showLoadingOverlay, isFalse);
      expect(layout.paintLoadingFallback, isFalse);
      expect(layout.preserveLoadingFallback, isTrue);
      expect(layout.paintWebView, isTrue);
      expect(layout.preserveWebView, isFalse);
      expect(layout.useFixedHeight, isFalse);
      expect(layout.preserveMeasuredHeight, isFalse);
    });

    test('keeps no-fallback original mode fixed and hidden while loading', () {
      final layout = emailHtmlWebViewLoadingLayoutForTesting(
        hasLoadingFallback: false,
        hasWebView: true,
        hasPreparedHtmlData: true,
        hasContentHeight: false,
        isLoading: true,
      );

      expect(layout.phase, 'loading');
      expect(layout.showLoadingOverlay, isTrue);
      expect(layout.paintLoadingFallback, isFalse);
      expect(layout.preserveLoadingFallback, isFalse);
      expect(layout.paintWebView, isFalse);
      expect(layout.preserveWebView, isTrue);
      expect(layout.useFixedHeight, isTrue);
      expect(layout.preserveMeasuredHeight, isFalse);
    });

    test('keeps no-fallback loaded WebView fixed before height arrives', () {
      final layout = emailHtmlWebViewLoadingLayoutForTesting(
        hasLoadingFallback: false,
        hasWebView: true,
        hasPreparedHtmlData: true,
        hasContentHeight: false,
        isLoading: false,
      );

      expect(layout.phase, 'fixedPlaceholder');
      expect(layout.showLoadingOverlay, isFalse);
      expect(layout.paintLoadingFallback, isFalse);
      expect(layout.preserveLoadingFallback, isFalse);
      expect(layout.paintWebView, isTrue);
      expect(layout.preserveWebView, isFalse);
      expect(layout.useFixedHeight, isTrue);
      expect(layout.preserveMeasuredHeight, isFalse);
    });
  });

  group('height commit gate', () {
    test('does not commit positive image-first height before readiness', () {
      expect(
        emailHtmlHeightCanCommitForTesting(
          hasPositiveHeight: true,
          usesPlatformFallback: false,
          documentReady: false,
          imagesReady: false,
          widthFitReady: true,
          layoutStable: false,
        ),
        isFalse,
      );
    });

    test('commits once document images width fit and layout are stable', () {
      expect(
        emailHtmlHeightCanCommitForTesting(
          hasPositiveHeight: true,
          usesPlatformFallback: false,
          documentReady: true,
          imagesReady: true,
          widthFitReady: true,
          layoutStable: true,
        ),
        isTrue,
      );
    });

    test('does not commit stable layout before document completes', () {
      expect(
        emailHtmlHeightCanCommitForTesting(
          hasPositiveHeight: true,
          usesPlatformFallback: false,
          documentReady: false,
          imagesReady: true,
          widthFitReady: true,
          layoutStable: true,
        ),
        isFalse,
      );
    });

    test('does not commit an unstable candidate height', () {
      expect(
        emailHtmlHeightCanCommitForTesting(
          hasPositiveHeight: true,
          usesPlatformFallback: false,
          documentReady: true,
          imagesReady: true,
          widthFitReady: true,
          layoutStable: false,
        ),
        isFalse,
      );
    });

    test('commits platform fallback height when DOM readiness failed', () {
      expect(
        emailHtmlHeightCanCommitForTesting(
          hasPositiveHeight: true,
          usesPlatformFallback: true,
          documentReady: false,
          imagesReady: false,
          widthFitReady: false,
          layoutStable: false,
        ),
        isTrue,
      );
    });

    test('does not commit invalid platform fallback height', () {
      expect(
        emailHtmlHeightCanCommitForTesting(
          hasPositiveHeight: false,
          usesPlatformFallback: true,
          documentReady: false,
          imagesReady: false,
          widthFitReady: false,
          layoutStable: false,
        ),
        isFalse,
      );
    });

    test('defers image and oversize reports until final stable height', () {
      final imageOnly = emailHtmlContentHeightAfterReportForTesting(
        currentContentHeight: null,
        isLoading: true,
        usesHeightBridge: true,
        reportedHeight: 96,
        canCommitHeight: false,
      );
      expect(imageOnly.contentHeight, isNull);
      expect(imageOnly.isLoading, isTrue);
      expect(imageOnly.committed, isFalse);

      final oversized = emailHtmlContentHeightAfterReportForTesting(
        currentContentHeight: imageOnly.contentHeight,
        isLoading: imageOnly.isLoading,
        usesHeightBridge: true,
        reportedHeight: 3200,
        canCommitHeight: false,
      );
      expect(oversized.contentHeight, isNull);
      expect(oversized.isLoading, isTrue);
      expect(oversized.committed, isFalse);

      final finalStable = emailHtmlContentHeightAfterReportForTesting(
        currentContentHeight: oversized.contentHeight,
        isLoading: oversized.isLoading,
        usesHeightBridge: true,
        reportedHeight: 640,
        canCommitHeight: true,
      );
      expect(finalStable.contentHeight, 640);
      expect(finalStable.isLoading, isFalse);
      expect(finalStable.committed, isTrue);
    });

    test(
      'commits first stable initial height because bridge dedupes repeats',
      () {
        final firstStableReport = emailHtmlContentHeightAfterReportForTesting(
          currentContentHeight: null,
          isLoading: false,
          usesHeightBridge: true,
          reportedHeight: 640,
          canCommitHeight: true,
        );
        final script = emailDocumentHeightObserverExpressionForTesting();

        expect(firstStableReport.contentHeight, 640);
        expect(firstStableReport.isLoading, isFalse);
        expect(firstStableReport.committed, isTrue);
        expect(
          script.contains('metricsKey === lastReportedMetricsKey'),
          isTrue,
        );
      },
    );

    test('does not commit invalid bridge report before first height', () {
      final invalid = emailHtmlContentHeightAfterReportForTesting(
        currentContentHeight: null,
        isLoading: true,
        usesHeightBridge: true,
        reportedHeight: 3200,
        canCommitHeight: false,
      );
      expect(invalid.contentHeight, isNull);
      expect(invalid.isLoading, isTrue);
      expect(invalid.committed, isFalse);
    });

    test('ignores unstable height changes after the first stable reveal', () {
      final unstableSpike = emailHtmlContentHeightAfterReportForTesting(
        currentContentHeight: 640,
        isLoading: false,
        usesHeightBridge: true,
        reportedHeight: 3200,
        canCommitHeight: false,
      );
      expect(unstableSpike.contentHeight, 640);
      expect(unstableSpike.isLoading, isFalse);
      expect(unstableSpike.committed, isFalse);

      final stableCorrection = emailHtmlContentHeightAfterReportForTesting(
        currentContentHeight: unstableSpike.contentHeight,
        isLoading: unstableSpike.isLoading,
        usesHeightBridge: true,
        reportedHeight: 672,
        canCommitHeight: true,
      );
      expect(stableCorrection.contentHeight, 672);
      expect(stableCorrection.isLoading, isFalse);
      expect(stableCorrection.committed, isTrue);
    });
  });

  group('height measurement policy', () {
    test('uses iframe DOM height for original mode on non-Linux platforms', () {
      expect(
        emailHtmlUsesDomContentHeightMeasurementForTesting(
          contentMode: EmailHtmlContentMode.originalPassive,
          platform: TargetPlatform.android,
        ),
        isTrue,
      );
      expect(
        emailHtmlUsesPlatformContentHeightMeasurementForTesting(
          contentMode: EmailHtmlContentMode.originalPassive,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
      expect(
        emailHtmlUsesPlatformContentHeightFallbackForTesting(
          contentMode: EmailHtmlContentMode.originalPassive,
          platform: TargetPlatform.linux,
        ),
        isFalse,
      );
    });

    test('uses DOM height with platform fallback for safe mode', () {
      expect(
        emailHtmlUsesDomContentHeightMeasurementForTesting(
          contentMode: EmailHtmlContentMode.safe,
          platform: TargetPlatform.android,
        ),
        isTrue,
      );
      expect(
        emailHtmlUsesPlatformContentHeightMeasurementForTesting(
          contentMode: EmailHtmlContentMode.safe,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
      expect(
        emailHtmlUsesPlatformContentHeightFallbackForTesting(
          contentMode: EmailHtmlContentMode.safe,
          platform: TargetPlatform.android,
        ),
        isTrue,
      );
    });

    test('keeps Linux safe mode on the shared DOM path', () {
      expect(
        emailHtmlUsesDomContentHeightMeasurementForTesting(
          contentMode: EmailHtmlContentMode.safe,
          platform: TargetPlatform.linux,
        ),
        isTrue,
      );
      expect(
        emailHtmlUsesPlatformContentHeightMeasurementForTesting(
          contentMode: EmailHtmlContentMode.safe,
          platform: TargetPlatform.linux,
        ),
        isFalse,
      );
      expect(
        emailHtmlUsesPlatformContentHeightFallbackForTesting(
          contentMode: EmailHtmlContentMode.safe,
          platform: TargetPlatform.linux,
        ),
        isTrue,
      );
    });

    test('keeps delayed height probes active for safe and original modes', () {
      expect(
        emailHtmlUsesDelayedContentHeightMeasurementsForTesting(
          contentMode: EmailHtmlContentMode.safe,
          platform: TargetPlatform.android,
        ),
        isTrue,
      );
      expect(
        emailHtmlUsesDelayedContentHeightMeasurementsForTesting(
          contentMode: EmailHtmlContentMode.originalPassive,
          platform: TargetPlatform.android,
        ),
        isTrue,
      );
      expect(
        emailHtmlUsesDelayedContentHeightMeasurementsForTesting(
          contentMode: EmailHtmlContentMode.safe,
          platform: TargetPlatform.linux,
        ),
        isTrue,
      );
      expect(
        emailHtmlUsesDelayedContentHeightMeasurementsForTesting(
          contentMode: EmailHtmlContentMode.safe,
          platform: TargetPlatform.macOS,
        ),
        isTrue,
      );
    });
  });

  group('buildEmailHtmlWebViewSettings', () {
    test('keeps safe and original WebView policies separate', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final safeSettings = buildEmailHtmlWebViewSettings(
        usesInternalScroll: false,
        useHybridComposition: true,
        simplifyLayout: false,
        allowRemoteImages: false,
        contentMode: EmailHtmlContentMode.safe,
      );
      final originalSettings = buildEmailHtmlWebViewSettings(
        usesInternalScroll: false,
        useHybridComposition: true,
        simplifyLayout: false,
        allowRemoteImages: false,
        contentMode: EmailHtmlContentMode.originalPassive,
      );

      expect(safeSettings.javaScriptEnabled, isTrue);
      expect(safeSettings.blockNetworkImage, isTrue);
      expect(safeSettings.blockNetworkLoads, isFalse);
      expect(originalSettings.javaScriptEnabled, isTrue);
      expect(originalSettings.blockNetworkImage, isFalse);
      expect(originalSettings.blockNetworkLoads, isFalse);
    });

    test('treats original passive unblock as remote-load approval', () {
      final settings = buildEmailHtmlWebViewSettings(
        usesInternalScroll: false,
        useHybridComposition: true,
        simplifyLayout: true,
        allowRemoteImages: false,
        contentMode: EmailHtmlContentMode.originalPassive,
      );

      expect(settings.blockNetworkImage, isFalse);
      expect(settings.blockNetworkLoads, isFalse);
      expect(settings.useShouldOverrideUrlLoading, isTrue);
      expect(settings.useOnDownloadStart, isTrue);
      expect(settings.disableVerticalScroll, isTrue);
      expect(settings.disableHorizontalScroll, isTrue);
      expect(settings.layoutAlgorithm, isNull);
      expect(settings.initialScale, isNull);
      expect(settings.textZoom, 100);
      expect(settings.useWideViewPort, isFalse);
      expect(settings.loadWithOverviewMode, isFalse);
    });

    test('simplified layout keeps normal WebView scale settings', () {
      final settings = buildEmailHtmlWebViewSettings(
        usesInternalScroll: false,
        useHybridComposition: true,
        simplifyLayout: true,
        allowRemoteImages: true,
        contentMode: EmailHtmlContentMode.safe,
      );

      expect(settings.javaScriptEnabled, isTrue);
      expect(settings.layoutAlgorithm, isNull);
      expect(settings.initialScale, isNull);
      expect(settings.textZoom, 100);
      expect(settings.minimumFontSize, 14);
      expect(settings.minimumLogicalFontSize, 14);
      expect(settings.supportZoom, isFalse);
      expect(settings.builtInZoomControls, isFalse);
      expect(settings.displayZoomControls, isFalse);
      expect(settings.useWideViewPort, isFalse);
      expect(settings.loadWithOverviewMode, isFalse);
    });

    test('allows approved original passive remote content safely', () {
      final settings = buildEmailHtmlWebViewSettings(
        usesInternalScroll: false,
        useHybridComposition: true,
        simplifyLayout: true,
        allowRemoteImages: true,
        contentMode: EmailHtmlContentMode.originalPassive,
      );

      expect(settings.blockNetworkImage, isFalse);
      expect(settings.blockNetworkLoads, isFalse);
      expect(settings.useShouldOverrideUrlLoading, isTrue);
      expect(settings.useOnDownloadStart, isTrue);
      expect(settings.javaScriptEnabled, isTrue);
    });

    test('allows remote images without changing baseline layout settings', () {
      final settings = buildEmailHtmlWebViewSettings(
        usesInternalScroll: true,
        useHybridComposition: false,
        simplifyLayout: false,
        allowRemoteImages: true,
        contentMode: EmailHtmlContentMode.safe,
      );

      expect(settings.blockNetworkImage, isFalse);
      expect(settings.blockNetworkLoads, isFalse);
      expect(settings.useWideViewPort, isFalse);
      expect(settings.loadWithOverviewMode, isFalse);
      expect(settings.initialScale, isNull);
      expect(settings.textZoom, 100);
      expect(settings.layoutAlgorithm, isNull);
      expect(settings.supportZoom, isFalse);
      expect(settings.disableVerticalScroll, isFalse);
      expect(settings.disableHorizontalScroll, isFalse);
    });
  });
}
