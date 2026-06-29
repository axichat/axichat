// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/push/apns_token_service.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:logging/logging.dart';

enum _PushRegistrationCleanupResult { cleaned, failed, skipped }

final class PushRegistrationState {
  const PushRegistrationState({
    required this.bareJid,
    required this.token,
    required this.environment,
    required this.bundleId,
    required this.xmppRegistered,
    required this.fpushComponentJid,
    required this.fpushIosPushModule,
    required this.registeredAt,
  });

  final String bareJid;
  final String token;
  final ApnsEnvironment environment;
  final String bundleId;
  final bool xmppRegistered;
  final String fpushComponentJid;
  final String fpushIosPushModule;
  final DateTime registeredAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'bareJid': bareJid,
    'token': token,
    'environment': environment.name,
    'bundleId': bundleId,
    'xmppRegistered': xmppRegistered,
    'fpushComponentJid': fpushComponentJid,
    'fpushIosPushModule': fpushIosPushModule,
    'registeredAt': registeredAt.toUtc().toIso8601String(),
  };

  static PushRegistrationState? fromJson(Object? value) {
    if (value is! Map) return null;
    final bareJid = value['bareJid']?.toString().trim();
    final token = value['token']?.toString().trim();
    final environment = ApnsEnvironment.parse(value['environment']);
    final bundleId = value['bundleId']?.toString().trim();
    final xmppRegistered = value['xmppRegistered'] == true;
    final fpushComponentJid =
        value['fpushComponentJid']?.toString().trim() ??
        EndpointConfig.legacyDefaultFpushComponentJid;
    final fpushIosPushModule =
        value['fpushIosPushModule']?.toString().trim() ??
        EndpointConfig.defaultFpushIosPushModule;
    final registeredAt = DateTime.tryParse(
      value['registeredAt']?.toString() ?? '',
    );
    if (bareJid == null ||
        bareJid.isEmpty ||
        token == null ||
        token.isEmpty ||
        environment == null ||
        bundleId == null ||
        bundleId.isEmpty ||
        fpushComponentJid.isEmpty ||
        fpushIosPushModule.isEmpty ||
        registeredAt == null) {
      return null;
    }
    return PushRegistrationState(
      bareJid: bareJid,
      token: token,
      environment: environment,
      bundleId: bundleId,
      xmppRegistered: xmppRegistered,
      fpushComponentJid: fpushComponentJid,
      fpushIosPushModule: fpushIosPushModule,
      registeredAt: registeredAt,
    );
  }
}

class PushRegistrationCoordinator {
  PushRegistrationCoordinator({
    required ApnsTokenService apnsTokenService,
    required CredentialStore credentialStore,
    required XmppService xmppService,
    required Future<bool> Function() registrationAllowed,
    EndpointConfig endpointConfig = const EndpointConfig(),
    Logger? logger,
    Duration Function(int attempt)? retryDelay,
    Timer Function(Duration duration, void Function() callback)? createTimer,
    DateTime Function()? now,
  }) : _apnsTokenService = apnsTokenService,
       _credentialStore = credentialStore,
       _xmppService = xmppService,
       _registrationAllowed = registrationAllowed,
       _endpointConfig = endpointConfig,
       _log = logger ?? Logger('PushRegistrationCoordinator'),
       _retryDelay = retryDelay ?? _defaultRetryDelay,
       _createTimer = createTimer ?? Timer.new,
       _now = now ?? DateTime.timestamp;

  static final RegisteredCredentialKey _lastRegistrationKey =
      CredentialStore.registerKey('push_last_registration_v1');
  static const int _maxRetryAttempts = 5;
  static const Duration _maxRetryDelay = Duration(seconds: 30);

  final ApnsTokenService _apnsTokenService;
  final CredentialStore _credentialStore;
  final XmppService _xmppService;
  final Future<bool> Function() _registrationAllowed;
  final Logger _log;
  final Duration Function(int attempt) _retryDelay;
  final Timer Function(Duration duration, void Function() callback)
  _createTimer;
  final DateTime Function() _now;

  EndpointConfig _endpointConfig;
  ApnsRegistration? _currentRegistration;
  String? _activeBareJid;
  StreamSubscription<ApnsRegistration>? _registrationSubscription;
  StreamSubscription<ApnsRegistrationFailed>? _registrationFailureSubscription;
  PushRegistrationState? _lastCleanedRegistration;
  Timer? _retryTimer;
  Future<void>? _registrationTask;
  var _started = false;
  var _registrationPassRequested = false;
  var _disposed = false;
  var _retryAttempt = 0;
  var _sessionGeneration = 0;
  var _apnsRegistrationNeedsRequest = false;
  var _apnsRegistrationRequestInFlight = false;
  var _remoteNotificationsUnregistered = false;

  Future<void> start() async {
    if (_started || !_apnsTokenService.isEnabled) {
      return;
    }
    _started = true;
    _registrationSubscription = _apnsTokenService.registrations.listen(
      (registration) {
        if (_currentRegistration != registration) {
          _sessionGeneration += 1;
        }
        _currentRegistration = registration;
        _lastCleanedRegistration = null;
        _remoteNotificationsUnregistered = false;
        _apnsRegistrationNeedsRequest = false;
        _registerSoon(resetBackoff: true);
      },
      onError: (Object error, StackTrace stackTrace) {
        _log.fine('APNs registration stream failed.', error, stackTrace);
      },
    );
    _registrationFailureSubscription = _apnsTokenService.registrationFailures
        .listen(
          (failure) {
            _currentRegistration = null;
            _sessionGeneration += 1;
            _apnsRegistrationNeedsRequest = true;
            _log.fine('APNs registration failed: ${failure.message}');
          },
          onError: (Object error, StackTrace stackTrace) {
            _log.fine(
              'APNs registration failure stream failed.',
              error,
              stackTrace,
            );
          },
        );
    final existing = await _apnsTokenService.currentRegistration();
    if (existing != null) {
      _currentRegistration = existing;
      _apnsRegistrationNeedsRequest = false;
      _registerSoon(resetBackoff: true);
    }
  }

  void updateEndpointConfig(EndpointConfig config) {
    if (_endpointConfig == config) return;
    _endpointConfig = config;
    _sessionGeneration += 1;
    _registerSoon(resetBackoff: true);
  }

  void handleRegistrationEligibilityChanged() {
    _sessionGeneration += 1;
    _registerSoon(resetBackoff: true);
  }

  void handleLifecycleResume() {
    if (_currentRegistration == null) {
      _apnsRegistrationNeedsRequest = true;
    }
    _registerSoon(resetBackoff: true);
  }

  Future<bool> handleBackgroundMessagingPreferenceChanged({
    required bool enabled,
  }) async {
    _sessionGeneration += 1;
    if (enabled) {
      _lastCleanedRegistration = null;
      _remoteNotificationsUnregistered = false;
      if (_currentRegistration == null) {
        _apnsRegistrationNeedsRequest = true;
      }
      _registerSoon(resetBackoff: true);
      return true;
    }
    final serverCleaned = await _cleanupStoredRegistration(
      waitForActivePass: true,
      activeBareJid: _activeBareJid,
      includeCurrentRegistration: true,
    );
    final apnsUnregistered = await _unregisterRemoteNotifications();
    if (serverCleaned && apnsUnregistered) {
      await _forgetLocalRegistration();
      return true;
    }
    return serverCleaned;
  }

  void handleAuthenticated({required String jid, EndpointConfig? config}) {
    final bareJid = _bareJid(jid);
    if (bareJid == null) return;
    if (config != null) {
      if (_endpointConfig != config) {
        _sessionGeneration += 1;
      }
      _endpointConfig = config;
    }
    if (_activeBareJid != bareJid) {
      _sessionGeneration += 1;
    }
    _activeBareJid = bareJid;
    _registerSoon(resetBackoff: true);
  }

  Future<bool> handleLogout({
    required String? jid,
    EndpointConfig? config,
  }) async {
    if (config != null) {
      _endpointConfig = config;
    }
    final logoutBareJid = _bareJid(jid) ?? _bareJid(_activeBareJid);
    _activeBareJid = null;
    _sessionGeneration += 1;
    _registrationPassRequested = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    final cleaned = await _cleanupStoredRegistration(
      waitForActivePass: false,
      activeBareJid: logoutBareJid,
      includeCurrentRegistration: true,
    );
    if (!cleaned) {
      _log.fine(
        'Push logout cleanup could not be completed; leaving local registration state unchanged.',
      );
      _activeBareJid = null;
      return false;
    }
    return true;
  }

  void _registerSoon({required bool resetBackoff}) {
    if (resetBackoff) {
      _retryAttempt = 0;
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    _registrationPassRequested = true;
    _ensureRegistrationTask();
  }

  void _ensureRegistrationTask() {
    if (_disposed || _registrationTask != null) {
      return;
    }
    late final Future<void> task;
    task = _drainRegistrationRequests();
    _registrationTask = task;
    unawaited(
      task.whenComplete(() {
        if (_registrationTask == task) {
          _registrationTask = null;
        }
        if (_registrationPassRequested && !_disposed) {
          _ensureRegistrationTask();
        }
      }),
    );
  }

  Future<void> _drainRegistrationRequests() async {
    while (_registrationPassRequested && !_disposed) {
      _registrationPassRequested = false;
      try {
        await _attemptRegistrationPass();
      } on Object catch (error, stackTrace) {
        _log.warning(
          'Unexpected push registration pass failure.',
          error,
          stackTrace,
        );
        _scheduleRetry();
      }
    }
  }

  Future<void> _attemptRegistrationPass() async {
    final bareJid = _bareJid(_activeBareJid);
    if (bareJid == null) {
      _xmppService.setDesiredPushRegistration(null);
      return;
    }
    final generation = _sessionGeneration;
    final componentJid = _endpointConfig.resolvedFpushComponentJid;
    final xmppEnabled = _endpointConfig.xmppEnabled;
    final registration = _currentRegistration;
    final requestApnsIfTokenMissing = _apnsRegistrationNeedsRequest;
    final currentPushModule = registration == null
        ? null
        : _pushModuleFor(registration);
    final registrationAllowed = await _registrationAllowed();
    if (!registrationAllowed) {
      if (_isCurrentRegistrationPassContext(
        generation: generation,
        bareJid: bareJid,
        registration: registration,
        componentJid: componentJid,
        pushModule: currentPushModule,
      )) {
        _xmppService.setDesiredPushRegistration(null);
      }
      return;
    }
    if (registration == null) {
      if (_isCurrentRegistrationPassContext(
        generation: generation,
        bareJid: bareJid,
        registration: null,
        componentJid: componentJid,
        pushModule: null,
      )) {
        _xmppService.setDesiredPushRegistration(null);
      }
      if (requestApnsIfTokenMissing &&
          _isCurrentRegistrationPassContext(
            generation: generation,
            bareJid: bareJid,
            registration: null,
            componentJid: componentJid,
            pushModule: null,
          )) {
        await _requestRemoteNotificationsIfNeeded();
      }
      return;
    }
    final pushModule = currentPushModule!;
    final previous = await _readLastRegistration();
    final nextRegistration = PushRegistrationState(
      bareJid: bareJid,
      token: registration.token,
      environment: registration.environment,
      bundleId: registration.bundleId,
      xmppRegistered: xmppEnabled,
      fpushComponentJid: componentJid,
      fpushIosPushModule: pushModule,
      registeredAt: _now().toUtc(),
    );
    if (!_isCurrentRegistrationPass(
      generation: generation,
      bareJid: bareJid,
      registration: registration,
      componentJid: componentJid,
      pushModule: pushModule,
    )) {
      return;
    }
    final desiredIntent = _intentForState(nextRegistration);
    final previousCleanupTarget = xmppEnabled
        ? _previousCleanupTargetIfReplaced(
            previous,
            bareJid: bareJid,
            registration: registration,
            componentJid: componentJid,
          )
        : null;
    if (xmppEnabled) {
      final cleanupTargets = previousCleanupTarget == null
          ? const <XmppPushRegistrationIntent>[]
          : <XmppPushRegistrationIntent>[
              _intentForState(previousCleanupTarget),
            ];
      try {
        final committed = await _xmppService.commitDesiredPushRegistration(
          desired: desiredIntent,
          cleanupTargets: cleanupTargets,
          isCurrent: () => _isCurrentRegistrationPass(
            generation: generation,
            bareJid: bareJid,
            registration: registration,
            componentJid: componentJid,
            pushModule: pushModule,
          ),
          onEnabled: _recordConfirmedXmppPushRegistration,
        );
        if (!committed) {
          return;
        }
      } on XmppPushRegistrationException catch (error, stackTrace) {
        _log.fine('XMPP push cleanup queueing failed.', error, stackTrace);
        _scheduleRetry();
        return;
      }
    } else {
      if (!_isCurrentRegistrationPass(
        generation: generation,
        bareJid: bareJid,
        registration: registration,
        componentJid: componentJid,
        pushModule: pushModule,
      )) {
        return;
      }
      _xmppService.setDesiredPushRegistration(null);
    }
    if (_matchesCurrentRegistration(
      previous,
      bareJid: bareJid,
      registration: registration,
      componentJid: componentJid,
      pushModule: pushModule,
    )) {
      _retryAttempt = 0;
      return;
    }
    if (!_isCurrentRegistrationPass(
      generation: generation,
      bareJid: bareJid,
      registration: registration,
      componentJid: componentJid,
      pushModule: pushModule,
    )) {
      return;
    }
    if (!xmppEnabled) {
      await _writeLastRegistration(nextRegistration);
    }
    _retryAttempt = 0;
  }

  void _scheduleRetry() {
    if (_disposed) {
      return;
    }
    if (_retryAttempt >= _maxRetryAttempts) {
      _log.warning('Push registration retry limit reached.');
      return;
    }
    _retryAttempt += 1;
    final delay = _retryDelay(_retryAttempt);
    _retryTimer?.cancel();
    _retryTimer = _createTimer(delay, () {
      _retryTimer = null;
      _registerSoon(resetBackoff: false);
    });
  }

  String _pushModuleFor(ApnsRegistration registration) {
    final configured = _endpointConfig.fpushIosPushModule.trim();
    if (configured.isNotEmpty &&
        configured != EndpointConfig.defaultFpushIosPushModule) {
      return configured;
    }
    return switch (registration.environment) {
      ApnsEnvironment.sandbox => 'apns-sandbox',
      ApnsEnvironment.production => 'apns-prod',
    };
  }

  bool _matchesCurrentRegistration(
    PushRegistrationState? previous, {
    required String bareJid,
    required ApnsRegistration registration,
    required String componentJid,
    required String pushModule,
  }) {
    if (previous == null) {
      return false;
    }
    return previous.bareJid == bareJid &&
        previous.token == registration.token &&
        previous.environment == registration.environment &&
        previous.bundleId == registration.bundleId &&
        previous.fpushComponentJid == componentJid &&
        previous.fpushIosPushModule == pushModule &&
        previous.xmppRegistered == _endpointConfig.xmppEnabled;
  }

  bool _isCurrentRegistrationPass({
    required int generation,
    required String bareJid,
    required ApnsRegistration registration,
    required String componentJid,
    required String pushModule,
  }) {
    return !_disposed &&
        generation == _sessionGeneration &&
        _bareJid(_activeBareJid) == bareJid &&
        _currentRegistration == registration &&
        _endpointConfig.resolvedFpushComponentJid == componentJid &&
        _pushModuleFor(registration) == pushModule;
  }

  bool _isCurrentRegistrationPassContext({
    required int generation,
    required String bareJid,
    required ApnsRegistration? registration,
    required String componentJid,
    required String? pushModule,
  }) {
    if (_disposed ||
        generation != _sessionGeneration ||
        _bareJid(_activeBareJid) != bareJid ||
        _endpointConfig.resolvedFpushComponentJid != componentJid ||
        _currentRegistration != registration) {
      return false;
    }
    if (registration == null) {
      return pushModule == null;
    }
    return pushModule != null && _pushModuleFor(registration) == pushModule;
  }

  Future<void> _requestRemoteNotificationsIfNeeded() async {
    if (!_apnsRegistrationNeedsRequest ||
        _apnsRegistrationRequestInFlight ||
        !_apnsTokenService.isEnabled) {
      return;
    }
    _apnsRegistrationRequestInFlight = true;
    try {
      await _apnsTokenService.requestRemoteNotifications();
      _apnsRegistrationNeedsRequest = false;
    } on Exception catch (error, stackTrace) {
      _apnsRegistrationNeedsRequest = true;
      _log.fine('APNs registration request failed.', error, stackTrace);
    } finally {
      _apnsRegistrationRequestInFlight = false;
    }
  }

  Future<bool> _unregisterRemoteNotifications() async {
    if (!_apnsTokenService.isEnabled) {
      return true;
    }
    try {
      await _apnsTokenService.unregisterRemoteNotifications();
      _currentRegistration = null;
      _remoteNotificationsUnregistered = true;
      _apnsRegistrationNeedsRequest = true;
      _apnsRegistrationRequestInFlight = false;
      return true;
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Remote notification unregister request failed.',
        error,
        stackTrace,
      );
      return false;
    }
  }

  PushRegistrationState? _previousCleanupTargetIfReplaced(
    PushRegistrationState? previous, {
    required String bareJid,
    required ApnsRegistration registration,
    required String componentJid,
  }) {
    if (previous == null || !previous.xmppRegistered) {
      return null;
    }
    if (previous.bareJid != bareJid) {
      return null;
    }
    if (previous.token == registration.token &&
        previous.fpushComponentJid == componentJid) {
      return null;
    }
    return previous;
  }

  static Duration _defaultRetryDelay(int attempt) {
    final seconds = math.min(1 << attempt, _maxRetryDelay.inSeconds);
    return Duration(seconds: seconds);
  }

  Future<_PushRegistrationCleanupResult> _enqueueStoredRegistrationCleanup(
    PushRegistrationState registration, {
    required String? activeBareJid,
  }) async {
    if (!registration.xmppRegistered) {
      return _PushRegistrationCleanupResult.cleaned;
    }
    final active = _bareJid(activeBareJid);
    if (active == null || active != registration.bareJid) {
      _log.fine(
        'Skipping XMPP push disable because the active account does not match: '
        'bareJid=${registration.bareJid} '
        'activeBareJid=${active ?? '<none>'}.',
      );
      return _PushRegistrationCleanupResult.skipped;
    }
    try {
      await _enqueuePendingCleanup(registration);
      return _PushRegistrationCleanupResult.cleaned;
    } on Exception catch (error, stackTrace) {
      _log.fine('XMPP push cleanup queueing failed.', error, stackTrace);
      return _PushRegistrationCleanupResult.failed;
    }
  }

  Future<bool> _cleanupStoredRegistration({
    required bool waitForActivePass,
    required String? activeBareJid,
    bool includeCurrentRegistration = false,
  }) async {
    _registrationPassRequested = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    if (waitForActivePass) {
      final activeTask = _registrationTask;
      if (activeTask != null) {
        await activeTask;
      }
      _retryTimer?.cancel();
      _retryTimer = null;
    }
    final normalizedActiveBareJid = _bareJid(activeBareJid);
    _xmppService.setDesiredPushRegistration(null);
    var allCleaned = true;
    final previous = await _readLastRegistration();
    final current = includeCurrentRegistration
        ? await _currentCleanupRegistration(
            activeBareJid: normalizedActiveBareJid,
          )
        : null;
    var previousCleaned = previous == null;
    if (previous != null) {
      if (_hasSameDisableTarget(_lastCleanedRegistration, previous)) {
        previousCleaned = true;
      } else {
        final cleanupResult = await _enqueueStoredRegistrationCleanup(
          previous,
          activeBareJid: normalizedActiveBareJid,
        );
        previousCleaned =
            cleanupResult == _PushRegistrationCleanupResult.cleaned;
        allCleaned = allCleaned && previousCleaned;
      }
    }

    final shouldCleanCurrent =
        current != null &&
        !_hasSameDisableTarget(previous, current) &&
        !_hasSameDisableTarget(_lastCleanedRegistration, current);
    if (shouldCleanCurrent) {
      final cleanupResult = await _enqueueStoredRegistrationCleanup(
        current,
        activeBareJid: normalizedActiveBareJid,
      );
      final currentCleaned =
          cleanupResult == _PushRegistrationCleanupResult.cleaned;
      allCleaned = allCleaned && currentCleaned;
      if (!currentCleaned &&
          (previous == null ||
              previousCleaned ||
              !_isUsefulCleanupTarget(
                previous,
                activeBareJid: normalizedActiveBareJid,
              ))) {
        await _writeLastRegistration(current);
      }
    }

    if (allCleaned) {
      if (current != null) {
        _lastCleanedRegistration = current;
      } else if (previous != null) {
        _lastCleanedRegistration = previous;
      }
      await _credentialStore.delete(key: _lastRegistrationKey);
      return true;
    }
    return false;
  }

  Future<void> _forgetLocalRegistration() async {
    await _credentialStore.delete(key: _lastRegistrationKey);
  }

  Future<void> _enqueuePendingCleanup(
    PushRegistrationState registration,
  ) async {
    if (!registration.xmppRegistered) {
      return;
    }
    await _xmppService.enqueuePushCleanup(_intentForState(registration));
  }

  Future<PushRegistrationState?> _currentCleanupRegistration({
    required String? activeBareJid,
  }) async {
    if (_remoteNotificationsUnregistered) {
      return null;
    }
    final bareJid = _bareJid(activeBareJid);
    if (bareJid == null) {
      return null;
    }
    var registration = _currentRegistration;
    if (registration == null) {
      try {
        registration = await _apnsTokenService.currentRegistration();
      } on Exception catch (error, stackTrace) {
        _log.fine(
          'Failed to read current APNs registration for cleanup.',
          error,
          stackTrace,
        );
        return null;
      }
      if (registration != null) {
        _currentRegistration = registration;
      }
    }
    if (registration == null) {
      return null;
    }
    return PushRegistrationState(
      bareJid: bareJid,
      token: registration.token,
      environment: registration.environment,
      bundleId: registration.bundleId,
      xmppRegistered: true,
      fpushComponentJid: _endpointConfig.resolvedFpushComponentJid,
      fpushIosPushModule: _pushModuleFor(registration),
      registeredAt: _now().toUtc(),
    );
  }

  bool _hasSameDisableTarget(
    PushRegistrationState? left,
    PushRegistrationState right,
  ) {
    return left != null &&
        left.xmppRegistered &&
        right.xmppRegistered &&
        left.bareJid == right.bareJid &&
        left.token == right.token &&
        left.fpushComponentJid == right.fpushComponentJid;
  }

  bool _isUsefulCleanupTarget(
    PushRegistrationState registration, {
    required String? activeBareJid,
  }) {
    return registration.xmppRegistered &&
        _bareJid(activeBareJid) == registration.bareJid;
  }

  Future<PushRegistrationState?> _readLastRegistration() async {
    final raw = await _credentialStore.read(key: _lastRegistrationKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return PushRegistrationState.fromJson(jsonDecode(raw));
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to read last push registration.', error, stackTrace);
      return null;
    }
  }

  Future<void> _writeLastRegistration(PushRegistrationState state) async {
    await _credentialStore.write(
      key: _lastRegistrationKey,
      value: jsonEncode(state.toJson()),
    );
  }

  Future<void> _recordConfirmedXmppPushRegistration(
    XmppPushRegistrationIntent intent,
  ) async {
    final bareJid = _bareJid(_activeBareJid);
    final registration = _currentRegistration;
    if (_disposed || bareJid == null || registration == null) {
      return;
    }
    final componentJid = _endpointConfig.resolvedFpushComponentJid;
    final pushModule = _pushModuleFor(registration);
    if (intent.bareJid != bareJid ||
        intent.apnsToken != registration.token ||
        intent.environment != registration.environment.name ||
        intent.bundleId != registration.bundleId ||
        intent.componentJid != componentJid ||
        intent.pushModule != pushModule) {
      return;
    }
    await _writeLastRegistration(
      PushRegistrationState(
        bareJid: bareJid,
        token: registration.token,
        environment: registration.environment,
        bundleId: registration.bundleId,
        xmppRegistered: true,
        fpushComponentJid: componentJid,
        fpushIosPushModule: pushModule,
        registeredAt: _now().toUtc(),
      ),
    );
  }

  XmppPushRegistrationIntent _intentForState(PushRegistrationState state) {
    return XmppPushRegistrationIntent(
      bareJid: state.bareJid,
      apnsToken: state.token,
      componentJid: state.fpushComponentJid,
      pushModule: state.fpushIosPushModule,
      environment: state.environment.name,
      bundleId: state.bundleId,
      registeredAt: state.registeredAt,
    );
  }

  String? _bareJid(String? jid) {
    return normalizedAddressKey(jid);
  }

  Future<void> dispose() async {
    _disposed = true;
    _sessionGeneration += 1;
    _xmppService.setDesiredPushRegistration(null);
    _registrationPassRequested = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _registrationSubscription?.cancel();
    await _registrationFailureSubscription?.cancel();
  }
}
