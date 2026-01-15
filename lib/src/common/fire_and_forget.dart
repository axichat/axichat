// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/safe_logging.dart';

const String _defaultFireAndForgetOperationName = 'fireAndForget';
const String _defaultFireAndForgetLoggerName = 'Axichat';

typedef FireAndForgetOperation<T> = FutureOr<T>? Function();

void fireAndForget<T>(
  FireAndForgetOperation<T> operation, {
  String? operationName,
  String? loggerName,
}) {
  unawaited(() async {
    try {
      final result = operation();
      if (result is Future<T>) {
        await result;
      }
    } catch (error, stackTrace) {
      SafeLogging.debugLog(
        'Unhandled async error during '
        '${operationName ?? _defaultFireAndForgetOperationName}: '
        '${error.runtimeType}.',
        name: loggerName ?? _defaultFireAndForgetLoggerName,
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }
  }());
}
