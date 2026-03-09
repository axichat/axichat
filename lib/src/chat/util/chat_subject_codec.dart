// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/html_content.dart';

class ChatSubjectCodec {
  static const String _marker = '\u2060';
  static final RegExp _htmlTagPattern = RegExp(r'<\/?[a-zA-Z][^>]*>');

  static String composeXmppBody({
    required String body,
    required String? subject,
  }) {
    final trimmedBody = body.trim();
    final trimmedSubject = subject?.trim();
    final hasSubject = trimmedSubject?.isNotEmpty == true;
    final hasBody = trimmedBody.isNotEmpty;
    if (!hasSubject) {
      return trimmedBody;
    }
    if (!hasBody) {
      return '$_marker$trimmedSubject';
    }
    return '$_marker$trimmedSubject\n\n$trimmedBody';
  }

  static ({String? subject, String body}) splitXmppBody(String? text) {
    if (text == null || text.isEmpty || !text.startsWith(_marker)) {
      return (subject: null, body: text ?? '');
    }
    final raw = text.substring(1);
    final separatorIndex = raw.indexOf('\n\n');
    if (separatorIndex == -1) {
      final subject = raw.trim();
      return (subject: subject.isEmpty ? null : subject, body: '');
    }
    final subject = raw.substring(0, separatorIndex).trim();
    final body = raw.substring(separatorIndex + 2);
    return (subject: subject.isEmpty ? null : subject, body: body);
  }

  static ({String? subject, String body}) splitDisplayBody({
    required String? body,
    required String? subject,
  }) {
    final explicitSubject = subject?.trim();
    if (explicitSubject?.isNotEmpty == true) {
      return (subject: explicitSubject, body: body ?? '');
    }
    return splitXmppBody(body);
  }

  static String? previewText({
    required String? body,
    String? htmlBody,
    required String? subject,
  }) {
    final resolvedBody = _previewSourceBody(body: body, htmlBody: htmlBody);
    final explicitSubject = subject?.trim();
    if (explicitSubject?.isNotEmpty == true) {
      final trimmedBody = previewBodyText(
        stripRepeatedSubject(body: resolvedBody, subject: explicitSubject!),
      ).trim();
      if (trimmedBody.isNotEmpty) {
        return '$explicitSubject — $trimmedBody';
      }
      return explicitSubject;
    }
    final split = splitXmppBody(resolvedBody);
    final trimmedSubject = split.subject?.trim();
    final trimmedBody = previewBodyText(split.body).trim();
    if (trimmedSubject?.isNotEmpty == true && trimmedBody.isNotEmpty) {
      return '$trimmedSubject — $trimmedBody';
    }
    if (trimmedSubject?.isNotEmpty == true) {
      return trimmedSubject;
    }
    if (trimmedBody.isNotEmpty) {
      return trimmedBody;
    }
    return null;
  }

  static String stripRepeatedSubject({
    required String? body,
    required String subject,
  }) {
    final rawBody = body ?? '';
    final trimmedSubject = subject.trim();
    if (rawBody.isEmpty || trimmedSubject.isEmpty) {
      return rawBody;
    }
    final leadingTrimmed = rawBody.trimLeft();
    if (!_startsWithIgnoreCase(leadingTrimmed, trimmedSubject)) {
      return rawBody;
    }
    var remainder = leadingTrimmed.substring(trimmedSubject.length);
    remainder = remainder.replaceFirst(RegExp(r'^\s*(?:[:\-–—]\s*)?'), '');
    return remainder;
  }

  static String previewBodyText(String? body) {
    final rawBody = body?.trim();
    if (rawBody == null || rawBody.isEmpty) {
      return '';
    }
    if (!_htmlTagPattern.hasMatch(rawBody)) {
      return rawBody;
    }
    final plainText = HtmlContentCodec.toPlainText(rawBody).trim();
    return plainText.isEmpty ? rawBody : plainText;
  }

  static String _previewSourceBody({
    required String? body,
    required String? htmlBody,
  }) {
    final normalizedHtml = HtmlContentCodec.normalizeHtml(htmlBody);
    if (normalizedHtml != null) {
      final plainText = HtmlContentCodec.toPlainText(normalizedHtml).trim();
      if (plainText.isNotEmpty) {
        return plainText;
      }
    }
    return body ?? '';
  }

  static bool _startsWithIgnoreCase(String value, String prefix) =>
      value.length >= prefix.length &&
      value.substring(0, prefix.length).toLowerCase() == prefix.toLowerCase();
}
