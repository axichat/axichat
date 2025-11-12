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

    return DeltaContextHandle._(_bindings, ctx);
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

class DeltaContextHandle {
  DeltaContextHandle._(this._bindings, this._context);

  final DeltaChatBindings _bindings;
  final ffi.Pointer<dc_context_t> _context;

  ffi.Pointer<dc_event_emitter_t>? _eventEmitter;
  ReceivePort? _eventPort;
  StreamSubscription<_DeltaRawEvent>? _eventSubscription;
  StreamController<DeltaCoreEvent>? _eventController;
  Isolate? _eventIsolate;

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
    if (_ioRunning) return;
    _bindings.dc_start_io(_context);
    _ioRunning = true;
    await _ensureEventLoop();
  }

  Future<void> stopIo() async {
    if (!_ioRunning) return;
    await _teardownEventLoop();
    _bindings.dc_stop_io(_context);
    _ioRunning = false;
  }

  Stream<DeltaCoreEvent> events() {
    _eventController ??= StreamController<DeltaCoreEvent>.broadcast(
      onListen: () {
        if (_ioRunning) {
          _ensureEventLoop();
        }
      },
    );
    return _eventController!.stream;
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
      final address = _takeString(
        _bindings.dc_chat_get_mailinglist_addr(chatPtr),
        bindings: _bindings,
      );
      return DeltaChat(id: chatId, name: name, contactAddress: address);
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
      );
    } finally {
      _bindings.dc_msg_unref(msgPtr);
    }
  }

  Future<void> close() async {
    await stopIo();
    await _eventController?.close();
    _eventController = null;
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

  Future<void> _ensureEventLoop() async {
    if (_eventIsolate != null) {
      return;
    }
    _eventEmitter ??= _bindings.dc_get_event_emitter(_context);
    if (_eventEmitter == null || _eventEmitter == ffi.nullptr) {
      throw const DeltaSafeException('Failed to obtain Delta event emitter');
    }

    _eventPort = ReceivePort('delta-events');
    _eventSubscription = _eventPort!.cast<_DeltaRawEvent>().listen((event) {
      _eventController?.add(
        DeltaCoreEvent(
          type: event.type,
          data1: event.data1,
          data2: event.data2,
          data1Text: event.data1Text,
          data2Text: event.data2Text,
        ),
      );
    });

    _eventIsolate = await Isolate.spawn<_EventLoopConfig>(
      _eventLoop,
      _EventLoopConfig(
        emitterAddress: _eventEmitter!.address,
        sendPort: _eventPort!.sendPort,
      ),
      debugName: 'delta-event-loop',
    );
  }

  Future<void> _teardownEventLoop() async {
    _eventIsolate?.kill(priority: Isolate.immediate);
    _eventIsolate = null;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _eventPort?.close();
    _eventPort = null;
    if (_eventEmitter != null && _eventEmitter != ffi.nullptr) {
      _bindings.dc_event_emitter_unref(_eventEmitter!);
      _eventEmitter = null;
    }
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

class DeltaCoreEvent {
  const DeltaCoreEvent({
    required this.type,
    required this.data1,
    required this.data2,
    this.data1Text,
    this.data2Text,
  });

  final int type;
  final int data1;
  final int data2;
  final String? data1Text;
  final String? data2Text;
}

class DeltaChat {
  const DeltaChat({required this.id, this.name, this.contactAddress});

  final int id;
  final String? name;
  final String? contactAddress;
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

  bool get hasFile => filePath != null && filePath!.isNotEmpty;
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
  });

  final int type;
  final int data1;
  final int data2;
  final String? data1Text;
  final String? data2Text;
}

class _EventLoopConfig {
  const _EventLoopConfig({
    required this.emitterAddress,
    required this.sendPort,
  });

  final int emitterAddress;
  final SendPort sendPort;
}

void _eventLoop(_EventLoopConfig config) {
  final bindings = DeltaChatBindings(loadDeltaLibrary());
  final emitter =
      ffi.Pointer<dc_event_emitter_t>.fromAddress(config.emitterAddress);
  while (true) {
    final eventPtr = bindings.dc_get_next_event(emitter);
    if (eventPtr == ffi.nullptr) {
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
    config.sendPort.send(
      _DeltaRawEvent(
        type: type,
        data1: data1,
        data2: data2,
        data1Text: data1Str,
        data2Text: data2Str,
      ),
    );
    bindings.dc_event_unref(eventPtr);
  }
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
