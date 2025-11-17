import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'nl_schedule_adapter.dart';
import 'schedule_parser.dart';

/// Lightweight runtime service that wires the offline `ScheduleParser`
/// into the app through `NlScheduleAdapter`. It centralizes timezone
/// initialization and provides a convenient async entry point for UI
/// and bloc layers.
class NlScheduleParserService {
  NlScheduleParserService({NlAdapterConfig config = const NlAdapterConfig()})
      : _config = config {
    _adapter = NlScheduleAdapter(config: config);
  }

  final NlAdapterConfig _config;
  late final NlScheduleAdapter _adapter;

  static Completer<void>? _timezoneInit;
  static const String _fallbackTz = 'UTC';

  NlAdapterConfig get config => _config;

  /// Parses [input] and returns the mapped adapter result. Consumers may supply
  /// an explicit [context] (useful for tests); otherwise the service will
  /// derive one from the current device timezone.
  Future<NlAdapterResult> parse(
    String input, {
    ParseContext? context,
  }) async {
    final ctx = context ?? await _parseContext();
    final parser = _adapter.buildParser(ctx);
    final ScheduleItem parsed = parser.parse(input);
    final result = _adapter.mapToAppTypes(parsed, ctx: ctx);
    _maybeLogNotes(result);
    return result;
  }

  Future<ParseContext> _parseContext() async {
    await _ensureTimezonesInitialized();
    final tzName = await _resolveTimezone();
    return ParseContext(
      location: _lookupLocation(tzName),
      timezoneId: tzName,
    );
  }

  void _maybeLogNotes(NlAdapterResult result) {
    if (result.parseNotes == null) return;
    debugPrint('NL parser notes (${result.bucket.name}): ${result.parseNotes}');
  }

  Future<void> _ensureTimezonesInitialized() {
    final current = _timezoneInit;
    if (current != null) return current.future;
    final completer = Completer<void>();
    _timezoneInit = completer;
    try {
      tzdata.initializeTimeZones();
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    }
    return completer.future;
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
    } catch (_) {
      return tz.getLocation(_fallbackTz);
    }
  }
}
