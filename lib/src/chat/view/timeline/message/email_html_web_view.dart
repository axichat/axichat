// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
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
  static final Set<Factory<OneSequenceGestureRecognizer>>
  _tapOnlyGestureRecognizers = <Factory<OneSequenceGestureRecognizer>>{
    Factory<OneSequenceGestureRecognizer>(TapGestureRecognizer.new),
  };
  static final WebUri _emailWebViewUri = WebUri(_emailWebViewBaseUrl);

  InAppWebViewController? _controller;
  dynamic _desktopWebview;
  bool _isLoading = true;
  bool _isOpeningDesktopWebview = false;
  String? _preparedHtmlData;
  String? _preparedHtmlInputKey;
  double? _contentHeight;

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
    final desktopWebview = _desktopWebview;
    if (desktopWebview != null) {
      try {
        desktopWebview.close();
      } on Exception {
        // Ignore close errors, especially when the window has already been closed.
      }
    }
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
    if (defaultTargetPlatform == TargetPlatform.linux) {
      _isLoading = false;
    }
    setState(() {});
  }

  Future<void> _openDesktopWebview() async {
    final preparedHtmlData = _preparedHtmlData;
    if (preparedHtmlData == null || _isOpeningDesktopWebview) {
      return;
    }
    _isOpeningDesktopWebview = true;
    if (mounted) {
      setState(() {});
    }

    try {
      final desktopWebview = await WebviewWindow.create();
      _desktopWebview = desktopWebview;
      final normalizedIdentifier =
          (_preparedHtmlInputKey ?? widget.html.hashCode.toString())
              .replaceAll(' ', '_')
              .replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_');
      final safeIdentifier = normalizedIdentifier.length > 128
          ? normalizedIdentifier.substring(0, 128)
          : normalizedIdentifier;
      final fileName = 'axichat-email-webview-$safeIdentifier.html';
      final htmlFile = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName',
      );
      await htmlFile.writeAsString(
        preparedHtmlData,
        encoding: convert.utf8,
      );
      desktopWebview.onClose.whenComplete(() {
        if (!mounted) {
          if (identical(_desktopWebview, desktopWebview)) {
            _desktopWebview = null;
          }
          return;
        }
        if (identical(_desktopWebview, desktopWebview)) {
          setState(() {
            _desktopWebview = null;
          });
        }
      });
      desktopWebview.launch(htmlFile.uri.toString());
    } on Exception {
      _desktopWebview = null;
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningDesktopWebview = false;
        });
      }
    }
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
    final rawHeight = await controller.getContentHeight();
    if (!mounted || rawHeight == null || rawHeight <= 0) {
      return;
    }
    var measuredHeight = rawHeight.toDouble();
    if (defaultTargetPlatform == TargetPlatform.android) {
      measuredHeight *= await controller.getZoomScale() ?? 1.0;
    }
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

    if (defaultTargetPlatform == TargetPlatform.linux) {
      final isLoading = _isLoading || _preparedHtmlData == null;
      final isLaunching = _isOpeningDesktopWebview;
      return SizedBox(
        width: double.infinity,
        height: _resolvedHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: context.colorScheme.card,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(spacing.m),
                    child: isLoading
                        ? const AxiProgressIndicator()
                        : AxiButton.outline(
                            onPressed: isLaunching ? null : _openDesktopWebview,
                            child: Text(
                              isLaunching
                                  ? 'Opening email preview'
                                  : 'Open email preview',
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

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
              },
              onContentSizeChanged:
                  (controller, oldContentSize, newContentSize) {
                    _updateContentHeight(newContentSize.height);
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
                await _measureContentHeight();
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
