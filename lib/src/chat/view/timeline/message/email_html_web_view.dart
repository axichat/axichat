// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/email_html_logging.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/common/url_safety.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

const String _emailScaleRootId = 'axichat-original-email-scale-root';
const String _emailScaleRootAttributeName =
    'data-axichat-original-email-scale-root';
const String _emailScaleRootOpenTag =
    '<div id="$_emailScaleRootId" $_emailScaleRootAttributeName="true" '
    'style="transform-origin: top left; display: block;">';
final RegExp _originalPassiveRemoteUrlPattern = RegExp(
  r'''(?:(?:https?:)?//)[^\s"'<>),;]+''',
  caseSensitive: false,
);
final RegExp _originalPassiveCssRemoteUrlPattern = RegExp(
  r'''url\(\s*(?:"|')?(?:https?:)?//[^)"']+(?:"|')?\s*\)''',
  caseSensitive: false,
);
final RegExp _originalPassiveCssRemoteImportPattern = RegExp(
  r'''@import\b[^;{}]*(?:(?:https?:)?//|url\(\s*(?:"|')?(?:https?:)?//)[^;{}]*;?''',
  caseSensitive: false,
);
final RegExp _originalPassiveTrackerImagePattern = RegExp(
  r'(?:beacon|pixel|spacer|tracking)',
  caseSensitive: false,
);
String _prepareEmailHtmlData(Map<String, Object> arguments) {
  final html = arguments['html']! as String;
  final allowRemoteImages = arguments['allowRemoteImages']! as bool;
  final themeStyle = arguments['themeStyle']! as String;
  final contentMode = EmailHtmlContentMode.values.byName(
    arguments['contentMode']! as String,
  );
  return prepareEmailHtmlDataForWebView(
    html: html,
    allowRemoteImages: allowRemoteImages,
    themeStyle: themeStyle,
    contentMode: contentMode,
  );
}

String buildEmailHtmlDataForWebView({
  required String html,
  required bool allowRemoteImages,
  required String themeStyle,
  required EmailHtmlContentMode contentMode,
}) {
  if (contentMode == EmailHtmlContentMode.originalPassive) {
    return _buildOriginalPassiveEmailHtmlShell(
      html: html,
      allowRemoteImages: allowRemoteImages,
      themeStyle: themeStyle,
    );
  }
  final preparedHtml = HtmlContentCodec.prepareEmailHtmlForWebView(
    html,
    allowRemoteImages: allowRemoteImages,
  );
  return _wrapEmailHtmlScaleRoot(
    _injectEmailThemeStyle(preparedHtml, themeStyle),
  );
}

@visibleForTesting
String prepareEmailHtmlDataForWebView({
  required String html,
  required bool allowRemoteImages,
  required String themeStyle,
  required EmailHtmlContentMode contentMode,
}) => buildEmailHtmlDataForWebView(
  html: html,
  allowRemoteImages: allowRemoteImages,
  themeStyle: themeStyle,
  contentMode: contentMode,
);

String _injectEmailThemeStyle(String html, String themeStyle) {
  final headClose = RegExp(
    r'</head\s*>',
    caseSensitive: false,
  ).firstMatch(html);
  if (headClose != null) {
    return html.replaceRange(headClose.start, headClose.start, themeStyle);
  }
  final headOpen = RegExp(
    r'<head\b[^>]*>',
    caseSensitive: false,
  ).firstMatch(html);
  if (headOpen != null) {
    return html.replaceRange(headOpen.end, headOpen.end, themeStyle);
  }
  return '$themeStyle$html';
}

String _wrapEmailHtmlScaleRoot(String html) {
  final bodyOpen = RegExp(
    r'<body\b[^>]*>',
    caseSensitive: false,
  ).firstMatch(html);
  final bodyCloseMatches = RegExp(
    r'</body\s*>',
    caseSensitive: false,
  ).allMatches(html).toList();
  if (bodyOpen == null || bodyCloseMatches.isEmpty) {
    return '$_emailScaleRootOpenTag$html</div>';
  }
  final bodyClose = bodyCloseMatches.last;
  if (bodyClose.start < bodyOpen.end) {
    return '$_emailScaleRootOpenTag$html</div>';
  }
  final bodyTag = bodyOpen.group(0) ?? '';
  if (bodyTag.toLowerCase().contains(_emailScaleRootAttributeName) ||
      html.contains('id="$_emailScaleRootId"') ||
      html.contains("id='$_emailScaleRootId'")) {
    return html;
  }
  return html.replaceRange(
    bodyOpen.end - 1,
    bodyOpen.end - 1,
    ' $_emailScaleRootAttributeName="true"',
  );
}

String _inlineJsonString(String value) => jsonEncode(value)
    .replaceAll('<', r'\u003C')
    .replaceAll('>', r'\u003E')
    .replaceAll('&', r'\u0026');

String _preSanitizeOriginalPassiveEmailHtml({
  required String html,
  required bool allowRemoteImages,
}) {
  if (allowRemoteImages) {
    return html;
  }
  try {
    final document = html_parser.parse(html);
    _stripOriginalPassiveRemoteImageLoads(document);
    _stripOriginalPassiveRemoteStyleLoads(document);
    _stripOriginalPassiveRefreshRedirects(document);
    _stripOriginalPassiveRemoteResourceAttributes(document);
    return document.outerHtml;
  } on Exception {
    return html.replaceAll(
      _originalPassiveRemoteUrlPattern,
      HtmlContentCodec.blockedRemoteEmailImagePlaceholderDataUri,
    );
  }
}

void _stripOriginalPassiveRemoteImageLoads(dom.Document document) {
  for (final image in document.querySelectorAll('img').toList()) {
    image.attributes.remove('srcset');
    final source = image.attributes['src'];
    if (!_isOriginalPassiveRemoteResource(source)) {
      continue;
    }
    if (_isOriginalPassiveTrackerOrSpacerImage(image)) {
      image.remove();
      continue;
    }
    image.attributes['src'] =
        HtmlContentCodec.blockedRemoteEmailImagePlaceholderDataUri;
  }
  for (final source in document.querySelectorAll('source').toList()) {
    final srcset = source.attributes['srcset'];
    if (srcset == null || !_containsOriginalPassiveRemoteResource(srcset)) {
      continue;
    }
    source.attributes.remove('srcset');
  }
}

void _stripOriginalPassiveRemoteStyleLoads(dom.Document document) {
  for (final style in document.querySelectorAll('style').toList()) {
    final sanitized = _stripOriginalPassiveRemoteCssLoads(style.text);
    if (sanitized.trim().isEmpty) {
      style.remove();
      continue;
    }
    style.text = sanitized;
  }
  for (final element in document.querySelectorAll('[style]')) {
    final style = element.attributes['style'];
    if (style == null) {
      continue;
    }
    final sanitized = _stripOriginalPassiveRemoteCssLoads(style);
    if (sanitized.trim().isEmpty) {
      element.attributes.remove('style');
      continue;
    }
    element.attributes['style'] = sanitized;
  }
}

void _stripOriginalPassiveRefreshRedirects(dom.Document document) {
  for (final meta in document.querySelectorAll('meta').toList()) {
    if (_isOriginalPassiveRefreshMeta(meta)) {
      meta.remove();
    }
  }
}

void _stripOriginalPassiveRemoteResourceAttributes(dom.Document document) {
  for (final element in document.querySelectorAll('*')) {
    final tag = (element.localName ?? '').toLowerCase();
    for (final entry in element.attributes.entries.toList()) {
      final name = entry.key.toString().trim().toLowerCase();
      if (name == 'srcdoc') {
        element.attributes.remove(entry.key);
        continue;
      }
      if (name == 'src' &&
          tag != 'img' &&
          _isOriginalPassiveRemoteResource(entry.value)) {
        element.attributes.remove(entry.key);
        continue;
      }
      if (name == 'href' &&
          tag == 'link' &&
          _isOriginalPassiveRemoteResource(entry.value)) {
        element.attributes.remove(entry.key);
        continue;
      }
      if (name == 'srcset') {
        if (_containsOriginalPassiveRemoteResource(entry.value)) {
          element.attributes.remove(entry.key);
        }
        continue;
      }
      if (name == 'data' &&
          tag == 'object' &&
          _isOriginalPassiveRemoteResource(entry.value)) {
        element.attributes.remove(entry.key);
        continue;
      }
      if (const <String>{'background', 'poster'}.contains(name) &&
          _isOriginalPassiveRemoteResource(entry.value)) {
        element.attributes.remove(entry.key);
      }
    }
  }
}

bool _isOriginalPassiveRefreshMeta(dom.Element element) {
  final tag = (element.localName ?? '').toLowerCase();
  if (tag != 'meta') {
    return false;
  }
  for (final entry in element.attributes.entries) {
    final name = entry.key.toString().trim().toLowerCase();
    if (name != 'http-equiv') {
      continue;
    }
    return entry.value.trim().toLowerCase() == 'refresh';
  }
  return false;
}

String _stripOriginalPassiveRemoteCssLoads(String css) {
  return css
      .replaceAll(_originalPassiveCssRemoteImportPattern, '')
      .replaceAll(_originalPassiveCssRemoteUrlPattern, 'none');
}

bool _containsOriginalPassiveRemoteResource(String value) =>
    _originalPassiveRemoteUrlPattern.hasMatch(value);

bool _isOriginalPassiveRemoteResource(String? value) {
  final source = value?.trim();
  if (source == null || source.isEmpty) {
    return false;
  }
  return source.startsWith('//') ||
      source.toLowerCase().startsWith('http://') ||
      source.toLowerCase().startsWith('https://');
}

bool _isOriginalPassiveTrackerOrSpacerImage(dom.Element image) {
  final width = double.tryParse(image.attributes['width']?.trim() ?? '');
  final height = double.tryParse(image.attributes['height']?.trim() ?? '');
  if (width != null &&
      height != null &&
      width > 0 &&
      height > 0 &&
      width <= 1 &&
      height <= 1) {
    return true;
  }
  return _originalPassiveTrackerImagePattern.hasMatch(
    image.attributes['src'] ?? '',
  );
}

String _emailRenderedDomExpression() => '''
(() => {
  const root = document.documentElement;
  return root ? root.outerHTML : '';
})()
''';

@visibleForTesting
String emailRenderedDomExpressionForTesting() => _emailRenderedDomExpression();

String? _safeEmailLinkUrl(String value) {
  final report = assessLinkSafety(raw: value, kind: LinkSafetyKind.message);
  return report == null || !report.isSafe ? null : report.displayUri;
}

@visibleForTesting
String? safeEmailLinkUrlForTesting(String value) => _safeEmailLinkUrl(value);

({
  double? measuredHeight,
  double? scrollHeight,
  double? viewportHeight,
  double? contentWidth,
  double? viewportWidth,
  double? widthScale,
  int pendingImages,
  bool documentReady,
  bool imagesReady,
  bool fontsReady,
  bool widthFitReady,
  bool layoutStable,
  int layoutSequence,
})
_emailDomContentHeightMetrics({
  double? measuredHeight,
  double? scrollHeight,
  double? viewportHeight,
  double? contentWidth,
  double? viewportWidth,
  double? widthScale,
  int pendingImages = 0,
  bool documentReady = false,
  bool imagesReady = false,
  bool fontsReady = false,
  bool widthFitReady = false,
  bool layoutStable = false,
  int layoutSequence = 0,
}) => (
  measuredHeight: measuredHeight,
  scrollHeight: scrollHeight,
  viewportHeight: viewportHeight,
  contentWidth: contentWidth,
  viewportWidth: viewportWidth,
  widthScale: widthScale,
  pendingImages: pendingImages,
  documentReady: documentReady,
  imagesReady: imagesReady,
  fontsReady: fontsReady,
  widthFitReady: widthFitReady,
  layoutStable: layoutStable,
  layoutSequence: layoutSequence,
);

bool _emailHtmlHeightCanCommit({
  required bool hasPositiveHeight,
  required bool usesPlatformFallback,
  required bool documentReady,
  required bool imagesReady,
  required bool widthFitReady,
  required bool layoutStable,
}) {
  if (!hasPositiveHeight) {
    return false;
  }
  if (usesPlatformFallback) {
    return true;
  }
  return documentReady && imagesReady && widthFitReady && layoutStable;
}

@visibleForTesting
bool emailHtmlHeightCanCommitForTesting({
  required bool hasPositiveHeight,
  required bool usesPlatformFallback,
  required bool documentReady,
  required bool imagesReady,
  required bool widthFitReady,
  required bool layoutStable,
}) => _emailHtmlHeightCanCommit(
  hasPositiveHeight: hasPositiveHeight,
  usesPlatformFallback: usesPlatformFallback,
  documentReady: documentReady,
  imagesReady: imagesReady,
  widthFitReady: widthFitReady,
  layoutStable: layoutStable,
);

enum _EmailHtmlWebViewLoadingPhase {
  loading,
  preservingFallback,
  fixedHeight,
  fixedPlaceholder,
}

_EmailHtmlWebViewLoadingPhase _resolveEmailHtmlWebViewLoadingPhase({
  required bool hasLoadingFallback,
  required bool hasPreparedHtmlData,
  required bool hasContentHeight,
  required bool isLoading,
}) {
  if (isLoading || !hasPreparedHtmlData) {
    return _EmailHtmlWebViewLoadingPhase.loading;
  }
  if (hasContentHeight) {
    return _EmailHtmlWebViewLoadingPhase.fixedHeight;
  }
  if (hasLoadingFallback) {
    return _EmailHtmlWebViewLoadingPhase.preservingFallback;
  }
  return _EmailHtmlWebViewLoadingPhase.fixedPlaceholder;
}

({
  String phase,
  bool showLoadingOverlay,
  bool paintLoadingFallback,
  bool preserveLoadingFallback,
  bool paintWebView,
  bool preserveWebView,
  bool useFixedHeight,
  bool preserveMeasuredHeight,
})
_resolveEmailHtmlWebViewLoadingLayout({
  required bool hasLoadingFallback,
  required bool hasWebView,
  required bool hasPreparedHtmlData,
  required bool hasContentHeight,
  required bool isLoading,
}) {
  final phase = _resolveEmailHtmlWebViewLoadingPhase(
    hasLoadingFallback: hasLoadingFallback,
    hasPreparedHtmlData: hasPreparedHtmlData,
    hasContentHeight: hasContentHeight,
    isLoading: isLoading,
  );
  final showLoadingOverlay = phase == _EmailHtmlWebViewLoadingPhase.loading;
  return (
    phase: phase.name,
    showLoadingOverlay: showLoadingOverlay,
    paintLoadingFallback: hasLoadingFallback && showLoadingOverlay,
    preserveLoadingFallback:
        hasLoadingFallback &&
        phase == _EmailHtmlWebViewLoadingPhase.preservingFallback,
    paintWebView: hasWebView && !showLoadingOverlay,
    preserveWebView: hasWebView && showLoadingOverlay,
    useFixedHeight: hasContentHeight || !hasLoadingFallback,
    preserveMeasuredHeight:
        hasLoadingFallback && hasContentHeight && showLoadingOverlay,
  );
}

bool _emailHtmlWebViewShouldPreserveMeasuredHeightForUpdate({
  required bool hasController,
  required bool hasMeasuredHeight,
  required bool htmlChanged,
  required bool modeChanged,
  required bool simplifyLayoutChanged,
  required bool baseFontSizeChanged,
}) =>
    hasController &&
    hasMeasuredHeight &&
    !htmlChanged &&
    !modeChanged &&
    !simplifyLayoutChanged &&
    !baseFontSizeChanged;

bool _emailHtmlWebViewShouldResetControllerForUpdate({
  required bool modeChanged,
  required bool simplifyLayoutChanged,
  required bool hybridCompositionChanged,
}) => modeChanged || simplifyLayoutChanged || hybridCompositionChanged;

@visibleForTesting
bool emailHtmlWebViewShouldPreserveMeasuredHeightForUpdateForTesting({
  required bool hasController,
  required bool hasMeasuredHeight,
  required bool htmlChanged,
  required bool modeChanged,
  required bool simplifyLayoutChanged,
  required bool baseFontSizeChanged,
}) => _emailHtmlWebViewShouldPreserveMeasuredHeightForUpdate(
  hasController: hasController,
  hasMeasuredHeight: hasMeasuredHeight,
  htmlChanged: htmlChanged,
  modeChanged: modeChanged,
  simplifyLayoutChanged: simplifyLayoutChanged,
  baseFontSizeChanged: baseFontSizeChanged,
);

@visibleForTesting
bool emailHtmlWebViewShouldResetControllerForUpdateForTesting({
  required bool modeChanged,
  required bool simplifyLayoutChanged,
  required bool hybridCompositionChanged,
}) => _emailHtmlWebViewShouldResetControllerForUpdate(
  modeChanged: modeChanged,
  simplifyLayoutChanged: simplifyLayoutChanged,
  hybridCompositionChanged: hybridCompositionChanged,
);

@visibleForTesting
({
  String phase,
  bool showLoadingOverlay,
  bool paintLoadingFallback,
  bool preserveLoadingFallback,
  bool paintWebView,
  bool preserveWebView,
  bool useFixedHeight,
  bool preserveMeasuredHeight,
})
emailHtmlWebViewLoadingLayoutForTesting({
  required bool hasLoadingFallback,
  required bool hasWebView,
  required bool hasPreparedHtmlData,
  required bool hasContentHeight,
  required bool isLoading,
}) => _resolveEmailHtmlWebViewLoadingLayout(
  hasLoadingFallback: hasLoadingFallback,
  hasWebView: hasWebView,
  hasPreparedHtmlData: hasPreparedHtmlData,
  hasContentHeight: hasContentHeight,
  isLoading: isLoading,
);

({bool includeWebView, bool visible, bool maintainState})
_resolveEmailHtmlWebViewVisibility({
  required bool hasWebView,
  required bool paintWebView,
  bool paintContent = true,
}) => (
  includeWebView: hasWebView,
  visible: hasWebView && paintWebView && paintContent,
  maintainState: hasWebView,
);

@visibleForTesting
({bool includeWebView, bool visible, bool maintainState})
emailHtmlWebViewVisibilityForTesting({
  required bool hasWebView,
  required bool paintWebView,
  bool paintContent = true,
}) => _resolveEmailHtmlWebViewVisibility(
  hasWebView: hasWebView,
  paintWebView: paintWebView,
  paintContent: paintContent,
);

bool _emailHtmlWebViewShouldScheduleLoadMeasurements({
  required int webViewGeneration,
  required int loadEpoch,
  required int? scheduledWebViewGeneration,
  required int? scheduledLoadEpoch,
}) {
  return scheduledWebViewGeneration != webViewGeneration ||
      scheduledLoadEpoch != loadEpoch;
}

@visibleForTesting
bool emailHtmlWebViewShouldScheduleLoadMeasurementsForTesting({
  required int webViewGeneration,
  required int loadEpoch,
  required int? scheduledWebViewGeneration,
  required int? scheduledLoadEpoch,
}) => _emailHtmlWebViewShouldScheduleLoadMeasurements(
  webViewGeneration: webViewGeneration,
  loadEpoch: loadEpoch,
  scheduledWebViewGeneration: scheduledWebViewGeneration,
  scheduledLoadEpoch: scheduledLoadEpoch,
);

({double? contentHeight, bool isLoading, bool committed})
_resolveEmailHtmlContentHeightAfterReport({
  required double? currentContentHeight,
  required bool isLoading,
  required bool usesHeightBridge,
  required double reportedHeight,
  required bool canCommitHeight,
}) {
  if (reportedHeight <= 0) {
    return (
      contentHeight: currentContentHeight,
      isLoading: isLoading,
      committed: false,
    );
  }
  if (usesHeightBridge && !canCommitHeight) {
    return (
      contentHeight: currentContentHeight,
      isLoading: isLoading,
      committed: false,
    );
  }
  final normalizedHeight = reportedHeight.ceilToDouble();
  final heightChanged = currentContentHeight != normalizedHeight;
  if (!heightChanged && !isLoading) {
    return (
      contentHeight: currentContentHeight,
      isLoading: isLoading,
      committed: false,
    );
  }
  return (contentHeight: normalizedHeight, isLoading: false, committed: true);
}

@visibleForTesting
({double? contentHeight, bool isLoading, bool committed})
emailHtmlContentHeightAfterReportForTesting({
  required double? currentContentHeight,
  required bool isLoading,
  required bool usesHeightBridge,
  required double reportedHeight,
  required bool canCommitHeight,
}) => _resolveEmailHtmlContentHeightAfterReport(
  currentContentHeight: currentContentHeight,
  isLoading: isLoading,
  usesHeightBridge: usesHeightBridge,
  reportedHeight: reportedHeight,
  canCommitHeight: canCommitHeight,
);

String _emailDomHeightMetricsExpression() => r'''(() => {
  const emptyMetrics = () => ({
    measuredHeight: 0,
    scrollHeight: 0,
    viewportHeight: 0,
    contentWidth: 0,
    viewportWidth: 0,
    widthScale: 1,
    pendingImages: 0,
    documentReady: false,
    imagesReady: false,
    fontsReady: false,
    widthFitReady: false,
    layoutStable: false,
    layoutSequence: 0,
  });
  const frame = document.getElementById('axichat-original-email-frame');
  if (frame && (!frame.contentDocument || !frame.contentDocument.body)) {
    return emptyMetrics();
  }
  if (frame && !frame.contentDocument.__axichatViewportNormalized) {
    return emptyMetrics();
  }
  const sourceDocument = frame ? frame.contentDocument : document;
  const sourceWindow = sourceDocument === document ? window : frame.contentWindow;
  const body = sourceDocument.body;
  if (!body) {
    return emptyMetrics();
  }
  const root = sourceDocument.documentElement;
  const layoutSequence = Math.ceil(
    Number(sourceDocument.__axichatEmailLayoutSequence || 0),
  );
  const widthFitRoot =
    sourceDocument.querySelector('[data-axichat-original-email-scale-root="true"]') ||
    sourceDocument.getElementById('axichat-original-email-scale-root');
  let widthFitReady = !widthFitRoot;
  if (frame && sourceDocument !== document) {
    frame.style.height = '';
    if (document.body) {
      document.body.style.minHeight = '';
    }
  }
  if (widthFitRoot) {
    widthFitRoot.style.removeProperty('transform');
    widthFitRoot.style.removeProperty('width');
    widthFitRoot.style.removeProperty('max-width');
    widthFitRoot.style.removeProperty('will-change');
  }
  const frameRect = frame && frame.getBoundingClientRect
    ? frame.getBoundingClientRect()
    : null;
  const firstPositiveWidth = (values) => {
    for (const value of values) {
      if (Number.isFinite(value) && value > 0) {
        return value;
      }
    }
    return 0;
  };
  const viewportWidth = Math.ceil(
    firstPositiveWidth([
      frameRect ? frameRect.width : 0,
      sourceWindow && sourceWindow.visualViewport
        ? sourceWindow.visualViewport.width || 0
        : 0,
      sourceWindow ? sourceWindow.innerWidth || 0 : 0,
      root ? root.clientWidth || 0 : 0,
      body.clientWidth || 0,
    ]),
  );
  const contentWidth = Math.ceil(
    Math.max(
      widthFitRoot ? widthFitRoot.scrollWidth || 0 : 0,
      widthFitRoot ? widthFitRoot.offsetWidth || 0 : 0,
      body.scrollWidth || 0,
      body.offsetWidth || 0,
      root ? root.scrollWidth || 0 : 0,
      root ? root.offsetWidth || 0 : 0,
    ),
  );
  const widthScale = widthFitRoot && viewportWidth > 0 && contentWidth > viewportWidth
    ? Math.max(viewportWidth / contentWidth, 0.01)
    : 1;
  if (widthFitRoot) {
    widthFitRoot.style.transformOrigin = 'top left';
    widthFitRoot.style.display = 'block';
    if (widthScale < 1) {
      widthFitRoot.style.setProperty('width', contentWidth + 'px', 'important');
      widthFitRoot.style.setProperty('max-width', 'none', 'important');
      widthFitRoot.style.transform = 'scale(' + widthScale + ')';
      widthFitRoot.style.willChange = 'transform';
    }
    sourceDocument.__axichatWidthFitApplied = true;
    widthFitReady = true;
  }
  const activeWidthScale = Number.isFinite(widthScale) && widthScale > 0
    ? widthScale
    : 1;
  let pendingImages = 0;
  let layoutBlockingPendingImages = 0;
  const hasReservedImageLayout = (image) => {
    if (image.getBoundingClientRect) {
      const rect = image.getBoundingClientRect();
      if (Number.isFinite(rect.width) &&
          Number.isFinite(rect.height) &&
          rect.width > 0 &&
          rect.height > 0) {
        return true;
      }
    }
    const width = Number.parseFloat(image.getAttribute('width') || '0');
    const height = Number.parseFloat(image.getAttribute('height') || '0');
    return Number.isFinite(width) &&
      Number.isFinite(height) &&
      width > 0 &&
      height > 0;
  };
  for (const image of sourceDocument.images) {
    if (!image.complete) {
      pendingImages += 1;
      const reservesLayout = hasReservedImageLayout(image);
      const isLazy =
        String(image.getAttribute('loading') || '').toLowerCase() === 'lazy';
      if (isLazy && !reservesLayout) {
        image.setAttribute('loading', 'eager');
      }
      if (!reservesLayout) {
        layoutBlockingPendingImages += 1;
      }
    }
  }
  const documentReady = sourceDocument.readyState === 'complete';
  const imagesReady = layoutBlockingPendingImages === 0;
  const fontsReady =
    !sourceDocument.fonts || sourceDocument.fonts.status === 'loaded';
  const scrollY = sourceWindow ? sourceWindow.scrollY || 0 : 0;
  const bodyTop = body.getBoundingClientRect().top + scrollY;
  let maxBottom = 0;
  let hasVisibleBounds = false;
  const getElementStyle = (element) =>
    sourceWindow && sourceWindow.getComputedStyle
      ? sourceWindow.getComputedStyle(element)
      : window.getComputedStyle(element);
  const ignoresRenderedBounds = (style) =>
    style.display === 'none' ||
    style.visibility === 'hidden' ||
    style.visibility === 'collapse' ||
    Number.parseFloat(style.opacity || '1') <= 0 ||
    style.position === 'fixed';

  for (const element of body.querySelectorAll('*')) {
    let style = null;
    let hiddenByAncestor = false;
    for (let current = element;
         current && current !== root;
         current = current.parentElement) {
      const currentStyle = getElementStyle(current);
      if (ignoresRenderedBounds(currentStyle)) {
        hiddenByAncestor = true;
        break;
      }
      if (current === element) {
        style = currentStyle;
      }
    }
    if (hiddenByAncestor || !style) {
      continue;
    }
    const rect = element.getBoundingClientRect();
    if (!Number.isFinite(rect.bottom) ||
        rect.width <= 0 ||
        rect.height <= 0) {
      continue;
    }
    const marginBottom = Number.parseFloat(style.marginBottom || '0');
    maxBottom = Math.max(
      maxBottom,
      rect.bottom + scrollY - bodyTop +
        (Number.isFinite(marginBottom) ? marginBottom * activeWidthScale : 0),
    );
    hasVisibleBounds = true;
  }

  const textWalker = sourceDocument.createTreeWalker(
    body,
    NodeFilter.SHOW_TEXT,
    {
      acceptNode: (node) =>
        node.nodeValue && node.nodeValue.trim()
          ? NodeFilter.FILTER_ACCEPT
          : NodeFilter.FILTER_REJECT,
    },
  );
  for (let textNode = textWalker.nextNode();
       textNode;
       textNode = textWalker.nextNode()) {
    let hiddenByAncestor = false;
    for (let current = textNode.parentElement;
         current && current !== root;
         current = current.parentElement) {
      if (ignoresRenderedBounds(getElementStyle(current))) {
        hiddenByAncestor = true;
        break;
      }
    }
    if (hiddenByAncestor) {
      continue;
    }
    const range = sourceDocument.createRange();
    range.selectNodeContents(textNode);
    for (const rect of range.getClientRects()) {
      if (!Number.isFinite(rect.bottom) ||
          rect.width <= 0 ||
          rect.height <= 0) {
        continue;
      }
      maxBottom = Math.max(maxBottom, rect.bottom + scrollY - bodyTop);
      hasVisibleBounds = true;
    }
  }

  let fallbackHeight = 0;
  if (!hasVisibleBounds) {
    const range = sourceDocument.createRange();
    range.selectNodeContents(body);
    const rangeRect = range.getBoundingClientRect();
    const bodyRect = body.getBoundingClientRect();
    fallbackHeight = Math.max(
      Number.isFinite(rangeRect.height) ? rangeRect.height : 0,
      Number.isFinite(bodyRect.bottom) ? bodyRect.bottom + scrollY - bodyTop : 0,
    );
  }

  const measuredHeight = Math.ceil(
    hasVisibleBounds ? maxBottom : fallbackHeight,
  );
  if (frame && sourceDocument !== document && measuredHeight > 0) {
    frame.style.height = measuredHeight + 'px';
    if (document.body) {
      document.body.style.minHeight = measuredHeight + 'px';
    }
  }
  const rawScrollHeight = Math.max(
    body.scrollHeight || 0,
    body.offsetHeight || 0,
    root ? root.scrollHeight || 0 : 0,
    root ? root.offsetHeight || 0 : 0,
  );
  const scaledScrollHeight = Math.ceil(rawScrollHeight * activeWidthScale);
  const measuredViewportHeight = Math.ceil(
    Math.max(
      sourceWindow ? sourceWindow.innerHeight || 0 : 0,
      root ? root.clientHeight || 0 : 0,
    ),
  );
  const stabilityKey = [
    measuredHeight,
    scaledScrollHeight,
    measuredViewportHeight,
    contentWidth,
    viewportWidth,
    Math.round(widthScale * 100000),
    pendingImages,
    documentReady ? 1 : 0,
    imagesReady ? 1 : 0,
    fontsReady ? 1 : 0,
    widthFitReady ? 1 : 0,
  ].join(':');
  const lastStabilityKey =
    String(sourceDocument.__axichatEmailLastStabilityKey || '');
  const lastStabilitySequence =
    sourceDocument.__axichatEmailLastStabilitySequence === undefined
      ? -1
      : Math.ceil(Number(sourceDocument.__axichatEmailLastStabilitySequence));
  const layoutStable =
    stabilityKey === lastStabilityKey &&
    layoutSequence === lastStabilitySequence;
  sourceDocument.__axichatEmailLastStabilityKey = stabilityKey;
  sourceDocument.__axichatEmailLastStabilitySequence = layoutSequence;
  return {
    measuredHeight: measuredHeight,
    scrollHeight: scaledScrollHeight,
    viewportHeight: measuredViewportHeight,
    contentWidth: contentWidth,
    viewportWidth: viewportWidth,
    widthScale: widthScale,
    pendingImages: pendingImages,
    documentReady: documentReady,
    imagesReady: imagesReady,
    fontsReady: fontsReady,
    widthFitReady: widthFitReady,
    layoutStable: layoutStable,
    layoutSequence: layoutSequence,
  };
})()
''';

@visibleForTesting
String emailDomHeightMetricsExpressionForTesting() =>
    _emailDomHeightMetricsExpression();

String _emailDocumentHeightObserverExpression() =>
    '''
(() => {
  if (window.__axichatEmailHeightObserverInstalled) {
    if (typeof window.__axichatEmailScheduleHeight === 'function') {
      window.__axichatEmailScheduleHeight();
    }
    return true;
  }

  const measureHeight = () => ${_emailDomHeightMetricsExpression()};
  let lastReportedMetricsKey = '';

  const reportHeight = () => {
    const metrics = measureHeight();
    if (metrics.measuredHeight > 0 &&
        window.flutter_inappwebview &&
        typeof window.flutter_inappwebview.callHandler === 'function') {
      const metricsKey = [
        Math.ceil(metrics.measuredHeight || 0),
        Math.ceil(metrics.scrollHeight || 0),
        Math.ceil(metrics.viewportHeight || 0),
        Math.ceil(metrics.contentWidth || 0),
        Math.ceil(metrics.viewportWidth || 0),
        Math.round((metrics.widthScale || 1) * 100000),
        Math.ceil(metrics.pendingImages || 0),
        metrics.documentReady ? 1 : 0,
        metrics.imagesReady ? 1 : 0,
        metrics.fontsReady ? 1 : 0,
        metrics.widthFitReady ? 1 : 0,
        metrics.layoutStable ? 1 : 0,
        Math.ceil(metrics.layoutSequence || 0),
      ].join(':');
      if (metricsKey === lastReportedMetricsKey) {
        return metrics;
      }
      lastReportedMetricsKey = metricsKey;
      Promise.resolve(
        window.flutter_inappwebview.callHandler('axichatEmailHeight', metrics),
      ).catch(() => {});
    }
    return metrics;
  };

  let frame = 0;
  const reportUntilStable = () => {
    frame = 0;
    const metrics = reportHeight();
    if (metrics && !metrics.layoutStable) {
      frame = window.requestAnimationFrame(reportUntilStable);
    }
  };
  const schedule = () => {
    if (frame) {
      return;
    }
    frame = window.requestAnimationFrame(reportUntilStable);
  };
  const noteLayoutChanged = () => {
    document.__axichatEmailLayoutSequence =
      Number(document.__axichatEmailLayoutSequence || 0) + 1;
    schedule();
  };

  window.__axichatEmailHeightObserverInstalled = true;
  window.__axichatEmailReportHeight = reportHeight;
  window.__axichatEmailScheduleHeight = schedule;

  window.addEventListener('load', schedule, { passive: true });
  window.addEventListener('resize', schedule, { passive: true });

  const observeImages = () => {
    for (const image of document.images) {
      if (image.__axichatEmailSizeHookInstalled) {
        continue;
      }
      image.__axichatEmailSizeHookInstalled = true;
      image.addEventListener('load', noteLayoutChanged, { passive: true });
      image.addEventListener('error', noteLayoutChanged, { passive: true });
    }
  };

  const isWidthFitRoot = (target) =>
    target &&
    target.nodeType === Node.ELEMENT_NODE &&
    (
      target.getAttribute('data-axichat-original-email-scale-root') === 'true' ||
      target.id === 'axichat-original-email-scale-root'
    );
  const isWidthFitStyleMutation = (mutation) =>
    mutation.type === 'attributes' &&
    mutation.attributeName === 'style' &&
    isWidthFitRoot(mutation.target);
  const mutationObserver = new MutationObserver((mutations) => {
    if (mutations.every(isWidthFitStyleMutation)) {
      return;
    }
    observeImages();
    noteLayoutChanged();
  });
  mutationObserver.observe(document.documentElement, {
    childList: true,
    subtree: true,
    characterData: true,
    attributes: true,
  });

  if (document.fonts && document.fonts.ready) {
    document.fonts.ready.then(schedule).catch(() => {});
  }

  observeImages();

  schedule();
  window.setTimeout(schedule, 100);
  window.setTimeout(schedule, 300);
  window.setTimeout(schedule, 1000);
  return true;
})()
''';

@visibleForTesting
String emailDocumentHeightObserverExpressionForTesting() =>
    _emailDocumentHeightObserverExpression();

bool _usesDomContentHeightMeasurement({
  required EmailHtmlContentMode contentMode,
  required TargetPlatform platform,
}) {
  return switch (contentMode) {
    EmailHtmlContentMode.safe => switch (platform) {
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.iOS ||
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
    },
    EmailHtmlContentMode.originalPassive => true,
  };
}

bool _usesPlatformContentHeightMeasurement({
  required EmailHtmlContentMode contentMode,
  required TargetPlatform platform,
}) =>
    !_usesDomContentHeightMeasurement(
      contentMode: contentMode,
      platform: platform,
    ) &&
    contentMode == EmailHtmlContentMode.safe;

bool _usesPlatformContentHeightFallback({
  required EmailHtmlContentMode contentMode,
  required TargetPlatform platform,
}) =>
    _usesDomContentHeightMeasurement(
      contentMode: contentMode,
      platform: platform,
    ) &&
    contentMode == EmailHtmlContentMode.safe;

bool _usesDelayedContentHeightMeasurements({
  required EmailHtmlContentMode contentMode,
  required TargetPlatform platform,
}) =>
    _usesDomContentHeightMeasurement(
      contentMode: contentMode,
      platform: platform,
    ) ||
    _usesPlatformContentHeightMeasurement(
      contentMode: contentMode,
      platform: platform,
    );

@visibleForTesting
bool emailHtmlUsesDomContentHeightMeasurementForTesting({
  required EmailHtmlContentMode contentMode,
  required TargetPlatform platform,
}) => _usesDomContentHeightMeasurement(
  contentMode: contentMode,
  platform: platform,
);

@visibleForTesting
bool emailHtmlUsesPlatformContentHeightMeasurementForTesting({
  required EmailHtmlContentMode contentMode,
  required TargetPlatform platform,
}) => _usesPlatformContentHeightMeasurement(
  contentMode: contentMode,
  platform: platform,
);

@visibleForTesting
bool emailHtmlUsesPlatformContentHeightFallbackForTesting({
  required EmailHtmlContentMode contentMode,
  required TargetPlatform platform,
}) => _usesPlatformContentHeightFallback(
  contentMode: contentMode,
  platform: platform,
);

@visibleForTesting
bool emailHtmlUsesDelayedContentHeightMeasurementsForTesting({
  required EmailHtmlContentMode contentMode,
  required TargetPlatform platform,
}) => _usesDelayedContentHeightMeasurements(
  contentMode: contentMode,
  platform: platform,
);

String _buildOriginalPassiveEmailHtmlShell({
  required String html,
  required bool allowRemoteImages,
  required String themeStyle,
}) {
  const linkHandlerName = _EmailHtmlWebViewState._linkHandlerName;
  final iframeHtml = _preSanitizeOriginalPassiveEmailHtml(
    html: html,
    allowRemoteImages: allowRemoteImages,
  );
  final encodedHtml = _inlineJsonString(
    _injectEmailThemeStyle(iframeHtml, themeStyle),
  );
  final encodedThemeStyle = _inlineJsonString(themeStyle);
  final encodedAllowRemoteImages = allowRemoteImages ? 'true' : 'false';
  final encodedImagePlaceholder = _inlineJsonString(
    HtmlContentCodec.blockedRemoteEmailImagePlaceholderDataUri,
  );
  return '''
<!doctype html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
html, body {
  width: 100%;
  max-width: 100%;
  background: transparent;
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}
*, *::before, *::after {
  box-sizing: border-box;
}
#axichat-original-email-frame {
  display: block;
  width: 100%;
  max-width: 100%;
  border: 0;
}
</style>
</head>
<body>
<iframe
  id="axichat-original-email-frame"
  sandbox="allow-same-origin"
  referrerpolicy="no-referrer"
></iframe>
<script>
(() => {
  const frame = document.getElementById('axichat-original-email-frame');
  const html = $encodedHtml;
  const themeStyleHtml = $encodedThemeStyle;
  const allowRemoteImages = $encodedAllowRemoteImages;
  const blockedRemoteImagePlaceholder = $encodedImagePlaceholder;

  const measureMetrics = () => ${_emailDomHeightMetricsExpression()};
  let lastReportedMetricsKey = '';

  const reportHeight = () => {
    const metrics = measureMetrics();
    const height = metrics.measuredHeight || 0;
    if (height <= 0) {
      return metrics;
    }
    if (window.flutter_inappwebview &&
        typeof window.flutter_inappwebview.callHandler === 'function') {
      const metricsKey = [
        Math.ceil(metrics.measuredHeight || 0),
        Math.ceil(metrics.scrollHeight || 0),
        Math.ceil(metrics.viewportHeight || 0),
        Math.ceil(metrics.contentWidth || 0),
        Math.ceil(metrics.viewportWidth || 0),
        Math.round((metrics.widthScale || 1) * 100000),
        Math.ceil(metrics.pendingImages || 0),
        metrics.documentReady ? 1 : 0,
        metrics.imagesReady ? 1 : 0,
        metrics.fontsReady ? 1 : 0,
        metrics.widthFitReady ? 1 : 0,
        metrics.layoutStable ? 1 : 0,
        Math.ceil(metrics.layoutSequence || 0),
      ].join(':');
      if (metricsKey === lastReportedMetricsKey) {
        return metrics;
      }
      lastReportedMetricsKey = metricsKey;
      Promise.resolve(
        window.flutter_inappwebview.callHandler('axichatEmailHeight', metrics),
      ).catch(() => {});
    }
    return metrics;
  };

  let frameRequest = 0;
  const reportUntilStable = () => {
    frameRequest = 0;
    const metrics = reportHeight();
    if (metrics && !metrics.layoutStable) {
      frameRequest = window.requestAnimationFrame(reportUntilStable);
    }
  };
  const scheduleHeight = () => {
    if (frameRequest) {
      return;
    }
    frameRequest = window.requestAnimationFrame(reportUntilStable);
  };

  const normalizeFrameDocument = () => {
    const doc = frame.contentDocument;
    if (!doc || !doc.documentElement) {
      return false;
    }
    const head = doc.head || doc.createElement('head');
    if (!doc.head) {
      doc.documentElement.insertBefore(head, doc.body || doc.documentElement.firstChild);
    }
    for (const viewport of doc.querySelectorAll('meta[name="viewport"]')) {
      viewport.remove();
    }
    for (const themeNode of doc.querySelectorAll('#axichat-email-webview-theme')) {
      themeNode.remove();
    }
    const template = doc.createElement('template');
    template.innerHTML = themeStyleHtml;
    const viewport = template.content.querySelector('meta[name="viewport"]');
    const style = template.content.querySelector('#axichat-email-webview-theme');
    if (viewport) {
      head.appendChild(viewport);
    }
    if (style) {
      head.appendChild(style);
    }
    const scaleRoot =
      doc.querySelector('[data-axichat-original-email-scale-root="true"]') ||
      doc.getElementById('axichat-original-email-scale-root');
    if (doc.body && !scaleRoot) {
      doc.body.setAttribute('data-axichat-original-email-scale-root', 'true');
      doc.body.style.transformOrigin = 'top left';
      doc.body.style.display = 'block';
    }
    doc.__axichatViewportNormalized = true;
    doc.__axichatWidthFitApplied = false;
    doc.__axichatEmailLayoutSequence = 0;
    doc.__axichatEmailLastStabilityKey = '';
    doc.__axichatEmailLastStabilitySequence = -1;
    if (!allowRemoteImages) {
      for (const image of Array.from(doc.images || [])) {
        let url = null;
        try {
          url = new URL(image.getAttribute('src') || '', doc.baseURI);
        } catch (_) {
          continue;
        }
        if (!url || (url.protocol !== 'http:' && url.protocol !== 'https:')) {
          continue;
        }
        const width = Number(image.getAttribute('width') || 0);
        const height = Number(image.getAttribute('height') || 0);
        const source = url.href.toLowerCase();
        if ((width > 0 && height > 0 && width <= 1 && height <= 1) ||
            /(?:beacon|pixel|spacer|tracking)/i.test(source)) {
          image.remove();
          continue;
        }
        image.removeAttribute('srcset');
        image.src = blockedRemoteImagePlaceholder;
      }
    }
    return true;
  };

  const routeLinksThroughMainFrame = () => {
    const doc = frame.contentDocument;
    if (!doc || doc.__axichatLinkRoutingInstalled) {
      return;
    }
    doc.__axichatLinkRoutingInstalled = true;
    const allowedLinkProtocols = new Set(['http:', 'https:', 'mailto:', 'xmpp:']);
    const findAnchor = (target) => {
      let current = target;
      if (!current) {
        return null;
      }
      if (current.nodeType !== Node.ELEMENT_NODE) {
        current = current.parentElement;
      }
      if (!current ||
          current.nodeType !== Node.ELEMENT_NODE ||
          typeof current.closest !== 'function') {
        return null;
      }
      return current.closest('a[href]');
    };
    const routeLink = (href) => {
      let url = null;
      try {
        url = new URL(href, doc.baseURI || frame.src || window.location.href);
      } catch (_) {
        return;
      }
      if (!url || !allowedLinkProtocols.has(url.protocol)) {
        return;
      }
      if (window.flutter_inappwebview &&
          typeof window.flutter_inappwebview.callHandler === 'function') {
        Promise.resolve(
          window.flutter_inappwebview.callHandler('$linkHandlerName', url.href),
        ).catch(() => {});
      }
    };
    doc.addEventListener('click', (event) => {
      const anchor = findAnchor(event.target);
      if (!anchor) {
        return;
      }
      const href = anchor.href;
      event.preventDefault();
      event.stopPropagation();
      if (!href) {
        return;
      }
      routeLink(href);
    }, true);
    doc.addEventListener('submit', (event) => {
      event.preventDefault();
      event.stopPropagation();
    }, true);
  };

  const installResizeHooks = () => {
    const doc = frame.contentDocument;
    if (!doc || doc.__axichatResizeHooksInstalled) {
      return;
    }
    doc.__axichatResizeHooksInstalled = true;
    const observeImages = () => {
      for (const image of doc.images) {
        if (image.__axichatEmailSizeHookInstalled) {
          continue;
        }
        image.__axichatEmailSizeHookInstalled = true;
        image.addEventListener('load', noteLayoutChanged, { passive: true });
        image.addEventListener('error', noteLayoutChanged, { passive: true });
      }
    };
    const noteLayoutChanged = () => {
      doc.__axichatEmailLayoutSequence =
        Number(doc.__axichatEmailLayoutSequence || 0) + 1;
      scheduleHeight();
    };
    const isWidthFitRoot = (target) =>
      target &&
      target.nodeType === Node.ELEMENT_NODE &&
      (
        target.getAttribute('data-axichat-original-email-scale-root') === 'true' ||
        target.id === 'axichat-original-email-scale-root'
      );
    const isWidthFitStyleMutation = (mutation) =>
      mutation.type === 'attributes' &&
      mutation.attributeName === 'style' &&
      isWidthFitRoot(mutation.target);
    new MutationObserver((mutations) => {
      if (mutations.every(isWidthFitStyleMutation)) {
        return;
      }
      observeImages();
      noteLayoutChanged();
    }).observe(doc.documentElement, {
      childList: true,
      subtree: true,
      characterData: true,
      attributes: true,
    });
    if (doc.fonts && doc.fonts.ready) {
      doc.fonts.ready.then(scheduleHeight).catch(() => {});
    }
    observeImages();
  };

  frame.addEventListener('load', () => {
    if (!normalizeFrameDocument()) {
      return;
    }
    routeLinksThroughMainFrame();
    installResizeHooks();
    scheduleHeight();
    window.setTimeout(scheduleHeight, 80);
    window.setTimeout(scheduleHeight, 200);
    window.setTimeout(scheduleHeight, 400);
    window.setTimeout(scheduleHeight, 800);
    window.setTimeout(scheduleHeight, 1600);
    window.setTimeout(scheduleHeight, 3000);
  });

  window.addEventListener('resize', scheduleHeight, { passive: true });
  frame.srcdoc = html;
})();
</script>
</body>
</html>
''';
}

String _emailWebViewCssColor(Color color) {
  final red = (color.r * 255.0).round().clamp(0, 255);
  final green = (color.g * 255.0).round().clamp(0, 255);
  final blue = (color.b * 255.0).round().clamp(0, 255);
  return 'rgba($red, $green, $blue, ${color.a.toStringAsFixed(3)})';
}

String _emailWebViewCssPixels(double pixels) => pixels == pixels.roundToDouble()
    ? pixels.toStringAsFixed(0)
    : pixels.toStringAsFixed(2);

String _buildEmailWebViewThemeStyle({
  required Brightness brightness,
  required Color backgroundColor,
  required double baseFontSize,
}) {
  final fallbackBackgroundColor = brightness == Brightness.dark
      ? const Color(0xFFFFFFFF)
      : backgroundColor;
  final baseFontSizeCss = _emailWebViewCssPixels(baseFontSize);
  const viewportContent =
      'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no';
  final layoutStyle =
      '''
html, body {
  width: 100% !important;
  max-width: 100% !important;
  font-size: max(1em, ${baseFontSizeCss}px);
  -webkit-text-size-adjust: 100% !important;
  text-size-adjust: 100% !important;
}
body {
  overflow-wrap: break-word !important;
  word-break: normal !important;
}
body, div, section, article, main, header, footer, p, ul, ol, li {
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
table, tbody, thead, tfoot, tr, td, th {
  max-width: 100% !important;
}
div, p, a, li,
b, strong, em, i, u, small {
  overflow-wrap: break-word !important;
  word-break: normal !important;
}
pre, code, blockquote {
  overflow-wrap: break-word !important;
  word-break: normal !important;
}
pre, code {
  white-space: pre-wrap !important;
}
''';
  return '''
<meta name="viewport" content="$viewportContent">
<style id="axichat-email-webview-theme">
html, body {
  background-color: ${_emailWebViewCssColor(fallbackBackgroundColor)} !important;
  box-sizing: border-box !important;
  height: auto !important;
  margin: 0 !important;
  min-height: 0 !important;
  padding: 0 !important;
}
*, *::before, *::after {
  box-sizing: border-box !important;
}
$layoutStyle
</style>
''';
}

String buildEmailWebViewThemeStyle({
  required Brightness brightness,
  required Color backgroundColor,
  required double baseFontSize,
}) => _buildEmailWebViewThemeStyle(
  brightness: brightness,
  backgroundColor: backgroundColor,
  baseFontSize: baseFontSize,
);

@visibleForTesting
String buildEmailWebViewThemeStyleForTesting({
  required Brightness brightness,
  required Color backgroundColor,
  required double baseFontSize,
}) => buildEmailWebViewThemeStyle(
  brightness: brightness,
  backgroundColor: backgroundColor,
  baseFontSize: baseFontSize,
);

enum _EmailHtmlWebViewMode { embedded, scrollable }

enum EmailHtmlContentMode {
  safe,
  originalPassive;

  bool allowsRemoteImages({required bool shouldLoadSafeRemoteImages}) =>
      switch (this) {
        EmailHtmlContentMode.safe => shouldLoadSafeRemoteImages,
        EmailHtmlContentMode.originalPassive => shouldLoadSafeRemoteImages,
      };

  bool usesWebViewJavaScript(TargetPlatform platform) => switch (this) {
    EmailHtmlContentMode.safe => true,
    EmailHtmlContentMode.originalPassive => true,
  };
}

@visibleForTesting
InAppWebViewSettings buildEmailHtmlWebViewSettings({
  required bool usesInternalScroll,
  required bool useHybridComposition,
  required bool simplifyLayout,
  required bool allowRemoteImages,
  required EmailHtmlContentMode contentMode,
}) {
  final effectiveAllowRemoteImages = contentMode.allowsRemoteImages(
    shouldLoadSafeRemoteImages: allowRemoteImages,
  );
  return InAppWebViewSettings(
    javaScriptEnabled: contentMode.usesWebViewJavaScript(defaultTargetPlatform),
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
    useOnDownloadStart: true,
    blockNetworkImage: !effectiveAllowRemoteImages,
    blockNetworkLoads: false,
    mixedContentMode: effectiveAllowRemoteImages
        ? MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW
        : MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
    useHybridComposition: useHybridComposition,
    supportZoom: false,
    builtInZoomControls: false,
    displayZoomControls: false,
    useWideViewPort: false,
    loadWithOverviewMode: false,
    initialScale: null,
    textZoom: 100,
    minimumFontSize: 14,
    minimumLogicalFontSize: 14,
    preferredContentMode: UserPreferredContentMode.MOBILE,
    disableVerticalScroll: !usesInternalScroll,
    disableHorizontalScroll: !usesInternalScroll,
    verticalScrollBarEnabled: usesInternalScroll,
    horizontalScrollBarEnabled: usesInternalScroll,
  );
}

@visibleForTesting
Set<Factory<OneSequenceGestureRecognizer>>
emailHtmlEmbeddedGestureRecognizersForTesting() =>
    _EmailHtmlWebViewState._tapOnlyGestureRecognizers;

class EmailHtmlWebView extends StatefulWidget {
  const EmailHtmlWebView.embedded({
    super.key,
    required this.html,
    required this.allowRemoteImages,
    required this.minHeight,
    required this.backgroundColor,
    required this.textColor,
    required this.linkColor,
    required this.baseFontSize,
    required this.onLinkTap,
    this.initialContentHeight,
    this.onContentHeightChanged,
    this.loadingFallback,
    this.simplifyLayout = false,
    this.useHybridComposition = true,
    this.contentMode = EmailHtmlContentMode.safe,
    this.diagnosticContentKey,
    this.diagnosticRawHtml,
    this.diagnosticFlutterHtml,
    this.paintContent = true,
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
    required this.baseFontSize,
    required this.onLinkTap,
    this.initialContentHeight,
    this.onContentHeightChanged,
    this.loadingFallback,
    this.simplifyLayout = false,
    this.useHybridComposition = true,
    this.contentMode = EmailHtmlContentMode.safe,
    this.diagnosticContentKey,
    this.diagnosticRawHtml,
    this.diagnosticFlutterHtml,
    this.paintContent = true,
  }) : _mode = _EmailHtmlWebViewMode.scrollable;

  final String html;
  final bool allowRemoteImages;
  final double? maxHeight;
  final double minHeight;
  final Color backgroundColor;
  final Color textColor;
  final Color linkColor;
  final double baseFontSize;
  final ValueChanged<String> onLinkTap;
  final double? initialContentHeight;
  final ValueChanged<double>? onContentHeightChanged;
  final Widget? loadingFallback;
  final bool simplifyLayout;
  final bool useHybridComposition;
  final EmailHtmlContentMode contentMode;
  final Object? diagnosticContentKey;
  final String? diagnosticRawHtml;
  final String? diagnosticFlutterHtml;
  final bool paintContent;
  final _EmailHtmlWebViewMode _mode;

  bool get _usesInternalScroll => _mode == _EmailHtmlWebViewMode.scrollable;

  @override
  State<EmailHtmlWebView> createState() => _EmailHtmlWebViewState();
}

final class _PreparedEmailHtmlInput {
  const _PreparedEmailHtmlInput({
    required this.html,
    required this.allowRemoteImages,
    required this.mode,
    required this.contentMode,
    required this.simplifyLayout,
    required this.brightness,
    required this.backgroundColor,
    required this.baseFontSize,
  });

  final String html;
  final bool allowRemoteImages;
  final _EmailHtmlWebViewMode mode;
  final EmailHtmlContentMode contentMode;
  final bool simplifyLayout;
  final Brightness brightness;
  final Color backgroundColor;
  final double baseFontSize;

  int get profileHash => Object.hash(
    html,
    allowRemoteImages,
    mode,
    contentMode,
    simplifyLayout,
    brightness,
    backgroundColor.toARGB32(),
    baseFontSize,
  );

  @override
  bool operator ==(Object other) {
    return other is _PreparedEmailHtmlInput &&
        other.html == html &&
        other.allowRemoteImages == allowRemoteImages &&
        other.mode == mode &&
        other.contentMode == contentMode &&
        other.simplifyLayout == simplifyLayout &&
        other.brightness == brightness &&
        other.backgroundColor == backgroundColor &&
        other.baseFontSize == baseFontSize;
  }

  @override
  int get hashCode => profileHash;
}

class _EmailHtmlWebViewState extends State<EmailHtmlWebView> {
  static const _emailWebViewBaseUrl = 'https://axichat.invalid/';
  static const _heightHandlerName = 'axichatEmailHeight';
  static const _linkHandlerName = 'axichatEmailLink';
  static bool get _debugTraceMeasurements => kDebugMode && false;
  static final Set<Factory<OneSequenceGestureRecognizer>>
  _tapOnlyGestureRecognizers = <Factory<OneSequenceGestureRecognizer>>{
    Factory<OneSequenceGestureRecognizer>(TapGestureRecognizer.new),
  };
  static final WebUri _emailWebViewUri = WebUri(_emailWebViewBaseUrl);

  InAppWebViewController? _controller;
  bool _isLoading = true;
  String? _preparedHtmlData;
  _PreparedEmailHtmlInput? _preparedHtmlInputKey;
  double? _contentHeight;
  int _webViewGeneration = 0;
  int _loadEpoch = 0;
  int _heightMeasurementEpoch = 0;
  Object? _activeWebViewId;
  final Map<Object?, int> _webViewGenerationsById = <Object?, int>{};
  bool _documentHeightObserverInstalled = false;
  bool _reloadPreparedHtmlWhenControllerReady = false;
  final GlobalKey _platformViewSizeKey = GlobalKey();
  bool _linuxPlatformViewResizeScheduled = false;
  int? _lastLinuxPlatformViewId;
  Size? _lastLinuxPlatformViewSize;
  Offset? _lastLinuxPlatformViewOffset;
  double? _linuxFitLockedHeight;
  int? _lastProgressLogBucket;
  int? _scheduledMeasurementWebViewGeneration;
  int? _scheduledMeasurementLoadEpoch;

  void _traceMeasurement(
    String event, {
    int? webViewGeneration,
    int? progress,
    double? measuredHeight,
    double? scrollHeight,
    double? viewportHeight,
    double? contentWidth,
    double? viewportWidth,
    double? widthScale,
    int? pendingImages,
    bool? documentReady,
    bool? imagesReady,
    bool? fontsReady,
    bool? widthFitReady,
    bool? layoutStable,
    int? layoutSequence,
    Size? contentSize,
    String? details,
    int? delayMs,
    int? elapsedMs,
    int? htmlLength,
    int? preparedHtmlLength,
    int? inputKeyHash,
  }) {
    if (!_debugTraceMeasurements) {
      return;
    }
    final fields = <String>[
      'event=$event',
      'mode=${widget.contentMode.name}',
      'platform=${defaultTargetPlatform.name}',
      'generation=${webViewGeneration ?? _webViewGeneration}',
      'loadEpoch=$_loadEpoch',
      'heightEpoch=$_heightMeasurementEpoch',
      'loading=$_isLoading',
      'prepared=${_preparedHtmlData != null}',
      'controller=${_controller != null}',
      'contentHeight=${_contentHeight?.ceil()}',
      'resolvedHeight=${_resolvedHeight.ceil()}',
      if (progress != null) 'progress=$progress',
      if (delayMs != null) 'delayMs=$delayMs',
      if (elapsedMs != null) 'elapsedMs=$elapsedMs',
      if (htmlLength != null) 'htmlLength=$htmlLength',
      if (preparedHtmlLength != null) 'preparedHtmlLength=$preparedHtmlLength',
      if (inputKeyHash != null) 'inputKeyHash=$inputKeyHash',
      if (measuredHeight != null) 'measuredHeight=${measuredHeight.ceil()}',
      if (scrollHeight != null) 'scrollHeight=${scrollHeight.ceil()}',
      if (viewportHeight != null) 'viewportHeight=${viewportHeight.ceil()}',
      if (contentWidth != null) 'contentWidth=${contentWidth.ceil()}',
      if (viewportWidth != null) 'viewportWidth=${viewportWidth.ceil()}',
      if (widthScale != null) 'widthScale=${widthScale.toStringAsFixed(4)}',
      if (pendingImages != null) 'pendingImages=$pendingImages',
      if (documentReady != null) 'documentReady=$documentReady',
      if (imagesReady != null) 'imagesReady=$imagesReady',
      if (fontsReady != null) 'fontsReady=$fontsReady',
      if (widthFitReady != null) 'widthFitReady=$widthFitReady',
      if (layoutStable != null) 'layoutStable=$layoutStable',
      if (layoutSequence != null) 'layoutSequence=$layoutSequence',
      if (contentSize != null)
        'contentSize=${contentSize.width.ceil()}x${contentSize.height.ceil()}',
      if (details != null) 'details=$details',
    ];
    debugPrint('[EmailHtmlWebView] ${fields.join(' ')}');
  }

  Object get _diagnosticContentKey => (
    contentKey: widget.diagnosticContentKey ?? widget.html.hashCode,
    mode: widget._mode.name,
    contentMode: widget.contentMode.name,
    remoteImages: widget.allowRemoteImages,
  );

  double? _normalizedInitialContentHeight() {
    final initialContentHeight = widget.initialContentHeight;
    if (initialContentHeight == null || initialContentHeight <= 0) {
      return null;
    }
    return initialContentHeight.ceilToDouble();
  }

  void _logPreparedHtmlStages(String preparedHtmlData) {
    logEmailHtmlStages(
      contentKey: _diagnosticContentKey,
      stages: {
        if (widget.diagnosticRawHtml != null) 'raw': widget.diagnosticRawHtml,
        'webview-input': widget.html,
        if (widget.diagnosticFlutterHtml != null)
          'prepared-flutter-html': widget.diagnosticFlutterHtml,
        'webview-prepared-shell': preparedHtmlData,
      },
    );
  }

  Future<void> _logRenderedDom(
    InAppWebViewController controller, {
    required int webViewGeneration,
  }) async {
    if (!emailHtmlLoggingEnabled ||
        !_canUseController(controller, webViewGeneration)) {
      return;
    }
    try {
      final result = await controller.evaluateJavascript(
        source: _emailRenderedDomExpression(),
      );
      if (!_canUseController(controller, webViewGeneration) ||
          result is! String ||
          result.trim().isEmpty) {
        return;
      }
      logEmailHtmlStages(
        contentKey: _diagnosticContentKey,
        stages: {'webview-rendered-dom': result},
      );
    } on Exception catch (error) {
      _traceMeasurement(
        'rendered-dom-log-exception',
        webViewGeneration: webViewGeneration,
        details: error.runtimeType.toString(),
      );
    }
  }

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
  void initState() {
    super.initState();
    _contentHeight = _normalizedInitialContentHeight();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshPreparedHtml(reload: _controller != null);
  }

  @override
  void dispose() {
    _traceMeasurement('dispose');
    _webViewGeneration++;
    _heightMeasurementEpoch++;
    _controller = null;
    _activeWebViewId = null;
    _webViewGenerationsById.clear();
    _documentHeightObserverInstalled = false;
    _lastProgressLogBucket = null;
    _scheduledMeasurementWebViewGeneration = null;
    _scheduledMeasurementLoadEpoch = null;
    _reloadPreparedHtmlWhenControllerReady = false;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EmailHtmlWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final htmlChanged = oldWidget.html != widget.html;
    final allowRemoteImagesChanged =
        oldWidget.allowRemoteImages != widget.allowRemoteImages;
    final simplifyLayoutChanged =
        oldWidget.simplifyLayout != widget.simplifyLayout;
    final modeChanged = oldWidget._mode != widget._mode;
    final hybridCompositionChanged =
        oldWidget.useHybridComposition != widget.useHybridComposition;
    final contentModeChanged = oldWidget.contentMode != widget.contentMode;
    final backgroundColorChanged =
        oldWidget.backgroundColor != widget.backgroundColor;
    final textColorChanged = oldWidget.textColor != widget.textColor;
    final linkColorChanged = oldWidget.linkColor != widget.linkColor;
    final baseFontSizeChanged = oldWidget.baseFontSize != widget.baseFontSize;
    final hadController = _controller != null;
    final preserveMeasuredHeightForRefresh =
        _emailHtmlWebViewShouldPreserveMeasuredHeightForUpdate(
          hasController: hadController,
          hasMeasuredHeight: _contentHeight != null && _contentHeight! > 0,
          htmlChanged: htmlChanged,
          modeChanged: modeChanged,
          simplifyLayoutChanged: simplifyLayoutChanged,
          baseFontSizeChanged: baseFontSizeChanged,
        );
    if (_emailHtmlWebViewShouldResetControllerForUpdate(
      modeChanged: modeChanged,
      simplifyLayoutChanged: simplifyLayoutChanged,
      hybridCompositionChanged: hybridCompositionChanged,
    )) {
      _traceMeasurement('widget-update-reset-controller');
      _controller = null;
      _activeWebViewId = null;
      _webViewGenerationsById.clear();
      _lastProgressLogBucket = null;
      _scheduledMeasurementWebViewGeneration = null;
      _scheduledMeasurementLoadEpoch = null;
    }
    final layoutChanged =
        htmlChanged ||
        allowRemoteImagesChanged ||
        simplifyLayoutChanged ||
        modeChanged ||
        contentModeChanged ||
        baseFontSizeChanged;
    if (layoutChanged) {
      _traceMeasurement('widget-update-reset-layout');
      _heightMeasurementEpoch++;
      if (!preserveMeasuredHeightForRefresh) {
        _contentHeight = _normalizedInitialContentHeight();
      }
      _documentHeightObserverInstalled = false;
      _linuxFitLockedHeight = null;
      _lastLinuxPlatformViewId = null;
      _lastLinuxPlatformViewSize = null;
      _lastLinuxPlatformViewOffset = null;
    }
    if (htmlChanged ||
        allowRemoteImagesChanged ||
        simplifyLayoutChanged ||
        modeChanged ||
        contentModeChanged ||
        backgroundColorChanged ||
        textColorChanged ||
        linkColorChanged ||
        baseFontSizeChanged) {
      _traceMeasurement('widget-update-refresh-prepared-html');
      _preparedHtmlInputKey = null;
      _documentHeightObserverInstalled = false;
      _linuxFitLockedHeight = null;
      if (!hadController && _preparedHtmlData != null) {
        _reloadPreparedHtmlWhenControllerReady = true;
      }
      _refreshPreparedHtml(
        reload: _controller != null,
        preserveMeasuredHeight: preserveMeasuredHeightForRefresh,
      );
    } else if (oldWidget.initialContentHeight != widget.initialContentHeight &&
        _contentHeight == null) {
      _contentHeight = _normalizedInitialContentHeight();
    }
  }

  void _refreshPreparedHtml({
    required bool reload,
    bool preserveMeasuredHeight = false,
  }) {
    final brightness = context.brightness;
    final inputKey = _PreparedEmailHtmlInput(
      html: widget.html,
      allowRemoteImages: widget.allowRemoteImages,
      mode: widget._mode,
      contentMode: widget.contentMode,
      simplifyLayout: widget.simplifyLayout,
      brightness: brightness,
      backgroundColor: widget.backgroundColor,
      baseFontSize: widget.baseFontSize,
    );
    if (_preparedHtmlInputKey == inputKey) {
      _traceMeasurement(
        'prepare-skip-same-input',
        inputKeyHash: inputKey.profileHash,
        htmlLength: widget.html.length,
      );
      return;
    }
    _preparedHtmlInputKey = inputKey;
    _traceMeasurement(
      'prepare-queued',
      inputKeyHash: inputKey.profileHash,
      htmlLength: widget.html.length,
      details:
          'reload=$reload preserveMeasuredHeight=$preserveMeasuredHeight '
          'brightness=${brightness.name}',
    );
    unawaited(
      _prepareHtmlData(
        inputKey: inputKey,
        reload: reload,
        brightness: brightness,
        preserveMeasuredHeight: preserveMeasuredHeight,
      ),
    );
  }

  Future<void> _prepareHtmlData({
    required _PreparedEmailHtmlInput inputKey,
    required bool reload,
    required Brightness brightness,
    required bool preserveMeasuredHeight,
  }) async {
    if (mounted) {
      _loadEpoch++;
      setState(() {
        _isLoading = true;
        if (!reload) {
          _preparedHtmlData = null;
        }
        if (!preserveMeasuredHeight) {
          _contentHeight = _normalizedInitialContentHeight();
        }
        _linuxFitLockedHeight = null;
      });
    }
    _documentHeightObserverInstalled = false;
    final themeStyle = _buildThemeStyle(brightness: brightness);
    final prepareTimer = Stopwatch()..start();
    _traceMeasurement(
      'prepare-start',
      inputKeyHash: inputKey.profileHash,
      htmlLength: widget.html.length,
      details:
          'reload=$reload preserveMeasuredHeight=$preserveMeasuredHeight '
          'brightness=${brightness.name}',
    );
    String preparedHtmlData;
    try {
      preparedHtmlData = await compute(_prepareEmailHtmlData, {
        'html': widget.html,
        'allowRemoteImages': widget.allowRemoteImages,
        'themeStyle': themeStyle,
        'contentMode': widget.contentMode.name,
      });
      _traceMeasurement(
        'prepare-complete',
        elapsedMs: prepareTimer.elapsedMilliseconds,
        inputKeyHash: inputKey.profileHash,
        preparedHtmlLength: preparedHtmlData.length,
      );
    } on Exception catch (error) {
      _traceMeasurement(
        'prepare-compute-exception',
        elapsedMs: prepareTimer.elapsedMilliseconds,
        inputKeyHash: inputKey.profileHash,
        details: error.runtimeType.toString(),
      );
      if (widget.contentMode == EmailHtmlContentMode.originalPassive) {
        preparedHtmlData = _buildOriginalPassiveEmailHtmlShell(
          html: widget.html,
          allowRemoteImages: widget.allowRemoteImages,
          themeStyle: themeStyle,
        );
      } else {
        final fallbackHtml = HtmlContentCodec.prepareEmailHtmlForWebView(
          widget.html,
          allowRemoteImages: widget.allowRemoteImages,
        );
        preparedHtmlData = _wrapEmailHtmlScaleRoot(
          _injectEmailThemeStyle(fallbackHtml, themeStyle),
        );
      }
      _traceMeasurement(
        'prepare-fallback-complete',
        elapsedMs: prepareTimer.elapsedMilliseconds,
        inputKeyHash: inputKey.profileHash,
        preparedHtmlLength: preparedHtmlData.length,
      );
    }
    if (!mounted || _preparedHtmlInputKey != inputKey) {
      _traceMeasurement(
        'prepare-discarded',
        elapsedMs: prepareTimer.elapsedMilliseconds,
        inputKeyHash: inputKey.profileHash,
        details:
            'mounted=$mounted activeInputKeyHash='
            '${_preparedHtmlInputKey?.profileHash}',
      );
      return;
    }
    _preparedHtmlData = preparedHtmlData;
    _logPreparedHtmlStages(preparedHtmlData);
    _traceMeasurement(
      'prepare-applied',
      elapsedMs: prepareTimer.elapsedMilliseconds,
      inputKeyHash: inputKey.profileHash,
      preparedHtmlLength: preparedHtmlData.length,
      details: 'reload=$reload',
    );
    if (reload || _reloadPreparedHtmlWhenControllerReady) {
      if (_controller == null) {
        _reloadPreparedHtmlWhenControllerReady = true;
        _traceMeasurement('prepare-reload-without-controller');
        setState(() {});
      } else {
        _reloadPreparedHtmlWhenControllerReady = false;
        _traceMeasurement('prepare-reload-load-html');
        await _loadHtml();
      }
      return;
    }
    setState(() {});
  }

  Future<void> _loadHtml() async {
    final controller = _controller;
    final preparedHtmlData = _preparedHtmlData;
    final webViewGeneration = controller == null
        ? null
        : _webViewGenerationForController(controller);
    if (controller == null) {
      _traceMeasurement('load-html-skip', details: 'missing-controller');
      return;
    }
    if (preparedHtmlData == null) {
      _traceMeasurement('load-html-skip', details: 'missing-prepared-html');
      return;
    }
    if (!_canUseController(controller, webViewGeneration)) {
      _traceMeasurement(
        'load-html-skip',
        webViewGeneration: webViewGeneration,
        details: 'stale-controller',
      );
      return;
    }
    if (mounted) {
      _loadEpoch++;
      setState(() {
        _isLoading = true;
      });
    }
    if (!_canUseController(controller, webViewGeneration)) {
      _traceMeasurement(
        'load-html-skip',
        webViewGeneration: webViewGeneration,
        details: 'stale-controller-after-loading-state',
      );
      return;
    }
    _traceMeasurement(
      'load-html-start',
      webViewGeneration: webViewGeneration,
      preparedHtmlLength: preparedHtmlData.length,
    );
    await controller.setSettings(settings: _webViewSettings());
    if (!_canUseController(controller, webViewGeneration)) {
      _traceMeasurement(
        'load-html-skip',
        webViewGeneration: webViewGeneration,
        details: 'stale-controller-after-settings',
      );
      return;
    }
    _scheduleLoadCompletionFallback(
      controller,
      webViewGeneration: webViewGeneration!,
    );
    await controller.loadData(
      data: preparedHtmlData,
      baseUrl: _emailWebViewUri,
      historyUrl: _emailWebViewUri,
    );
    _traceMeasurement(
      'load-html-requested',
      webViewGeneration: webViewGeneration,
    );
  }

  Object? _webViewIdForController(InAppWebViewController controller) =>
      controller.platform.id;

  int _beginWebViewGeneration(InAppWebViewController controller) {
    final webViewId = _webViewIdForController(controller);
    final webViewGeneration = ++_webViewGeneration;
    _controller = controller;
    _activeWebViewId = webViewId;
    _webViewGenerationsById
      ..clear()
      ..[webViewId] = webViewGeneration;
    _lastProgressLogBucket = null;
    _scheduledMeasurementWebViewGeneration = null;
    _scheduledMeasurementLoadEpoch = null;
    return webViewGeneration;
  }

  int? _webViewGenerationForController(InAppWebViewController controller) {
    return _webViewGenerationsById[_webViewIdForController(controller)];
  }

  bool _canUseController(
    InAppWebViewController controller,
    int? webViewGeneration,
  ) {
    final webViewId = _webViewIdForController(controller);
    return mounted &&
        webViewGeneration != null &&
        webViewGeneration == _webViewGeneration &&
        webViewId == _activeWebViewId &&
        _webViewGenerationsById[webViewId] == webViewGeneration;
  }

  bool _canMeasureContentHeight(
    InAppWebViewController controller,
    int? webViewGeneration,
    int? measurementEpoch,
  ) {
    return _canUseController(controller, webViewGeneration) &&
        (measurementEpoch == null ||
            measurementEpoch == _heightMeasurementEpoch);
  }

  Future<void> _measureContentHeight({
    InAppWebViewController? controller,
    int? webViewGeneration,
    int? measurementEpoch,
  }) async {
    final webViewController = controller ?? _controller;
    final currentGeneration =
        webViewGeneration ??
        (webViewController == null
            ? null
            : _webViewGenerationForController(webViewController));
    if (webViewController == null ||
        !_canMeasureContentHeight(
          webViewController,
          currentGeneration,
          measurementEpoch,
        )) {
      return;
    }
    if (_usesDomContentHeightMeasurement(
      contentMode: widget.contentMode,
      platform: defaultTargetPlatform,
    )) {
      final domMetrics = await _measureDomContentHeight(
        webViewController,
        webViewGeneration: currentGeneration,
        measurementEpoch: measurementEpoch,
      );
      if (!_canMeasureContentHeight(
        webViewController,
        currentGeneration,
        measurementEpoch,
      )) {
        return;
      }
      final domMeasuredHeight = domMetrics.measuredHeight == null
          ? null
          : await _scaleDomMeasuredHeightForDisplay(
              webViewController,
              measuredHeight: domMetrics.measuredHeight!,
              webViewGeneration: currentGeneration,
              measurementEpoch: measurementEpoch,
            );
      final measuredHeight =
          domMeasuredHeight ??
          (_usesPlatformContentHeightFallback(
                contentMode: widget.contentMode,
                platform: defaultTargetPlatform,
              )
              ? await _measurePlatformContentHeight(
                  webViewController,
                  webViewGeneration: currentGeneration,
                  measurementEpoch: measurementEpoch,
                )
              : null) ??
          0;
      if (!_canMeasureContentHeight(
            webViewController,
            currentGeneration,
            measurementEpoch,
          ) ||
          measuredHeight <= 0) {
        return;
      }
      final canCommitHeight = _emailHtmlHeightCanCommit(
        hasPositiveHeight: measuredHeight > 0,
        usesPlatformFallback: domMeasuredHeight == null,
        documentReady: domMetrics.documentReady,
        imagesReady: domMetrics.imagesReady,
        widthFitReady: domMetrics.widthFitReady,
        layoutStable: domMetrics.layoutStable,
      );
      if (defaultTargetPlatform == TargetPlatform.linux) {
        _updateLinuxContentHeightMetrics(
          measuredHeight: measuredHeight,
          scrollHeight: domMetrics.scrollHeight,
          viewportHeight: domMetrics.viewportHeight,
          canCommitHeight: canCommitHeight,
          layoutSequence: domMetrics.layoutSequence,
        );
      } else {
        _updateContentHeight(
          measuredHeight,
          canCommitHeight: canCommitHeight,
          layoutSequence: domMetrics.layoutSequence,
        );
      }
      return;
    }

    if (!_usesPlatformContentHeightMeasurement(
      contentMode: widget.contentMode,
      platform: defaultTargetPlatform,
    )) {
      return;
    }
    final measuredHeight =
        await _measurePlatformContentHeight(
          webViewController,
          webViewGeneration: currentGeneration,
          measurementEpoch: measurementEpoch,
        ) ??
        0;
    if (!_canMeasureContentHeight(
          webViewController,
          currentGeneration,
          measurementEpoch,
        ) ||
        measuredHeight <= 0) {
      return;
    }
    _updateContentHeight(measuredHeight);
  }

  void _scheduleContentHeightMeasurements({
    InAppWebViewController? controller,
    int? webViewGeneration,
  }) {
    final webViewController = controller ?? _controller;
    final currentGeneration =
        webViewGeneration ??
        (webViewController == null
            ? null
            : _webViewGenerationForController(webViewController));
    if (webViewController == null) {
      return;
    }
    final measurementEpoch = ++_heightMeasurementEpoch;
    if (!_canMeasureContentHeight(
      webViewController,
      currentGeneration,
      measurementEpoch,
    )) {
      return;
    }

    Future<void> measureAfter(Duration delay) async {
      await Future<void>.delayed(delay);
      if (!_canMeasureContentHeight(
        webViewController,
        currentGeneration,
        measurementEpoch,
      )) {
        return;
      }
      _traceMeasurement(
        'delayed-measure',
        webViewGeneration: currentGeneration,
      );
      await _measureContentHeight(
        controller: webViewController,
        webViewGeneration: currentGeneration,
        measurementEpoch: measurementEpoch,
      );
    }

    if (!_usesDelayedContentHeightMeasurements(
      contentMode: widget.contentMode,
      platform: defaultTargetPlatform,
    )) {
      return;
    }
    unawaited(measureAfter(Duration.zero));
    unawaited(measureAfter(const Duration(milliseconds: 80)));
    unawaited(measureAfter(const Duration(milliseconds: 200)));
    unawaited(measureAfter(const Duration(milliseconds: 400)));
    unawaited(measureAfter(const Duration(milliseconds: 800)));
    unawaited(measureAfter(const Duration(milliseconds: 1600)));
    if (widget.allowRemoteImages) {
      unawaited(measureAfter(const Duration(milliseconds: 3000)));
    }
  }

  void _markLoaded() {
    if (!mounted || !_isLoading) {
      _traceMeasurement(
        'mark-loaded-skip',
        details: 'mounted=$mounted loading=$_isLoading',
      );
      return;
    }
    _traceMeasurement('mark-loaded');
    setState(() {
      _isLoading = false;
    });
  }

  void _finishWebViewLoad(
    InAppWebViewController controller, {
    required int webViewGeneration,
  }) {
    if (!_canUseController(controller, webViewGeneration)) {
      return;
    }
    _traceMeasurement('finish-load', webViewGeneration: webViewGeneration);
    if (_emailHtmlWebViewShouldScheduleLoadMeasurements(
      webViewGeneration: webViewGeneration,
      loadEpoch: _loadEpoch,
      scheduledWebViewGeneration: _scheduledMeasurementWebViewGeneration,
      scheduledLoadEpoch: _scheduledMeasurementLoadEpoch,
    )) {
      _scheduledMeasurementWebViewGeneration = webViewGeneration;
      _scheduledMeasurementLoadEpoch = _loadEpoch;
      _scheduleContentHeightMeasurements(
        controller: controller,
        webViewGeneration: webViewGeneration,
      );
    } else {
      _traceMeasurement(
        'finish-load-measurements-skip',
        webViewGeneration: webViewGeneration,
      );
    }
    _markLoaded();
    if (defaultTargetPlatform == TargetPlatform.linux) {
      _scheduleLinuxPlatformViewResize();
    }
  }

  Future<void> _completeLoadStopSizing(
    InAppWebViewController controller, {
    required int webViewGeneration,
  }) async {
    await _installDocumentHeightObserver(
      controller,
      webViewGeneration: webViewGeneration,
    );
    await _measureContentHeight(
      controller: controller,
      webViewGeneration: webViewGeneration,
    );
    await _logRenderedDom(controller, webViewGeneration: webViewGeneration);
  }

  void _scheduleLoadCompletionFallback(
    InAppWebViewController controller, {
    required int webViewGeneration,
  }) {
    final loadEpoch = _loadEpoch;
    _traceMeasurement(
      'fallback-scheduled',
      webViewGeneration: webViewGeneration,
      details: 'epoch=$loadEpoch',
    );

    Future<void> finishAfter(Duration delay) async {
      await Future<void>.delayed(delay);
      final canUseController = _canUseController(controller, webViewGeneration);
      if (!canUseController ||
          loadEpoch != _loadEpoch ||
          !_isLoading ||
          _preparedHtmlData == null) {
        _traceMeasurement(
          'fallback-skip',
          webViewGeneration: webViewGeneration,
          delayMs: delay.inMilliseconds,
          details:
              'canUseController=$canUseController scheduledEpoch=$loadEpoch '
              'currentEpoch=$_loadEpoch loading=$_isLoading '
              'prepared=${_preparedHtmlData != null}',
        );
        return;
      }
      _traceMeasurement(
        'fallback-fire',
        webViewGeneration: webViewGeneration,
        delayMs: delay.inMilliseconds,
      );
      _finishWebViewLoad(controller, webViewGeneration: webViewGeneration);
    }

    unawaited(finishAfter(const Duration(milliseconds: 800)));
    unawaited(finishAfter(const Duration(milliseconds: 1600)));
  }

  Future<double?> _measurePlatformContentHeight(
    InAppWebViewController controller, {
    required int? webViewGeneration,
    int? measurementEpoch,
  }) async {
    if (!_canMeasureContentHeight(
      controller,
      webViewGeneration,
      measurementEpoch,
    )) {
      return null;
    }
    int? rawHeight;
    try {
      rawHeight = await controller.getContentHeight();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
    if (!_canMeasureContentHeight(
          controller,
          webViewGeneration,
          measurementEpoch,
        ) ||
        rawHeight == null ||
        rawHeight <= 0) {
      return null;
    }
    var measuredHeight = rawHeight.toDouble();
    if (defaultTargetPlatform == TargetPlatform.android) {
      double? zoomScale;
      try {
        zoomScale = await controller.getZoomScale();
      } on MissingPluginException {
        return measuredHeight > 0 ? measuredHeight : null;
      } on PlatformException {
        return measuredHeight > 0 ? measuredHeight : null;
      }
      if (!_canMeasureContentHeight(
        controller,
        webViewGeneration,
        measurementEpoch,
      )) {
        return null;
      }
      measuredHeight *= zoomScale ?? 1.0;
    }
    _traceMeasurement(
      'platform-result',
      webViewGeneration: webViewGeneration,
      measuredHeight: measuredHeight,
    );
    return measuredHeight > 0 ? measuredHeight : null;
  }

  Future<double?> _scaleDomMeasuredHeightForDisplay(
    InAppWebViewController controller, {
    required double measuredHeight,
    required int? webViewGeneration,
    int? measurementEpoch,
  }) async {
    if (measuredHeight <= 0) {
      return null;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return measuredHeight;
    }
    double? zoomScale;
    try {
      zoomScale = await controller.getZoomScale();
    } on MissingPluginException {
      return measuredHeight;
    } on PlatformException {
      return measuredHeight;
    }
    if (!_canMeasureContentHeight(
      controller,
      webViewGeneration,
      measurementEpoch,
    )) {
      return null;
    }
    if (zoomScale == null || zoomScale <= 0) {
      return measuredHeight;
    }
    return measuredHeight * zoomScale;
  }

  Future<
    ({
      double? measuredHeight,
      double? scrollHeight,
      double? viewportHeight,
      double? contentWidth,
      double? viewportWidth,
      double? widthScale,
      int pendingImages,
      bool documentReady,
      bool imagesReady,
      bool fontsReady,
      bool widthFitReady,
      bool layoutStable,
      int layoutSequence,
    })
  >
  _measureDomContentHeight(
    InAppWebViewController controller, {
    required int? webViewGeneration,
    int? measurementEpoch,
  }) async {
    if (!_canMeasureContentHeight(
      controller,
      webViewGeneration,
      measurementEpoch,
    )) {
      return _emailDomContentHeightMetrics();
    }
    try {
      final result = await controller.evaluateJavascript(
        source: _emailDomHeightMetricsExpression(),
      );
      if (!_canMeasureContentHeight(
        controller,
        webViewGeneration,
        measurementEpoch,
      )) {
        return _emailDomContentHeightMetrics();
      }
      if (result is Map) {
        final measuredHeight = _parsePositiveDouble(result['measuredHeight']);
        final scrollHeight = _parsePositiveDouble(result['scrollHeight']);
        final viewportHeight = _parsePositiveDouble(result['viewportHeight']);
        final contentWidth = _parsePositiveDouble(result['contentWidth']);
        final viewportWidth = _parsePositiveDouble(result['viewportWidth']);
        final widthScale = _parsePositiveDouble(result['widthScale']);
        final pendingImages = _parseNonNegativeInt(result['pendingImages']);
        final documentReady = _parseBool(result['documentReady']);
        final imagesReady = _parseBool(result['imagesReady']);
        final fontsReady = _parseBool(result['fontsReady']);
        final widthFitReady = _parseBool(result['widthFitReady']);
        final layoutStable = _parseBool(result['layoutStable']);
        final layoutSequence = _parseNonNegativeInt(result['layoutSequence']);
        _traceMeasurement(
          'dom-result',
          webViewGeneration: webViewGeneration,
          measuredHeight: measuredHeight,
          scrollHeight: scrollHeight,
          viewportHeight: viewportHeight,
          contentWidth: contentWidth,
          viewportWidth: viewportWidth,
          widthScale: widthScale,
          pendingImages: pendingImages,
          documentReady: documentReady,
          imagesReady: imagesReady,
          fontsReady: fontsReady,
          widthFitReady: widthFitReady,
          layoutStable: layoutStable,
          layoutSequence: layoutSequence,
        );
        return _emailDomContentHeightMetrics(
          measuredHeight: measuredHeight,
          scrollHeight: scrollHeight,
          viewportHeight: viewportHeight,
          contentWidth: contentWidth,
          viewportWidth: viewportWidth,
          widthScale: widthScale,
          pendingImages: pendingImages,
          documentReady: documentReady,
          imagesReady: imagesReady,
          fontsReady: fontsReady,
          widthFitReady: widthFitReady,
          layoutStable: layoutStable,
          layoutSequence: layoutSequence,
        );
      }
      if (result is num) {
        final parsed = result > 0 ? result.toDouble() : null;
        return _emailDomContentHeightMetrics(
          measuredHeight: parsed,
          documentReady: parsed != null,
          imagesReady: parsed != null,
          fontsReady: parsed != null,
          widthFitReady: parsed != null,
          layoutStable: parsed != null,
        );
      }
      if (result is String) {
        final parsed = double.tryParse(result.trim());
        if (parsed != null && parsed > 0) {
          return _emailDomContentHeightMetrics(
            measuredHeight: parsed,
            documentReady: true,
            imagesReady: true,
            fontsReady: true,
            widthFitReady: true,
            layoutStable: true,
          );
        }
      }
    } on Exception catch (error) {
      _traceMeasurement(
        'dom-measure-exception',
        webViewGeneration: webViewGeneration,
        details: error.runtimeType.toString(),
      );
      return _emailDomContentHeightMetrics();
    }
    return _emailDomContentHeightMetrics();
  }

  Future<void> _installDocumentHeightObserver(
    InAppWebViewController controller, {
    required int webViewGeneration,
  }) async {
    if (widget.contentMode != EmailHtmlContentMode.safe ||
        _documentHeightObserverInstalled ||
        !_canUseController(controller, webViewGeneration)) {
      return;
    }
    try {
      await controller.evaluateJavascript(
        source: _emailDocumentHeightObserverExpression(),
      );
      if (!_canUseController(controller, webViewGeneration)) {
        return;
      }
      _documentHeightObserverInstalled = true;
      _traceMeasurement(
        'document-observer-installed',
        webViewGeneration: webViewGeneration,
      );
    } on Exception catch (error) {
      _documentHeightObserverInstalled = false;
      _traceMeasurement(
        'document-observer-exception',
        webViewGeneration: webViewGeneration,
        details: error.runtimeType.toString(),
      );
    }
  }

  void _scheduleLinuxPlatformViewResize() {
    if (defaultTargetPlatform != TargetPlatform.linux ||
        _linuxPlatformViewResizeScheduled) {
      return;
    }
    _linuxPlatformViewResizeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _linuxPlatformViewResizeScheduled = false;
      await _syncLinuxPlatformViewBounds();
    });
  }

  Future<void> _syncLinuxPlatformViewBounds() async {
    if (!mounted || defaultTargetPlatform != TargetPlatform.linux) {
      return;
    }
    final controller = _controller;
    final webViewGeneration = controller == null
        ? null
        : _webViewGenerationForController(controller);
    if (controller == null ||
        !_canUseController(controller, webViewGeneration)) {
      return;
    }
    final renderObject =
        _platformViewSizeKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderObject == null || !renderObject.hasSize) {
      return;
    }
    final size = renderObject.size;
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    dynamic viewId;
    try {
      viewId = controller.platform.getViewId();
    } on UnimplementedError {
      return;
    }
    if (!_canUseController(controller, webViewGeneration) || viewId is! int) {
      return;
    }
    final offset = renderObject.localToGlobal(Offset.zero);
    final sizeChanged =
        _lastLinuxPlatformViewId != viewId ||
        _lastLinuxPlatformViewSize != size;
    final offsetChanged =
        _lastLinuxPlatformViewId != viewId ||
        _lastLinuxPlatformViewOffset != offset;
    if (!sizeChanged && !offsetChanged) {
      return;
    }
    final channel = MethodChannel(
      'com.pichillilorenzo/custom_platform_view_$viewId',
    );
    try {
      if (sizeChanged) {
        await channel.invokeMethod<void>('setSize', [
          size.width,
          size.height,
          View.of(context).devicePixelRatio,
        ]);
      }
      if (!_canUseController(controller, webViewGeneration)) {
        return;
      }
      if (sizeChanged || offsetChanged) {
        await channel.invokeMethod<void>('setTextureOffset', [
          offset.dx,
          offset.dy,
        ]);
      }
      if (!_canUseController(controller, webViewGeneration)) {
        return;
      }
      _lastLinuxPlatformViewId = viewId;
      _lastLinuxPlatformViewSize = size;
      _lastLinuxPlatformViewOffset = offset;
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  void _updateContentHeight(
    double height, {
    bool canCommitHeight = true,
    int layoutSequence = 0,
  }) {
    if (!mounted || height <= 0) {
      return;
    }
    final resolved = _resolveEmailHtmlContentHeightAfterReport(
      currentContentHeight: _contentHeight,
      isLoading: _isLoading,
      usesHeightBridge: _usesHeightBridge,
      reportedHeight: height,
      canCommitHeight: canCommitHeight,
    );
    if (!resolved.committed) {
      _traceMeasurement(
        'height-deferred',
        measuredHeight: height.ceilToDouble(),
        layoutSequence: layoutSequence,
      );
      return;
    }
    setState(() {
      _contentHeight = resolved.contentHeight;
      _isLoading = resolved.isLoading;
    });
    final contentHeight = resolved.contentHeight;
    if (contentHeight != null) {
      widget.onContentHeightChanged?.call(contentHeight);
    }
    _traceMeasurement('height-updated', measuredHeight: resolved.contentHeight);
    _scheduleLinuxPlatformViewResize();
  }

  void _updateLinuxContentHeightMetrics({
    required double measuredHeight,
    double? scrollHeight,
    double? viewportHeight,
    bool canCommitHeight = true,
    int layoutSequence = 0,
  }) {
    if (!mounted || measuredHeight <= 0) {
      return;
    }
    var normalizedHeight = measuredHeight.ceilToDouble();
    final currentHeight = _contentHeight;
    if (_usesHeightBridge && !canCommitHeight) {
      _traceMeasurement(
        'height-deferred',
        measuredHeight: normalizedHeight,
        layoutSequence: layoutSequence,
      );
      return;
    }
    final normalizedScrollHeight = scrollHeight?.ceilToDouble();
    final normalizedViewportHeight = viewportHeight?.ceilToDouble();
    final documentFitsViewport =
        normalizedScrollHeight != null &&
        normalizedViewportHeight != null &&
        normalizedScrollHeight <= normalizedViewportHeight + 1;
    final documentOverflowsViewport =
        normalizedScrollHeight != null &&
        normalizedViewportHeight != null &&
        normalizedScrollHeight > normalizedViewportHeight + 1;

    if (documentOverflowsViewport) {
      _linuxFitLockedHeight = null;
    }

    final fitLockedHeight = _linuxFitLockedHeight;
    if (documentFitsViewport &&
        fitLockedHeight != null &&
        normalizedHeight > fitLockedHeight) {
      return;
    }
    if (currentHeight == normalizedHeight) {
      if (documentFitsViewport) {
        _linuxFitLockedHeight = normalizedHeight;
      }
      if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }
    setState(() {
      _contentHeight = normalizedHeight;
      _isLoading = false;
    });
    widget.onContentHeightChanged?.call(normalizedHeight);
    if (documentFitsViewport) {
      _linuxFitLockedHeight = normalizedHeight;
    }
    _scheduleLinuxPlatformViewResize();
  }

  Future<void> _updateHeightBridgeMetrics(
    InAppWebViewController controller, {
    required int webViewGeneration,
    required double measuredHeight,
    double? scrollHeight,
    double? viewportHeight,
    double? contentWidth,
    double? viewportWidth,
    double? widthScale,
    int pendingImages = 0,
    bool documentReady = true,
    bool imagesReady = true,
    bool fontsReady = true,
    bool widthFitReady = true,
    bool layoutStable = true,
    int layoutSequence = 0,
  }) async {
    if (!_canMeasureContentHeight(controller, webViewGeneration, null)) {
      return;
    }
    _traceMeasurement(
      'bridge-result',
      webViewGeneration: webViewGeneration,
      measuredHeight: measuredHeight,
      scrollHeight: scrollHeight,
      viewportHeight: viewportHeight,
      contentWidth: contentWidth,
      viewportWidth: viewportWidth,
      widthScale: widthScale,
      pendingImages: pendingImages,
      documentReady: documentReady,
      imagesReady: imagesReady,
      fontsReady: fontsReady,
      widthFitReady: widthFitReady,
      layoutStable: layoutStable,
      layoutSequence: layoutSequence,
    );
    final canCommitHeight = _emailHtmlHeightCanCommit(
      hasPositiveHeight: measuredHeight > 0,
      usesPlatformFallback: false,
      documentReady: documentReady,
      imagesReady: imagesReady,
      widthFitReady: widthFitReady,
      layoutStable: layoutStable,
    );
    if (defaultTargetPlatform == TargetPlatform.linux) {
      _updateLinuxContentHeightMetrics(
        measuredHeight: measuredHeight,
        scrollHeight: scrollHeight,
        viewportHeight: viewportHeight,
        canCommitHeight: canCommitHeight,
        layoutSequence: layoutSequence,
      );
      return;
    }
    final scaledHeight = await _scaleDomMeasuredHeightForDisplay(
      controller,
      measuredHeight: measuredHeight,
      webViewGeneration: webViewGeneration,
    );
    if (scaledHeight == null ||
        !_canMeasureContentHeight(controller, webViewGeneration, null)) {
      return;
    }
    _updateContentHeight(
      scaledHeight,
      canCommitHeight: canCommitHeight,
      layoutSequence: layoutSequence,
    );
  }

  void _handleOriginalEmailLink(String value) {
    final safeUrl = _safeEmailLinkUrl(value);
    if (safeUrl == null) {
      return;
    }
    widget.onLinkTap(safeUrl);
  }

  double? _parsePositiveDouble(dynamic value) {
    return switch (value) {
      num number when number > 0 => number.toDouble(),
      String text => double.tryParse(text.trim()),
      _ => null,
    };
  }

  int _parseNonNegativeInt(dynamic value) {
    return switch (value) {
      num number when number >= 0 => number.floor(),
      String text => math.max(int.tryParse(text.trim()) ?? 0, 0),
      _ => 0,
    };
  }

  bool _parseBool(dynamic value) {
    return switch (value) {
      bool flag => flag,
      num number => number != 0,
      String text => switch (text.trim().toLowerCase()) {
        'true' || '1' => true,
        _ => false,
      },
      _ => false,
    };
  }

  String _buildThemeStyle({required Brightness brightness}) {
    return _buildEmailWebViewThemeStyle(
      brightness: brightness,
      backgroundColor: widget.backgroundColor,
      baseFontSize: widget.baseFontSize,
    );
  }

  bool get _usesHeightBridge => _usesDomContentHeightMeasurement(
    contentMode: widget.contentMode,
    platform: defaultTargetPlatform,
  );

  InAppWebViewSettings _webViewSettings() {
    return buildEmailHtmlWebViewSettings(
      usesInternalScroll: widget._usesInternalScroll,
      useHybridComposition: widget.useHybridComposition,
      simplifyLayout: widget.simplifyLayout,
      allowRemoteImages: widget.allowRemoteImages,
      contentMode: widget.contentMode,
    );
  }

  Key get _webViewSettingsKey => ValueKey<String>(
    [
      widget._mode.name,
      widget.simplifyLayout,
      widget.useHybridComposition,
    ].join(':'),
  );

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    if (defaultTargetPlatform == TargetPlatform.linux && _controller != null) {
      _scheduleLinuxPlatformViewResize();
    }

    final loadingOverlay = Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: widget.backgroundColor.withValues(alpha: 0.76),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.m),
              child: const AxiProgressIndicator(),
            ),
          ),
        ),
      ),
    );

    final webView = _preparedHtmlData == null
        ? null
        : InAppWebView(
            key: _webViewSettingsKey,
            gestureRecognizers: !widget._usesInternalScroll
                ? _tapOnlyGestureRecognizers
                : null,
            initialData: InAppWebViewInitialData(
              data: _preparedHtmlData!,
              baseUrl: _emailWebViewUri,
              historyUrl: _emailWebViewUri,
            ),
            initialSettings: _webViewSettings(),
            onWebViewCreated: (controller) {
              final webViewGeneration = _beginWebViewGeneration(controller);
              _traceMeasurement(
                'created',
                webViewGeneration: webViewGeneration,
              );
              _heightMeasurementEpoch++;
              _scheduleLoadCompletionFallback(
                controller,
                webViewGeneration: webViewGeneration,
              );
              _scheduleLinuxPlatformViewResize();
              if (_usesHeightBridge) {
                controller.addJavaScriptHandler(
                  handlerName: _heightHandlerName,
                  callback: (arguments) {
                    if (!_canUseController(controller, webViewGeneration)) {
                      return null;
                    }
                    if (arguments.isEmpty) {
                      return null;
                    }
                    final value = arguments.first;
                    if (value is Map) {
                      final measuredHeight = _parsePositiveDouble(
                        value['measuredHeight'],
                      );
                      if (measuredHeight != null) {
                        unawaited(
                          _updateHeightBridgeMetrics(
                            controller,
                            webViewGeneration: webViewGeneration,
                            measuredHeight: measuredHeight,
                            scrollHeight: _parsePositiveDouble(
                              value['scrollHeight'],
                            ),
                            viewportHeight: _parsePositiveDouble(
                              value['viewportHeight'],
                            ),
                            contentWidth: _parsePositiveDouble(
                              value['contentWidth'],
                            ),
                            viewportWidth: _parsePositiveDouble(
                              value['viewportWidth'],
                            ),
                            widthScale: _parsePositiveDouble(
                              value['widthScale'],
                            ),
                            pendingImages: _parseNonNegativeInt(
                              value['pendingImages'],
                            ),
                            documentReady: _parseBool(value['documentReady']),
                            imagesReady: _parseBool(value['imagesReady']),
                            fontsReady: _parseBool(value['fontsReady']),
                            widthFitReady: _parseBool(value['widthFitReady']),
                            layoutStable: _parseBool(value['layoutStable']),
                            layoutSequence: _parseNonNegativeInt(
                              value['layoutSequence'],
                            ),
                          ),
                        );
                      }
                    } else {
                      final parsed = _parsePositiveDouble(value);
                      if (parsed != null) {
                        unawaited(
                          _updateHeightBridgeMetrics(
                            controller,
                            webViewGeneration: webViewGeneration,
                            measuredHeight: parsed,
                          ),
                        );
                      }
                    }
                    return null;
                  },
                );
              }
              controller.addJavaScriptHandler(
                handlerName: _linkHandlerName,
                callback: (arguments) {
                  if (!_canUseController(controller, webViewGeneration)) {
                    return null;
                  }
                  if (arguments.isEmpty) {
                    return null;
                  }
                  final value = arguments.first;
                  if (value is String) {
                    _handleOriginalEmailLink(value);
                  }
                  return null;
                },
              );
              if (_reloadPreparedHtmlWhenControllerReady &&
                  _preparedHtmlData != null) {
                _reloadPreparedHtmlWhenControllerReady = false;
                unawaited(_loadHtml());
              }
            },
            onPageCommitVisible: (controller, url) {
              final webViewGeneration = _webViewGenerationForController(
                controller,
              );
              if (webViewGeneration != null) {
                _traceMeasurement(
                  'commit-visible',
                  webViewGeneration: webViewGeneration,
                );
                _finishWebViewLoad(
                  controller,
                  webViewGeneration: webViewGeneration,
                );
              }
            },
            onProgressChanged: (controller, progress) {
              final webViewGeneration = _webViewGenerationForController(
                controller,
              );
              if (webViewGeneration == null) {
                return;
              }
              final progressLogBucket = progress >= 100 ? 100 : progress ~/ 25;
              if (_lastProgressLogBucket != progressLogBucket ||
                  progress >= 100) {
                _lastProgressLogBucket = progressLogBucket;
                _traceMeasurement(
                  'progress',
                  webViewGeneration: webViewGeneration,
                  progress: progress,
                );
              }
              if (progress >= 100) {
                _finishWebViewLoad(
                  controller,
                  webViewGeneration: webViewGeneration,
                );
              }
            },
            onContentSizeChanged: (controller, oldContentSize, newContentSize) {
              final webViewGeneration = _webViewGenerationForController(
                controller,
              );
              if (!_canUseController(controller, webViewGeneration)) {
                return;
              }
              if (_usesPlatformContentHeightMeasurement(
                contentMode: widget.contentMode,
                platform: defaultTargetPlatform,
              )) {
                _updateContentHeight(newContentSize.height);
              }
              _traceMeasurement(
                'content-size',
                webViewGeneration: webViewGeneration,
                contentSize: Size(newContentSize.width, newContentSize.height),
              );
              _scheduleContentHeightMeasurements(
                controller: controller,
                webViewGeneration: webViewGeneration,
              );
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
            onDownloadStarting: (controller, downloadStartRequest) {
              final url = downloadStartRequest.url.toString().trim();
              if (url.isNotEmpty && !url.startsWith(_emailWebViewBaseUrl)) {
                widget.onLinkTap(url);
              }
              return DownloadStartResponse(
                action: DownloadStartResponseAction.CANCEL,
                handled: true,
              );
            },
            onLoadStop: (controller, url) {
              final webViewGeneration = _webViewGenerationForController(
                controller,
              );
              if (webViewGeneration == null ||
                  !_canUseController(controller, webViewGeneration)) {
                return;
              }
              _traceMeasurement(
                'load-stop',
                webViewGeneration: webViewGeneration,
              );
              _finishWebViewLoad(
                controller,
                webViewGeneration: webViewGeneration,
              );
              unawaited(
                _completeLoadStopSizing(
                  controller,
                  webViewGeneration: webViewGeneration,
                ),
              );
            },
            onReceivedError: (controller, request, error) {
              final webViewGeneration = _webViewGenerationForController(
                controller,
              );
              if (!_canUseController(controller, webViewGeneration)) return;
              _traceMeasurement(
                'load-error',
                webViewGeneration: webViewGeneration,
                details:
                    'mainFrame=${request.isForMainFrame} type=${error.type}',
              );
              if (_preparedHtmlData != null || request.isForMainFrame == true) {
                _finishWebViewLoad(
                  controller,
                  webViewGeneration: webViewGeneration!,
                );
              }
            },
            onReceivedHttpError: (controller, request, errorResponse) {
              final webViewGeneration = _webViewGenerationForController(
                controller,
              );
              if (!_canUseController(controller, webViewGeneration)) return;
              _traceMeasurement(
                'load-http-error',
                webViewGeneration: webViewGeneration,
                details:
                    'mainFrame=${request.isForMainFrame} '
                    'status=${errorResponse.statusCode}',
              );
              if (_preparedHtmlData != null || request.isForMainFrame == true) {
                _finishWebViewLoad(
                  controller,
                  webViewGeneration: webViewGeneration!,
                );
              }
            },
          );

    final loadingLayout = _resolveEmailHtmlWebViewLoadingLayout(
      hasLoadingFallback: widget.loadingFallback != null,
      hasWebView: webView != null,
      hasPreparedHtmlData: _preparedHtmlData != null,
      hasContentHeight: _contentHeight != null,
      isLoading: _isLoading,
    );
    final webViewVisibility = _resolveEmailHtmlWebViewVisibility(
      hasWebView: webView != null,
      paintWebView: loadingLayout.paintWebView,
      paintContent: widget.paintContent,
    );
    final webViewStack = Stack(
      children: [
        if (loadingLayout.paintLoadingFallback)
          widget.loadingFallback!
        else if (loadingLayout.preserveLoadingFallback)
          Visibility(
            visible: false,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: widget.loadingFallback!,
          ),
        if (webView != null && webViewVisibility.includeWebView)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !webViewVisibility.visible,
              child: Visibility(
                visible: webViewVisibility.visible,
                maintainState: webViewVisibility.maintainState,
                maintainAnimation: true,
                maintainSize: true,
                child: webView,
              ),
            ),
          ),
        if (loadingLayout.showLoadingOverlay) loadingOverlay,
      ],
    );
    final preservedMinHeight = loadingLayout.preserveMeasuredHeight
        ? _resolvedHeight
        : widget.minHeight;

    return SizedBox(
      key: _platformViewSizeKey,
      width: double.infinity,
      height: loadingLayout.useFixedHeight ? _resolvedHeight : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: preservedMinHeight),
        child: ClipRect(child: webViewStack),
      ),
    );
  }
}
