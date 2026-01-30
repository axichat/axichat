// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/unicode_safety.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

class AddressTools {
  const AddressTools._();

  static String? normalize(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static mox.JID? parse(String? raw) {
    final normalized = normalize(raw);
    if (normalized == null) return null;
    try {
      return mox.JID.fromString(normalized);
    } on Exception {
      return null;
    }
  }

  static mox.JID parseOrThrow(String raw) {
    final normalized = normalize(raw);
    if (normalized == null) {
      throw const FormatException('Empty JID');
    }
    return mox.JID.fromString(normalized);
  }

  static String? bare(String? raw) {
    final normalized = normalize(raw);
    if (normalized == null) return null;
    final parsed = parse(normalized);
    if (parsed == null) {
      return _stripResource(normalized);
    }
    return parsed.toBare().toString();
  }

  static String? bareOrNull(String? raw, {int? maxBytes}) {
    final normalized = normalize(raw);
    if (normalized == null) return null;
    if (maxBytes != null &&
        !isWithinUtf8ByteLimit(normalized, maxBytes: maxBytes)) {
      return null;
    }
    final parsed = parse(normalized);
    if (parsed == null) return null;
    return parsed.toBare().toString();
  }

  static String? full(String? raw) {
    final normalized = normalize(raw);
    if (normalized == null) return null;
    final parsed = parse(normalized);
    return parsed?.toString() ?? normalized;
  }

  static String? fullLower(String? raw) {
    final resolved = full(raw);
    return resolved?.toLowerCase();
  }

  static String? normalizedKey(String? raw) {
    final normalized = normalize(raw);
    if (normalized == null) return null;
    final parsed = parse(normalized);
    if (parsed == null) {
      return normalized.toLowerCase();
    }
    return parsed.toBare().toString().toLowerCase();
  }

  static bool sameBare(String? a, String? b) {
    final left = normalizedKey(a);
    final right = normalizedKey(b);
    if (left == null || right == null) return false;
    return left == right;
  }

  static bool sameFull(String? a, String? b) {
    final left = fullLower(a);
    final right = fullLower(b);
    if (left == null || right == null) return false;
    return left == right;
  }

  static bool isValid(String? raw, {int? maxBytes}) {
    return bareOrNull(raw, maxBytes: maxBytes) != null;
  }

  static String? displaySafe(String? raw, {bool includeResource = false}) {
    final normalized = normalize(raw);
    if (normalized == null) return null;
    final value = includeResource ? full(normalized) : bare(normalized);
    final fallback = value ?? normalized;
    return sanitizeUnicodeControls(fallback).value;
  }

  static String? localPart(String? raw) {
    final parsed = parse(raw);
    if (parsed == null) return null;
    final local = parsed.local.trim();
    return local.isEmpty ? null : local;
  }

  static String? domainPart(String? raw) {
    final parsed = parse(raw);
    if (parsed == null) return null;
    final domain = parsed.domain.trim();
    return domain.isEmpty ? null : domain;
  }

  static bool isAxiJid(String? raw, {String? axiDomain}) {
    final parsed = parse(raw);
    if (parsed == null) return false;
    final targetDomain = _normalizeDomain(axiDomain);
    if (targetDomain == null) return false;
    return parsed.domain.trim().toLowerCase() == targetDomain;
  }

  static bool isEmailJid(String? raw, {String? axiDomain}) {
    final parsed = parse(raw);
    if (parsed == null) return false;
    final targetDomain = _normalizeDomain(axiDomain);
    if (targetDomain == null) return true;
    return parsed.domain.trim().toLowerCase() != targetDomain;
  }

  static MessageTransport inferTransport(String? raw, {String? axiDomain}) {
    return isAxiJid(raw, axiDomain: axiDomain)
        ? MessageTransport.xmpp
        : MessageTransport.email;
  }

  static String? _normalizeDomain(String? domain) {
    final resolved = domain ?? EndpointConfig.defaultDomain;
    final trimmed = resolved.trim().toLowerCase();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _stripResource(String raw) {
    final index = raw.indexOf('/');
    if (index == -1) return raw;
    final bare = raw.substring(0, index).trim();
    return bare.isEmpty ? raw : bare;
  }
}

extension AddressStringExtensions on String {
  String? get normalizedJid => AddressTools.normalize(this);

  String? get bareJid => AddressTools.bare(this);

  String? get bareJidOrNull => AddressTools.bareOrNull(this);

  String? toBareJidOrNull({required int maxBytes}) =>
      AddressTools.bareOrNull(this, maxBytes: maxBytes);

  String? get normalizedJidKey => AddressTools.normalizedKey(this);

  bool sameBare(String? other) => AddressTools.sameBare(this, other);

  bool sameFull(String? other) => AddressTools.sameFull(this, other);

  bool get isValidJid => AddressTools.isValid(this);

  bool get isAxiJid => AddressTools.isAxiJid(this);

  bool get isEmailJid => AddressTools.isEmailJid(this);

  String? get displaySafeJid => AddressTools.displaySafe(this);

  MessageTransport get inferredTransport => AddressTools.inferTransport(this);

  mox.JID toJid() => AddressTools.parseOrThrow(this);

  mox.JID? toJidOrNull() => AddressTools.parse(this);
}

extension NullableAddressExtensions on String? {
  String? get normalizedJid => AddressTools.normalize(this);

  String? get bareJid => AddressTools.bare(this);

  String? get normalizedJidKey => AddressTools.normalizedKey(this);

  String? get displaySafeJid => AddressTools.displaySafe(this);

  bool sameBare(String? other) => AddressTools.sameBare(this, other);

  bool sameFull(String? other) => AddressTools.sameFull(this, other);
}
