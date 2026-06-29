// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum ApnsEnvironment {
  sandbox,
  production;

  static ApnsEnvironment? parse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'sandbox' || 'development' => ApnsEnvironment.sandbox,
      'production' || 'prod' => ApnsEnvironment.production,
      _ => null,
    };
  }
}

final class ApnsRegistration extends Equatable {
  const ApnsRegistration({
    required this.token,
    required this.environment,
    required this.bundleId,
  });

  final String token;
  final ApnsEnvironment environment;
  final String bundleId;

  String get environmentName => environment.name;

  Map<String, Object?> toJson() => <String, Object?>{
    'token': token,
    'environment': environment.name,
    'bundleId': bundleId,
  };

  static ApnsRegistration? fromMap(Map<Object?, Object?>? map) {
    if (map == null) return null;
    final rawToken = map['token']?.toString().trim().toLowerCase();
    final environment = ApnsEnvironment.parse(map['environment']);
    final bundleId = map['bundleId']?.toString().trim();
    if (rawToken == null ||
        rawToken.isEmpty ||
        environment == null ||
        bundleId == null ||
        bundleId.isEmpty) {
      return null;
    }
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(rawToken)) {
      return null;
    }
    return ApnsRegistration(
      token: rawToken,
      environment: environment,
      bundleId: bundleId,
    );
  }

  @override
  List<Object?> get props => [token, environment, bundleId];
}

sealed class ApnsEvent extends Equatable {
  const ApnsEvent();
}

final class ApnsRegistered extends ApnsEvent {
  const ApnsRegistered(this.registration);

  final ApnsRegistration registration;

  @override
  List<Object?> get props => [registration];
}

final class ApnsRegistrationFailed extends ApnsEvent {
  const ApnsRegistrationFailed({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

class ApnsTokenService {
  ApnsTokenService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    bool? enabled,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel(_methodChannelName),
       _eventChannel = eventChannel ?? const EventChannel(_eventChannelName),
       _enabled = enabled ?? (!kIsWeb && Platform.isIOS);

  static const String _methodChannelName = 'im.axi.axichat/apns';
  static const String _eventChannelName = 'im.axi.axichat/apns/events';
  static const String _eventTypeKey = 'type';
  static const String _eventRegistered = 'registered';
  static const String _eventRegistrationFailed = 'registrationFailed';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final bool _enabled;
  Stream<ApnsEvent>? _events;

  bool get isEnabled => _enabled;

  Future<ApnsRegistration?> currentRegistration() async {
    if (!_enabled) return null;
    final value = await _methodChannel.invokeMethod<Object?>(
      'currentRegistration',
    );
    return parseRegistration(value);
  }

  Stream<ApnsRegistration> get registrations => events
      .where((event) => event is ApnsRegistered)
      .cast<ApnsRegistered>()
      .map((event) => event.registration);

  Stream<ApnsRegistrationFailed> get registrationFailures => events
      .where((event) => event is ApnsRegistrationFailed)
      .cast<ApnsRegistrationFailed>();

  Stream<ApnsEvent> get events {
    if (!_enabled) return const Stream<ApnsEvent>.empty();
    return _events ??= _eventChannel.receiveBroadcastStream().map(parseEvent);
  }

  Future<void> requestRemoteNotifications() async {
    if (!_enabled) return;
    await _methodChannel.invokeMethod<void>('requestRemoteNotifications');
  }

  Future<void> unregisterRemoteNotifications() async {
    if (!_enabled) return;
    await _methodChannel.invokeMethod<void>('unregisterRemoteNotifications');
  }

  @visibleForTesting
  static ApnsRegistration? parseRegistration(Object? value) {
    if (value is Map<Object?, Object?>) {
      return ApnsRegistration.fromMap(value);
    }
    if (value is Map) {
      return ApnsRegistration.fromMap(Map<Object?, Object?>.from(value));
    }
    return null;
  }

  @visibleForTesting
  static ApnsEvent parseEvent(Object? value) {
    if (value is! Map) {
      return const ApnsRegistrationFailed(message: 'Malformed APNs event.');
    }
    final map = Map<Object?, Object?>.from(value);
    final type = map[_eventTypeKey]?.toString().trim();
    switch (type) {
      case _eventRegistered:
        final registration = ApnsRegistration.fromMap(map);
        if (registration != null) {
          return ApnsRegistered(registration);
        }
        return const ApnsRegistrationFailed(
          message: 'Malformed APNs registration event.',
        );
      case _eventRegistrationFailed:
        final message = map['message']?.toString().trim();
        return ApnsRegistrationFailed(
          message: message == null || message.isEmpty
              ? 'APNs registration failed.'
              : message,
        );
      default:
        return ApnsRegistrationFailed(message: 'Unknown APNs event: $type');
    }
  }
}
