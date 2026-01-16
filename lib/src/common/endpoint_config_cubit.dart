// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';

import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:bloc/bloc.dart';
import 'package:logging/logging.dart';

const String _endpointConfigStorageKeyName = 'endpoint_config_v1';

class EndpointConfigCubit extends Cubit<EndpointConfig> {
  EndpointConfigCubit({
    required CredentialStore credentialStore,
    EndpointConfig initialConfig = const EndpointConfig(),
  })  : _credentialStore = credentialStore,
        _storageKey =
            CredentialStore.registerKey(_endpointConfigStorageKeyName),
        super(initialConfig);

  final _log = Logger('EndpointConfigCubit');
  final CredentialStore _credentialStore;
  final RegisteredCredentialKey _storageKey;
  Future<void>? _restoreFuture;
  var _mutationId = 0;

  Future<void> restore() {
    final existing = _restoreFuture;
    if (existing != null) {
      return existing;
    }
    final mutationAtStart = _mutationId;
    final future = _restore(mutationAtStart);
    _restoreFuture = future;
    return future;
  }

  Future<void> updateConfig(EndpointConfig config) async {
    _mutationId++;
    emit(config);
    try {
      await _credentialStore.write(
        key: _storageKey,
        value: jsonEncode(config.toJson()),
      );
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to persist endpoint config', error, stackTrace);
    }
  }

  Future<void> reset() => updateConfig(const EndpointConfig());

  void overrideEphemeral(EndpointConfig config) {
    _mutationId++;
    emit(config);
  }

  Future<void> _restore(int mutationAtStart) async {
    try {
      final stored = await _credentialStore.read(key: _storageKey) ?? '';
      if (stored.trim().isEmpty) {
        return;
      }
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      if (_mutationId != mutationAtStart) {
        return;
      }
      emit(EndpointConfig.fromJson(decoded));
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to restore endpoint config', error, stackTrace);
    }
  }
}
