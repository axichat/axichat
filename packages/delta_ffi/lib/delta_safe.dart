import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'delta.dart';
import 'src/bindings.dart';

const int _zeroValue = 0;

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

typedef _DcGetConfigNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<dc_context_t>,
  ffi.Pointer<ffi.Char>,
);

typedef _DcGetConfigDart = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<dc_context_t>,
  ffi.Pointer<ffi.Char>,
);

final class _DeltaOptionalConfig {
  _DeltaOptionalConfig() : _getConfig = _loadGetConfig();

  final _DcGetConfigDart? _getConfig;

  static _DcGetConfigDart? _loadGetConfig() {
    try {
      final library = loadDeltaLibrary();
      final symbol = library.lookup<ffi.NativeFunction<_DcGetConfigNative>>(
        'dc_get_config',
      );
      return symbol.asFunction<_DcGetConfigDart>();
    } on Exception {
      return null;
    }
  }

  String? read(
    ffi.Pointer<dc_context_t> context,
    String key,
    DeltaChatBindings bindings,
  ) {
    final fn = _getConfig;
    if (fn == null) return null;
    final ptr = _withCString(key, (keyPtr) => fn(context, keyPtr));
    return _takeString(ptr, bindings: bindings);
  }
}

final _DeltaOptionalConfig _deltaOptionalConfig = _DeltaOptionalConfig();

class DeltaMessageType {
  static const int text = 10;
  static const int image = 20;
  static const int gif = 21;
  static const int audio = 40;
  static const int voice = 41;
  static const int video = 50;
  static const int file = 60;
}

class DeltaDownloadState {
  static const int done = 0;
  static const int available = 10;
  static const int failure = 20;
  static const int undecipherable = 30;
  static const int inProgress = 1000;
}

class DeltaChatVisibility {
  static const int normal = 0;
  static const int archived = 1;
  static const int pinned = 2;
}

class DeltaEventCode {
  static const int error = DC_EVENT_ERROR;
  static const int errorSelfNotInGroup = DC_EVENT_ERROR_SELF_NOT_IN_GROUP;
  static const int configureProgress = DC_EVENT_CONFIGURE_PROGRESS;
  static const int incomingMsgBunch = DC_EVENT_INCOMING_MSG_BUNCH;
  static const int accountsBackgroundFetchDone =
      DC_EVENT_ACCOUNTS_BACKGROUND_FETCH_DONE;
  static const int connectivityChanged = DC_EVENT_CONNECTIVITY_CHANGED;
  static const int channelOverflow = DC_EVENT_CHANNEL_OVERFLOW;
  static const int msgsChanged = DC_EVENT_MSGS_CHANGED;
  static const int chatModified = DC_EVENT_CHAT_MODIFIED;
  static const int msgsNoticed = DC_EVENT_MSGS_NOTICED;
}

class DeltaContactListFlags {
  static const int addSelf = 0x1;
  static const int verifiedOnly = 0x2;
  static const int addRecent = 0x4;
}

class DeltaChatlistEntry {
  const DeltaChatlistEntry({
    required this.chatId,
    required this.msgId,
  });

  final int chatId;
  final int msgId;
}

const int _deltaMessageIdInitial = 0;
const int _freshMessageCountDefault = 0;

class DeltaFreshMessageCount {
  const DeltaFreshMessageCount({
    required this.count,
    required this.supported,
  });

  const DeltaFreshMessageCount.unsupported()
      : count = _freshMessageCountDefault,
        supported = false;

  final int count;
  final bool supported;
}

class DeltaMessageState {
  static const int undefined = 0;
  static const int inFresh = 10;
  static const int inNoticed = 13;
  static const int inSeen = 16;
  static const int outPreparing = 18;
  static const int outDraft = 19;
  static const int outPending = 20;
  static const int outFailed = 24;
  static const int outDelivered = 26;
  static const int outMdnRcvd = 28;
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
  static const _lastSpecialContactId = 9;

  _DeltaEventLoop? _eventLoop;

  bool _opened = false;
  bool _ioRunning = false;
  bool? _supportsMessageIsOutgoing;
  bool? _supportsFreshMsgs;
  bool? _supportsFreshMsgCount;
  bool? _supportsMarkNoticed;
  bool? _supportsMarkSeen;
  bool? _supportsDeleteMsgs;
  bool? _supportsQuote;
  bool? _supportsForward;
  bool? _supportsDraft;
  bool? _supportsSearch;
  bool? _supportsVisibility;
  bool? _supportsDownload;
  bool? _supportsResend;
  bool? _supportsContactList;
  bool? _supportsMessageSetHtml;

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

  bool get isConfigured {
    _ensureState(_opened, 'check configuration state');
    return _bindings.dc_is_configured(_context) != 0;
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

  Future<void> setConfig({
    required String key,
    required String value,
  }) async {
    _ensureState(_opened, 'set config $key');
    await _setConfig(key, value);
  }

  Future<String?> getConfig(String key) async {
    _ensureState(_opened, 'get config $key');
    return _deltaOptionalConfig.read(_context, key, _bindings);
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

  Future<void> maybeNetworkAvailable() async {
    _ensureState(_opened, 'notify network availability');
    _bindings.dc_maybe_network(_context);
  }

  Future<void> maybeNetworkLost() async {
    _ensureState(_opened, 'notify network change');
    _bindings.dc_maybe_network(_context);
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
    _ensurePositive(contactId, 'create contact', _lastError);
    return contactId;
  }

  Future<int> createChatByContactId(int contactId) async {
    final chatId = _bindings.dc_create_chat_by_contact_id(
      _context,
      contactId,
    );
    _ensurePositive(chatId, 'create chat from contact', _lastError);
    return chatId;
  }

  Future<int?> lookupContactIdByAddress(String address) async {
    _ensureState(_opened, 'lookup contact');
    final contactId = _withCString(address, (addrPtr) {
      return _bindings.dc_lookup_contact_id_by_addr(_context, addrPtr);
    });
    return contactId == 0 ? null : contactId;
  }

  Future<void> blockContact(int contactId) async {
    _ensureState(_opened, 'block contact');
    final result = _bindings.dc_block_contact(_context, contactId);
    _ensureSuccess(result, 'block contact $contactId', _lastError);
  }

  Future<void> unblockContact(int contactId) async {
    _ensureState(_opened, 'unblock contact');
    final result = _bindings.dc_unblock_contact(_context, contactId);
    _ensureSuccess(result, 'unblock contact $contactId', _lastError);
  }

  Future<DeltaContact?> getContact(int contactId) async {
    _ensureState(_opened, 'get contact');
    final contactPtr = _bindings.dc_get_contact(_context, contactId);
    if (contactPtr == ffi.nullptr) {
      return null;
    }
    try {
      final address = _cleanString(
        _takeString(_bindings.dc_contact_get_addr(contactPtr),
            bindings: _bindings),
      );
      final name = _cleanString(
        _takeString(_bindings.dc_contact_get_name(contactPtr),
            bindings: _bindings),
      );
      return DeltaContact(
        id: contactId,
        address: address,
        name: name,
      );
    } finally {
      _bindings.dc_contact_unref(contactPtr);
    }
  }

  Future<int> sendText({
    required int chatId,
    required String message,
    String? subject,
    String? html,
  }) async {
    _ensureState(_opened, 'send text message');
    final deltaMessage = _bindings.dc_msg_new(_context, DeltaMessageType.text);
    if (deltaMessage == ffi.nullptr) {
      throw const DeltaSafeException('Failed to allocate Delta message');
    }
    try {
      _withCString(message, (msgPtr) {
        _bindings.dc_msg_set_text(deltaMessage, msgPtr);
      });
      final normalizedHtml = html?.trim();
      if (normalizedHtml != null && normalizedHtml.isNotEmpty) {
        _setMessageHtml(deltaMessage, normalizedHtml);
      }
      final normalizedSubject = subject?.trim();
      if (normalizedSubject != null && normalizedSubject.isNotEmpty) {
        _withCString(normalizedSubject, (subjectPtr) {
          _bindings.dc_msg_set_subject(deltaMessage, subjectPtr);
        });
      }
      final msgId = _bindings.dc_send_msg(_context, chatId, deltaMessage);
      _ensurePositive(msgId, 'send text message', _lastError);
      return msgId;
    } finally {
      _bindings.dc_msg_unref(deltaMessage);
    }
  }

  Future<int> sendFileMessage({
    required int chatId,
    required int viewType,
    required String filePath,
    String? fileName,
    String? mimeType,
    String? text,
    String? subject,
    String? html,
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
      final normalizedHtml = html?.trim();
      if (normalizedHtml != null && normalizedHtml.isNotEmpty) {
        _setMessageHtml(message, normalizedHtml);
      }
      final normalizedSubject = subject?.trim();
      if (normalizedSubject != null && normalizedSubject.isNotEmpty) {
        _withCString(normalizedSubject, (subjectPtr) {
          _bindings.dc_msg_set_subject(message, subjectPtr);
        });
      }
      _setFileForMessage(
        message,
        filePath: filePath,
        fileName: fileName,
        mimeType: mimeType,
      );
      final msgId = _bindings.dc_send_msg(_context, chatId, message);
      _ensurePositive(msgId, 'send file message', _lastError);
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
      final contactId = _primaryContactIdForChat(chatId);
      String? contactAddress;
      String? contactName;
      if (contactId != null) {
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
        contactId: contactId,
        contactName: contactName,
        type: type == 0 ? null : type,
      );
    } finally {
      _bindings.dc_chat_unref(chatPtr);
    }
  }

  Future<List<DeltaChatlistEntry>> getChatlist({
    int flags = 0,
    String? query,
    int queryId = 0,
  }) async {
    _ensureState(_opened, 'get chat list');
    ffi.Pointer<ffi.Char> queryPointer = ffi.nullptr;
    ffi.Pointer<dc_chatlist_t> chatlistPointer = ffi.nullptr;
    try {
      final normalizedQuery = query?.trim();
      if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
        queryPointer = _toCString(normalizedQuery);
      }
      chatlistPointer = _bindings.dc_get_chatlist(
        _context,
        flags,
        queryPointer,
        queryId,
      );
      if (chatlistPointer == ffi.nullptr) {
        return const <DeltaChatlistEntry>[];
      }
      final count = _bindings.dc_chatlist_get_cnt(chatlistPointer);
      final entries = <DeltaChatlistEntry>[];
      for (var index = 0; index < count; index++) {
        entries.add(
          DeltaChatlistEntry(
            chatId: _bindings.dc_chatlist_get_chat_id(chatlistPointer, index),
            msgId: _bindings.dc_chatlist_get_msg_id(chatlistPointer, index),
          ),
        );
      }
      return entries;
    } catch (error) {
      if (error is ArgumentError || error is UnsupportedError) {
        return const <DeltaChatlistEntry>[];
      }
      rethrow;
    } finally {
      if (chatlistPointer != ffi.nullptr) {
        _bindings.dc_chatlist_unref(chatlistPointer);
      }
      if (queryPointer != ffi.nullptr) {
        malloc.free(queryPointer);
      }
    }
  }

  Future<List<int>> getChatMessageIds({
    required int chatId,
    int flags = 0,
    int beforeMessageId = _deltaMessageIdInitial,
  }) async {
    _ensureState(_opened, 'get chat messages');
    ffi.Pointer<dc_array_t> array = ffi.nullptr;
    try {
      array = _bindings.dc_get_chat_msgs(
        _context,
        chatId,
        flags,
        beforeMessageId,
      );
      if (array == ffi.nullptr) {
        return const <int>[];
      }
      final count = _bindings.dc_array_get_cnt(array);
      final ids = <int>[];
      for (var index = 0; index < count; index++) {
        ids.add(_bindings.dc_array_get_id(array, index));
      }
      return ids;
    } catch (error) {
      if (error is ArgumentError || error is UnsupportedError) {
        return const <int>[];
      }
      rethrow;
    } finally {
      if (array != ffi.nullptr) {
        _bindings.dc_array_unref(array);
      }
    }
  }

  int? _primaryContactIdForChat(int chatId) {
    final array = _bindings.dc_get_chat_contacts(_context, chatId);
    if (array == ffi.nullptr) {
      return null;
    }
    try {
      final count = _bindings.dc_array_get_cnt(array);
      for (var i = 0; i < count; i++) {
        final id = _bindings.dc_array_get_id(array, i);
        if (id > _lastSpecialContactId) {
          return id;
        }
      }
      return null;
    } finally {
      _bindings.dc_array_unref(array);
    }
  }

  bool _messageIsOutgoing(ffi.Pointer<dc_msg_t> msgPtr) {
    final supportsSymbol = _supportsMessageIsOutgoing;
    if (supportsSymbol != false) {
      try {
        final isOutgoing = _bindings.dc_msg_is_outgoing(msgPtr) != 0;
        _supportsMessageIsOutgoing = true;
        return isOutgoing;
      } on Object catch (error) {
        if (error is! ArgumentError && error is! UnsupportedError) {
          rethrow;
        }
        _supportsMessageIsOutgoing = false;
      }
    }

    final state = _bindings.dc_msg_get_state(msgPtr);
    return state == DeltaMessageState.outPreparing ||
        state == DeltaMessageState.outDraft ||
        state == DeltaMessageState.outPending ||
        state == DeltaMessageState.outFailed ||
        state == DeltaMessageState.outDelivered ||
        state == DeltaMessageState.outMdnRcvd;
  }

  int? _getDownloadState(ffi.Pointer<dc_msg_t> msgPtr) {
    if (_supportsDownload == false) return null;
    try {
      final state = _bindings.dc_msg_get_download_state(msgPtr);
      _supportsDownload = true;
      return state;
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsDownload = false;
      return null;
    }
  }

  String? _getMessageError(ffi.Pointer<dc_msg_t> msgPtr) {
    if (_supportsResend == false) return null;
    try {
      final errorPtr = _bindings.dc_msg_get_error(msgPtr);
      _supportsResend = true;
      if (errorPtr == ffi.nullptr) return null;
      return _takeString(errorPtr, bindings: _bindings);
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsResend = false;
      return null;
    }
  }

  void _setMessageHtml(ffi.Pointer<dc_msg_t> msgPtr, String html) {
    if (_supportsMessageSetHtml == false) return;
    try {
      _withCString(html, (htmlPtr) {
        _bindings.dc_msg_set_html(msgPtr, htmlPtr);
      });
      _supportsMessageSetHtml = true;
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsMessageSetHtml = false;
    }
  }

  Future<DeltaMessage?> getMessage(int messageId) async {
    final msgPtr = _bindings.dc_get_msg(_context, messageId);
    if (msgPtr == ffi.nullptr) {
      return null;
    }
    try {
      final viewType = _bindings.dc_msg_get_viewtype(msgPtr);
      final state = _bindings.dc_msg_get_state(msgPtr);
      final normalizedState =
          state == DeltaMessageState.undefined ? null : state;
      final text =
          _takeString(_bindings.dc_msg_get_text(msgPtr), bindings: _bindings);
      final html = _cleanString(
        _takeString(_bindings.dc_msg_get_html(msgPtr), bindings: _bindings),
      );
      final subject = _cleanString(
        _takeString(_bindings.dc_msg_get_subject(msgPtr), bindings: _bindings),
      );
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
      final isOutgoing = _messageIsOutgoing(msgPtr);
      final downloadState = _getDownloadState(msgPtr);
      final error = _getMessageError(msgPtr);
      return DeltaMessage(
        id: id,
        chatId: chatId,
        text: text,
        html: html,
        subject: subject,
        viewType: viewType,
        state: normalizedState,
        filePath: filePath,
        fileName: fileName,
        fileMime: fileMime,
        fileSize: fileBytes == 0 ? null : fileBytes,
        width: width == 0 ? null : width,
        height: height == 0 ? null : height,
        timestamp: timestamp,
        isOutgoing: isOutgoing,
        downloadState: downloadState,
        error: error,
      );
    } finally {
      _bindings.dc_msg_unref(msgPtr);
    }
  }

  Future<List<int>> getFreshMessageIds() async {
    if (_supportsFreshMsgs == false) return const [];
    try {
      final array = _bindings.dc_get_fresh_msgs(_context);
      _supportsFreshMsgs = true;
      if (array == ffi.nullptr) return const [];
      try {
        final count = _bindings.dc_array_get_cnt(array);
        final ids = <int>[];
        for (var i = 0; i < count; i++) {
          ids.add(_bindings.dc_array_get_id(array, i));
        }
        return ids;
      } finally {
        _bindings.dc_array_unref(array);
      }
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsFreshMsgs = false;
      return const [];
    }
  }

  Future<bool> probeFreshMessagesSupport() async {
    await getFreshMessageIds();
    return _supportsFreshMsgs == true;
  }

  Future<DeltaFreshMessageCount> getFreshMessageCountSafe(int chatId) async {
    if (_supportsFreshMsgCount == false) {
      return const DeltaFreshMessageCount.unsupported();
    }
    try {
      final count = _bindings.dc_get_fresh_msg_cnt(_context, chatId);
      _supportsFreshMsgCount = true;
      return DeltaFreshMessageCount(
        count: count,
        supported: true,
      );
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsFreshMsgCount = false;
      return const DeltaFreshMessageCount.unsupported();
    }
  }

  Future<int> getFreshMessageCount(int chatId) async {
    final result = await getFreshMessageCountSafe(chatId);
    return result.count;
  }

  Future<bool> markNoticedChat(int chatId) async {
    if (_supportsMarkNoticed == false) return false;
    try {
      _bindings.dc_marknoticed_chat(_context, chatId);
      _supportsMarkNoticed = true;
      return true;
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsMarkNoticed = false;
      return false;
    }
  }

  Future<bool> markSeenMessages(List<int> messageIds) async {
    if (_supportsMarkSeen == false || messageIds.isEmpty) return false;
    final idsPointer = malloc<ffi.Uint32>(messageIds.length);
    try {
      for (var i = 0; i < messageIds.length; i++) {
        idsPointer[i] = messageIds[i];
      }
      _bindings.dc_markseen_msgs(_context, idsPointer, messageIds.length);
      _supportsMarkSeen = true;
      return true;
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsMarkSeen = false;
      return false;
    } finally {
      malloc.free(idsPointer);
    }
  }

  Future<bool> deleteMessages(List<int> messageIds) async {
    if (_supportsDeleteMsgs == false || messageIds.isEmpty) return false;
    final idsPointer = malloc<ffi.Uint32>(messageIds.length);
    try {
      for (var i = 0; i < messageIds.length; i++) {
        idsPointer[i] = messageIds[i];
      }
      _bindings.dc_delete_msgs(_context, idsPointer, messageIds.length);
      _supportsDeleteMsgs = true;
      return true;
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsDeleteMsgs = false;
      return false;
    } finally {
      malloc.free(idsPointer);
    }
  }

  Future<bool> forwardMessages({
    required List<int> messageIds,
    required int toChatId,
  }) async {
    if (_supportsForward == false || messageIds.isEmpty) return false;
    final idsPointer = malloc<ffi.Uint32>(messageIds.length);
    try {
      for (var i = 0; i < messageIds.length; i++) {
        idsPointer[i] = messageIds[i];
      }
      _bindings.dc_forward_msgs(
        _context,
        idsPointer,
        messageIds.length,
        toChatId,
      );
      _supportsForward = true;
      return true;
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsForward = false;
      return false;
    } finally {
      malloc.free(idsPointer);
    }
  }

  Future<bool> setDraft({required int chatId, DeltaMessage? message}) async {
    if (_supportsDraft == false) return false;
    try {
      if (message == null) {
        _bindings.dc_set_draft(_context, chatId, ffi.nullptr);
      } else {
        final filePath = message.filePath?.trim();
        final hasFile = filePath != null && filePath.isNotEmpty;
        final resolvedViewType = message.viewType ??
            (hasFile ? DeltaMessageType.file : DeltaMessageType.text);
        final msg = _bindings.dc_msg_new(
          _context,
          resolvedViewType,
        );
        if (msg == ffi.nullptr) return false;
        try {
          final text = message.text;
          if (text != null) {
            _withCString(text, (textPtr) {
              _bindings.dc_msg_set_text(msg, textPtr);
            });
          }
          final normalizedHtml = message.html?.trim();
          if (normalizedHtml != null && normalizedHtml.isNotEmpty) {
            _setMessageHtml(msg, normalizedHtml);
          }
          final normalizedSubject = message.subject?.trim();
          if (normalizedSubject != null && normalizedSubject.isNotEmpty) {
            _withCString(normalizedSubject, (subjectPtr) {
              _bindings.dc_msg_set_subject(msg, subjectPtr);
            });
          }
          if (filePath != null && filePath.isNotEmpty) {
            _setFileForMessage(
              msg,
              filePath: filePath,
              fileName: message.fileName,
              mimeType: message.fileMime,
            );
          }
          _bindings.dc_set_draft(_context, chatId, msg);
        } finally {
          _bindings.dc_msg_unref(msg);
        }
      }
      _supportsDraft = true;
      return true;
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsDraft = false;
      return false;
    }
  }

  Future<DeltaMessage?> getDraft(int chatId) async {
    if (_supportsDraft == false) return null;
    try {
      final msgPtr = _bindings.dc_get_draft(_context, chatId);
      _supportsDraft = true;
      if (msgPtr == ffi.nullptr) return null;
      try {
        final text = _takeString(
          _bindings.dc_msg_get_text(msgPtr),
          bindings: _bindings,
        );
        final html = _cleanString(
          _takeString(_bindings.dc_msg_get_html(msgPtr), bindings: _bindings),
        );
        final subject = _cleanString(
          _takeString(
            _bindings.dc_msg_get_subject(msgPtr),
            bindings: _bindings,
          ),
        );
        final viewType = _bindings.dc_msg_get_viewtype(msgPtr);
        final id = _bindings.dc_msg_get_id(msgPtr);
        final filePath = _cleanString(
          _takeString(_bindings.dc_msg_get_file(msgPtr), bindings: _bindings),
        );
        final fileName = _cleanString(
          _takeString(
            _bindings.dc_msg_get_filename(msgPtr),
            bindings: _bindings,
          ),
        );
        final fileMime = _cleanString(
          _takeString(
            _bindings.dc_msg_get_filemime(msgPtr),
            bindings: _bindings,
          ),
        );
        final fileBytes = _bindings.dc_msg_get_filebytes(msgPtr);
        final width = _bindings.dc_msg_get_width(msgPtr);
        final height = _bindings.dc_msg_get_height(msgPtr);
        return DeltaMessage(
          id: id,
          chatId: chatId,
          text: text,
          html: html,
          subject: subject,
          viewType: viewType,
          filePath: filePath,
          fileName: fileName,
          fileMime: fileMime,
          fileSize: fileBytes == _zeroValue ? null : fileBytes,
          width: width == _zeroValue ? null : width,
          height: height == _zeroValue ? null : height,
        );
      } finally {
        _bindings.dc_msg_unref(msgPtr);
      }
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsDraft = false;
      return null;
    }
  }

  Future<List<int>> searchMessages({
    required int chatId,
    required String query,
  }) async {
    if (_supportsSearch == false) return const [];
    try {
      final array = _withCString(query, (queryPtr) {
        return _bindings.dc_search_msgs(_context, chatId, queryPtr);
      });
      _supportsSearch = true;
      if (array == ffi.nullptr) return const [];
      try {
        final count = _bindings.dc_array_get_cnt(array);
        final ids = <int>[];
        for (var i = 0; i < count; i++) {
          ids.add(_bindings.dc_array_get_id(array, i));
        }
        return ids;
      } finally {
        _bindings.dc_array_unref(array);
      }
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsSearch = false;
      return const [];
    }
  }

  Future<bool> setChatVisibility({
    required int chatId,
    required int visibility,
  }) async {
    if (_supportsVisibility == false) return false;
    try {
      _bindings.dc_set_chat_visibility(_context, chatId, visibility);
      _supportsVisibility = true;
      return true;
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsVisibility = false;
      return false;
    }
  }

  Future<bool> downloadFullMessage(int messageId) async {
    if (_supportsDownload == false) return false;
    try {
      _bindings.dc_download_full_msg(_context, messageId);
      _supportsDownload = true;
      return true;
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsDownload = false;
      return false;
    }
  }

  Future<bool> resendMessages(List<int> messageIds) async {
    if (_supportsResend == false || messageIds.isEmpty) return false;
    final idsPointer = malloc<ffi.Uint32>(messageIds.length);
    try {
      for (var i = 0; i < messageIds.length; i++) {
        idsPointer[i] = messageIds[i];
      }
      final result = _bindings.dc_resend_msgs(
        _context,
        idsPointer,
        messageIds.length,
      );
      _supportsResend = true;
      return result != 0;
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsResend = false;
      return false;
    } finally {
      malloc.free(idsPointer);
    }
  }

  Future<List<int>> getContactIds({int flags = 0, String? query}) async {
    if (_supportsContactList == false) return const [];
    ffi.Pointer<ffi.Char> queryPtr = ffi.nullptr;
    try {
      if (query != null && query.isNotEmpty) {
        queryPtr = _toCString(query);
      }
      final array = _bindings.dc_get_contacts(_context, flags, queryPtr);
      _supportsContactList = true;
      if (array == ffi.nullptr) return const [];
      try {
        final count = _bindings.dc_array_get_cnt(array);
        final ids = <int>[];
        for (var i = 0; i < count; i++) {
          ids.add(_bindings.dc_array_get_id(array, i));
        }
        return ids;
      } finally {
        _bindings.dc_array_unref(array);
      }
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsContactList = false;
      return const [];
    } finally {
      if (queryPtr != ffi.nullptr) {
        malloc.free(queryPtr);
      }
    }
  }

  Future<List<int>> getBlockedContactIds() async {
    if (_supportsContactList == false) return const [];
    try {
      final array = _bindings.dc_get_blocked_contacts(_context);
      _supportsContactList = true;
      if (array == ffi.nullptr) return const [];
      try {
        final count = _bindings.dc_array_get_cnt(array);
        final ids = <int>[];
        for (var i = 0; i < count; i++) {
          ids.add(_bindings.dc_array_get_id(array, i));
        }
        return ids;
      } finally {
        _bindings.dc_array_unref(array);
      }
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsContactList = false;
      return const [];
    }
  }

  Future<bool> deleteContact(int contactId) async {
    if (_supportsContactList == false) return false;
    try {
      final result = _bindings.dc_delete_contact(_context, contactId);
      _supportsContactList = true;
      return result != 0;
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsContactList = false;
      return false;
    }
  }

  Future<int> sendTextWithQuote({
    required int chatId,
    required String message,
    required int quotedMessageId,
    String? subject,
    String? html,
  }) async {
    if (_supportsQuote == false) {
      return sendText(
        chatId: chatId,
        message: message,
        subject: subject,
        html: html,
      );
    }
    _ensureState(_opened, 'send quoted message');
    final deltaMessage = _bindings.dc_msg_new(_context, DeltaMessageType.text);
    if (deltaMessage == ffi.nullptr) {
      throw const DeltaSafeException('Failed to allocate Delta message');
    }
    try {
      _withCString(message, (msgPtr) {
        _bindings.dc_msg_set_text(deltaMessage, msgPtr);
      });
      final normalizedHtml = html?.trim();
      if (normalizedHtml != null && normalizedHtml.isNotEmpty) {
        _setMessageHtml(deltaMessage, normalizedHtml);
      }
      final normalizedSubject = subject?.trim();
      if (normalizedSubject != null && normalizedSubject.isNotEmpty) {
        _withCString(normalizedSubject, (subjectPtr) {
          _bindings.dc_msg_set_subject(deltaMessage, subjectPtr);
        });
      }

      final quotedMsg = _bindings.dc_get_msg(_context, quotedMessageId);
      if (quotedMsg != ffi.nullptr) {
        try {
          _bindings.dc_msg_set_quote(deltaMessage, quotedMsg);
          _supportsQuote = true;
        } on Object catch (error) {
          if (error is! ArgumentError && error is! UnsupportedError) rethrow;
          _supportsQuote = false;
        } finally {
          _bindings.dc_msg_unref(quotedMsg);
        }
      }

      final msgId = _bindings.dc_send_msg(_context, chatId, deltaMessage);
      _ensurePositive(msgId, 'send quoted message', _lastError);
      return msgId;
    } finally {
      _bindings.dc_msg_unref(deltaMessage);
    }
  }

  Future<DeltaQuotedMessage?> getQuotedMessage(int messageId) async {
    if (_supportsQuote == false) return null;
    final msgPtr = _bindings.dc_get_msg(_context, messageId);
    if (msgPtr == ffi.nullptr) return null;
    try {
      final quotedMsgPtr = _bindings.dc_msg_get_quoted_msg(msgPtr);
      _supportsQuote = true;
      if (quotedMsgPtr == ffi.nullptr) {
        final quotedText = _takeString(
          _bindings.dc_msg_get_quoted_text(msgPtr),
          bindings: _bindings,
        );
        if (quotedText == null || quotedText.isEmpty) return null;
        return DeltaQuotedMessage(text: quotedText);
      }
      try {
        final quotedId = _bindings.dc_msg_get_id(quotedMsgPtr);
        final quotedText = _takeString(
          _bindings.dc_msg_get_text(quotedMsgPtr),
          bindings: _bindings,
        );
        return DeltaQuotedMessage(id: quotedId, text: quotedText);
      } finally {
        _bindings.dc_msg_unref(quotedMsgPtr);
      }
    } on Object catch (error) {
      if (error is! ArgumentError && error is! UnsupportedError) rethrow;
      _supportsQuote = false;
      return null;
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
    _ensureSuccess(result, 'set config $key', _lastError);
  }

  bool? _maybeIsOpen() {
    try {
      return _bindings.dc_context_is_open(_context) != 0;
    } on Object {
      return null;
    }
  }

  String? _lastError() =>
      _takeString(_bindings.dc_get_last_error(_context), bindings: _bindings);

  int connectivity() => _bindings.dc_get_connectivity(_context);

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

class DeltaContact {
  const DeltaContact({
    required this.id,
    this.address,
    this.name,
  });

  final int id;
  final String? address;
  final String? name;
}

class DeltaMessage {
  const DeltaMessage({
    required this.id,
    required this.chatId,
    this.text,
    this.html,
    this.subject,
    this.viewType,
    this.state,
    this.filePath,
    this.fileName,
    this.fileMime,
    this.fileSize,
    this.width,
    this.height,
    this.timestamp,
    this.isOutgoing = false,
    this.downloadState,
    this.error,
  });

  final int id;
  final int chatId;
  final String? text;
  final String? html;
  final String? subject;
  final int? viewType;
  final int? state;
  final String? filePath;
  final String? fileName;
  final String? fileMime;
  final int? fileSize;
  final int? width;
  final int? height;
  final DateTime? timestamp;
  final bool isOutgoing;
  final int? downloadState;
  final String? error;

  bool get hasFile => filePath != null && filePath!.isNotEmpty;

  bool get needsDownload =>
      downloadState == DeltaDownloadState.available ||
      downloadState == DeltaDownloadState.failure;
}

class DeltaQuotedMessage {
  const DeltaQuotedMessage({this.id, this.text});

  final int? id;
  final String? text;
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

void _ensureSuccess(
  int code,
  String operation, [
  String? Function()? errorProvider,
]) {
  if (code == 0) {
    final details = errorProvider?.call();
    final suffix = details == null || details.isEmpty ? '' : ': $details';
    throw DeltaSafeException('Failed to $operation$suffix');
  }
}

void _ensurePositive(
  int value,
  String operation, [
  String? Function()? errorProvider,
]) {
  if (value <= 0) {
    final details = errorProvider?.call();
    final suffix = details == null || details.isEmpty ? '' : ': $details';
    throw DeltaSafeException('Failed to $operation$suffix (code: $value)');
  }
}

void _ensureState(bool predicate, String operation) {
  if (!predicate) {
    throw DeltaSafeException('Cannot $operation before opening the context');
  }
}
