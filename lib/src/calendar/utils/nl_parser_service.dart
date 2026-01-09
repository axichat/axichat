// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'nl_schedule_adapter.dart';
import 'schedule_parser.dart';
import 'task_share_formatter.dart';

/// Lightweight runtime service that wires the offline `ScheduleParser`
/// into the app through `NlScheduleAdapter`. It centralizes timezone
/// initialization and provides a convenient async entry point for UI
/// and bloc layers.
class NlScheduleParserService {
  NlScheduleParserService({
    NlAdapterConfig config = const NlAdapterConfig(),
    FutureOr<void> Function()? initializeTimezones,
  })  : _config = config,
        _initializeTimezones =
            initializeTimezones ?? tzdata.initializeTimeZones {
    _adapter = NlScheduleAdapter(config: config);
  }

  final NlAdapterConfig _config;
  late final NlScheduleAdapter _adapter;
  final FutureOr<void> Function() _initializeTimezones;

  static Completer<void>? _timezoneInit;
  static const String _fallbackTz = 'UTC';
  static final tz.Location _fallbackLocation = tz.UTC;

  NlAdapterConfig get config => _config;

  /// Parses [input] and returns the mapped adapter result. Consumers may supply
  /// an explicit [context] (useful for tests); otherwise the service will
  /// derive one from the current device timezone.
  Future<NlAdapterResult> parse(
    String input, {
    ParseContext? context,
  }) async {
    final ctx = context ?? await _parseContext();
    final NlAdapterResult? shared = TaskShareDecoder.tryDecode(
      input: input,
      adapter: _adapter,
      context: ctx,
    );
    if (shared != null) {
      _maybeLogNotes(shared);
      return shared;
    }
    final parser = _adapter.buildParser(ctx);
    final ScheduleItem parsed = parser.parse(input);
    final result = _adapter.mapToAppTypes(parsed, ctx: ctx);
    _maybeLogNotes(result);
    return result;
  }

  Future<ParseContext> _parseContext() async {
    await _ensureTimezonesInitialized();
    final tzName = await _resolveTimezone();
    final location = _lookupLocation(tzName);
    tz.setLocalLocation(location);
    return ParseContext(
      location: location,
      timezoneId: location.name,
    );
  }

  void _maybeLogNotes(NlAdapterResult result) {
    if (result.parseNotes == null) return;
  }

  Future<void> _ensureTimezonesInitialized() {
    final current = _timezoneInit;
    if (current != null) return current.future;
    final completer = Completer<void>();
    _timezoneInit = completer;
    try {
      _initializeTimezones();
      completer.complete();
    } catch (error, stackTrace) {
      _timezoneInit = null;
      completer.completeError(error, stackTrace);
    }
    return completer.future.catchError((_) {
      // Swallow init errors so parsing can proceed with the fallback timezone.
    });
  }

  Future<String> _resolveTimezone() async {
    try {
      return await FlutterNativeTimezone.getLocalTimezone();
    } catch (_) {
      return _fallbackTz;
    }
  }

  tz.Location _lookupLocation(String tzName) {
    try {
      return tz.getLocation(tzName);
    } catch (error) {
      return _fallbackLocation;
    }
  }
}
