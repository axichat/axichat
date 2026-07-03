// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/url_safety.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

final messageLinkPattern = RegExp(
  r'((https?:\/\/|mailto:|xmpp:|www\.)[^\s<>()\[\]{}]+)',
  caseSensitive: false,
);

String trimTrailingLinkPunctuation(String value) {
  var trimmed = value;
  while (trimmed.isNotEmpty &&
      '.,!?:;)'.contains(trimmed[trimmed.length - 1])) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

String normalizeMessageLink(String value) {
  final trimmed = value.trim();
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('mailto:') ||
      lower.startsWith('xmpp:')) {
    return trimmed;
  }
  if (lower.startsWith('www.')) {
    return 'https://$trimmed';
  }
  return 'https://$trimmed';
}

({String url, String filename, String? mimeType})? firstMediaLinkInText(
  String? text,
) {
  for (final url in safeHttpsMessageLinksInText(text)) {
    final uri = Uri.parse(url);
    final media = _mediaLinkForUri(uri);
    if (media == null) continue;
    return (url: url, filename: media.filename, mimeType: media.mimeType);
  }
  return null;
}

Iterable<String> safeHttpsMessageLinksInText(String? text) =>
    safeMessageAttachmentLinksInText(text);

Iterable<String> safeMessageAttachmentLinksInText(
  String? text, {
  bool allowHttp = false,
}) sync* {
  if (text == null || text.isEmpty) return;
  final seen = <String>{};
  for (final match in messageLinkPattern.allMatches(text)) {
    final normalized = normalizeMessageLink(
      trimTrailingLinkPunctuation(match.group(0)!),
    );
    final uri = Uri.tryParse(normalized);
    if (uri == null || !isSafeAttachmentUri(uri)) {
      continue;
    }
    if (uri.scheme != 'https' && !(allowHttp && uri.scheme == 'http')) {
      continue;
    }
    if (seen.add(normalized)) yield normalized;
  }
}

String linkMediaFileMetadataId(String seed) => 'link-media-$seed';

bool isLinkMediaFileMetadata(String? id) =>
    id?.trim().startsWith('link-media-') ?? false;

String? _mediaMimeTypeForPath(String path) => lookupMimeType(path);

({String filename, String? mimeType})? _mediaLinkForUri(Uri uri) {
  return _mediaLinkForUriPath(uri) ?? _mediaLinkForUriQuery(uri);
}

({String filename, String? mimeType})? _mediaLinkForUriPath(Uri uri) {
  return _mediaLinkForPath(uri.path);
}

({String filename, String? mimeType})? _mediaLinkForPath(String path) {
  final filename = p.basename(path).trim();
  if (filename.isEmpty || filename == '/' || filename == '.') return null;
  final mimeType = _mediaMimeTypeForPath(path);
  if (_isMediaPreviewMimeType(mimeType)) {
    return (filename: filename, mimeType: mimeType);
  }
  return null;
}

({String filename, String? mimeType})? _mediaLinkForUriQuery(Uri uri) {
  for (final value in _queryValuesInOrder(uri)) {
    final media = _mediaLinkForQueryValue(value);
    if (media != null) return media;
  }
  return null;
}

Iterable<String> _queryValuesInOrder(Uri uri) sync* {
  if (uri.query.isEmpty) return;
  for (final part in uri.query.split('&')) {
    final separator = part.indexOf('=');
    if (separator < 0) continue;
    try {
      yield Uri.decodeQueryComponent(part.substring(separator + 1));
    } on FormatException {
      continue;
    }
  }
}

({String filename, String? mimeType})? _mediaLinkForQueryValue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme) {
    if (uri.scheme != 'https' || !isSafeAttachmentUri(uri)) return null;
    return _mediaLinkForUriPath(uri);
  }
  return uri == null ? _mediaLinkForPath(trimmed) : _mediaLinkForPath(uri.path);
}

bool _isMediaPreviewMimeType(String? mimeType) {
  if (mimeType == null || mimeType == 'image/svg+xml') return false;
  return mimeType.startsWith('image/') || mimeType.startsWith('video/');
}
