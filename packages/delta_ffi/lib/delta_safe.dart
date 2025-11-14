import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'delta.dart';
import 'src/bindings.dart';

class DeltaSafe {
  DeltaSafe({DeltaChatBindings? bindings})
      : _bindings = bindings ?? deltaBindings;

  final DeltaChatBindings _bindings;

  Future<DeltaContextHandle> createContext({
    required String databasePath,
    String osName = 'dart',
    String? blobDirectoryPath,
  }) async {
    final ctx = _withCString(databasePath, (dbPtr) {
      if (blobDirectoryPath != null) {
        // Recent deltachat-ffi versions manage blob storage internally and no
        // longer accept a custom directory. Provide a null pointer so the C
        // API can choose its own location. Retaining the parameter keeps
        // compatibility with older call sites.
      }
      try {
        return _bindings.dc_context_new_closed(dbPtr);
      } on Object catch (error) {
        if (error is! ArgumentError && error is! UnsupportedError) {
          rethrow;
        }
        return _withCString(osName, (osPtr) {
          return _bindings.dc_context_new(osPtr, dbPtr, ffi.nullptr);
        });
      }
    });

    if (ctx == ffi.nullptr) {
      throw const DeltaSafeException('Failed to allocate Delta Chat context');
    }

    return DeltaContextHandle._owned(_bindings, ctx);
  }

  Future<DeltaAccountsHandle> createAccounts({
    required String directory,
    bool writable = true,
  }) async {
    final accounts = _withCString(directory, (dirPtr) {
      return _bindings.dc_accounts_new(dirPtr, writable ? 1 : 0);
    });
    if (accounts == ffi.nullptr) {
      throw const DeltaSafeException('Failed to allocate Delta accounts');
    }
    return DeltaAccountsHandle._(_bindings, accounts);
  }
}

class DeltaMessageType {
  static const int text = 10;
  static const int image = 20;
  static const int gif = 21;
  static const int audio = 40;
  static const int voice = 41;
  static const int video = 50;
  static const int file = 60;
}

class DeltaChatType {
  static const int single = 100;
  static const int group = 200;
  static const int verifiedGroup = 300;
  static const int broadcast = 400;
}

class DeltaContextHandle {
  DeltaContextHandle._owned(this._bindings, this._context)
      : _accountsOwner = null,
        _accountId = null,
        _ownsContext = true;

  DeltaContextHandle._borrowed(
    this._bindings,
    this._context,
    this._accountsOwner,
    this._accountId,
  ) : _ownsContext = false;

  final DeltaChatBindings _bindings;
  final ffi.Pointer<dc_context_t> _context;
  final DeltaAccountsHandle? _accountsOwner;
  final int? _accountId;
  final bool _ownsContext;

  _DeltaEventLoop? _eventLoop;

  bool _opened = false;
  bool _ioRunning = false;

  Future<void> open({required String passphrase}) async {
    final result = _withCString(passphrase, (passPtr) {
      return _bindings.dc_context_open(_context, passPtr);
    });
    if (result == 0) {
      final isOpen = _maybeIsOpen();
      if (isOpen != true) {
        throw const DeltaSafeException('Failed to open context');
      }
    }
    _opened = true;
  }

  Future<void> configureAccount({
    required String address,
    required String password,
    required String displayName,
    Map<String, String> additional = const {},
  }) async {
    _ensureState(_opened, 'configure account');

    await _setConfig('addr', address);
    await _setConfig('mail_pw', password);
    await _setConfig('displayname', displayName);

    for (final entry in additional.entries) {
      await _setConfig(entry.key, entry.value);
    }

    _bindings.dc_configure(_context);
  }

  Future<void> startIo() async {
    _ensureState(_opened, 'start IO');
    final owner = _accountsOwner;
    if (owner != null) {
      await owner.startIo();
      return;
    }
    if (_ioRunning) return;
    _bindings.dc_start_io(_context);
    _ioRunning = true;
  }

  Future<void> stopIo() async {
    final owner = _accountsOwner;
    if (owner != null) {
      await owner.stopIo();
      return;
    }
    if (!_ioRunning) return;
    _bindings.dc_stop_io(_context);
    _ioRunning = false;
  }

  Stream<DeltaCoreEvent> events() {
    final owner = _accountsOwner;
    final accountId = _accountId;
    if (owner != null && accountId != null) {
      return owner.eventsFor(accountId);
    }
    _eventLoop ??= _DeltaEventLoop(
      emitterFactory: () => _bindings.dc_get_event_emitter(_context),
      debugLabel: 'context-${_context.address}',
    );
    return _eventLoop!.stream;
  }

  Future<int> createContact({
    required String address,
    required String displayName,
  }) async {
    final contactId = _withCString(displayName, (namePtr) {
      return _withCString(address, (addrPtr) {
        return _bindings.dc_create_contact(_context, namePtr, addrPtr);
      });
    });
    _ensurePositive(contactId, 'create contact');
    return contactId;
  }

  Future<int> createChatByContactId(int contactId) async {
    final chatId = _bindings.dc_create_chat_by_contact_id(
      _context,
      contactId,
    );
    _ensurePositive(chatId, 'create chat from contact');
    return chatId;
  }

  Future<int> sendText({
    required int chatId,
    required String message,
  }) async {
    final msgId = _withCString(message, (msgPtr) {
      return _bindings.dc_send_text_msg(_context, chatId, msgPtr);
    });
    _ensurePositive(msgId, 'send text message');
    return msgId;
  }

  Future<int> sendFileMessage({
    required int chatId,
    required int viewType,
    required String filePath,
    String? fileName,
    String? mimeType,
    String? text,
  }) async {
    _ensureState(_opened, 'send attachment');
    final message = _bindings.dc_msg_new(_context, viewType);
    if (message == ffi.nullptr) {
      throw const DeltaSafeException('Failed to allocate Delta message');
    }
    try {
      if (text != null && text.isNotEmpty) {
        _withCString(text, (textPtr) {
          _bindings.dc_msg_set_text(message, textPtr);
        });
      }
      _setFileForMessage(
        message,
        filePath: filePath,
        fileName: fileName,
        mimeType: mimeType,
      );
      final msgId = _bindings.dc_send_msg(_context, chatId, message);
      _ensurePositive(msgId, 'send file message');
      return msgId;
    } finally {
      _bindings.dc_msg_unref(message);
    }
  }

  Future<DeltaChat?> getChat(int chatId) async {
    final chatPtr = _bindings.dc_get_chat(_context, chatId);
    if (chatPtr == ffi.nullptr) {
      return null;
    }
    try {
      final name =
          _takeString(_bindings.dc_chat_get_name(chatPtr), bindings: _bindings);
      final mailingListAddress = _takeString(
        _bindings.dc_chat_get_mailinglist_addr(chatPtr),
        bindings: _bindings,
      );
      final type = _bindings.dc_chat_get_type(chatPtr);
      final contactId = _bindings.dc_chat_get_contact_id(chatPtr);
      String? contactAddress;
      String? contactName;
      if (contactId > 0) {
        final contactPtr = _bindings.dc_get_contact(_context, contactId);
        if (contactPtr != ffi.nullptr) {
          try {
            contactAddress = _cleanString(
              _takeString(
                _bindings.dc_contact_get_addr(contactPtr),
                bindings: _bindings,
              ),
            );
            contactName = _cleanString(
              _takeString(
                _bindings.dc_contact_get_name(contactPtr),
                bindings: _bindings,
              ),
            );
          } finally {
            _bindings.dc_contact_unref(contactPtr);
          }
        }
      }
      return DeltaChat(
        id: chatId,
        name: name ?? contactName,
        contactAddress: contactAddress ?? mailingListAddress,
        contactId: contactId == 0 ? null : contactId,
        contactName: contactName,
        type: type == 0 ? null : type,
      );
    } finally {
      _bindings.dc_chat_unref(chatPtr);
    }
  }

  Future<DeltaMessage?> getMessage(int messageId) async {
    final msgPtr = _bindings.dc_get_msg(_context, messageId);
    if (msgPtr == ffi.nullptr) {
      return null;
    }
    try {
      final viewType = _bindings.dc_msg_get_viewtype(msgPtr);
      final text =
          _takeString(_bindings.dc_msg_get_text(msgPtr), bindings: _bindings);
      final chatId = _bindings.dc_msg_get_chat_id(msgPtr);
      final id = _bindings.dc_msg_get_id(msgPtr);
      final filePath = _cleanString(
        _takeString(_bindings.dc_msg_get_file(msgPtr), bindings: _bindings),
      );
      final fileName = _cleanString(
        _takeString(_bindings.dc_msg_get_filename(msgPtr), bindings: _bindings),
      );
      final fileMime = _cleanString(
        _takeString(_bindings.dc_msg_get_filemime(msgPtr), bindings: _bindings),
      );
      final fileBytes = _bindings.dc_msg_get_filebytes(msgPtr);
      final width = _bindings.dc_msg_get_width(msgPtr);
      final height = _bindings.dc_msg_get_height(msgPtr);
      final timestampSeconds = _bindings.dc_msg_get_timestamp(msgPtr);
      final timestamp = timestampSeconds == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              timestampSeconds * 1000,
              isUtc: true,
            ).toLocal();
      final isOutgoing = _bindings.dc_msg_is_outgoing(msgPtr) != 0;
      return DeltaMessage(
        id: id,
        chatId: chatId,
        text: text,
        viewType: viewType,
        filePath: filePath,
        fileName: fileName,
        fileMime: fileMime,
        fileSize: fileBytes == 0 ? null : fileBytes,
        width: width == 0 ? null : width,
        height: height == 0 ? null : height,
        timestamp: timestamp,
        isOutgoing: isOutgoing,
      );
    } finally {
      _bindings.dc_msg_unref(msgPtr);
    }
  }

  Future<void> close() async {
    if (_accountsOwner != null || !_ownsContext) {
      return;
    }
    await stopIo();
    await _eventLoop?.dispose();
    _eventLoop = null;
    _bindings.dc_context_unref(_context);
  }

  Future<void> _setConfig(String key, String value) async {
    final result = _withCString(key, (keyPtr) {
      return _withCString(value, (valuePtr) {
        return _bindings.dc_set_config(_context, keyPtr, valuePtr);
      });
    });
    _ensureSuccess(result, 'set config $key');
  }

  bool? _maybeIsOpen() {
    try {
      return _bindings.dc_context_is_open(_context) != 0;
    } on Object {
      return null;
    }
  }

  void _setFileForMessage(
    ffi.Pointer<dc_msg_t> message, {
    required String filePath,
    String? fileName,
    String? mimeType,
  }) {
    final namePointer = fileName == null || fileName.isEmpty
        ? ffi.nullptr
        : _toCString(fileName);
    final mimePointer = mimeType == null || mimeType.isEmpty
        ? ffi.nullptr
        : _toCString(mimeType);
    try {
      _withCString(filePath, (filePtr) {
        _bindings.dc_msg_set_file_and_deduplicate(
          message,
          filePtr,
          namePointer,
          mimePointer,
        );
      });
    } finally {
      if (namePointer != ffi.nullptr) {
        malloc.free(namePointer);
      }
      if (mimePointer != ffi.nullptr) {
        malloc.free(mimePointer);
      }
    }
  }
}

class DeltaAccountsHandle {
  DeltaAccountsHandle._(this._bindings, this._accounts);

  final DeltaChatBindings _bindings;
  final ffi.Pointer<dc_accounts_t> _accounts;

  _DeltaEventLoop? _eventLoop;
  bool _ioRunning = false;
  bool _disposed = false;

  Future<int> ensureAccount({String? legacyDatabasePath}) async {
    final existing = _existingAccountId();
    if (existing != null && existing != 0) {
      return existing;
    }
    if (legacyDatabasePath != null) {
      final migrated = _withCString(legacyDatabasePath, (dbPtr) {
        return _bindings.dc_accounts_migrate_account(_accounts, dbPtr);
      });
      if (migrated != 0) {
        return migrated;
      }
    }
    final accountId = _bindings.dc_accounts_add_account(_accounts);
    if (accountId == 0) {
      throw const DeltaSafeException('Failed to allocate Delta account');
    }
    return accountId;
  }

  DeltaContextHandle contextFor(int accountId) {
    final ctx = _bindings.dc_accounts_get_account(_accounts, accountId);
    if (ctx == ffi.nullptr) {
      throw DeltaSafeException('Account $accountId is unavailable');
    }
    return DeltaContextHandle._borrowed(
      _bindings,
      ctx,
      this,
      accountId,
    );
  }

  Stream<DeltaCoreEvent> eventsFor(int accountId) {
    final stream = _ensureEventStream();
    return stream.where(
      (event) => event.accountId == null || event.accountId == accountId,
    );
  }

  Future<void> startIo() async {
    if (_ioRunning) return;
    _bindings.dc_accounts_start_io(_accounts);
    _ioRunning = true;
  }

  Future<void> stopIo() async {
    if (!_ioRunning) return;
    _bindings.dc_accounts_stop_io(_accounts);
    _ioRunning = false;
  }

  Future<void> maybeNetworkAvailable() async {
    _bindings.dc_accounts_maybe_network(_accounts);
  }

  Future<void> maybeNetworkLost() async {
    _bindings.dc_accounts_maybe_network_lost(_accounts);
  }

  Future<bool> backgroundFetch(Duration timeout) async {
    final seconds = timeout.inSeconds <= 0 ? 1 : timeout.inSeconds;
    final result = _bindings.dc_accounts_background_fetch(
      _accounts,
      seconds,
    );
    return result != 0;
  }

  Future<void> setPushDeviceToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;
    _withCString(trimmed, (tokenPtr) {
      _bindings.dc_accounts_set_push_device_token(
        _accounts,
        tokenPtr,
      );
    });
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await stopIo();
    await _eventLoop?.dispose();
    _eventLoop = null;
    _bindings.dc_accounts_unref(_accounts);
    _disposed = true;
  }

  Stream<DeltaCoreEvent> _ensureEventStream() {
    _eventLoop ??= _DeltaEventLoop(
      emitterFactory: () => _bindings.dc_accounts_get_event_emitter(_accounts),
      debugLabel: 'accounts',
    );
    return _eventLoop!.stream;
  }

  int? _existingAccountId() {
    final array = _bindings.dc_accounts_get_all(_accounts);
    if (array == ffi.nullptr) {
      return null;
    }
    try {
      final count = _bindings.dc_array_get_cnt(array);
      if (count <= 0) {
        return null;
      }
      return _bindings.dc_array_get_id(array, 0);
    } finally {
      _bindings.dc_array_unref(array);
    }
  }
}

class DeltaCoreEvent {
  const DeltaCoreEvent({
    required this.type,
    required this.data1,
    required this.data2,
    this.data1Text,
    this.data2Text,
    this.accountId,
  });

  final int type;
  final int data1;
  final int data2;
  final String? data1Text;
  final String? data2Text;
  final int? accountId;
}

class DeltaChat {
  const DeltaChat({
    required this.id,
    this.name,
    this.contactAddress,
    this.contactId,
    this.contactName,
    this.type,
  });

  final int id;
  final String? name;
  final String? contactAddress;
  final int? contactId;
  final String? contactName;
  final int? type;
}

class DeltaMessage {
  const DeltaMessage({
    required this.id,
    required this.chatId,
    this.text,
    this.viewType,
    this.filePath,
    this.fileName,
    this.fileMime,
    this.fileSize,
    this.width,
    this.height,
    this.timestamp,
    this.isOutgoing = false,
  });

  final int id;
  final int chatId;
  final String? text;
  final int? viewType;
  final String? filePath;
  final String? fileName;
  final String? fileMime;
  final int? fileSize;
  final int? width;
  final int? height;
  final DateTime? timestamp;
  final bool isOutgoing;

  bool get hasFile => filePath != null && filePath!.isNotEmpty;
}

class _DeltaEventLoop {
  _DeltaEventLoop({
    required ffi.Pointer<dc_event_emitter_t> Function() emitterFactory,
    required String debugLabel,
  })  : _emitterFactory = emitterFactory,
        _debugLabel = debugLabel;
  final ffi.Pointer<dc_event_emitter_t> Function() _emitterFactory;
  final String _debugLabel;
  late final StreamController<DeltaCoreEvent> _controller =
      StreamController<DeltaCoreEvent>.broadcast(
    onListen: _handleListen,
  );

  ReceivePort? _eventPort;
  ReceivePort? _controlPort;
  StreamSubscription<dynamic>? _eventSubscription;
  StreamSubscription<dynamic>? _controlSubscription;
  SendPort? _loopControlPort;
  Isolate? _isolate;
  ffi.Pointer<dc_event_emitter_t>? _emitter;
  bool _started = false;
  bool _stopRequested = false;
  bool _disposed = false;
  Completer<void>? _stoppedCompleter;

  Stream<DeltaCoreEvent> get stream => _controller.stream;

  void _handleListen() {
    if (_started || _disposed) {
      return;
    }
    _started = true;
    unawaited(_startLoop());
  }

  Future<void> _startLoop() async {
    _emitter ??= _emitterFactory();
    if (_emitter == null || _emitter == ffi.nullptr) {
      _controller.addError(
        const DeltaSafeException('Failed to obtain Delta event emitter'),
      );
      await _controller.close();
      return;
    }

    _eventPort = ReceivePort('delta-events($_debugLabel)');
    _controlPort = ReceivePort('delta-events-control($_debugLabel)');

    _eventSubscription = _eventPort!.listen((message) {
      if (message is _DeltaRawEvent) {
        _controller.add(
          DeltaCoreEvent(
            type: message.type,
            data1: message.data1,
            data2: message.data2,
            data1Text: message.data1Text,
            data2Text: message.data2Text,
            accountId: message.accountId == 0 ? null : message.accountId,
          ),
        );
      }
    });

    _controlSubscription = _controlPort!.listen((message) {
      if (message is SendPort) {
        _loopControlPort = message;
      } else if (message is _EventLoopStatus &&
          message.code == _EventLoopStatusCode.stopped) {
        _stoppedCompleter?.complete();
      }
    });

    _isolate = await Isolate.spawn<_EventLoopConfig>(
      _eventLoop,
      _EventLoopConfig(
        emitterAddress: _emitter!.address,
        eventPort: _eventPort!.sendPort,
        controlPort: _controlPort!.sendPort,
        label: _debugLabel,
      ),
      debugName: 'delta-event-loop($_debugLabel)',
    );
  }

  void _requestStop() {
    if (_stopRequested || _loopControlPort == null) {
      return;
    }
    _stopRequested = true;
    _stoppedCompleter ??= Completer<void>();
    _loopControlPort!.send(const _EventLoopCommandStop());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_started) {
      _requestStop();
      if (_stoppedCompleter != null) {
        await _stoppedCompleter!.future
            .timeout(const Duration(seconds: 5), onTimeout: () {});
      }
    }
    await _eventSubscription?.cancel();
    await _controlSubscription?.cancel();
    _eventPort?.close();
    _controlPort?.close();
    await _controller.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _loopControlPort = null;
    _emitter = null;
  }
}

class DeltaSafeException implements Exception {
  const DeltaSafeException(this.message);

  final String message;

  @override
  String toString() => 'DeltaSafeException: $message';
}

class _DeltaRawEvent {
  const _DeltaRawEvent({
    required this.type,
    required this.data1,
    required this.data2,
    this.data1Text,
    this.data2Text,
    required this.accountId,
  });

  final int type;
  final int data1;
  final int data2;
  final String? data1Text;
  final String? data2Text;
  final int accountId;
}

class _EventLoopCommandStop {
  const _EventLoopCommandStop();
}

enum _EventLoopStatusCode { stopped }

class _EventLoopStatus {
  const _EventLoopStatus(this.code);

  final _EventLoopStatusCode code;
}

class _EventLoopConfig {
  const _EventLoopConfig({
    required this.emitterAddress,
    required this.eventPort,
    required this.controlPort,
    required this.label,
  });

  final int emitterAddress;
  final SendPort eventPort;
  final SendPort controlPort;
  final String label;
}

void _eventLoop(_EventLoopConfig config) {
  final bindings = DeltaChatBindings(loadDeltaLibrary());
  final emitter =
      ffi.Pointer<dc_event_emitter_t>.fromAddress(config.emitterAddress);
  final controlReceive =
      ReceivePort('delta-event-loop-control(${config.label})');
  config.controlPort.send(controlReceive.sendPort);
  var shouldStop = false;
  final controlSubscription = controlReceive.listen((message) {
    if (message is _EventLoopCommandStop) {
      shouldStop = true;
    }
  });
  while (true) {
    final eventPtr = bindings.dc_get_next_event(emitter);
    if (eventPtr == ffi.nullptr) {
      if (shouldStop) {
        config.controlPort.send(
          const _EventLoopStatus(_EventLoopStatusCode.stopped),
        );
        break;
      }
      continue;
    }
    final type = bindings.dc_event_get_id(eventPtr);
    final data1 = bindings.dc_event_get_data1_int(eventPtr);
    final data2 = bindings.dc_event_get_data2_int(eventPtr);
    final data1Str = _takeString(
      bindings.dc_event_get_data1_str(eventPtr),
      bindings: bindings,
    );
    final data2Str = _takeString(
      bindings.dc_event_get_data2_str(eventPtr),
      bindings: bindings,
    );
    final accountId = bindings.dc_event_get_account_id(eventPtr);
    config.eventPort.send(
      _DeltaRawEvent(
        type: type,
        data1: data1,
        data2: data2,
        data1Text: data1Str,
        data2Text: data2Str,
        accountId: accountId,
      ),
    );
    bindings.dc_event_unref(eventPtr);
  }
  controlSubscription.cancel();
  controlReceive.close();
  bindings.dc_event_emitter_unref(emitter);
}

ffi.Pointer<ffi.Char> _toCString(String value) =>
    value.toNativeUtf8().cast<ffi.Char>();

T _withCString<T>(String value, T Function(ffi.Pointer<ffi.Char>) fn) {
  final pointer = value.toNativeUtf8().cast<ffi.Char>();
  try {
    return fn(pointer);
  } finally {
    malloc.free(pointer);
  }
}

String? _takeString(
  ffi.Pointer<ffi.Char> ptr, {
  DeltaChatBindings? bindings,
}) {
  if (ptr == ffi.nullptr) {
    return null;
  }
  final result = ptr.cast<Utf8>().toDartString();
  (bindings ?? deltaBindings).dc_str_unref(ptr);
  return result;
}

String? _cleanString(String? value) =>
    value == null || value.isEmpty ? null : value;

void _ensureSuccess(int code, String operation) {
  if (code == 0) {
    throw DeltaSafeException('Failed to $operation');
  }
}

void _ensurePositive(int value, String operation) {
  if (value <= 0) {
    throw DeltaSafeException('Failed to $operation (code: $value)');
  }
}

void _ensureState(bool predicate, String operation) {
  if (!predicate) {
    throw DeltaSafeException('Cannot $operation before opening the context');
  }
}
