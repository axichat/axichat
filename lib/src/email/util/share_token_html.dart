// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';

class ShareTokenHtmlCodec {
  static const String _tokenDataAttribute = 'data-axichat-share-token';
  static const String _tokenRoleAttribute = 'data-axichat-share-token-role';
  static const String _tokenRolePrefix = 'prefix';
  static const String _tokenRoleFooter = 'footer';
  static const String _tokenHiddenStyle = 'display:none';
  static const String _tokenStyleAttribute = 'style';
  static const String _tokenTagName = 'span';
  static const String _tokenFooterSeparator = '<br /><br />';
  static const String _emptyBody = '';
  static const String _space = ' ';
  static const String _tokenElementPatternSource =
      '<$_tokenTagName\\b[^>]*$_tokenDataAttribute="[^"]+"[^>]*>.*?</$_tokenTagName>';
  static const String _tokenFooterSeparatorPatternSuffix = r'\s*$';

  static final RegExp _tokenElementPattern = RegExp(
    _tokenElementPatternSource,
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _tokenFooterSeparatorPattern = RegExp(
    '${RegExp.escape(_tokenFooterSeparator)}$_tokenFooterSeparatorPatternSuffix',
    caseSensitive: false,
  );

  static String? injectToken({
    required String? html,
    required String token,
    bool asSignature = false,
  }) {
    final normalized = HtmlContentCodec.normalizeHtml(html);
    if (normalized == null) return null;

    final plain = HtmlContentCodec.toPlainText(normalized);
    if (ShareTokenCodec.stripToken(plain) != null) {
      return normalized;
    }

    final trimmed = normalized.trim();
    final tokenText = asSignature
        ? ShareTokenCodec.injectToken(
            token: token,
            body: _emptyBody,
            asSignature: true,
          )
        : ShareTokenCodec.decorateToken(token);
    final role = asSignature ? _tokenRoleFooter : _tokenRolePrefix;
    final tokenElement = _buildTokenElement(
      token: token,
      text: tokenText,
      role: role,
    );

    if (asSignature) {
      return '$trimmed$_tokenFooterSeparator$tokenElement';
    }
    return '$tokenElement$_space$trimmed';
  }

  static String? stripInjectedToken(String? html) {
    final normalized = HtmlContentCodec.normalizeHtml(html);
    if (normalized == null) return null;
    final withoutToken = normalized.replaceAll(_tokenElementPattern, '');
    final trimmed = withoutToken.trim();
    final cleaned = trimmed.replaceAll(_tokenFooterSeparatorPattern, '');
    return cleaned.trim();
  }

  static ShareTokenParseResult? parseToken({
    required String? plainText,
    required String? html,
  }) {
    final direct = ShareTokenCodec.stripToken(plainText);
    if (direct != null) {
      return direct;
    }
    final normalized = HtmlContentCodec.normalizeHtml(html);
    if (normalized == null) return null;
    final plain = HtmlContentCodec.toPlainText(normalized);
    return ShareTokenCodec.stripToken(plain);
  }

  static String _buildTokenElement({
    required String token,
    required String text,
    required String role,
  }) {
    final encodedText = HtmlContentCodec.fromPlainText(text);
    return '<$_tokenTagName '
        '$_tokenDataAttribute="$token" '
        '$_tokenRoleAttribute="$role" '
        '$_tokenStyleAttribute="$_tokenHiddenStyle">'
        '$encodedText'
        '</$_tokenTagName>';
  }
}
