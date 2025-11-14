import 'package:equatable/equatable.dart';
import 'package:delta_ffi/delta_safe.dart';

enum DeltaChatErrorCode {
  network,
  auth,
  server,
  attachmentTooLarge,
  permission,
  internal,
}

sealed class DeltaChatException extends Equatable implements Exception {
  const DeltaChatException({
    required this.code,
    required this.operation,
    required this.message,
  });

  final DeltaChatErrorCode code;
  final String operation;
  final String message;

  @override
  List<Object?> get props => [code, operation, message];

  @override
  String toString() => 'DeltaChatException($code, $operation): $message';
}

class DeltaNetworkException extends DeltaChatException {
  const DeltaNetworkException({
    required super.operation,
    required super.message,
  }) : super(
          code: DeltaChatErrorCode.network,
        );
}

class DeltaAuthException extends DeltaChatException {
  const DeltaAuthException({
    required super.operation,
    required super.message,
  }) : super(
          code: DeltaChatErrorCode.auth,
        );
}

class DeltaServerException extends DeltaChatException {
  const DeltaServerException({
    required super.operation,
    required super.message,
  }) : super(
          code: DeltaChatErrorCode.server,
        );
}

class DeltaAttachmentTooLargeException extends DeltaChatException {
  const DeltaAttachmentTooLargeException({
    required super.operation,
    required super.message,
  }) : super(
          code: DeltaChatErrorCode.attachmentTooLarge,
        );
}

class DeltaPermissionException extends DeltaChatException {
  const DeltaPermissionException({
    required super.operation,
    required super.message,
  }) : super(
          code: DeltaChatErrorCode.permission,
        );
}

class DeltaInternalException extends DeltaChatException {
  const DeltaInternalException({
    required super.operation,
    required super.message,
  }) : super(
          code: DeltaChatErrorCode.internal,
        );
}

class DeltaChatExceptionMapper {
  const DeltaChatExceptionMapper._();

  static DeltaChatException fromDeltaSafe(
    DeltaSafeException error, {
    required String operation,
  }) {
    return fromCoreMessage(
      operation: operation,
      message: error.message,
    );
  }

  static DeltaChatException fromCoreMessage({
    required String operation,
    String? message,
  }) {
    const fallback = 'Email operation failed.';
    final normalized = (message ?? '').trim();
    final resolvedMessage = normalized.isEmpty ? fallback : normalized;
    final lower = resolvedMessage.toLowerCase();
    if (_matchesAny(lower, const ['network', 'disconnect', 'offline', 'dns'])) {
      return DeltaNetworkException(
        operation: operation,
        message: resolvedMessage,
      );
    }
    if (_matchesAny(lower, const ['auth', 'password', 'login', 'credential'])) {
      return DeltaAuthException(operation: operation, message: resolvedMessage);
    }
    if (_matchesAny(lower, const ['too large', 'quota', 'attachment'])) {
      return DeltaAttachmentTooLargeException(
        operation: operation,
        message: resolvedMessage,
      );
    }
    if (_matchesAny(lower, const ['permission', 'not allowed', 'forbidden'])) {
      return DeltaPermissionException(
        operation: operation,
        message: resolvedMessage,
      );
    }
    if (_matchesAny(
        lower, const ['server', 'imap', 'smtp', 'timeout', 'remote'])) {
      return DeltaServerException(
        operation: operation,
        message: resolvedMessage,
      );
    }
    return DeltaInternalException(
      operation: operation,
      message: resolvedMessage,
    );
  }

  static bool _matchesAny(String input, List<String> needles) =>
      needles.any(input.contains);
}
