// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/unicode_safety.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

String? normalizeAddress(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String? normalizedAddressValue(String? raw) {
  final normalized = normalizeAddress(raw);
  return normalized?.toLowerCase();
}

String normalizedAddressValueOrEmpty(String? raw) {
  return normalizedAddressValue(raw) ?? '';
}

mox.JID? parseJid(String? raw) {
  final normalized = normalizeAddress(raw);
  if (normalized == null) return null;
  try {
    return mox.JID.fromString(normalized);
  } on Exception {
    return null;
  }
}

mox.JID parseJidOrThrow(String raw) {
  final normalized = normalizeAddress(raw);
  if (normalized == null) {
    throw const FormatException('Empty JID');
  }
  return mox.JID.fromString(normalized);
}

String? bareAddress(String? raw) {
  final normalized = normalizeAddress(raw);
  if (normalized == null) return null;
  final parsed = parseJid(normalized);
  if (parsed == null) {
    return _stripResource(normalized);
  }
  return parsed.toBare().toString();
}

String? bareAddressValue(String? raw) {
  if (raw == null) return null;
  final index = raw.indexOf('/');
  if (index == -1) return raw;
  return raw.substring(0, index);
}

String? normalizedBareAddressValue(String? raw) {
  final normalized = normalizeAddress(raw);
  if (normalized == null) return null;
  final parsed = parseJid(normalized);
  if (parsed == null) {
    return normalized.toLowerCase();
  }
  return parsed.toBare().toString().toLowerCase();
}

String? bareAddressOrNull(String? raw, {int? maxBytes}) {
  final normalized = normalizeAddress(raw);
  if (normalized == null) return null;
  if (maxBytes != null &&
      !isWithinUtf8ByteLimit(normalized, maxBytes: maxBytes)) {
    return null;
  }
  final parsed = parseJid(normalized);
  if (parsed == null) return null;
  return parsed.toBare().toString();
}

String? fullAddress(String? raw) {
  final normalized = normalizeAddress(raw);
  if (normalized == null) return null;
  final parsed = parseJid(normalized);
  return parsed?.toString() ?? normalized;
}

String? fullAddressLower(String? raw) {
  final resolved = fullAddress(raw);
  return resolved?.toLowerCase();
}

String? normalizedAddressKey(String? raw) {
  final normalized = normalizeAddress(raw);
  if (normalized == null) return null;
  final parsed = parseJid(normalized);
  if (parsed != null) {
    return parsed.toBare().toString().toLowerCase();
  }
  final bare = bareAddressValue(normalized) ?? normalized;
  return bare.toLowerCase();
}

String normalizedAddressKeyOrEmpty(String? raw) {
  return normalizedAddressKey(raw) ?? '';
}

bool sameNormalizedAddressValue(String? a, String? b) {
  final left = normalizedAddressValue(a);
  final right = normalizedAddressValue(b);
  if (left == null || right == null) return false;
  return left == right;
}

bool sameBareAddress(String? a, String? b) {
  final left = normalizedAddressKey(a);
  final right = normalizedAddressKey(b);
  if (left == null || right == null) return false;
  return left == right;
}

bool sameFullAddress(String? a, String? b) {
  final left = fullAddressLower(a);
  final right = fullAddressLower(b);
  if (left == null || right == null) return false;
  return left == right;
}

bool isValidAddress(String? raw, {int? maxBytes}) {
  return bareAddressOrNull(raw, maxBytes: maxBytes) != null;
}

String? displaySafeAddress(String? raw, {bool includeResource = false}) {
  final normalized = normalizeAddress(raw);
  if (normalized == null) return null;
  final value =
      includeResource ? fullAddress(normalized) : bareAddress(normalized);
  final fallback = value ?? normalized;
  return sanitizeUnicodeControls(fallback).value;
}

String? normalizedOccupantId(String? raw) {
  final normalized = normalizeAddress(raw);
  if (normalized == null) return null;
  final parsed = parseJid(normalized);
  if (parsed == null) {
    return normalized.toLowerCase();
  }
  final bare = parsed.toBare().toString().toLowerCase();
  final resource = parsed.resource.trim();
  if (resource.isEmpty) {
    return bare;
  }
  return '$bare/${resource.toLowerCase()}';
}

String? addressLocalPart(String? raw) {
  final parsed = parseJid(raw);
  if (parsed != null) {
    return parsed.local.trim();
  }
  final normalized = normalizeAddress(raw);
  if (normalized == null) return null;
  final atIndex = normalized.indexOf('@');
  if (atIndex == -1) return null;
  return normalized.substring(0, atIndex).trim();
}

String? addressDomainPart(String? raw) {
  final normalized = normalizeAddress(raw);
  if (normalized == null || !normalized.contains('@')) {
    return null;
  }
  final parts = normalized.split('@');
  if (parts.length != 2) {
    return null;
  }
  final domain = parts.last.trim();
  return domain.isEmpty ? null : domain;
}

({String localPart, String domainPart})? addressAutocompleteParts(String? raw) {
  final normalized = normalizeAddress(raw);
  if (normalized == null) return null;
  final atIndex = normalized.indexOf('@');
  if (atIndex <= 0) return null;
  final localPart = normalized.substring(0, atIndex).trim();
  if (localPart.isEmpty) return null;
  final domainPart = normalized.substring(atIndex + 1).trim();
  return (localPart: localPart, domainPart: domainPart);
}

String? addressResourcePart(String? raw) {
  final parsed = parseJid(raw);
  if (parsed == null) return null;
  final resource = parsed.resource.trim();
  return resource.isEmpty ? null : resource;
}

bool isAxiJid(String? raw, {String? axiDomain}) {
  return _isAxiJidInternal(raw, axiDomain: axiDomain);
}

bool _isAxiJidInternal(String? raw, {String? axiDomain}) {
  final targetDomain = _normalizeDomain(axiDomain);
  if (targetDomain == null) return false;
  final domain = _domainFromBare(raw);
  if (domain == null) return false;
  return domain == targetDomain;
}

String? _normalizeDomain(String? domain) {
  final resolved = domain ?? EndpointConfig.defaultDomain;
  final trimmed = resolved.trim().toLowerCase();
  return trimmed.isEmpty ? null : trimmed;
}

String? _domainFromBare(String? raw) {
  final bare = bareAddress(raw);
  if (bare == null) return null;
  final domain = addressDomainPart(bare)?.toLowerCase();
  return domain == null || domain.isEmpty ? null : domain;
}

String _stripResource(String raw) {
  final index = raw.indexOf('/');
  if (index == -1) return raw;
  final bare = raw.substring(0, index).trim();
  return bare.isEmpty ? raw : bare;
}

extension AddressStringExtensions on String {
  String? get normalizedJid => normalizeAddress(this);

  String? get bareJid => bareAddress(this);

  String? get bareJidOrNull => bareAddressOrNull(this);

  String? toBareJidOrNull({required int maxBytes}) =>
      bareAddressOrNull(this, maxBytes: maxBytes);

  String? get normalizedJidKey => normalizedAddressKey(this);

  bool sameBare(String? other) => sameBareAddress(this, other);

  bool sameFull(String? other) => sameFullAddress(this, other);

  bool get isValidJid => isValidAddress(this);

  bool get isAxiJid => _isAxiJidInternal(this);

  String? get displaySafeJid => displaySafeAddress(this);

  mox.JID toJid() => parseJidOrThrow(this);

  mox.JID? toJidOrNull() => parseJid(this);
}

extension NullableAddressExtensions on String? {
  String? get normalizedJid => normalizeAddress(this);

  String? get bareJid => bareAddress(this);

  String? get normalizedJidKey => normalizedAddressKey(this);

  String? get displaySafeJid => displaySafeAddress(this);

  bool sameBare(String? other) => sameBareAddress(this, other);

  bool sameFull(String? other) => sameFullAddress(this, other);
}
