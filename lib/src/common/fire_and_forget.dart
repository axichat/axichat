// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/safe_logging.dart';

const String _defaultFireAndForgetOperationName = 'fireAndForget';
const String _defaultFireAndForgetLoggerName = 'Axichat';

typedef FireAndForgetOperation<T> = FutureOr<T>? Function();

Future<void> fireAndForget<T>(
  FireAndForgetOperation<T> operation, {
  String? operationName,
  String? loggerName,
}) async {
  try {
    await Future<T?>.sync(operation);
  } on Exception catch (error, stackTrace) {
    SafeLogging.debugLog(
      'Unhandled async error during '
      '${operationName ?? _defaultFireAndForgetOperationName}: '
      '${error.runtimeType}.',
      name: loggerName ?? _defaultFireAndForgetLoggerName,
      error: error.runtimeType,
      stackTrace: stackTrace,
    );
  }
}
