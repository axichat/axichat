// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

String _prepareEmailHtmlData(Map<String, Object> arguments) {
  final html = arguments['html']! as String;
  final allowRemoteImages = arguments['allowRemoteImages']! as bool;
  final themeStyle = arguments['themeStyle']! as String;
  final preparedHtml = HtmlContentCodec.prepareEmailHtmlForWebView(
    html,
    allowRemoteImages: allowRemoteImages,
  );
  return _injectEmailThemeStyle(preparedHtml, themeStyle);
}

String _injectEmailThemeStyle(String html, String themeStyle) {
  if (html.contains('</head>')) {
    return html.replaceFirst('</head>', '$themeStyle</head>');
  }
  return '$themeStyle$html';
}

String _emailWebViewCssColor(Color color) {
  final red = (color.r * 255.0).round().clamp(0, 255);
  final green = (color.g * 255.0).round().clamp(0, 255);
  final blue = (color.b * 255.0).round().clamp(0, 255);
  return 'rgba($red, $green, $blue, ${color.a.toStringAsFixed(3)})';
}

String _buildEmailWebViewThemeStyle({
  required Brightness brightness,
  required Color backgroundColor,
}) {
  final fallbackBackgroundColor = brightness == Brightness.dark
      ? const Color(0xFFFFFFFF)
      : backgroundColor;
  return '''
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style id="axichat-email-webview-theme">
html, body {
  background-color: ${_emailWebViewCssColor(fallbackBackgroundColor)} !important;
  box-sizing: border-box !important;
  margin: 0 !important;
  padding: 0 !important;
  width: 100% !important;
  max-width: 100% !important;
  overflow-x: hidden !important;
}
*, *::before, *::after {
  box-sizing: border-box !important;
  max-width: 100% !important;
}
body > *:first-child {
  margin-top: 0 !important;
}
body > *:last-child {
  margin-bottom: 0 !important;
}
img, table, iframe, pre, blockquote {
  max-width: 100% !important;
}
img, svg, video, canvas {
  height: auto !important;
}
table {
  width: 100% !important;
  table-layout: fixed !important;
}
pre, code, blockquote, td, th, div, p, span, a {
  overflow-wrap: anywhere !important;
  word-break: break-word !important;
}
</style>
''';
}

enum _EmailHtmlWebViewMode { embedded, scrollable }

class EmailHtmlWebView extends StatefulWidget {
  const EmailHtmlWebView.embedded({
    super.key,
    required this.html,
    required this.allowRemoteImages,
    required this.minHeight,
    required this.backgroundColor,
    required this.textColor,
    required this.linkColor,
    required this.onLinkTap,
    this.simplifyLayout = false,
    this.useHybridComposition = true,
  }) : _mode = _EmailHtmlWebViewMode.embedded,
       maxHeight = null;

  const EmailHtmlWebView.scrollable({
    super.key,
    required this.html,
    required this.allowRemoteImages,
    required this.maxHeight,
    required this.minHeight,
    required this.backgroundColor,
    required this.textColor,
    required this.linkColor,
    required this.onLinkTap,
    this.simplifyLayout = false,
    this.useHybridComposition = true,
  }) : _mode = _EmailHtmlWebViewMode.scrollable;

  final String html;
  final bool allowRemoteImages;
  final double? maxHeight;
  final double minHeight;
  final Color backgroundColor;
  final Color textColor;
  final Color linkColor;
  final ValueChanged<String> onLinkTap;
  final bool simplifyLayout;
  final bool useHybridComposition;
  final _EmailHtmlWebViewMode _mode;

  bool get _usesInternalScroll => _mode == _EmailHtmlWebViewMode.scrollable;

  @override
  State<EmailHtmlWebView> createState() => _EmailHtmlWebViewState();
}

class _EmailHtmlWebViewState extends State<EmailHtmlWebView> {
  static const _emailWebViewBaseUrl = 'https://axichat.invalid/';
  static const _linuxHeightHandlerName = 'axichatEmailHeight';
  static final Set<Factory<OneSequenceGestureRecognizer>>
  _tapOnlyGestureRecognizers = <Factory<OneSequenceGestureRecognizer>>{
    Factory<OneSequenceGestureRecognizer>(TapGestureRecognizer.new),
  };
  static final WebUri _emailWebViewUri = WebUri(_emailWebViewBaseUrl);

  InAppWebViewController? _controller;
  bool _isLoading = true;
  String? _preparedHtmlData;
  String? _preparedHtmlInputKey;
  double? _contentHeight;
  int _heightMeasurementEpoch = 0;
  bool _linuxHeightObserverInstalled = false;

  double get _resolvedHeight {
    final measuredHeight = _contentHeight;
    if (measuredHeight == null || measuredHeight <= 0) {
      return widget.minHeight;
    }
    if (!widget._usesInternalScroll) {
      return math.max(widget.minHeight, measuredHeight);
    }
    final maxHeight = widget.maxHeight;
    if (maxHeight == null || maxHeight < widget.minHeight) {
      return widget.minHeight;
    }
    return measuredHeight.clamp(widget.minHeight, maxHeight).toDouble();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshPreparedHtml(reload: _controller != null);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EmailHtmlWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html ||
        oldWidget.allowRemoteImages != widget.allowRemoteImages ||
        oldWidget.backgroundColor != widget.backgroundColor ||
        oldWidget.textColor != widget.textColor ||
        oldWidget.linkColor != widget.linkColor) {
      _preparedHtmlInputKey = null;
      _contentHeight = null;
      _linuxHeightObserverInstalled = false;
      _refreshPreparedHtml(reload: _controller != null);
    }
  }

  void _refreshPreparedHtml({required bool reload}) {
    final brightness = context.brightness;
    final inputKey = [
      widget.html.hashCode,
      widget.allowRemoteImages,
      brightness.name,
      widget.backgroundColor.toARGB32(),
    ].join(':');
    if (_preparedHtmlInputKey == inputKey) {
      return;
    }
    _preparedHtmlInputKey = inputKey;
    unawaited(
      _prepareHtmlData(
        inputKey: inputKey,
        reload: reload,
        brightness: brightness,
      ),
    );
  }

  Future<void> _prepareHtmlData({
    required String inputKey,
    required bool reload,
    required Brightness brightness,
  }) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        if (!reload) {
          _preparedHtmlData = null;
        }
        _contentHeight = null;
      });
    }
    _linuxHeightObserverInstalled = false;
    final themeStyle = _buildThemeStyle(brightness: brightness);
    String preparedHtmlData;
    try {
      preparedHtmlData = await compute(_prepareEmailHtmlData, {
        'html': widget.html,
        'allowRemoteImages': widget.allowRemoteImages,
        'themeStyle': themeStyle,
      });
    } on Exception {
      final fallbackHtml = HtmlContentCodec.prepareEmailHtmlForWebView(
        widget.html,
        allowRemoteImages: widget.allowRemoteImages,
      );
      preparedHtmlData = _injectEmailThemeStyle(fallbackHtml, themeStyle);
    }
    if (!mounted || _preparedHtmlInputKey != inputKey) {
      return;
    }
    _preparedHtmlData = preparedHtmlData;
    if (reload) {
      await _loadHtml();
      return;
    }
    setState(() {});
  }

  Future<void> _loadHtml() async {
    final controller = _controller;
    final preparedHtmlData = _preparedHtmlData;
    if (controller == null || preparedHtmlData == null) return;
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    await controller.loadData(
      data: preparedHtmlData,
      baseUrl: _emailWebViewUri,
      historyUrl: _emailWebViewUri,
    );
  }

  Future<void> _measureContentHeight() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final measuredHeight = defaultTargetPlatform == TargetPlatform.linux
        ? math.max(
            await _measureLinuxDomContentHeight(controller) ?? 0,
            await _measurePlatformContentHeight(controller) ?? 0,
          )
        : (await _measurePlatformContentHeight(controller) ?? 0);
    if (!mounted || measuredHeight <= 0) {
      return;
    }
    final normalizedHeight = measuredHeight.ceilToDouble();
    if (_contentHeight == normalizedHeight) {
      return;
    }
    setState(() {
      _contentHeight = normalizedHeight;
    });
  }

  void _scheduleContentHeightMeasurements() {
    final epoch = ++_heightMeasurementEpoch;

    Future<void> measureAfter(Duration delay) async {
      await Future<void>.delayed(delay);
      if (!mounted || epoch != _heightMeasurementEpoch) {
        return;
      }
      await _measureContentHeight();
    }

    unawaited(measureAfter(Duration.zero));
    unawaited(measureAfter(const Duration(milliseconds: 80)));
    unawaited(measureAfter(const Duration(milliseconds: 200)));
    unawaited(measureAfter(const Duration(milliseconds: 400)));
    if (defaultTargetPlatform == TargetPlatform.linux) {
      unawaited(measureAfter(const Duration(milliseconds: 800)));
      unawaited(measureAfter(const Duration(milliseconds: 1600)));
    }
  }

  void _updateContentHeight(double height) {
    if (!mounted || height <= 0) {
      return;
    }
    final normalizedHeight = height.ceilToDouble();
    if (_contentHeight == normalizedHeight) {
      return;
    }
    setState(() {
      _contentHeight = normalizedHeight;
    });
  }

  Future<double?> _measurePlatformContentHeight(
    InAppWebViewController controller,
  ) async {
    final rawHeight = await controller.getContentHeight();
    if (rawHeight == null || rawHeight <= 0) {
      return null;
    }
    var measuredHeight = rawHeight.toDouble();
    if (defaultTargetPlatform == TargetPlatform.android) {
      measuredHeight *= await controller.getZoomScale() ?? 1.0;
    }
    return measuredHeight > 0 ? measuredHeight : null;
  }

  Future<double?> _measureLinuxDomContentHeight(
    InAppWebViewController controller,
  ) async {
    try {
      final result = await controller.evaluateJavascript(
        source: '''
(() => {
  const body = document.body;
  const doc = document.documentElement;
  const scrolling = document.scrollingElement;
  const candidates = [
    body ? body.scrollHeight : 0,
    body ? body.offsetHeight : 0,
    body ? body.clientHeight : 0,
    doc ? doc.scrollHeight : 0,
    doc ? doc.offsetHeight : 0,
    doc ? doc.clientHeight : 0,
    scrolling ? scrolling.scrollHeight : 0,
    scrolling ? scrolling.offsetHeight : 0,
    scrolling ? scrolling.clientHeight : 0,
  ];
  if (body) {
    const range = document.createRange();
    range.selectNodeContents(body);
    const rangeRect = range.getBoundingClientRect();
    candidates.push(rangeRect.height);
    let maxBottom = 0;
    for (const element of body.querySelectorAll('*')) {
      const style = window.getComputedStyle(element);
      if (style.display === 'none' ||
          style.visibility === 'hidden' ||
          style.position === 'fixed') {
        continue;
      }
      const rect = element.getBoundingClientRect();
      if (Number.isFinite(rect.bottom)) {
        maxBottom = Math.max(maxBottom, rect.bottom + window.scrollY);
      }
    }
    candidates.push(maxBottom);
  }
  return Math.ceil(
    candidates.reduce(
      (maxHeight, candidate) => Math.max(
        maxHeight,
        Number.isFinite(candidate) ? candidate : 0,
      ),
      0,
    ),
  );
})()
''',
      );
      if (result is num) {
        return result > 0 ? result.toDouble() : null;
      }
      if (result is String) {
        final parsed = double.tryParse(result.trim());
        if (parsed != null && parsed > 0) {
          return parsed;
        }
      }
    } on Exception {
      return null;
    }
    return null;
  }

  Future<void> _installLinuxHeightObserver(
    InAppWebViewController controller,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.linux ||
        _linuxHeightObserverInstalled) {
      return;
    }
    try {
      await controller.evaluateJavascript(
        source: '''
(() => {
  if (window.__axichatEmailHeightObserverInstalled) {
    if (typeof window.__axichatEmailScheduleHeight === 'function') {
      window.__axichatEmailScheduleHeight();
    }
    return true;
  }

  const body = document.body;
  const doc = document.documentElement;
  const scrolling = document.scrollingElement;

  const reportHeight = () => {
    const candidates = [
      body ? body.scrollHeight : 0,
      body ? body.offsetHeight : 0,
      body ? body.clientHeight : 0,
      doc ? doc.scrollHeight : 0,
      doc ? doc.offsetHeight : 0,
      doc ? doc.clientHeight : 0,
      scrolling ? scrolling.scrollHeight : 0,
      scrolling ? scrolling.offsetHeight : 0,
      scrolling ? scrolling.clientHeight : 0,
    ];
    if (body) {
      const range = document.createRange();
      range.selectNodeContents(body);
      const rangeRect = range.getBoundingClientRect();
      candidates.push(rangeRect.height);
      let maxBottom = 0;
      for (const element of body.querySelectorAll('*')) {
        const style = window.getComputedStyle(element);
        if (style.display === 'none' ||
            style.visibility === 'hidden' ||
            style.position === 'fixed') {
          continue;
        }
        const rect = element.getBoundingClientRect();
        if (Number.isFinite(rect.bottom)) {
          maxBottom = Math.max(maxBottom, rect.bottom + window.scrollY);
        }
      }
      candidates.push(maxBottom);
    }
    const height = Math.ceil(
      candidates.reduce(
        (maxHeight, candidate) => Math.max(
          maxHeight,
          Number.isFinite(candidate) ? candidate : 0,
        ),
        0,
      ),
    );
    if (height > 0 && window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('axichatEmailHeight', height);
    }
    return height;
  };

  let frame = 0;
  const schedule = () => {
    if (frame) {
      return;
    }
    frame = window.requestAnimationFrame(() => {
      frame = 0;
      reportHeight();
    });
  };

  window.__axichatEmailHeightObserverInstalled = true;
  window.__axichatEmailReportHeight = reportHeight;
  window.__axichatEmailScheduleHeight = schedule;

  window.addEventListener('load', schedule, { passive: true });
  window.addEventListener('resize', schedule, { passive: true });

  const mutationObserver = new MutationObserver(schedule);
  mutationObserver.observe(document.documentElement, {
    childList: true,
    subtree: true,
    characterData: true,
    attributes: true,
  });

  if (window.ResizeObserver) {
    const resizeObserver = new ResizeObserver(schedule);
    if (doc) {
      resizeObserver.observe(doc);
    }
    if (body) {
      resizeObserver.observe(body);
    }
  }

  if (document.fonts && document.fonts.ready) {
    document.fonts.ready.then(schedule).catch(() => {});
  }

  for (const image of document.images) {
    if (!image.complete) {
      image.addEventListener('load', schedule, { passive: true });
      image.addEventListener('error', schedule, { passive: true });
    }
  }

  schedule();
  window.setTimeout(schedule, 100);
  window.setTimeout(schedule, 300);
  window.setTimeout(schedule, 1000);
  return true;
})()
''',
      );
      _linuxHeightObserverInstalled = true;
    } on Exception {
      _linuxHeightObserverInstalled = false;
    }
  }

  String _buildThemeStyle({required Brightness brightness}) {
    return _buildEmailWebViewThemeStyle(
      brightness: brightness,
      backgroundColor: widget.backgroundColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return SizedBox(
      width: double.infinity,
      height: _resolvedHeight,
      child: Stack(
        children: [
          if (_preparedHtmlData != null)
            InAppWebView(
              gestureRecognizers: !widget._usesInternalScroll
                  ? _tapOnlyGestureRecognizers
                  : null,
              initialData: InAppWebViewInitialData(
                data: _preparedHtmlData!,
                baseUrl: _emailWebViewUri,
                historyUrl: _emailWebViewUri,
              ),
              initialSettings: InAppWebViewSettings(
                // Linux height measurement is driven from the page DOM.
                javaScriptEnabled:
                    defaultTargetPlatform == TargetPlatform.linux,
                javaScriptCanOpenWindowsAutomatically: false,
                supportMultipleWindows: false,
                allowContentAccess: false,
                allowFileAccess: false,
                allowFileAccessFromFileURLs: false,
                allowUniversalAccessFromFileURLs: false,
                mediaPlaybackRequiresUserGesture: true,
                safeBrowsingEnabled: true,
                transparentBackground: true,
                useShouldOverrideUrlLoading: true,
                useHybridComposition: widget.useHybridComposition,
                supportZoom: true,
                useWideViewPort: false,
                loadWithOverviewMode: false,
                layoutAlgorithm: widget.simplifyLayout
                    ? LayoutAlgorithm.TEXT_AUTOSIZING
                    : LayoutAlgorithm.NORMAL,
                initialScale: 100,
                textZoom: widget.simplifyLayout ? 125 : 100,
                minimumFontSize: widget.simplifyLayout ? 17 : 14,
                minimumLogicalFontSize: widget.simplifyLayout ? 17 : 14,
                preferredContentMode: UserPreferredContentMode.MOBILE,
                disableVerticalScroll: !widget._usesInternalScroll,
                disableHorizontalScroll: !widget._usesInternalScroll,
                verticalScrollBarEnabled: widget._usesInternalScroll,
                horizontalScrollBarEnabled: widget._usesInternalScroll,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
                if (defaultTargetPlatform == TargetPlatform.linux) {
                  controller.addJavaScriptHandler(
                    handlerName: _linuxHeightHandlerName,
                    callback: (arguments) {
                      if (arguments.isEmpty) {
                        return null;
                      }
                      final value = arguments.first;
                      if (value is num) {
                        _updateContentHeight(value.toDouble());
                      } else if (value is String) {
                        final parsed = double.tryParse(value.trim());
                        if (parsed != null) {
                          _updateContentHeight(parsed);
                        }
                      }
                      return null;
                    },
                  );
                }
              },
              onContentSizeChanged:
                  (controller, oldContentSize, newContentSize) {
                    _updateContentHeight(newContentSize.height);
                    _scheduleContentHeightMeasurements();
                  },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final url =
                    navigationAction.request.url?.toString().trim() ?? '';
                if (url.isEmpty ||
                    url == 'about:blank' ||
                    url.startsWith(_emailWebViewBaseUrl)) {
                  return NavigationActionPolicy.ALLOW;
                }
                widget.onLinkTap(url);
                return NavigationActionPolicy.CANCEL;
              },
              onLoadStop: (controller, url) async {
                await _installLinuxHeightObserver(controller);
                await _measureContentHeight();
                _scheduleContentHeightMeasurements();
                if (!mounted) return;
                setState(() {
                  _isLoading = false;
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
          if (_isLoading || _preparedHtmlData == null)
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
