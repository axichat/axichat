// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

class XmppPushRegistrationException extends XmppException {
  XmppPushRegistrationException([super.wrapped]);
}

class XmppPushUnsupportedException extends XmppPushRegistrationException {}

final class XmppPushRegistrationIntent {
  const XmppPushRegistrationIntent({
    required this.bareJid,
    required this.apnsToken,
    required this.componentJid,
    required this.pushModule,
    required this.environment,
    required this.bundleId,
    required this.registeredAt,
  });

  final String bareJid;
  final String apnsToken;
  final String componentJid;
  final String pushModule;
  final String environment;
  final String bundleId;
  final DateTime registeredAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'bareJid': bareJid,
    'token': apnsToken,
    'environment': environment,
    'bundleId': bundleId,
    'xmppRegistered': true,
    'fpushComponentJid': componentJid,
    'fpushIosPushModule': pushModule,
    'registeredAt': registeredAt.toUtc().toIso8601String(),
  };

  static XmppPushRegistrationIntent? fromJson(Object? value) {
    if (value is! Map) return null;
    final bareJid = normalizedAddressKey(value['bareJid']?.toString());
    final apnsToken = (value['token'] ?? value['apnsToken'])
        ?.toString()
        .trim()
        .toLowerCase();
    final componentJid = normalizedAddressKey(
      (value['fpushComponentJid'] ?? value['componentJid'])?.toString(),
    );
    final pushModule = (value['fpushIosPushModule'] ?? value['pushModule'])
        ?.toString()
        .trim();
    final environment = value['environment']?.toString().trim();
    final bundleId = value['bundleId']?.toString().trim();
    final registeredAt =
        DateTime.tryParse(value['registeredAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    if (bareJid == null ||
        bareJid.isEmpty ||
        apnsToken == null ||
        apnsToken.isEmpty ||
        componentJid == null ||
        componentJid.isEmpty ||
        pushModule == null ||
        pushModule.isEmpty ||
        environment == null ||
        environment.isEmpty ||
        bundleId == null ||
        bundleId.isEmpty) {
      return null;
    }
    return XmppPushRegistrationIntent(
      bareJid: bareJid,
      apnsToken: apnsToken,
      componentJid: componentJid,
      pushModule: pushModule,
      environment: environment,
      bundleId: bundleId,
      registeredAt: registeredAt,
    );
  }

  bool hasSameDisableTarget(XmppPushRegistrationIntent other) {
    return bareJid == other.bareJid &&
        apnsToken == other.apnsToken &&
        componentJid == other.componentJid;
  }

  bool hasSameRegistrationTarget(XmppPushRegistrationIntent other) {
    return hasSameDisableTarget(other) &&
        pushModule == other.pushModule &&
        environment == other.environment &&
        bundleId == other.bundleId;
  }

  String get cleanupTargetKey {
    return [bareJid, apnsToken, componentJid].join('\u{1f}');
  }
}

final class XmppPushRegistrationRecord {
  const XmppPushRegistrationRecord({
    required this.bareJid,
    required this.tokenHash,
    required this.componentJid,
    required this.pushModule,
    required this.registeredAt,
  });

  final String bareJid;
  final String tokenHash;
  final String componentJid;
  final String pushModule;
  final DateTime registeredAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'bareJid': bareJid,
    'tokenHash': tokenHash,
    'componentJid': componentJid,
    'pushModule': pushModule,
    'registeredAt': registeredAt.toUtc().toIso8601String(),
  };

  static XmppPushRegistrationRecord? fromJson(Object? value) {
    if (value is! Map) return null;
    final bareJid = value['bareJid']?.toString().trim();
    final tokenHash = value['tokenHash']?.toString().trim();
    final componentJid = value['componentJid']?.toString().trim();
    final pushModule = value['pushModule']?.toString().trim();
    final registeredAt = DateTime.tryParse(
      value['registeredAt']?.toString() ?? '',
    );
    if (bareJid == null ||
        bareJid.isEmpty ||
        tokenHash == null ||
        tokenHash.isEmpty ||
        componentJid == null ||
        componentJid.isEmpty ||
        pushModule == null ||
        pushModule.isEmpty ||
        registeredAt == null) {
      return null;
    }
    return XmppPushRegistrationRecord(
      bareJid: bareJid,
      tokenHash: tokenHash,
      componentJid: componentJid,
      pushModule: pushModule,
      registeredAt: registeredAt,
    );
  }
}

class XmppPushRegistrationService {
  XmppPushRegistrationService({
    required XmppService xmppService,
    required CredentialStore credentialStore,
    DateTime Function()? now,
    @visibleForTesting XmppPushManager? Function()? pushManager,
  }) : _xmppService = xmppService,
       _credentialStore = credentialStore,
       _now = now ?? DateTime.timestamp,
       _pushManagerLookup = pushManager;

  final XmppService _xmppService;
  final CredentialStore _credentialStore;
  final DateTime Function() _now;
  final XmppPushManager? Function()? _pushManagerLookup;

  static final RegisteredCredentialKey _pendingCleanupKey =
      CredentialStore.registerKey('push_pending_cleanup_v1');

  Future<void> enable({
    required String bareJid,
    required String apnsToken,
    required String componentJid,
    required String pushModule,
  }) async {
    final normalizedBareJid = _normalizeJidInput(bareJid);
    final normalizedComponent = _normalizeJidInput(componentJid);
    final normalizedModule = pushModule.trim();
    final normalizedToken = apnsToken.trim().toLowerCase();
    if (normalizedBareJid.isEmpty ||
        normalizedComponent.isEmpty ||
        normalizedModule.isEmpty ||
        normalizedToken.isEmpty) {
      throw XmppPushRegistrationException();
    }
    final tokenHash = _tokenHash(normalizedToken);
    final manager = _pushManager;
    if (manager == null) {
      throw XmppPushUnsupportedException();
    }
    final enabled = await manager.enable(
      accountJid: normalizedBareJid,
      componentJid: normalizedComponent,
      node: normalizedToken,
      pushModule: normalizedModule,
    );
    if (!enabled) {
      throw XmppPushRegistrationException();
    }
    await _credentialStore.write(
      key: _stateKey(normalizedBareJid),
      value: jsonEncode(
        XmppPushRegistrationRecord(
          bareJid: normalizedBareJid,
          tokenHash: tokenHash,
          componentJid: normalizedComponent,
          pushModule: normalizedModule,
          registeredAt: _now().toUtc(),
        ).toJson(),
      ),
    );
  }

  Future<void> disable({
    required String bareJid,
    required String apnsToken,
    required String componentJid,
  }) async {
    final normalizedBareJid = _normalizeJidInput(bareJid);
    final normalizedComponent = _normalizeJidInput(componentJid);
    final normalizedToken = apnsToken.trim().toLowerCase();
    if (normalizedBareJid.isEmpty ||
        normalizedComponent.isEmpty ||
        normalizedToken.isEmpty) {
      return;
    }
    if (!_xmppService.connected) {
      throw XmppDisconnectedException();
    }
    final manager = _pushManager;
    if (manager == null) {
      throw XmppPushUnsupportedException();
    }
    final disabled = await manager.disable(
      accountJid: normalizedBareJid,
      componentJid: normalizedComponent,
      node: normalizedToken,
    );
    if (!disabled) {
      throw XmppPushRegistrationException();
    }
    final existing = await currentRegistration(bareJid: normalizedBareJid);
    if (existing == null || existing.tokenHash == _tokenHash(normalizedToken)) {
      await _credentialStore.delete(key: _stateKey(normalizedBareJid));
    }
  }

  Future<XmppPushRegistrationRecord?> currentRegistration({
    required String bareJid,
  }) async {
    final normalizedBareJid = _normalizeJidInput(bareJid);
    if (normalizedBareJid.isEmpty) return null;
    final raw = await _credentialStore.read(key: _stateKey(normalizedBareJid));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return XmppPushRegistrationRecord.fromJson(jsonDecode(raw));
    } on Exception {
      return null;
    }
  }

  Future<void> enqueuePendingCleanup(XmppPushRegistrationIntent target) async {
    final pending = await pendingCleanups();
    pending.removeWhere((candidate) => candidate.hasSameDisableTarget(target));
    pending.add(target);
    await writePendingCleanups(pending);
  }

  Future<List<XmppPushRegistrationIntent>> pendingCleanups() async {
    final raw = await _credentialStore.read(key: _pendingCleanupKey);
    if (raw == null || raw.trim().isEmpty) {
      return <XmppPushRegistrationIntent>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <XmppPushRegistrationIntent>[];
      }
      return _dedupeCleanupTargets(
        decoded
            .map(XmppPushRegistrationIntent.fromJson)
            .whereType<XmppPushRegistrationIntent>(),
      );
    } on Exception {
      return <XmppPushRegistrationIntent>[];
    }
  }

  Future<void> removePendingCleanup(XmppPushRegistrationIntent target) async {
    final pending = await pendingCleanups();
    pending.removeWhere((candidate) => candidate.hasSameDisableTarget(target));
    await writePendingCleanups(pending);
  }

  Future<void> writePendingCleanups(
    Iterable<XmppPushRegistrationIntent> targets,
  ) async {
    final pending = _dedupeCleanupTargets(targets);
    if (pending.isEmpty) {
      await _credentialStore.delete(key: _pendingCleanupKey);
      return;
    }
    await _credentialStore.write(
      key: _pendingCleanupKey,
      value: jsonEncode([for (final target in pending) target.toJson()]),
    );
  }

  XmppPushManager? get _pushManager {
    final lookup = _pushManagerLookup;
    if (lookup != null) {
      return lookup();
    }
    return _xmppService._connection.getManager<XmppPushManager>();
  }

  RegisteredCredentialKey _stateKey(String bareJid) {
    final digest = sha256.convert(utf8.encode(bareJid)).toString();
    return CredentialStore.registerKey('xmpp_push_registration_v1_$digest');
  }

  List<XmppPushRegistrationIntent> _dedupeCleanupTargets(
    Iterable<XmppPushRegistrationIntent> targets,
  ) {
    final deduped = <String, XmppPushRegistrationIntent>{};
    for (final target in targets) {
      deduped[target.cleanupTargetKey] = target;
    }
    return deduped.values.toList(growable: true);
  }

  String _normalizeJidInput(String value) {
    return normalizedAddressKey(value) ?? '';
  }

  String _tokenHash(String token) =>
      sha256.convert(utf8.encode(token)).toString();
}
