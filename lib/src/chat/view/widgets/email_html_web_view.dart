// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class EmailHtmlWebView extends StatefulWidget {
  const EmailHtmlWebView({
    super.key,
    required this.html,
    required this.allowRemoteImages,
    required this.maxHeight,
    required this.minHeight,
    required this.backgroundColor,
    required this.textColor,
    required this.linkColor,
    required this.onLinkTap,
    this.onBackgroundTap,
    this.clampHeightToMax = true,
    this.disableInternalScroll = false,
    this.simplifyLayout = false,
    this.useHybridComposition = true,
  });

  final String html;
  final bool allowRemoteImages;
  final double maxHeight;
  final double minHeight;
  final Color backgroundColor;
  final Color textColor;
  final Color linkColor;
  final ValueChanged<String> onLinkTap;
  final VoidCallback? onBackgroundTap;
  final bool clampHeightToMax;
  final bool disableInternalScroll;
  final bool simplifyLayout;
  final bool useHybridComposition;

  @override
  State<EmailHtmlWebView> createState() => _EmailHtmlWebViewState();
}

class _EmailHtmlWebViewState extends State<EmailHtmlWebView> {
  static const _emailWebViewBaseUrl = 'https://axichat.invalid/';
  static const _backgroundTapHandlerName = 'axichatBackgroundTap';
  static const _heightMeasurementScript = '''
(() => {
  const body = document.body;
  const html = document.documentElement;
  if (!body || !html) {
    return 0;
  }
  const boxHeight = Math.max(
    body.getBoundingClientRect ? body.getBoundingClientRect().height : 0,
    html.getBoundingClientRect ? html.getBoundingClientRect().height : 0
  );
  const scrollHeight = Math.max(
    body.scrollHeight,
    body.offsetHeight,
    body.clientHeight,
    html.scrollHeight,
    html.offsetHeight,
    html.clientHeight
  );
  return Math.ceil(Math.max(scrollHeight, boxHeight));
})()
''';
  static const _backgroundTapBridgeScript = '''
(() => {
  if (window.__axichatBackgroundTapInstalled) {
    return;
  }
  const handler = () => {
    document.addEventListener('click', function(event) {
      const target = event.target;
      if (target && target.closest && target.closest('a[href]')) {
        return;
      }
      const selection = window.getSelection ? String(window.getSelection()) : '';
      if (selection.trim().length > 0) {
        return;
      }
      window.flutter_inappwebview.callHandler('axichatBackgroundTap');
    }, true);
  };
  window.__axichatBackgroundTapInstalled = true;
  if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
    handler();
  } else {
    window.addEventListener('flutterInAppWebViewPlatformReady', handler, { once: true });
  }
})()
''';

  static final WebUri _emailWebViewUri = WebUri(_emailWebViewBaseUrl);

  InAppWebViewController? _controller;
  bool _isLoading = true;
  double? _contentHeight;

  double get _resolvedHeight {
    final measuredHeight = _contentHeight ?? widget.minHeight;
    if (!widget.clampHeightToMax) {
      return math.max(widget.minHeight, measuredHeight);
    }
    return measuredHeight.clamp(widget.minHeight, widget.maxHeight);
  }

  @override
  void didUpdateWidget(covariant EmailHtmlWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html ||
        oldWidget.allowRemoteImages != widget.allowRemoteImages ||
        oldWidget.maxHeight != widget.maxHeight ||
        oldWidget.minHeight != widget.minHeight) {
      _contentHeight = null;
      _loadHtml();
    }
  }

  Future<void> _loadHtml() async {
    final controller = _controller;
    if (controller == null) return;
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    await controller.loadData(
      data: _sourceHtml,
      baseUrl: _emailWebViewUri,
      historyUrl: _emailWebViewUri,
    );
  }

  String get _sourceHtml {
    final preparedHtml = HtmlContentCodec.prepareEmailHtmlForWebView(
      widget.html,
      allowRemoteImages: widget.allowRemoteImages,
    );
    final brightness = context.brightness;
    final colorSchemeValue = brightness == Brightness.dark ? 'dark' : 'light';
    final themeStyle =
        '''
<style id="axichat-email-webview-theme">
:root { color-scheme: $colorSchemeValue !important; }
html, body {
  background-color: ${_cssColor(widget.backgroundColor)} !important;
  color: ${_cssColor(widget.textColor)} !important;
}
body, p, div, span, li, td, th, blockquote, pre, code, h1, h2, h3, h4, h5, h6 {
  color: ${_cssColor(widget.textColor)} !important;
}
a, a:visited {
  color: ${_cssColor(widget.linkColor)} !important;
}
</style>
''';
    if (preparedHtml.contains('</head>')) {
      return preparedHtml.replaceFirst('</head>', '$themeStyle</head>');
    }
    return '$themeStyle$preparedHtml';
  }

  String _cssColor(Color color) {
    final red = (color.r * 255.0).round().clamp(0, 255);
    final green = (color.g * 255.0).round().clamp(0, 255);
    final blue = (color.b * 255.0).round().clamp(0, 255);
    return 'rgba($red, $green, $blue, ${color.a.toStringAsFixed(3)})';
  }

  Future<void> _measureContentHeight() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final result = await controller.evaluateJavascript(
        source: _heightMeasurementScript,
      );
      final measuredHeight = switch (result) {
        num value => value.toDouble(),
        String value => double.tryParse(value.trim()),
        _ => null,
      };
      if (!mounted || measuredHeight == null || measuredHeight <= 0) return;
      setState(() {
        _contentHeight = math.max(widget.minHeight, measuredHeight);
      });
    } on Exception {
      // Keep the fallback height if the page refuses measurement.
    }
  }

  Future<void> _scheduleRemeasurements() async {
    for (final delay in const <Duration>[
      Duration(milliseconds: 50),
      Duration(milliseconds: 150),
      Duration(milliseconds: 350),
      Duration(milliseconds: 800),
    ]) {
      await Future.delayed(delay);
      if (!mounted) {
        return;
      }
      await _measureContentHeight();
    }
  }

  Future<void> _installBackgroundTapBridge() async {
    if (widget.onBackgroundTap == null) {
      return;
    }
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.evaluateJavascript(source: _backgroundTapBridgeScript);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return SizedBox(
      width: double.infinity,
      height: _resolvedHeight,
      child: Stack(
        children: [
          InAppWebView(
            initialData: InAppWebViewInitialData(
              data: _sourceHtml,
              baseUrl: _emailWebViewUri,
              historyUrl: _emailWebViewUri,
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
              useShouldOverrideUrlLoading: true,
              useHybridComposition: widget.useHybridComposition,
              supportZoom: widget.simplifyLayout,
              useWideViewPort: widget.simplifyLayout,
              loadWithOverviewMode: widget.simplifyLayout,
              layoutAlgorithm: widget.simplifyLayout
                  ? LayoutAlgorithm.TEXT_AUTOSIZING
                  : null,
              initialScale: widget.simplifyLayout ? 0 : 100,
              textZoom: widget.simplifyLayout ? 110 : 100,
              minimumFontSize: widget.simplifyLayout ? 14 : 14,
              minimumLogicalFontSize: widget.simplifyLayout ? 14 : 14,
              preferredContentMode: UserPreferredContentMode.MOBILE,
              disableVerticalScroll: widget.disableInternalScroll,
              disableHorizontalScroll: widget.disableInternalScroll,
              verticalScrollBarEnabled: !widget.disableInternalScroll,
              horizontalScrollBarEnabled: !widget.disableInternalScroll,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
              if (widget.onBackgroundTap != null) {
                controller.addJavaScriptHandler(
                  handlerName: _backgroundTapHandlerName,
                  callback: (_) {
                    widget.onBackgroundTap?.call();
                    return null;
                  },
                );
              }
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url?.toString().trim() ?? '';
              if (url.isEmpty ||
                  url == 'about:blank' ||
                  url.startsWith(_emailWebViewBaseUrl)) {
                return NavigationActionPolicy.ALLOW;
              }
              widget.onLinkTap(url);
              return NavigationActionPolicy.CANCEL;
            },
            onLoadStop: (controller, url) async {
              await _measureContentHeight();
              await _installBackgroundTapBridge();
              unawaited(_scheduleRemeasurements());
              if (!mounted) return;
              setState(() {
                _isLoading = false;
              });
            },
            onContentSizeChanged: (controller, oldContentSize, newContentSize) {
              final nextHeight = newContentSize.height;
              if (!mounted || nextHeight <= 0) {
                return;
              }
              setState(() {
                _contentHeight = math.max(widget.minHeight, nextHeight);
              });
            },
            onReceivedError: (controller, request, error) {
              if (!mounted) return;
              setState(() {
                _isLoading = false;
              });
            },
            onReceivedHttpError: (controller, request, errorResponse) {
              if (!mounted) return;
              setState(() {
                _isLoading = false;
              });
            },
          ),
          if (_isLoading)
            Positioned.fill(
              child: ColoredBox(
                color: context.colorScheme.card,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(spacing.m),
                    child: const AxiProgressIndicator(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
