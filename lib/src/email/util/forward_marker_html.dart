// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/html_content.dart';

class ForwardMarkerHtmlCodec {
  static const String _markerAttribute = 'data-axichat-forwarded';
  static const String _markerValue = 'synthetic';
  static const String _markerStyle = 'display:none';
  static const String _markerText = '\u2060\u2061\u2062';
  static const String _markerElementPatternSource =
      '<span\\b[^>]*$_markerAttribute="$_markerValue"[^>]*>.*?</span>';

  static final RegExp _markerElementPattern = RegExp(
    _markerElementPatternSource,
    caseSensitive: false,
    dotAll: true,
  );

  static String? inject(String? html) {
    final normalized = HtmlContentCodec.normalizeHtml(html);
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (hasMarker(normalized)) {
      return normalized;
    }
    return '$_markerElement$normalized';
  }

  static bool hasMarker(String? html) {
    final normalized = HtmlContentCodec.normalizeHtml(html);
    if (normalized == null || normalized.isEmpty) {
      return false;
    }
    return _markerElementPattern.hasMatch(normalized);
  }

  static String? strip(String? html) {
    final normalized = HtmlContentCodec.normalizeHtml(html);
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final cleaned = normalized.replaceAll(_markerElementPattern, '').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static const String _markerElement =
      '<span '
      '$_markerAttribute="$_markerValue" '
      'style="$_markerStyle">'
      '$_markerText'
      '</span>';
}
