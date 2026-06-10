// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/transport/email_delta_transport.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

final class EmailDeltaWorkerRuntimeException implements Exception {
  const EmailDeltaWorkerRuntimeException(this.message);

  final String message;

  @override
  String toString() => 'EmailDeltaWorkerRuntimeException: $message';
}

Future<File> _deltaDatabaseFileFor(String databasePrefix) {
  return dbFileFor('${databasePrefix}_email');
}

const String _emailDeltaRpcVersion = '2.0';
// Aligned with Delta Chat's public deltachat-jsonrpc envelope so this bridge
// can delegate to upstream dc_jsonrpc_* methods where that becomes practical.
const String _emailDeltaRpcMethodPrefix = 'axichat.email.';
const String _emailDeltaRpcReadyMethod = 'axichat.email.ready';
const String _emailDeltaRpcEventMethod = 'axichat.email.event';
const String _emailDeltaRpcTypeKey = r'$type';

Map<String, Object?> _emailDeltaWorkerConfigMessage({
  required SendPort mainPort,
  required String deltaDatabasePath,
  required String databasePrefix,
  required String databasePassphrase,
  required Map<String, bool> emailEncryptionBetaEnabledByAddress,
  required String? xmppSelfJid,
}) => {
  'mainPort': mainPort,
  'deltaDatabasePath': deltaDatabasePath,
  'databasePrefix': databasePrefix,
  'databasePassphrase': databasePassphrase,
  'emailEncryptionBetaEnabledByAddress': Map<String, bool>.from(
    emailEncryptionBetaEnabledByAddress,
  ),
  'xmppSelfJid': xmppSelfJid,
};

Map<String, Object?> _emailDeltaRpcRequest(
  int id,
  String op,
  Map<String, Object?> params,
) => {
  'jsonrpc': _emailDeltaRpcVersion,
  'id': id,
  'method': '$_emailDeltaRpcMethodPrefix$op',
  'params': _encodeEmailDeltaRpcValue(params),
};

Map<String, Object?> _emailDeltaRpcResponse({
  required int id,
  Object? result,
}) => {
  'jsonrpc': _emailDeltaRpcVersion,
  'id': id,
  'result': _encodeEmailDeltaRpcValue(result),
};

Map<String, Object?> _emailDeltaRpcError({
  required int id,
  required Object error,
}) => {
  'jsonrpc': _emailDeltaRpcVersion,
  'id': id,
  'error': _emailDeltaRpcErrorPayload(error),
};

Map<String, Object?> _emailDeltaRpcErrorPayload(Object error) {
  final payload = <String, Object?>{
    'code': -32000,
    'type': _emailDeltaRpcErrorType(error),
    'message': _emailDeltaRpcErrorMessage(error),
  };
  if (error is DeltaAccountUnavailableException) {
    payload['accountId'] = error.accountId;
  }
  return payload;
}

String _emailDeltaRpcErrorType(Object error) {
  if (error is DeltaConfigurationTimeoutException) {
    return 'DeltaConfigurationTimeoutException';
  }
  if (error is DeltaAllocationException) {
    return 'DeltaAllocationException';
  }
  if (error is DeltaOperationException) {
    return 'DeltaOperationException';
  }
  if (error is DeltaStateException) {
    return 'DeltaStateException';
  }
  if (error is DeltaAccountUnavailableException) {
    return 'DeltaAccountUnavailableException';
  }
  if (error is DeltaTransportSecurityException) {
    return 'DeltaTransportSecurityException';
  }
  if (error is EmailDeltaImexTimeoutException) {
    return 'EmailDeltaImexTimeoutException';
  }
  if (error is EmailDeltaImexCancelledException) {
    return 'EmailDeltaImexCancelledException';
  }
  if (error is EmailDeltaImexException) {
    return 'EmailDeltaImexException';
  }
  if (error is EmailDeltaWorkerRuntimeException) {
    return 'EmailDeltaWorkerRuntimeException';
  }
  if (error is StateError) {
    return 'StateError';
  }
  return error.runtimeType.toString();
}

String _emailDeltaRpcErrorMessage(Object error) {
  if (error is EmailDeltaWorkerRuntimeException) {
    return error.message;
  }
  if (error is DeltaSafeException) {
    return error.message;
  }
  if (error is EmailDeltaImexException) {
    return error.message;
  }
  if (error is StateError) {
    return error.message;
  }
  return 'Delta worker request failed with ${error.runtimeType}.';
}

Object _emailDeltaRpcExceptionFromError(Map<Object?, Object?> error) {
  final rawMessage = error['message'];
  final message = rawMessage is String && rawMessage.isNotEmpty
      ? rawMessage
      : 'Delta worker request failed.';
  final type = error['type'];
  return switch (type) {
    'DeltaConfigurationTimeoutException' =>
      const DeltaConfigurationTimeoutException(),
    'DeltaAllocationException' => DeltaAllocationException(message),
    'DeltaOperationException' => DeltaOperationException(message),
    'DeltaStateException' => DeltaStateException(message),
    'DeltaAccountUnavailableException' => switch (error['accountId']) {
      final int accountId => DeltaAccountUnavailableException(accountId),
      _ => DeltaOperationException(message),
    },
    'DeltaTransportSecurityException' => DeltaTransportSecurityException(
      message,
    ),
    'EmailDeltaImexTimeoutException' => const EmailDeltaImexTimeoutException(),
    'EmailDeltaImexCancelledException' =>
      const EmailDeltaImexCancelledException(),
    'EmailDeltaImexException' => EmailDeltaImexException(message),
    'EmailDeltaWorkerRuntimeException' => EmailDeltaWorkerRuntimeException(
      message,
    ),
    'StateError' => StateError(message),
    _ => EmailDeltaWorkerRuntimeException(message),
  };
}

Map<String, Object?> _emailDeltaRpcNotification(
  String method,
  Map<String, Object?> params,
) => {
  'jsonrpc': _emailDeltaRpcVersion,
  'method': method,
  'params': _encodeEmailDeltaRpcValue(params),
};

Map<String, Object?> _emailDeltaReadyMessage(SendPort port) =>
    _emailDeltaRpcNotification(_emailDeltaRpcReadyMethod, {'port': port});

Map<String, Object?> _emailDeltaEventMessage(DeltaCoreEvent event) =>
    _emailDeltaRpcNotification(_emailDeltaRpcEventMethod, {'event': event});

Map<Object?, Object?>? _rpcMap(Object? message) {
  if (message is Map<Object?, Object?>) {
    return message;
  }
  if (message is Map) {
    return message.cast<Object?, Object?>();
  }
  return null;
}

String? _rpcMethod(Map<Object?, Object?> message) {
  final method = message['method'];
  return method is String ? method : null;
}

int? _rpcId(Map<Object?, Object?> message) {
  final id = message['id'];
  return id is int ? id : null;
}

Map<String, Object?> _rpcParams(Map<Object?, Object?> message) {
  final decoded = _decodeEmailDeltaRpcValue(message['params']);
  if (decoded is Map<String, Object?>) {
    return decoded;
  }
  return const <String, Object?>{};
}

String? _opFromRpcMethod(String method) {
  if (!method.startsWith(_emailDeltaRpcMethodPrefix)) {
    return null;
  }
  return method.substring(_emailDeltaRpcMethodPrefix.length);
}

SendPort? _readyPortFromMessage(Object? message) {
  final rpc = _rpcMap(message);
  if (rpc == null || _rpcMethod(rpc) != _emailDeltaRpcReadyMethod) {
    return null;
  }
  final port = _rpcParams(rpc)['port'];
  return port is SendPort ? port : null;
}

Object? _encodeEmailDeltaRpcValue(Object? value) {
  if (value == null ||
      value is bool ||
      value is num ||
      value is String ||
      value is SendPort) {
    return value;
  }
  if (value is Duration) {
    return {
      _emailDeltaRpcTypeKey: 'Duration',
      'microseconds': value.inMicroseconds,
    };
  }
  if (value is DateTime) {
    return {
      _emailDeltaRpcTypeKey: 'DateTime',
      'microsecondsSinceEpoch': value.microsecondsSinceEpoch,
      'isUtc': value.isUtc,
    };
  }
  if (value is MessageTimelineFilter) {
    return {_emailDeltaRpcTypeKey: 'MessageTimelineFilter', 'name': value.name};
  }
  if (value is DeltaOpenPgpKeyKind) {
    return {_emailDeltaRpcTypeKey: 'DeltaOpenPgpKeyKind', 'name': value.name};
  }
  if (value is EmailAttachment) {
    return {
      _emailDeltaRpcTypeKey: 'EmailAttachment',
      'path': value.path,
      'fileName': value.fileName,
      'sizeBytes': value.sizeBytes,
      'mimeType': value.mimeType,
      'width': value.width,
      'height': value.height,
      'caption': value.caption,
      'metadataId': value.metadataId,
    };
  }
  if (value is DeltaCoreEvent) {
    return {
      _emailDeltaRpcTypeKey: 'DeltaCoreEvent',
      'type': value.type,
      'data1': value.data1,
      'data2': value.data2,
      'data1Text': value.data1Text,
      'data2Text': value.data2Text,
      'accountId': value.accountId,
    };
  }
  if (value is DeltaOpenPgpKeyMetadata) {
    return {
      _emailDeltaRpcTypeKey: 'DeltaOpenPgpKeyMetadata',
      'kind': value.kind.name,
      'fingerprint': value.fingerprint,
      'userIds': _encodeEmailDeltaRpcValue(value.userIds),
      'hasExpectedAddress': value.hasExpectedAddress,
      'hasEncryptionCapability': value.hasEncryptionCapability,
    };
  }
  if (value is DeltaContactPublicKeyImport) {
    return {
      _emailDeltaRpcTypeKey: 'DeltaContactPublicKeyImport',
      'metadata': _encodeEmailDeltaRpcValue(value.metadata),
      'contactId': value.contactId,
      'chatId': value.chatId,
    };
  }
  if (value is DeltaContactPublicKeyRemoval) {
    return {
      _emailDeltaRpcTypeKey: 'DeltaContactPublicKeyRemoval',
      'contactId': value.contactId,
      'chatId': value.chatId,
      'fallbackContactId': value.fallbackContactId,
      'fingerprint': value.fingerprint,
    };
  }
  if (value is EmailDeltaImexResult) {
    return {
      _emailDeltaRpcTypeKey: 'EmailDeltaImexResult',
      'accountId': value.accountId,
      'exportedPaths': _encodeEmailDeltaRpcValue(value.exportedPaths),
    };
  }
  if (value is DeltaChatSendCapabilities) {
    return {
      _emailDeltaRpcTypeKey: 'DeltaChatSendCapabilities',
      'exists': value.exists,
      'canSend': value.canSend,
      'isEncrypted': value.isEncrypted,
    };
  }
  if (value is DeltaChatlistEntry) {
    return {
      _emailDeltaRpcTypeKey: 'DeltaChatlistEntry',
      'chatId': value.chatId,
      'msgId': value.msgId,
    };
  }
  if (value is DeltaFreshMessageCount) {
    return {
      _emailDeltaRpcTypeKey: 'DeltaFreshMessageCount',
      'count': value.count,
      'supported': value.supported,
    };
  }
  if (value is DeltaChat) {
    return {
      _emailDeltaRpcTypeKey: 'DeltaChat',
      'id': value.id,
      'name': value.name,
      'contactAddress': value.contactAddress,
      'contactId': value.contactId,
      'contactName': value.contactName,
      'type': value.type,
    };
  }
  if (value is DeltaContact) {
    return {
      _emailDeltaRpcTypeKey: 'DeltaContact',
      'id': value.id,
      'address': value.address,
      'name': value.name,
    };
  }
  if (value is DeltaMessage) {
    return {
      _emailDeltaRpcTypeKey: 'DeltaMessage',
      'id': value.id,
      'chatId': value.chatId,
      'text': value.text,
      'html': value.html,
      'subject': value.subject,
      'viewType': value.viewType,
      'infoType': value.infoType,
      'state': value.state,
      'filePath': value.filePath,
      'fileName': value.fileName,
      'fileMime': value.fileMime,
      'fileSize': value.fileSize,
      'width': value.width,
      'height': value.height,
      'timestamp': _encodeEmailDeltaRpcValue(value.timestamp),
      'isOutgoing': value.isOutgoing,
      'downloadState': value.downloadState,
      'error': value.error,
      'showPadlock': value.showPadlock,
    };
  }
  if (value is DeltaMessageRfc822Body) {
    return {
      _emailDeltaRpcTypeKey: 'DeltaMessageRfc822Body',
      'plainText': value.plainText,
      'htmlBody': value.htmlBody,
    };
  }
  if (value is DeltaQuotedMessage) {
    return {
      _emailDeltaRpcTypeKey: 'DeltaQuotedMessage',
      'id': value.id,
      'text': value.text,
    };
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      result[entry.key.toString()] = _encodeEmailDeltaRpcValue(entry.value);
    }
    return result;
  }
  if (value is Iterable) {
    return value.map(_encodeEmailDeltaRpcValue).toList(growable: false);
  }
  throw EmailDeltaWorkerRuntimeException(
    'Delta RPC value ${value.runtimeType} is not sendable.',
  );
}

Object? _decodeEmailDeltaRpcValue(Object? value) {
  if (value == null ||
      value is bool ||
      value is num ||
      value is String ||
      value is SendPort) {
    return value;
  }
  if (value is List) {
    final decoded = value
        .map(_decodeEmailDeltaRpcValue)
        .toList(growable: false);
    if (decoded.every((item) => item is int)) {
      return decoded.cast<int>().toList(growable: false);
    }
    if (decoded.every((item) => item is String)) {
      return decoded.cast<String>().toList(growable: false);
    }
    return decoded;
  }
  if (value is! Map) {
    return value;
  }
  final map = <String, Object?>{};
  for (final entry in value.entries) {
    map[entry.key.toString()] = _decodeEmailDeltaRpcValue(entry.value);
  }
  final type = map[_emailDeltaRpcTypeKey];
  if (type is! String) {
    return map;
  }
  return switch (type) {
    'Duration' => Duration(microseconds: _intValue(map['microseconds'])),
    'DateTime' => DateTime.fromMicrosecondsSinceEpoch(
      _intValue(map['microsecondsSinceEpoch']),
      isUtc: map['isUtc'] == true,
    ),
    'MessageTimelineFilter' => MessageTimelineFilter.values.byName(
      _stringValue(map['name']),
    ),
    'DeltaOpenPgpKeyKind' => DeltaOpenPgpKeyKind.values.byName(
      _stringValue(map['name']),
    ),
    'EmailAttachment' => EmailAttachment(
      path: _stringValue(map['path']),
      fileName: _stringValue(map['fileName']),
      sizeBytes: _intValue(map['sizeBytes']),
      mimeType: _nullableStringValue(map['mimeType']),
      width: _nullableIntValue(map['width']),
      height: _nullableIntValue(map['height']),
      caption: _nullableStringValue(map['caption']),
      metadataId: _nullableStringValue(map['metadataId']),
    ),
    'DeltaCoreEvent' => DeltaCoreEvent(
      type: _intValue(map['type']),
      data1: _intValue(map['data1']),
      data2: _intValue(map['data2']),
      data1Text: _nullableStringValue(map['data1Text']),
      data2Text: _nullableStringValue(map['data2Text']),
      accountId: _nullableIntValue(map['accountId']),
    ),
    'DeltaOpenPgpKeyMetadata' => DeltaOpenPgpKeyMetadata(
      kind: DeltaOpenPgpKeyKind.values.byName(_stringValue(map['kind'])),
      fingerprint: _stringValue(map['fingerprint']),
      userIds: _stringListValue(map['userIds']),
      hasExpectedAddress: map['hasExpectedAddress'] == true,
      hasEncryptionCapability: map['hasEncryptionCapability'] == true,
    ),
    'DeltaContactPublicKeyImport' => DeltaContactPublicKeyImport(
      metadata: map['metadata'] as DeltaOpenPgpKeyMetadata,
      contactId: _intValue(map['contactId']),
      chatId: _intValue(map['chatId']),
    ),
    'DeltaContactPublicKeyRemoval' => DeltaContactPublicKeyRemoval(
      contactId: _intValue(map['contactId']),
      chatId: _intValue(map['chatId']),
      fallbackContactId: _intValue(map['fallbackContactId']),
      fingerprint: _stringValue(map['fingerprint']),
    ),
    'EmailDeltaImexResult' => EmailDeltaImexResult(
      accountId: _intValue(map['accountId']),
      exportedPaths: _stringListValue(map['exportedPaths']),
    ),
    'DeltaChatSendCapabilities' => DeltaChatSendCapabilities(
      exists: map['exists'] == true,
      canSend: _nullableBoolValue(map['canSend']),
      isEncrypted: _nullableBoolValue(map['isEncrypted']),
    ),
    'DeltaChatlistEntry' => DeltaChatlistEntry(
      chatId: _intValue(map['chatId']),
      msgId: _intValue(map['msgId']),
    ),
    'DeltaFreshMessageCount' => DeltaFreshMessageCount(
      count: _intValue(map['count']),
      supported: map['supported'] == true,
    ),
    'DeltaChat' => DeltaChat(
      id: _intValue(map['id']),
      name: _nullableStringValue(map['name']),
      contactAddress: _nullableStringValue(map['contactAddress']),
      contactId: _nullableIntValue(map['contactId']),
      contactName: _nullableStringValue(map['contactName']),
      type: _nullableIntValue(map['type']),
    ),
    'DeltaContact' => DeltaContact(
      id: _intValue(map['id']),
      address: _nullableStringValue(map['address']),
      name: _nullableStringValue(map['name']),
    ),
    'DeltaMessage' => DeltaMessage(
      id: _intValue(map['id']),
      chatId: _intValue(map['chatId']),
      text: _nullableStringValue(map['text']),
      html: _nullableStringValue(map['html']),
      subject: _nullableStringValue(map['subject']),
      viewType: _nullableIntValue(map['viewType']),
      infoType: _nullableIntValue(map['infoType']),
      state: _nullableIntValue(map['state']),
      filePath: _nullableStringValue(map['filePath']),
      fileName: _nullableStringValue(map['fileName']),
      fileMime: _nullableStringValue(map['fileMime']),
      fileSize: _nullableIntValue(map['fileSize']),
      width: _nullableIntValue(map['width']),
      height: _nullableIntValue(map['height']),
      timestamp: map['timestamp'] as DateTime?,
      isOutgoing: map['isOutgoing'] == true,
      downloadState: _nullableIntValue(map['downloadState']),
      error: _nullableStringValue(map['error']),
      showPadlock: map['showPadlock'] == true,
    ),
    'DeltaMessageRfc822Body' => DeltaMessageRfc822Body(
      plainText: _nullableStringValue(map['plainText']),
      htmlBody: _nullableStringValue(map['htmlBody']),
    ),
    'DeltaQuotedMessage' => DeltaQuotedMessage(
      id: _nullableIntValue(map['id']),
      text: _nullableStringValue(map['text']),
    ),
    _ => map,
  };
}

@visibleForTesting
Object? encodeEmailDeltaRpcValueForTesting(Object? value) =>
    _encodeEmailDeltaRpcValue(value);

@visibleForTesting
Object? decodeEmailDeltaRpcValueForTesting(Object? value) =>
    _decodeEmailDeltaRpcValue(value);

int _intValue(Object? value) {
  if (value is int) return value;
  throw EmailDeltaWorkerRuntimeException('Expected int Delta RPC value.');
}

int? _nullableIntValue(Object? value) =>
    value == null ? null : _intValue(value);

String _stringValue(Object? value) {
  if (value is String) return value;
  throw EmailDeltaWorkerRuntimeException('Expected String Delta RPC value.');
}

String? _nullableStringValue(Object? value) =>
    value == null ? null : _stringValue(value);

bool? _nullableBoolValue(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  throw EmailDeltaWorkerRuntimeException('Expected bool Delta RPC value.');
}

List<String> _stringListValue(Object? value) {
  if (value is List<String>) return value;
  if (value is List) {
    return value.map(_stringValue).toList(growable: false);
  }
  return const <String>[];
}

List<int> _intListValue(Object? value) {
  if (value is List<int>) return value;
  if (value is List) {
    return value.map(_intValue).toList(growable: false);
  }
  return const <int>[];
}

Map<String, Object?> _mapValue(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return const <String, Object?>{};
}

Map<String, bool> _boolMapValue(Object? value) {
  if (value is! Map) {
    return const <String, bool>{};
  }
  final result = <String, bool>{};
  for (final entry in value.entries) {
    final key = entry.key;
    final mapValue = entry.value;
    if (key is String && mapValue is bool) {
      result[key] = mapValue;
    }
  }
  return result;
}

class EmailDeltaWorkerRuntime implements EmailDeltaRuntime {
  EmailDeltaWorkerRuntime({
    String? Function()? xmppSelfJidProvider,
    Logger? logger,
    @visibleForTesting
    Duration debugBackgroundFetchRpcGracePeriod = const Duration(seconds: 5),
    @visibleForTesting
    Future<SendPort> Function({
      required SendPort mainPort,
      required String deltaDatabasePath,
      required String databasePrefix,
      required String databasePassphrase,
      required Map<String, bool> emailEncryptionBetaEnabledByAddress,
      required String? xmppSelfJid,
    })?
    debugWorkerStarter,
  }) : _xmppSelfJidProvider = xmppSelfJidProvider,
       _backgroundFetchRpcGracePeriod = debugBackgroundFetchRpcGracePeriod,
       _debugWorkerStarter = debugWorkerStarter,
       _log = logger ?? Logger('EmailDeltaWorkerRuntime');

  final String? Function()? _xmppSelfJidProvider;
  final Duration _backgroundFetchRpcGracePeriod;
  final Future<SendPort> Function({
    required SendPort mainPort,
    required String deltaDatabasePath,
    required String databasePrefix,
    required String databasePassphrase,
    required Map<String, bool> emailEncryptionBetaEnabledByAddress,
    required String? xmppSelfJid,
  })?
  _debugWorkerStarter;
  final Logger _log;
  final StreamController<DeltaCoreEvent> _events =
      StreamController<DeltaCoreEvent>.broadcast(sync: true);
  final List<void Function(DeltaCoreEvent event)> _eventListeners = [];
  final Map<int, Completer<Object?>> _pending = {};
  Map<String, bool> _emailEncryptionBetaEnabledByAddress =
      const <String, bool>{};
  Future<void>? _startFuture;
  Future<void>? _workerInitializationFuture;
  ReceivePort? _receivePort;
  StreamSubscription<Object?>? _receiveSubscription;
  Isolate? _isolate;
  SendPort? _workerPort;
  int _nextRequestId = 0;
  String? _databasePrefix;
  String? _databasePassphrase;
  bool _accountsSupported = true;
  bool _accountsActive = false;
  int _activeAccountId = DeltaAccountDefaults.legacyId;
  bool _isIoRunning = false;
  bool _workerInitialized = false;
  final Map<int, String> _selfJids = {};

  @override
  Stream<DeltaCoreEvent> get events => _events.stream;

  @override
  String? get selfJid => selfJidForAccount(_activeAccountId);

  @override
  bool get accountsSupported => _accountsSupported;

  @override
  bool get accountsActive => _accountsActive;

  @override
  int get activeAccountId => _activeAccountId;

  @override
  bool get isIoRunning => _isIoRunning;

  @override
  bool get persistsAppStateInternally => false;

  @override
  void updateDatabaseOperationTracker(
    Future<T> Function<T>(Future<T> Function() operation)? tracker,
  ) {}

  @override
  void updateEmailEncryptionBetaSettings(Map<String, bool> enabledByAddress) {
    _emailEncryptionBetaEnabledByAddress = Map<String, bool>.unmodifiable(
      enabledByAddress,
    );
    _sendBestEffort('updateEmailEncryptionBetaSettings', {
      'enabledByAddress': _emailEncryptionBetaEnabledByAddress,
    });
  }

  @override
  void hydrateAccountAddress({required String address, int? accountId}) {
    if (accountId != null) {
      _selfJids[accountId] = address;
    }
    _sendBestEffort('hydrateAccountAddress', {
      'address': address,
      'accountId': accountId,
    });
  }

  @override
  void setPrimaryAccountId(int? accountId) {
    if (accountId == null) {
      _activeAccountId = DeltaAccountDefaults.legacyId;
    } else {
      _activeAccountId = accountId;
    }
    _sendBestEffort('setPrimaryAccountId', {'accountId': accountId});
  }

  @override
  String? selfJidForAccount(int accountId) => _selfJids[accountId];

  @override
  void addEventListener(void Function(DeltaCoreEvent event) listener) {
    if (!_eventListeners.contains(listener)) {
      _eventListeners.add(listener);
    }
  }

  @override
  void removeEventListener(void Function(DeltaCoreEvent event) listener) {
    _eventListeners.remove(listener);
  }

  @override
  Future<void> ensureInitialized({
    required String databasePrefix,
    required String databasePassphrase,
  }) async {
    await _ensureWorker(
      databasePrefix: databasePrefix,
      databasePassphrase: databasePassphrase,
    );
    await _ensureWorkerInitialized();
    await _refreshState();
  }

  Future<void> _ensureWorker({
    required String databasePrefix,
    required String databasePassphrase,
  }) async {
    if (_workerPort != null &&
        _databasePrefix == databasePrefix &&
        _databasePassphrase == databasePassphrase) {
      return;
    }
    final starting = _startFuture;
    if (starting != null) {
      await starting;
      if (_workerPort != null &&
          _databasePrefix == databasePrefix &&
          _databasePassphrase == databasePassphrase) {
        return;
      }
    }
    _startFuture = _startWorker(
      databasePrefix: databasePrefix,
      databasePassphrase: databasePassphrase,
    );
    try {
      await _startFuture;
    } finally {
      _startFuture = null;
    }
  }

  void _sendBestEffort(String op, Map<String, Object?> payload) {
    if (_workerPort == null) {
      return;
    }
    unawaited(
      _invoke<void>(op, payload).onError<Exception>((error, stackTrace) {
        _log.fine('Best-effort Delta worker $op failed.', error, stackTrace);
      }),
    );
  }

  Future<void> _startWorker({
    required String databasePrefix,
    required String databasePassphrase,
  }) async {
    await _stopWorker(clearInitialization: false);
    final deltaDatabaseFile = await _deltaDatabaseFileFor(databasePrefix);
    final receivePort = ReceivePort('email-delta-worker-main');
    final ready = Completer<SendPort>();
    _receivePort = receivePort;
    _receiveSubscription = receivePort.listen((message) {
      final readyPort = _readyPortFromMessage(message);
      if (readyPort != null) {
        if (!ready.isCompleted) {
          ready.complete(readyPort);
        }
        return;
      }
      _handleWorkerMessage(message);
    });
    try {
      final debugWorkerStarter = _debugWorkerStarter;
      if (debugWorkerStarter == null) {
        _isolate = await Isolate.spawn<Map<String, Object?>>(
          _emailDeltaWorkerMain,
          _emailDeltaWorkerConfigMessage(
            mainPort: receivePort.sendPort,
            deltaDatabasePath: deltaDatabaseFile.path,
            databasePrefix: databasePrefix,
            databasePassphrase: databasePassphrase,
            emailEncryptionBetaEnabledByAddress:
                _emailEncryptionBetaEnabledByAddress,
            xmppSelfJid: _xmppSelfJidProvider?.call(),
          ),
          debugName: 'email-delta-runtime',
        );
        _workerPort = await ready.future.timeout(const Duration(seconds: 10));
      } else {
        _workerPort = await debugWorkerStarter(
          mainPort: receivePort.sendPort,
          deltaDatabasePath: deltaDatabaseFile.path,
          databasePrefix: databasePrefix,
          databasePassphrase: databasePassphrase,
          emailEncryptionBetaEnabledByAddress:
              _emailEncryptionBetaEnabledByAddress,
          xmppSelfJid: _xmppSelfJidProvider?.call(),
        ).timeout(const Duration(seconds: 10));
      }
      _databasePrefix = databasePrefix;
      _databasePassphrase = databasePassphrase;
      _workerInitialized = false;
      _log.info('Email Delta worker started.');
    } on Exception {
      await _stopWorker(requestDispose: false);
      rethrow;
    }
  }

  Future<void> _stopWorker({
    bool clearInitialization = true,
    bool requestDispose = true,
  }) async {
    _workerInitializationFuture = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          const EmailDeltaWorkerRuntimeException('Delta worker stopped.'),
        );
      }
    }
    _pending.clear();
    _workerInitialized = false;
    _isIoRunning = false;
    final workerPort = _workerPort;
    _workerPort = null;
    if (workerPort != null && requestDispose) {
      final id = ++_nextRequestId;
      final disposeCompleter = Completer<Object?>();
      _pending[id] = disposeCompleter;
      workerPort.send(_emailDeltaRpcRequest(id, 'dispose', const {}));
      try {
        await disposeCompleter.future.timeout(const Duration(seconds: 5));
      } on Exception catch (error, stackTrace) {
        _log.fine('Delta worker dispose request failed.', error, stackTrace);
      } finally {
        _pending.remove(id);
      }
    }
    if (clearInitialization) {
      _databasePrefix = null;
      _databasePassphrase = null;
    }
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
    await _receiveSubscription?.cancel();
    _receiveSubscription = null;
    _receivePort?.close();
    _receivePort = null;
  }

  @visibleForTesting
  Future<void> debugStopWorkerPreservingInitializationForTest() =>
      _stopWorker(clearInitialization: false);

  void _handleWorkerMessage(Object? message) {
    final rpc = _rpcMap(message);
    if (rpc == null) {
      return;
    }
    final method = _rpcMethod(rpc);
    if (method == _emailDeltaRpcEventMethod) {
      final event = _rpcParams(rpc)['event'];
      if (event is! DeltaCoreEvent || _events.isClosed) {
        return;
      }
      _events.add(event);
      for (final listener in List.of(_eventListeners)) {
        listener(event);
      }
      return;
    }
    final id = _rpcId(rpc);
    if (id != null) {
      final completer = _pending.remove(id);
      if (completer == null || completer.isCompleted) {
        return;
      }
      final error = rpc['error'];
      if (error is Map) {
        completer.completeError(
          _emailDeltaRpcExceptionFromError(error.cast<Object?, Object?>()),
        );
      } else {
        completer.complete(_decodeEmailDeltaRpcValue(rpc['result']));
      }
      return;
    }
  }

  Future<T> _invoke<T>(
    String op,
    Map<String, Object?> payload, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final port = _workerPort;
    if (port == null) {
      final starting = _startFuture;
      if (starting != null) {
        await starting;
      } else {
        final prefix = _databasePrefix;
        final passphrase = _databasePassphrase;
        if (prefix == null || passphrase == null) {
          throw const EmailDeltaWorkerRuntimeException(
            'Delta worker is not initialized.',
          );
        }
        await _ensureWorker(
          databasePrefix: prefix,
          databasePassphrase: passphrase,
        );
      }
    }
    await _ensureWorkerInitializedForRequest(op);
    final activePort = _workerPort;
    if (activePort == null) {
      throw const EmailDeltaWorkerRuntimeException(
        'Delta worker is unavailable.',
      );
    }
    final id = ++_nextRequestId;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    activePort.send(_emailDeltaRpcRequest(id, op, payload));
    final result = await completer.future.timeout(
      timeout,
      onTimeout: () async {
        _pending.remove(id);
        await _stopWorker(clearInitialization: false, requestDispose: false);
        throw EmailDeltaWorkerRuntimeException('Delta worker $op timed out.');
      },
    );
    if (op == 'ensureInitialized') {
      _workerInitialized = true;
    }
    return result as T;
  }

  Future<void> _ensureWorkerInitializedForRequest(String op) async {
    if (_workerInitialized ||
        op == 'ensureInitialized' ||
        op == 'runtimeState') {
      return;
    }
    await _ensureWorkerInitialized();
  }

  Future<void> _ensureWorkerInitialized() async {
    if (_workerInitialized) {
      return;
    }
    final existing = _workerInitializationFuture;
    if (existing != null) {
      await existing;
      return;
    }
    final prefix = _databasePrefix;
    final passphrase = _databasePassphrase;
    if (prefix == null || passphrase == null) {
      throw const EmailDeltaWorkerRuntimeException(
        'Delta worker is not initialized.',
      );
    }
    final future = _invoke<void>('ensureInitialized', {
      'databasePrefix': prefix,
      'databasePassphrase': passphrase,
    });
    _workerInitializationFuture = future;
    try {
      await future;
    } finally {
      if (identical(_workerInitializationFuture, future)) {
        _workerInitializationFuture = null;
      }
    }
  }

  void _applyState(Map<String, Object?> state) {
    _accountsSupported = state['accountsSupported'] == true;
    _accountsActive = state['accountsActive'] == true;
    _activeAccountId = _intValue(state['activeAccountId']);
    _isIoRunning = state['isIoRunning'] == true;
    _selfJids
      ..clear()
      ..addAll(_selfJidsFromState(state['selfJids']));
  }

  Future<void> _refreshState() async {
    try {
      final state = await _invoke<Map<String, Object?>>(
        'runtimeState',
        const {},
      );
      _applyState(state);
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to refresh Delta worker state.', error, stackTrace);
    }
  }

  Map<int, String> _selfJidsFromState(Object? value) {
    if (value is! Map) {
      return const <int, String>{};
    }
    final result = <int, String>{};
    for (final entry in value.entries) {
      final id = int.tryParse(entry.key.toString());
      final jid = entry.value;
      if (id != null && jid is String) {
        result[id] = jid;
      }
    }
    return result;
  }

  @override
  Future<bool> isConfigured({int? accountId}) =>
      _invoke<bool>('isConfigured', {'accountId': accountId});

  @override
  Future<void> deconfigureAccount({int? accountId}) async {
    await _invoke<void>('deconfigureAccount', {'accountId': accountId});
    await _refreshState();
  }

  @override
  Future<void> configureAccount({
    required String address,
    required String password,
    required String displayName,
    Map<String, String> additional = const {},
    int? accountId,
  }) async {
    await _invoke<void>('configureAccount', {
      'address': address,
      'password': password,
      'displayName': displayName,
      'additional': additional,
      'accountId': accountId,
    }, timeout: const Duration(seconds: 90));
    await _refreshState();
    if (accountId != null) {
      _selfJids[accountId] = address;
    } else {
      _selfJids[_activeAccountId] = address;
    }
  }

  @override
  Future<void> start() async {
    await _invoke<void>('start', const {});
    _isIoRunning = true;
    await _refreshState();
  }

  @override
  Future<void> stop() async {
    await _invoke<void>('stop', const {});
    _isIoRunning = false;
    await _refreshState();
  }

  @override
  Future<void> stopEventDeliveryForLogout() =>
      _invoke<void>('stopEventDeliveryForLogout', const {});

  @override
  Future<void> dispose({bool requestWorkerDispose = true}) async {
    await _stopWorker(requestDispose: requestWorkerDispose);
    if (!_events.isClosed) {
      await _events.close();
    }
  }

  @override
  Future<bool> bootstrapFromCore({int? accountId}) =>
      _invoke<bool>('bootstrapFromCore', {'accountId': accountId});

  @override
  Future<void> refreshChatlistSnapshot({int? accountId}) =>
      _invoke<void>('refreshChatlistSnapshot', {'accountId': accountId});

  @override
  Future<void> notifyNetworkAvailable() =>
      _invoke<void>('notifyNetworkAvailable', const {});

  @override
  Future<void> notifyNetworkLost() =>
      _invoke<void>('notifyNetworkLost', const {});

  @override
  Future<bool> performBackgroundFetch(Duration timeout) {
    final rpcTimeout = timeout + _backgroundFetchRpcGracePeriod;
    return _invoke<bool>('performBackgroundFetch', {
      'timeout': timeout,
    }, timeout: rpcTimeout);
  }

  @override
  Future<void> backfillChatHistory({
    required int chatId,
    required String chatJid,
    required int desiredWindow,
    int? beforeMessageId,
    DateTime? beforeTimestamp,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    int? accountId,
  }) => _invoke<void>('backfillChatHistory', {
    'chatId': chatId,
    'chatJid': chatJid,
    'desiredWindow': desiredWindow,
    'beforeMessageId': beforeMessageId,
    'beforeTimestamp': beforeTimestamp,
    'filter': filter,
    'accountId': accountId,
  });

  @override
  Future<int?> connectivity({int? accountId}) =>
      _invoke<int?>('connectivity', {'accountId': accountId});

  @override
  Future<String?> connectivityDetails({int? accountId}) =>
      _invoke<String?>('connectivityDetails', {'accountId': accountId});

  @override
  Future<DeltaChatSendCapabilities> chatSendCapabilities({
    required int chatId,
    int? accountId,
  }) => _invoke<DeltaChatSendCapabilities>('chatSendCapabilities', {
    'chatId': chatId,
    'accountId': accountId,
  });

  @override
  Future<DeltaContactPublicKeyRemoval> removeContactPublicKey({
    required String address,
    required String fingerprint,
    required int contactId,
    required int chatId,
    int? accountId,
  }) => _invoke<DeltaContactPublicKeyRemoval>('removeContactPublicKey', {
    'address': address,
    'fingerprint': fingerprint,
    'contactId': contactId,
    'chatId': chatId,
    'accountId': accountId,
  });

  @override
  Future<List<int>> accountIds() async {
    final result = await _invoke<Map<String, Object?>>('accountIds', const {});
    _applyState(_mapValue(result['state']));
    return _intListValue(result['accountIds']);
  }

  @override
  Future<int> createAccount({bool closed = false}) async {
    final result = await _invoke<Map<String, Object?>>('createAccount', {
      'closed': closed,
    });
    _applyState(_mapValue(result['state']));
    return _intValue(result['accountId']);
  }

  @override
  Future<void> ensureAccountSession(int? accountId) async {
    final state = await _invoke<Map<String, Object?>>('ensureAccountSession', {
      'accountId': accountId,
    });
    _applyState(state);
  }

  @override
  Future<bool> removeAccount(int accountId) async {
    final result = await _invoke<Map<String, Object?>>('removeAccount', {
      'accountId': accountId,
    });
    _applyState(_mapValue(result['state']));
    return result['value'] == true;
  }

  @override
  Future<String?> getCoreConfig(String key, {int? accountId}) =>
      _invoke<String?>('getCoreConfig', {'key': key, 'accountId': accountId});

  @override
  Future<String?> getOauth2Url({
    required String address,
    required String redirectUri,
    int? accountId,
  }) => _invoke<String?>('getOauth2Url', {
    'address': address,
    'redirectUri': redirectUri,
    'accountId': accountId,
  });

  @override
  Future<void> setCoreConfig({
    required String key,
    required String value,
    int? accountId,
  }) => _invoke<void>('setCoreConfig', {
    'key': key,
    'value': value,
    'accountId': accountId,
  });

  @override
  Future<bool> setCoreConfigIfSupported({
    required String key,
    required String value,
    int? accountId,
  }) => _invoke<bool>('setCoreConfigIfSupported', {
    'key': key,
    'value': value,
    'accountId': accountId,
  });

  @override
  Future<DeltaOpenPgpKeyMetadata> inspectOpenPgpKey({
    required String armored,
    required String expectedAddress,
    required DeltaOpenPgpKeyKind expectedKind,
    int? accountId,
  }) => _invoke<DeltaOpenPgpKeyMetadata>('inspectOpenPgpKey', {
    'armored': armored,
    'expectedAddress': expectedAddress,
    'expectedKind': expectedKind,
    'accountId': accountId,
  });

  @override
  Future<DeltaContactPublicKeyImport> importContactPublicKey({
    required String address,
    required String displayName,
    required String armoredPublicKey,
    int? accountId,
  }) => _invoke<DeltaContactPublicKeyImport>('importContactPublicKey', {
    'address': address,
    'displayName': displayName,
    'armoredPublicKey': armoredPublicKey,
    'accountId': accountId,
  });

  @override
  Future<EmailDeltaImexResult> runImex({
    required int mode,
    required String path,
    int? accountId,
    Duration timeout = const Duration(minutes: 2),
  }) => _invoke<EmailDeltaImexResult>('runImex', {
    'mode': mode,
    'path': path,
    'accountId': accountId,
    'timeout': timeout,
  }, timeout: timeout + const Duration(seconds: 5));

  @override
  Future<void> cancelImex({int? accountId}) =>
      _invoke<void>('cancelImex', {'accountId': accountId});

  @override
  Future<void> registerPushToken(String token) =>
      _invoke<void>('registerPushToken', {'token': token});

  @override
  Future<int> sendText({
    required int chatId,
    required String body,
    String? subject,
    String? shareId,
    String? localBodyOverride,
    String? htmlBody,
    String? quotingStanzaId,
    int? accountId,
    bool forcePlaintext = false,
    bool skipAutocrypt = false,
  }) => _invoke<int>('sendText', {
    'chatId': chatId,
    'body': body,
    'subject': subject,
    'shareId': shareId,
    'localBodyOverride': localBodyOverride,
    'htmlBody': htmlBody,
    'quotingStanzaId': quotingStanzaId,
    'accountId': accountId,
    'forcePlaintext': forcePlaintext,
    'skipAutocrypt': skipAutocrypt,
  });

  @override
  Future<int> sendAttachment({
    required int chatId,
    required EmailAttachment attachment,
    String? subject,
    String? shareId,
    String? captionOverride,
    String? htmlCaption,
    String? quotingStanzaId,
    int? accountId,
    bool forcePlaintext = false,
    bool skipAutocrypt = false,
  }) => _invoke<int>('sendAttachment', {
    'chatId': chatId,
    'attachment': attachment,
    'subject': subject,
    'shareId': shareId,
    'captionOverride': captionOverride,
    'htmlCaption': htmlCaption,
    'quotingStanzaId': quotingStanzaId,
    'accountId': accountId,
    'forcePlaintext': forcePlaintext,
    'skipAutocrypt': skipAutocrypt,
  });

  @override
  Future<int> ensureChatForAddress({
    required String address,
    String? displayName,
    int? accountId,
  }) => _invoke<int>('ensureChatForAddress', {
    'address': address,
    'displayName': displayName,
    'accountId': accountId,
  });

  @override
  Future<int> createContact({
    required String address,
    String? displayName,
    int? accountId,
  }) => _invoke<int>('createContact', {
    'address': address,
    'displayName': displayName,
    'accountId': accountId,
  });

  @override
  Future<bool> blockContact(String address, {int? accountId}) => _invoke<bool>(
    'blockContact',
    {'address': address, 'accountId': accountId},
  );

  @override
  Future<bool> unblockContact(String address, {int? accountId}) =>
      _invoke<bool>('unblockContact', {
        'address': address,
        'accountId': accountId,
      });

  @override
  Future<bool> markNoticedChat(int chatId, {int? accountId}) => _invoke<bool>(
    'markNoticedChat',
    {'chatId': chatId, 'accountId': accountId},
  );

  @override
  Future<bool> markSeenMessages(List<int> messageIds, {int? accountId}) =>
      _invoke<bool>('markSeenMessages', {
        'messageIds': messageIds,
        'accountId': accountId,
      });

  @override
  Future<int> getFreshMessageCount(int chatId, {int? accountId}) =>
      _invoke<int>('getFreshMessageCount', {
        'chatId': chatId,
        'accountId': accountId,
      });

  @override
  Future<DeltaFreshMessageCount> getFreshMessageCountSafe(
    int chatId, {
    int? accountId,
  }) => _invoke<DeltaFreshMessageCount>('getFreshMessageCountSafe', {
    'chatId': chatId,
    'accountId': accountId,
  });

  @override
  Future<List<DeltaChatlistEntry>> getChatlist({
    int flags = 0,
    int? accountId,
  }) async {
    final result = await _invoke<List<Object?>>('getChatlist', {
      'flags': flags,
      'accountId': accountId,
    });
    return result.cast<DeltaChatlistEntry>().toList(growable: false);
  }

  @override
  Future<DeltaChat?> getChat(int chatId, {int? accountId}) =>
      _invoke<DeltaChat?>('getChat', {
        'chatId': chatId,
        'accountId': accountId,
      });

  @override
  Future<List<int>> getFreshMessageIds({int? accountId}) =>
      _invoke<List<int>>('getFreshMessageIds', {'accountId': accountId});

  @override
  Future<bool> deleteMessages(List<int> messageIds, {int? accountId}) =>
      _invoke<bool>('deleteMessages', {
        'messageIds': messageIds,
        'accountId': accountId,
      });

  @override
  Future<bool> forwardMessages({
    required List<int> messageIds,
    required int toChatId,
    int? accountId,
  }) => _invoke<bool>('forwardMessages', {
    'messageIds': messageIds,
    'toChatId': toChatId,
    'accountId': accountId,
  });

  @override
  Future<List<int>> searchMessages({
    required int chatId,
    required String query,
    int? accountId,
  }) => _invoke<List<int>>('searchMessages', {
    'chatId': chatId,
    'query': query,
    'accountId': accountId,
  });

  @override
  Future<List<int>> getChatMessageIds({
    required int chatId,
    int? beforeMessageId,
    int? accountId,
  }) => _invoke<List<int>>('getChatMessageIds', {
    'chatId': chatId,
    'beforeMessageId': beforeMessageId,
    'accountId': accountId,
  });

  @override
  Future<void> hydrateMessages(List<int> messageIds, {int? accountId}) =>
      _invoke<void>('hydrateMessages', {
        'messageIds': messageIds,
        'accountId': accountId,
      });

  @override
  Future<bool> setChatVisibility({
    required int chatId,
    required int visibility,
    int? accountId,
  }) => _invoke<bool>('setChatVisibility', {
    'chatId': chatId,
    'visibility': visibility,
    'accountId': accountId,
  });

  @override
  Future<bool> downloadFullMessage(int messageId, {int? accountId}) =>
      _invoke<bool>('downloadFullMessage', {
        'messageId': messageId,
        'accountId': accountId,
      });

  @override
  Future<bool> resendMessages(List<int> messageIds, {int? accountId}) =>
      _invoke<bool>('resendMessages', {
        'messageIds': messageIds,
        'accountId': accountId,
      });

  @override
  Future<int> sendTextWithQuote({
    required int chatId,
    required String body,
    required int quotedMessageId,
    String? quotedStanzaId,
    String? subject,
    String? htmlBody,
    int? accountId,
    bool forcePlaintext = false,
    bool skipAutocrypt = false,
  }) => _invoke<int>('sendTextWithQuote', {
    'chatId': chatId,
    'body': body,
    'quotedMessageId': quotedMessageId,
    'quotedStanzaId': quotedStanzaId,
    'subject': subject,
    'htmlBody': htmlBody,
    'accountId': accountId,
    'forcePlaintext': forcePlaintext,
    'skipAutocrypt': skipAutocrypt,
  });

  @override
  Future<DeltaQuotedMessage?> getQuotedMessage(
    int messageId, {
    int? accountId,
  }) => _invoke<DeltaQuotedMessage?>('getQuotedMessage', {
    'messageId': messageId,
    'accountId': accountId,
  });

  @override
  Future<bool> setDraft({
    required int chatId,
    DeltaMessage? message,
    int? accountId,
  }) => _invoke<bool>('setDraft', {
    'chatId': chatId,
    'message': message,
    'accountId': accountId,
  });

  @override
  Future<DeltaMessage?> getDraft(int chatId, {int? accountId}) =>
      _invoke<DeltaMessage?>('getDraft', {
        'chatId': chatId,
        'accountId': accountId,
      });

  @override
  Future<DeltaMessage?> getMessage(int messageId, {int? accountId}) =>
      _invoke<DeltaMessage?>('getMessage', {
        'messageId': messageId,
        'accountId': accountId,
      });

  @override
  Future<String?> getMessageMimeHeaders(int messageId, {int? accountId}) =>
      _invoke<String?>('getMessageMimeHeaders', {
        'messageId': messageId,
        'accountId': accountId,
      });

  @override
  Future<String?> getMessageRfc724Mid(int messageId, {int? accountId}) =>
      _invoke<String?>('getMessageRfc724Mid', {
        'messageId': messageId,
        'accountId': accountId,
      });

  @override
  Future<String?> getMessageInfo(int messageId, {int? accountId}) =>
      _invoke<String?>('getMessageInfo', {
        'messageId': messageId,
        'accountId': accountId,
      });

  @override
  Future<String?> getMessageDebugInfo(int messageId, {int? accountId}) =>
      _invoke<String?>('getMessageDebugInfo', {
        'messageId': messageId,
        'accountId': accountId,
      });

  @override
  Future<String?> getMessageFullHtml(int messageId, {int? accountId}) =>
      _invoke<String?>('getMessageFullHtml', {
        'messageId': messageId,
        'accountId': accountId,
      });

  @override
  Future<DeltaMessageRfc822Body?> getMessageRfc822Body(
    int messageId, {
    int? accountId,
  }) => _invoke<DeltaMessageRfc822Body?>('getMessageRfc822Body', {
    'messageId': messageId,
    'accountId': accountId,
  });

  @override
  Future<List<int>> getContactIds({
    int flags = 0,
    String? query,
    int? accountId,
  }) => _invoke<List<int>>('getContactIds', {
    'flags': flags,
    'query': query,
    'accountId': accountId,
  });

  @override
  Future<List<int>> getBlockedContactIds({int? accountId}) =>
      _invoke<List<int>>('getBlockedContactIds', {'accountId': accountId});

  @override
  Future<bool> deleteContact(int contactId, {int? accountId}) => _invoke<bool>(
    'deleteContact',
    {'contactId': contactId, 'accountId': accountId},
  );

  @override
  Future<DeltaContact?> getContact(int contactId, {int? accountId}) =>
      _invoke<DeltaContact?>('getContact', {
        'contactId': contactId,
        'accountId': accountId,
      });

  @override
  Future<void> deleteStorageArtifacts({String? databasePrefix}) =>
      _invoke<void>('deleteStorageArtifacts', {
        'databasePrefix': databasePrefix,
      });
}

@pragma('vm:entry-point')
void _emailDeltaWorkerMain(Map<String, Object?> config) {
  _EmailDeltaWorkerServer(config).start();
}

final class _EmailDeltaWorkerServer {
  _EmailDeltaWorkerServer(Map<String, Object?> config)
    : _mainPort = config['mainPort'] as SendPort,
      _deltaDatabasePath = config['deltaDatabasePath'] as String,
      _databasePrefix = config['databasePrefix'] as String,
      _emailEncryptionBetaEnabledByAddress = _boolMapValue(
        config['emailEncryptionBetaEnabledByAddress'],
      ),
      _xmppSelfJid = config['xmppSelfJid'] as String?,
      _receivePort = ReceivePort('email-delta-worker'),
      _l10n = lookupAppLocalizations(const ui.Locale('en')) {
    _transport = EmailDeltaTransport(
      databaseBuilder: _databaseBuilder,
      deltaDatabaseFileBuilder: _deltaDatabaseFileForPrefix,
      localizationsProvider: () => _l10n,
      xmppSelfJidProvider: () => _xmppSelfJid,
      persistEvents: false,
    );
    _transport.updateEmailEncryptionBetaSettings(
      _emailEncryptionBetaEnabledByAddress,
    );
    _transport.addEventListener((event) {
      _mainPort.send(_emailDeltaEventMessage(event));
    });
  }

  final SendPort _mainPort;
  final String _deltaDatabasePath;
  final String _databasePrefix;
  final Map<String, bool> _emailEncryptionBetaEnabledByAddress;
  final ReceivePort _receivePort;
  final AppLocalizations _l10n;
  late final EmailDeltaTransport _transport;
  final String? _xmppSelfJid;
  Future<void> _queue = Future<void>.value();

  void start() {
    _receivePort.listen((message) {
      final rpc = _rpcMap(message);
      if (rpc == null) {
        return;
      }
      final id = _rpcId(rpc);
      final method = _rpcMethod(rpc);
      if (id == null || method == null) {
        return;
      }
      _queue = _queue.then((_) => _handleRequest(rpc)).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        _mainPort.send(_emailDeltaRpcError(id: id, error: error));
      });
    });
    _mainPort.send(_emailDeltaReadyMessage(_receivePort.sendPort));
  }

  Future<XmppDatabase> _databaseBuilder() async {
    throw StateError('Delta worker cannot access the Axichat database.');
  }

  Future<File> _deltaDatabaseFileForPrefix(String prefix) async {
    if (prefix == _databasePrefix) {
      return File(_deltaDatabasePath);
    }
    final normalized = normalizeAppOwnedPathSegment('${prefix}_email');
    return File(
      p.join(p.dirname(_deltaDatabasePath), '$normalized.axichat.drift'),
    );
  }

  Future<void> dispose() async {
    _receivePort.close();
    await _transport.dispose();
  }

  Future<void> _handleRequest(Map<Object?, Object?> request) async {
    final id = _rpcId(request);
    final method = _rpcMethod(request);
    final op = method == null ? null : _opFromRpcMethod(method);
    if (id == null || op == null) {
      return;
    }
    try {
      final result = await _dispatch(op, _rpcParams(request));
      _mainPort.send(_emailDeltaRpcResponse(id: id, result: result));
    } on StateError catch (error) {
      _mainPort.send(_emailDeltaRpcError(id: id, error: error));
    } on Exception catch (error) {
      _mainPort.send(_emailDeltaRpcError(id: id, error: error));
    }
  }

  Future<Object?> _dispatch(String op, Map<String, Object?> payload) async {
    switch (op) {
      case 'runtimeState':
        return _runtimeState();
      case 'updateEmailEncryptionBetaSettings':
        _transport.updateEmailEncryptionBetaSettings(
          (payload['enabledByAddress'] as Map).cast<String, bool>(),
        );
        return null;
      case 'hydrateAccountAddress':
        _transport.hydrateAccountAddress(
          address: payload['address'] as String,
          accountId: payload['accountId'] as int?,
        );
        return null;
      case 'setPrimaryAccountId':
        _transport.setPrimaryAccountId(payload['accountId'] as int?);
        return null;
      case 'ensureInitialized':
        await _transport.ensureInitialized(
          databasePrefix: payload['databasePrefix'] as String,
          databasePassphrase: payload['databasePassphrase'] as String,
        );
        return null;
      case 'isConfigured':
        return _transport.isConfigured(accountId: payload['accountId'] as int?);
      case 'deconfigureAccount':
        await _transport.deconfigureAccount(
          accountId: payload['accountId'] as int?,
        );
        return null;
      case 'configureAccount':
        await _transport.configureAccount(
          address: payload['address'] as String,
          password: payload['password'] as String,
          displayName: payload['displayName'] as String,
          additional: (payload['additional'] as Map).cast<String, String>(),
          accountId: payload['accountId'] as int?,
        );
        return null;
      case 'start':
        await _transport.start();
        return null;
      case 'stop':
        await _transport.stop();
        return null;
      case 'stopEventDeliveryForLogout':
        await _transport.stopEventDeliveryForLogout();
        return null;
      case 'dispose':
        await dispose();
        return null;
      case 'bootstrapFromCore':
        return _transport.bootstrapFromCore(
          accountId: payload['accountId'] as int?,
        );
      case 'refreshChatlistSnapshot':
        await _transport.refreshChatlistSnapshot(
          accountId: payload['accountId'] as int?,
        );
        return null;
      case 'notifyNetworkAvailable':
        await _transport.notifyNetworkAvailable();
        return null;
      case 'notifyNetworkLost':
        await _transport.notifyNetworkLost();
        return null;
      case 'performBackgroundFetch':
        return _transport.performBackgroundFetch(
          payload['timeout'] as Duration,
        );
      case 'backfillChatHistory':
        await _transport.backfillChatHistory(
          chatId: payload['chatId'] as int,
          chatJid: payload['chatJid'] as String,
          desiredWindow: payload['desiredWindow'] as int,
          beforeMessageId: payload['beforeMessageId'] as int?,
          beforeTimestamp: payload['beforeTimestamp'] as DateTime?,
          filter: payload['filter'] as MessageTimelineFilter,
          accountId: payload['accountId'] as int?,
        );
        return null;
      case 'connectivity':
        return _transport.connectivity(accountId: payload['accountId'] as int?);
      case 'connectivityDetails':
        return _transport.connectivityDetails(
          accountId: payload['accountId'] as int?,
        );
      case 'chatSendCapabilities':
        return _transport.chatSendCapabilities(
          chatId: payload['chatId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'removeContactPublicKey':
        return _transport.removeContactPublicKey(
          address: payload['address'] as String,
          fingerprint: payload['fingerprint'] as String,
          contactId: payload['contactId'] as int,
          chatId: payload['chatId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'accountIds':
        final ids = await _transport.accountIds();
        return {'accountIds': ids, 'state': _runtimeState(accountIds: ids)};
      case 'createAccount':
        final accountId = await _transport.createAccount(
          closed: payload['closed'] as bool,
        );
        return {
          'accountId': accountId,
          'state': _runtimeState(accountIds: <int>[accountId]),
        };
      case 'ensureAccountSession':
        await _transport.ensureAccountSession(payload['accountId'] as int?);
        return _runtimeState(
          accountIds: _singleAccountId(payload['accountId'] as int?),
        );
      case 'removeAccount':
        final removed = await _transport.removeAccount(
          payload['accountId'] as int,
        );
        return {'value': removed, 'state': _runtimeState()};
      case 'getCoreConfig':
        return _transport.getCoreConfig(
          payload['key'] as String,
          accountId: payload['accountId'] as int?,
        );
      case 'getOauth2Url':
        return _transport.getOauth2Url(
          address: payload['address'] as String,
          redirectUri: payload['redirectUri'] as String,
          accountId: payload['accountId'] as int?,
        );
      case 'setCoreConfig':
        await _transport.setCoreConfig(
          key: payload['key'] as String,
          value: payload['value'] as String,
          accountId: payload['accountId'] as int?,
        );
        return null;
      case 'setCoreConfigIfSupported':
        return _transport.setCoreConfigIfSupported(
          key: payload['key'] as String,
          value: payload['value'] as String,
          accountId: payload['accountId'] as int?,
        );
      case 'inspectOpenPgpKey':
        return _transport.inspectOpenPgpKey(
          armored: payload['armored'] as String,
          expectedAddress: payload['expectedAddress'] as String,
          expectedKind: payload['expectedKind'] as DeltaOpenPgpKeyKind,
          accountId: payload['accountId'] as int?,
        );
      case 'importContactPublicKey':
        return _transport.importContactPublicKey(
          address: payload['address'] as String,
          displayName: payload['displayName'] as String,
          armoredPublicKey: payload['armoredPublicKey'] as String,
          accountId: payload['accountId'] as int?,
        );
      case 'runImex':
        return _transport.runImex(
          mode: payload['mode'] as int,
          path: payload['path'] as String,
          accountId: payload['accountId'] as int?,
          timeout: payload['timeout'] as Duration,
        );
      case 'cancelImex':
        await _transport.cancelImex(accountId: payload['accountId'] as int?);
        return null;
      case 'registerPushToken':
        await _transport.registerPushToken(payload['token'] as String);
        return null;
      case 'sendText':
        return _transport.sendText(
          chatId: payload['chatId'] as int,
          body: payload['body'] as String,
          subject: payload['subject'] as String?,
          shareId: payload['shareId'] as String?,
          localBodyOverride: payload['localBodyOverride'] as String?,
          htmlBody: payload['htmlBody'] as String?,
          quotingStanzaId: payload['quotingStanzaId'] as String?,
          accountId: payload['accountId'] as int?,
          forcePlaintext: payload['forcePlaintext'] as bool,
          skipAutocrypt: payload['skipAutocrypt'] as bool,
        );
      case 'sendAttachment':
        return _transport.sendAttachment(
          chatId: payload['chatId'] as int,
          attachment: payload['attachment'] as EmailAttachment,
          subject: payload['subject'] as String?,
          shareId: payload['shareId'] as String?,
          captionOverride: payload['captionOverride'] as String?,
          htmlCaption: payload['htmlCaption'] as String?,
          quotingStanzaId: payload['quotingStanzaId'] as String?,
          accountId: payload['accountId'] as int?,
          forcePlaintext: payload['forcePlaintext'] as bool,
          skipAutocrypt: payload['skipAutocrypt'] as bool,
        );
      case 'ensureChatForAddress':
        return _transport.ensureChatForAddress(
          address: payload['address'] as String,
          displayName: payload['displayName'] as String?,
          accountId: payload['accountId'] as int?,
        );
      case 'createContact':
        return _transport.createContact(
          address: payload['address'] as String,
          displayName: payload['displayName'] as String?,
          accountId: payload['accountId'] as int?,
        );
      case 'blockContact':
        return _transport.blockContact(
          payload['address'] as String,
          accountId: payload['accountId'] as int?,
        );
      case 'unblockContact':
        return _transport.unblockContact(
          payload['address'] as String,
          accountId: payload['accountId'] as int?,
        );
      case 'markNoticedChat':
        return _transport.markNoticedChat(
          payload['chatId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'markSeenMessages':
        return _transport.markSeenMessages(
          (payload['messageIds'] as List).cast<int>(),
          accountId: payload['accountId'] as int?,
        );
      case 'getFreshMessageCount':
        return _transport.getFreshMessageCount(
          payload['chatId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'getFreshMessageCountSafe':
        return _transport.getFreshMessageCountSafe(
          payload['chatId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'getChatlist':
        return _transport.getChatlist(
          flags: payload['flags'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'getChat':
        return _transport.getChat(
          payload['chatId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'getFreshMessageIds':
        return _transport.getFreshMessageIds(
          accountId: payload['accountId'] as int?,
        );
      case 'deleteMessages':
        return _transport.deleteMessages(
          (payload['messageIds'] as List).cast<int>(),
          accountId: payload['accountId'] as int?,
        );
      case 'forwardMessages':
        return _transport.forwardMessages(
          messageIds: (payload['messageIds'] as List).cast<int>(),
          toChatId: payload['toChatId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'searchMessages':
        return _transport.searchMessages(
          chatId: payload['chatId'] as int,
          query: payload['query'] as String,
          accountId: payload['accountId'] as int?,
        );
      case 'getChatMessageIds':
        return _transport.getChatMessageIds(
          chatId: payload['chatId'] as int,
          beforeMessageId: payload['beforeMessageId'] as int?,
          accountId: payload['accountId'] as int?,
        );
      case 'hydrateMessages':
        await _transport.hydrateMessages(
          (payload['messageIds'] as List).cast<int>(),
          accountId: payload['accountId'] as int?,
        );
        return null;
      case 'setChatVisibility':
        return _transport.setChatVisibility(
          chatId: payload['chatId'] as int,
          visibility: payload['visibility'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'downloadFullMessage':
        return _transport.downloadFullMessage(
          payload['messageId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'resendMessages':
        return _transport.resendMessages(
          (payload['messageIds'] as List).cast<int>(),
          accountId: payload['accountId'] as int?,
        );
      case 'sendTextWithQuote':
        return _transport.sendTextWithQuote(
          chatId: payload['chatId'] as int,
          body: payload['body'] as String,
          quotedMessageId: payload['quotedMessageId'] as int,
          quotedStanzaId: payload['quotedStanzaId'] as String?,
          subject: payload['subject'] as String?,
          htmlBody: payload['htmlBody'] as String?,
          accountId: payload['accountId'] as int?,
          forcePlaintext: payload['forcePlaintext'] as bool,
          skipAutocrypt: payload['skipAutocrypt'] as bool,
        );
      case 'getQuotedMessage':
        return _transport.getQuotedMessage(
          payload['messageId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'setDraft':
        return _transport.setDraft(
          chatId: payload['chatId'] as int,
          message: payload['message'] as DeltaMessage?,
          accountId: payload['accountId'] as int?,
        );
      case 'getDraft':
        return _transport.getDraft(
          payload['chatId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'getMessage':
        return _transport.getMessage(
          payload['messageId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'getMessageMimeHeaders':
        return _transport.getMessageMimeHeaders(
          payload['messageId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'getMessageRfc724Mid':
        return _transport.getMessageRfc724Mid(
          payload['messageId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'getMessageInfo':
        return _transport.getMessageInfo(
          payload['messageId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'getMessageDebugInfo':
        return _transport.getMessageDebugInfo(
          payload['messageId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'getMessageFullHtml':
        return _transport.getMessageFullHtml(
          payload['messageId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'getMessageRfc822Body':
        return _transport.getMessageRfc822Body(
          payload['messageId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'getContactIds':
        return _transport.getContactIds(
          flags: payload['flags'] as int,
          query: payload['query'] as String?,
          accountId: payload['accountId'] as int?,
        );
      case 'getBlockedContactIds':
        return _transport.getBlockedContactIds(
          accountId: payload['accountId'] as int?,
        );
      case 'deleteContact':
        return _transport.deleteContact(
          payload['contactId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'getContact':
        return _transport.getContact(
          payload['contactId'] as int,
          accountId: payload['accountId'] as int?,
        );
      case 'deleteStorageArtifacts':
        await _transport.deleteStorageArtifacts(
          databasePrefix: payload['databasePrefix'] as String?,
        );
        return null;
      default:
        throw EmailDeltaWorkerRuntimeException('Unknown Delta worker op $op.');
    }
  }

  Iterable<int> _singleAccountId(int? accountId) sync* {
    if (accountId != null) {
      yield accountId;
    }
  }

  Map<String, Object?> _runtimeState({
    Iterable<int> accountIds = const <int>[],
  }) {
    final ids = <int>{...accountIds, _transport.activeAccountId};
    final selfJids = <int, String>{};
    for (final id in ids) {
      final jid = _transport.selfJidForAccount(id);
      if (jid != null && jid.isNotEmpty) {
        selfJids[id] = jid;
      }
    }
    return {
      'accountsSupported': _transport.accountsSupported,
      'accountsActive': _transport.accountsActive,
      'activeAccountId': _transport.activeAccountId,
      'isIoRunning': _transport.isIoRunning,
      'selfJids': selfJids.map(
        (accountId, jid) => MapEntry(accountId.toString(), jid),
      ),
    };
  }
}
