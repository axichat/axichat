// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

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
  if (preparedHtml.contains('</head>')) {
    return preparedHtml.replaceFirst('</head>', '$themeStyle</head>');
  }
  return '$themeStyle$preparedHtml';
}

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
  final bool clampHeightToMax;
  final bool disableInternalScroll;
  final bool simplifyLayout;
  final bool useHybridComposition;

  @override
  State<EmailHtmlWebView> createState() => _EmailHtmlWebViewState();
}

class _EmailHtmlWebViewState extends State<EmailHtmlWebView> {
  static const _emailWebViewBaseUrl = 'https://axichat.invalid/';
  static final Set<Factory<OneSequenceGestureRecognizer>>
  _webViewGestureRecognizers = <Factory<OneSequenceGestureRecognizer>>{
    Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
  };
  static final WebUri _emailWebViewUri = WebUri(_emailWebViewBaseUrl);

  InAppWebViewController? _controller;
  bool _isLoading = true;
  String? _preparedHtmlData;
  String? _preparedHtmlInputKey;

  double get _resolvedHeight {
    if (widget.maxHeight < widget.minHeight) {
      return widget.minHeight;
    }
    return widget.maxHeight;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshPreparedHtml(reload: _controller != null);
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
      });
    }
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
      preparedHtmlData = '$themeStyle$fallbackHtml';
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

  String _buildThemeStyle({required Brightness brightness}) {
    final fallbackBackgroundColor = brightness == Brightness.dark
        ? const Color(0xFFFFFFFF)
        : widget.backgroundColor;
    return '''
<style id="axichat-email-webview-theme">
html, body {
  background-color: ${_cssColor(fallbackBackgroundColor)} !important;
}
</style>
''';
  }

  String _cssColor(Color color) {
    final red = (color.r * 255.0).round().clamp(0, 255);
    final green = (color.g * 255.0).round().clamp(0, 255);
    final blue = (color.b * 255.0).round().clamp(0, 255);
    return 'rgba($red, $green, $blue, ${color.a.toStringAsFixed(3)})';
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
              gestureRecognizers: _webViewGestureRecognizers,
              initialData: InAppWebViewInitialData(
                data: _preparedHtmlData!,
                baseUrl: _emailWebViewUri,
                historyUrl: _emailWebViewUri,
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: false,
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
                useWideViewPort: true,
                loadWithOverviewMode: false,
                layoutAlgorithm: null,
                initialScale: 100,
                textZoom: widget.simplifyLayout ? 140 : 100,
                minimumFontSize: widget.simplifyLayout ? 17 : 14,
                minimumLogicalFontSize: widget.simplifyLayout ? 17 : 14,
                preferredContentMode: UserPreferredContentMode.MOBILE,
                disableVerticalScroll: widget.disableInternalScroll,
                disableHorizontalScroll: widget.disableInternalScroll,
                verticalScrollBarEnabled: !widget.disableInternalScroll,
                horizontalScrollBarEnabled: !widget.disableInternalScroll,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
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
