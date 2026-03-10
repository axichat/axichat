// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/html_content.dart';

const _syntheticForwardHtmlMarkerAttribute = 'data-axichat-synthetic-forward';
const _syntheticForwardHtmlMarkerValue = '1';
const _syntheticForwardHtmlMarkerStyleAttribute = 'style';
const _syntheticForwardHtmlMarkerStyle = 'display:none';
const _syntheticForwardHtmlMarkerTag = 'span';
const _syntheticForwardHtmlMarkerElement =
    '<$_syntheticForwardHtmlMarkerTag '
    '$_syntheticForwardHtmlMarkerAttribute="$_syntheticForwardHtmlMarkerValue" '
    '$_syntheticForwardHtmlMarkerStyleAttribute="$_syntheticForwardHtmlMarkerStyle"></$_syntheticForwardHtmlMarkerTag>';

final RegExp _syntheticForwardHtmlMarkerPattern = RegExp(
  '<$_syntheticForwardHtmlMarkerTag\\b[^>]*$_syntheticForwardHtmlMarkerAttribute="$_syntheticForwardHtmlMarkerValue"[^>]*></$_syntheticForwardHtmlMarkerTag>',
  caseSensitive: false,
);

String injectSyntheticForwardHtmlMarker(String? html) {
  final normalizedHtml = HtmlContentCodec.normalizeHtml(html);
  if (normalizedHtml == null) {
    return _syntheticForwardHtmlMarkerElement;
  }
  if (hasSyntheticForwardHtmlMarker(html: normalizedHtml)) {
    return normalizedHtml;
  }
  return '$_syntheticForwardHtmlMarkerElement $normalizedHtml';
}

bool hasSyntheticForwardHtmlMarker({required String? html}) {
  final normalizedHtml = HtmlContentCodec.normalizeHtml(html);
  if (normalizedHtml == null) {
    return false;
  }
  return _syntheticForwardHtmlMarkerPattern.hasMatch(normalizedHtml);
}

String? stripSyntheticForwardHtmlMarker(String? html) {
  final normalizedHtml = HtmlContentCodec.normalizeHtml(html);
  if (normalizedHtml == null) {
    return null;
  }
  final cleanedHtml = normalizedHtml
      .replaceAll(_syntheticForwardHtmlMarkerPattern, '')
      .trim();
  return cleanedHtml.isEmpty ? null : cleanedHtml;
}
