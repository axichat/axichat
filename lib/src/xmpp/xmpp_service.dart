import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:axichat/main.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/defer.dart';
import 'package:axichat/src/common/event_manager.dart';
import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/common/network_safety.dart';
import 'package:axichat/src/common/security_flags.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/demo/demo_chats.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/models/draft_save_result.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/settings/message_storage_mode.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/impatient_completer.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:axichat/src/xmpp/safe_pubsub_manager.dart';
import 'package:axichat/src/xmpp/safe_user_avatar_manager.dart';
import 'package:axichat/src/xmpp/safe_vcard_manager.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:logging/logging.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:moxxmpp_socket_tcp/moxxmpp_socket_tcp.dart' as mox_tcp;
import 'package:omemo_dart/omemo_dart.dart'
    show RatchetMapKey, OmemoDataPackage; // For persistence types only
import 'package:omemo_dart/omemo_dart.dart' as omemo;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:retry/retry.dart' show RetryOptions;
import 'package:stream_transform/stream_transform.dart';
import 'package:uuid/uuid.dart';

part 'base_stream_service.dart';
part 'blocking_service.dart';
part 'chats_service.dart';
part 'avatar_service.dart';
part 'muc_service.dart';
part 'message_service.dart';
part 'message_sanitizer.dart';
part 'mam_sm_guard.dart';
part 'omemo_service.dart';
part 'presence_service.dart';
part 'roster_service.dart';
part 'xmpp_connection.dart';

sealed class XmppException implements Exception {
  XmppException([this.wrapped]) : super();

  final Object? wrapped;
}

final class XmppAuthenticationException extends XmppException {
  XmppAuthenticationException([super.wrapped]);
}

final class XmppNetworkException extends XmppException {
  XmppNetworkException([super.wrapped]);
}

final class XmppUserNotFoundException extends XmppException {
  XmppUserNotFoundException([super.wrapped]);
}

final class XmppAlreadyConnectedException extends XmppException {}

final class XmppDatabaseCreationException extends XmppException {
  XmppDatabaseCreationException([super.wrapped]);
}

final class XmppUnknownException extends XmppException {
  XmppUnknownException([super.wrapped]);
}

final class XmppAbortedException extends XmppException {}

final class XmppMessageException extends XmppException {}

final class XmppForeignDomainException extends XmppMessageException {}

final class XmppRosterException extends XmppException {}

final class XmppPresenceException extends XmppException {}

final class XmppBlocklistException extends XmppException {}

final class XmppBlockUnsupportedException extends XmppException {}

final class ForegroundServiceUnavailableException extends XmppException {
  ForegroundServiceUnavailableException([super.wrapped]);
}

final class XmppAvatarException extends XmppException {
  XmppAvatarException([super.wrapped]);
}

final class XmppFileTooBigException extends XmppMessageException {
  XmppFileTooBigException(this.maxBytes);

  final int? maxBytes;
}

final class XmppUploadUnavailableException extends XmppMessageException {}

final class XmppUploadNotSupportedException extends XmppMessageException {}

final class XmppUploadMisconfiguredException extends XmppMessageException {
  XmppUploadMisconfiguredException([this.diagnostics]);

  final String? diagnostics;
}

class HttpUploadSupport {
  const HttpUploadSupport({
    required this.supported,
    this.entityJid,
    this.maxFileSizeBytes,
  });

  final bool supported;
  final String? entityJid;
  final int? maxFileSizeBytes;

  @override
  bool operator ==(Object other) {
    return other is HttpUploadSupport &&
        other.supported == supported &&
        other.entityJid == entityJid &&
        other.maxFileSizeBytes == maxFileSizeBytes;
  }

  @override
  int get hashCode => Object.hash(supported, entityJid, maxFileSizeBytes);
}

class StoredAvatar {
  const StoredAvatar({
    required this.path,
    required this.hash,
  });

  final String? path;
  final String? hash;

  bool get isEmpty => path == null && hash == null;
}

// Hardcode the socket endpoints so we never block on DNS when dialing the XMPP
// server. The `domain` parameter is still passed through for TLS/SASL SNI.
final serverLookup = <String, IOEndpoint>{
  'nz.axichat.com': const IOEndpoint('167.160.14.12', 5222),
  'axi.im': const IOEndpoint('167.160.14.12', 5222),
  'hookipa.net': const IOEndpoint('31.172.31.205', 5222),
  'xmpp.social': const IOEndpoint('31.172.31.205', 5222),
  'trashserver.net': const IOEndpoint('5.1.72.136', 5222),
  'conversations.im': const IOEndpoint('78.47.177.120', 5222),
  'draugr.de': const IOEndpoint('23.88.8.69', 5222),
  'jix.im': const IOEndpoint('51.77.59.5', 5222),
};

bool _isFirstPartyJid({
  required mox.JID? myJid,
  required String jid,
}) {
  if (myJid == null) {
    return false;
  }
  try {
    final target = mox.JID.fromString(jid);
    final myDomain = myJid.domain.toLowerCase();
    final targetDomain = target.domain.toLowerCase();
    return targetDomain == myDomain || targetDomain.endsWith('.$myDomain');
  } on Exception {
    return false;
  }
}

typedef ConnectionState = mox.XmppConnectionState;

abstract interface class XmppBase {
  XmppBase();

  late XmppConnection _connection;

  XmppBase get owner;

  String? get myJid;

  String? get resource;

  String? get username;

  mox.JID? get _myJid;

  HttpUploadSupport get httpUploadSupport;
  RegisteredStateKey get selfAvatarPathKey;
  RegisteredStateKey get selfAvatarHashKey;
  SecretKey? get avatarEncryptionKey;
  Stream<StoredAvatar?> get selfAvatarStream;
  void _notifySelfAvatarUpdated(StoredAvatar? avatar);
  List<int> secureBytes(int length);

  Future<XmppDatabase> get database;
  Stream<void> get databaseReloadStream;

  bool get needsReset => false;

  EventManager<mox.XmppEvent>? _eventManagerInstance;

  EventManager<mox.XmppEvent> get _eventManager =>
      _eventManagerInstance ??= _buildEventManager();

  EventManager<mox.XmppEvent> _buildEventManager() {
    final manager = EventManager<mox.XmppEvent>();
    configureEventHandlers(manager);
    return manager;
  }

  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {}

  void resetEventHandlers() {
    _eventManagerInstance?.unregisterAllHandlers();
    _eventManagerInstance = null;
  }

  List<mox.XmppManagerBase> get featureManagers => [];

  ConnectionState get connectionState;

  Stream<ConnectionState> get connectivityStream;

  Future<String?> connect({
    required String jid,
    required String password,
    required String databasePrefix,
    required String databasePassphrase,
    bool preHashed = false,
    bool reuseExistingSession = false,
  });

  Future<void> resumeOfflineSession({
    required String jid,
    required String databasePrefix,
    required String databasePassphrase,
  });

  Future<void> disconnect();

  FutureOr<V> _dbOpReturning<D extends Database, V>(
    FutureOr<V> Function(D) operation,
  );

  Future<void> _dbOp<T extends Database>(
    FutureOr<void> Function(T) operation, {
    bool awaitDatabase = false,
  });

  Future<void> _reset() async {}

  bool get isDatabaseReady;

  bool get isStateStoreReady;

  Stream<mox.OmemoActivityEvent> get omemoActivityStream;

  void emitOmemoActivity(mox.OmemoActivityEvent event) {}

  bool get demoOfflineMode;
}

class XmppService extends XmppBase
    with
        BaseStreamService,
        MucService,
        ChatsService,
        MessageService,
        AvatarService,
        // OmemoService,
        RosterService,
        PresenceService,
        BlockingService {
  XmppService._(
    this._connectionFactory,
    this._stateStoreFactory,
    this._databaseFactory,
    this._notificationService,
    this._capability,
  );

  static XmppService? _instance;
  static const bool _enableStreamManagement = true;

  factory XmppService({
    required FutureOr<XmppConnection> Function() buildConnection,
    required FutureOr<XmppStateStore> Function(String, String) buildStateStore,
    required FutureOr<XmppDatabase> Function(String, String) buildDatabase,
    NotificationService? notificationService,
    Capability capability = const Capability(),
  }) =>
      _instance ??= XmppService._(
        buildConnection,
        buildStateStore,
        buildDatabase,
        notificationService ?? NotificationService(),
        capability,
      );

  final Logger _xmppLogger = Logger('XmppService');
  var _stateStore = ImpatientCompleter(Completer<XmppStateStore>());
  @override
  var _database = ImpatientCompleter(Completer<XmppDatabase>());
  var _hasInitializedDatabases = false;
  final _databaseReloadController = StreamController<void>.broadcast();
  final _selfAvatarController = StreamController<StoredAvatar?>.broadcast();
  @override
  String? _databasePrefix;
  @override
  String? _databasePassphrase;

  final FutureOr<XmppConnection> Function() _connectionFactory;
  final FutureOr<XmppStateStore> Function(String, String) _stateStoreFactory;
  final FutureOr<XmppDatabase> Function(String, String) _databaseFactory;
  final NotificationService _notificationService;
  final Capability _capability;

  // Calendar sync message callback
  Future<void> Function(CalendarSyncMessage)? _calendarSyncCallback;

  final _httpUploadSupportController =
      StreamController<HttpUploadSupport>.broadcast();
  var _httpUploadSupport = const HttpUploadSupport(supported: false);
  bool get mamSupported => _mamSupported;
  Stream<bool> get mamSupportStream => _mamSupportController.stream;

  @override
  HttpUploadSupport get httpUploadSupport => _httpUploadSupport;

  Stream<HttpUploadSupport> get httpUploadSupportStream =>
      _httpUploadSupportController.stream;

  @override
  SecretKey? get avatarEncryptionKey => _avatarEncryptionKey;
  @override
  Stream<StoredAvatar?> get selfAvatarStream => _selfAvatarController.stream;
  @override
  Stream<void> get databaseReloadStream => _databaseReloadController.stream;

  @override
  void _notifyDatabaseReloaded() {
    if (_databaseReloadController.isClosed) return;
    _databaseReloadController.add(null);
  }

  @override
  void _notifySelfAvatarUpdated(StoredAvatar? avatar) {
    if (_selfAvatarController.isClosed) return;
    _selfAvatarController.add(avatar);
  }

  final fastTokenStorageKey = XmppStateStore.registerKey('fast_token');
  final userAgentStorageKey = XmppStateStore.registerKey('user_agent');
  final resourceStorageKey = XmppStateStore.registerKey('resource');
  @override
  final selfAvatarPathKey = XmppStateStore.registerKey('self_avatar_path');
  @override
  final selfAvatarHashKey = XmppStateStore.registerKey('self_avatar_hash');
  final avatarEncryptionSaltKey =
      XmppStateStore.registerKey('avatar_encryption_salt');

  final StreamController<mox.OmemoActivityEvent> _omemoActivityController =
      StreamController<mox.OmemoActivityEvent>.broadcast();
  StreamSubscription<mox.OmemoActivityEvent>? _omemoActivitySubscription;

  @override
  XmppService get owner => this;

  @override
  Future<XmppDatabase> get database => _database.future;

  @override
  @override
  bool get isDatabaseReady => _database.isCompleted;

  @override
  bool get isStateStoreReady => _stateStore.isCompleted;

  @override
  Stream<mox.OmemoActivityEvent> get omemoActivityStream =>
      _omemoActivityController.stream;

  @override
  bool get demoOfflineMode => _demoOfflineMode;

  @override
  void emitOmemoActivity(mox.OmemoActivityEvent event) {
    _omemoActivityController.add(event);
  }

  @override
  String? get myJid => _myJid?.toBare().toString();

  @override
  mox.JID? _myJid;

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<mox.ConnectionStateChangedEvent>((event) {
        _connectionState = event.state;
        _connectivityStream.add(event.state);
        if (event.state != ConnectionState.connected) {
          _updateHttpUploadSupport(const HttpUploadSupport(supported: false));
        }
        if (withForeground) {
          _connection.updateConnectivityNotification(event.state);
        }
      })
      ..registerHandler<mox.StanzaAckedEvent>((event) async {
        if (event.stanza.id == null) return;
        await _dbOp<XmppDatabase>(
            (db) => db.markMessageAcked(event.stanza.id!));
      })
      ..registerHandler<mox.StreamNegotiationsDoneEvent>((event) async {
        if (_connection.carbonsEnabled != true) {
          _xmppLogger.info('Enabling carbons...');
          if (!await _connection.enableCarbons()) {
            _xmppLogger.warning('Failed to enable carbons.');
          }
        }
        // Device publishing is now handled internally by OmemoManager.
        if (!event.resumed && _streamResumptionAttempted) {
          final sm = _connection.getManager<XmppStreamManagementManager>();
          await sm?.handleFailedResumption();
        }
        _streamResumptionAttempted = false;
        if (event.resumed) return;
        unawaited(_refreshHttpUploadSupport());
        // Connection handling is automatic in moxxmpp v0.5.0.
      })
      ..registerHandler<mox.ResourceBoundEvent>((event) async {
        _xmppLogger.info('Bound resource: ${event.resource}...');

        await _dbOp<XmppStateStore>(
            (ss) => ss.write(key: resourceStorageKey, value: event.resource));
      })
      ..registerHandler<mox.NewFASTTokenReceivedEvent>((event) async {
        _xmppLogger.fine('Saving FAST token.');
        await _dbOp<XmppStateStore>((ss) async {
          await ss.write(key: fastTokenStorageKey, value: event.token.token);
          _xmppLogger.fine('FAST token persisted.');
        });
      })
      ..registerHandler<mox.NonRecoverableErrorEvent>((event) async {
        if (event.error is mox.StreamUndefinedConditionError) {
          final sm = _connection.getManager<XmppStreamManagementManager>();
          await sm?.resetState();
          await sm?.clearPersistedState();
          await _connection.setShouldReconnect(false);
          if (await _connection.reconnectionPolicy.canTriggerFailure()) {
            await _connection.reconnectionPolicy.onFailure();
          }
        }
      });
  }

  @override
  List<mox.XmppManagerBase> get featureManagers {
    final managers = super.featureManagers
      ..addAll([
        XmppStreamManagementManager(owner: this),
        mox.DiscoManager([
          mox.Identity(
            category: 'client',
            type: _capability.discoClient,
            name: appDisplayName,
          ),
        ]),
        mox.PingManager(const Duration(minutes: 3)),
        // mox.EntityCapabilitiesManager(),
        SafePubSubManager(),
        mox.CSIManager(),
        mox.StableIdManager(),
        mox.CryptographicHashManager(),
        mox.OccupantIdManager(),
      ]);

    return managers;
  }

  @override
  String? get username => _myJid?.local;

  @override
  String? get resource => _myJid?.resource;

  String? get boundResource => _connection.hasConnectionSettings
      ? _connection.connectionSettings.jid.resource
      : null;

  bool get supportsHttpUpload => _httpUploadSupport.supported;

  bool get connected => connectionState == mox.XmppConnectionState.connected;

  bool get databasesInitialized =>
      _stateStore.isCompleted && _database.isCompleted;

  Future<StoredAvatar?> getOwnAvatar() async {
    if (!_stateStore.isCompleted) return null;
    try {
      final path = await _dbOpReturning<XmppStateStore, String?>(
        (ss) => ss.read(key: selfAvatarPathKey) as String?,
      );
      final hash = await _dbOpReturning<XmppStateStore, String?>(
        (ss) => ss.read(key: selfAvatarHashKey) as String?,
      );
      if (path == null && hash == null) return null;
      return StoredAvatar(path: path, hash: hash);
    } on XmppAbortedException {
      return null;
    }
  }

  @override
  bool get needsReset =>
      super.needsReset ||
      _myJid != null ||
      _eventSubscription != null ||
      _messageSubscription != null ||
      _stateStore.isCompleted ||
      _database.isCompleted ||
      _synchronousConnection.isCompleted;

  StreamSubscription<mox.XmppEvent>? _eventSubscription;
  StreamSubscription<Message>? _messageSubscription;

  @override
  ConnectionState get connectionState => _connectionState;
  var _connectionState = ConnectionState.notConnected;

  @override
  Stream<ConnectionState> get connectivityStream => _connectivityStream.stream;
  final _connectivityStream = StreamController<ConnectionState>.broadcast();

  var _synchronousConnection = Completer<void>();
  var _foregroundServiceNotificationSent = false;
  var _streamResumptionAttempted = false;
  var _demoSeedAttempted = false;
  var _demoOfflineMode = false;
  SecretKey? _avatarEncryptionKey;
  List<int>? _avatarEncryptionSalt;

  @override
  Future<String?> connect({
    required String jid,
    required String password,
    required String databasePrefix,
    required String databasePassphrase,
    bool preHashed = false,
    bool reuseExistingSession = false,
    EndpointOverride? endpoint,
  }) async {
    _databasePrefix = databasePrefix;
    _databasePassphrase = databasePassphrase;
    if (_synchronousConnection.isCompleted && connected) {
      throw XmppAlreadyConnectedException();
    }
    if (needsReset && !reuseExistingSession) await _reset();
    if (!_synchronousConnection.isCompleted) {
      _synchronousConnection.complete();
    }

    return await deferToError(
      defer: _reset,
      operation: () async {
        final attemptForeground =
            withForeground && foregroundServiceActive.value;
        try {
          return await _establishConnection(
            jid: jid,
            password: password,
            databasePrefix: databasePrefix,
            databasePassphrase: databasePassphrase,
            preHashed: preHashed,
            endpoint: endpoint,
          );
        } on ForegroundServiceUnavailableException catch (error, stackTrace) {
          if (!attemptForeground) {
            rethrow;
          }

          _xmppLogger.warning(
            'Foreground service unavailable, switching to direct socket.',
            error,
            stackTrace,
          );

          if (foregroundServiceActive.value) {
            foregroundServiceActive.value = false;
          }

          if (!_foregroundServiceNotificationSent) {
            unawaited(
              _notificationService.sendNotification(
                title: 'Background connection disabled',
                body:
                    'Android blocked Axichat\'s message service. Re-enable overlay and battery optimization permissions to restore background messaging.',
                allowForeground: true,
              ),
            );
            _foregroundServiceNotificationSent = true;
          }

          return await _establishConnection(
            jid: jid,
            password: password,
            databasePrefix: databasePrefix,
            databasePassphrase: databasePassphrase,
            preHashed: preHashed,
            endpoint: endpoint,
          );
        }
      },
    );
  }

  @override
  Future<void> resumeOfflineSession({
    required String jid,
    required String databasePrefix,
    required String databasePassphrase,
  }) async {
    final shouldNotify = _hasInitializedDatabases;
    _databasePrefix = databasePrefix;
    _databasePassphrase = databasePassphrase;
    final targetJid = mox.JID.fromString(jid);
    final activeJid = _myJid?.toBare().toString();
    if (activeJid != null && activeJid != targetJid.toBare().toString()) {
      await _reset();
    }
    if (_eventSubscription != null || _messageSubscription != null) {
      await _reset();
    }
    if (!_synchronousConnection.isCompleted) {
      _synchronousConnection.complete();
    }
    _connection = await _connectionFactory();
    _myJid = targetJid;
    if (!_stateStore.isCompleted) {
      _stateStore.complete(
        await _stateStoreFactory(databasePrefix, databasePassphrase),
      );
    }
    if (!_database.isCompleted) {
      _database.complete(
        await _buildDatabase(databasePrefix, databasePassphrase),
      );
    }
    _hasInitializedDatabases = true;
    if (shouldNotify) {
      _notifyDatabaseReloaded();
    }
    await _initializeAvatarEncryption(databasePassphrase);
    _demoOfflineMode = kEnableDemoChats && jid == kDemoSelfJid;
    if (_demoOfflineMode) {
      updateMessageStorageMode(MessageStorageMode.local);
    }
    _connectionState = ConnectionState.notConnected;
    _connectivityStream.add(_connectionState);
    await _seedDemoChatsIfNeeded();
  }

  Future<String?> _establishConnection({
    required String jid,
    required String password,
    required String databasePrefix,
    required String databasePassphrase,
    required bool preHashed,
    EndpointOverride? endpoint,
  }) async {
    _xmppLogger.info(
      foregroundServiceActive.value
          ? 'Attempting login with foreground service socket...'
          : 'Attempting login with direct socket...',
    );

    _connection = await _connectionFactory();
    _omemoActivitySubscription?.cancel();
    _omemoActivitySubscription =
        _connection.omemoActivityStream.listen(_omemoActivityController.add);

    if (!_stateStore.isCompleted) {
      _stateStore.complete(
        await _stateStoreFactory(databasePrefix, databasePassphrase),
      );
    }

    _myJid = mox.JID.fromString(jid);
    final bareDomain = _myJid?.toBare().toString().split('@').last;
    if (bareDomain != null && endpoint != null) {
      serverLookup[bareDomain] = IOEndpoint(endpoint.host, endpoint.port);
    }

    await _initConnection(preHashed: preHashed);

    await _eventSubscription?.cancel();
    _eventSubscription =
        _connection.asBroadcastStream().listen(_eventManager.executeHandlers);

    _connection.connectionSettings = XmppConnectionSettings(
      jid: _myJid!.toBare(),
      password: password,
    );

    final result = await _connection.connect(
      shouldReconnect: false,
      waitForConnection: true,
      waitUntilLogin: true,
    );

    if (result.isType<mox.XmppError>()) {
      final error = result.get<mox.XmppError>();
      _xmppLogger.info('Login failed with error: $error');
      if (_isAuthenticationError(error)) {
        throw XmppAuthenticationException(
          error is Exception ? error : null,
        );
      }
      throw XmppNetworkException(error is Exception ? error : null);
    }
    if (!result.get<bool>()) {
      _xmppLogger.info('Login rejected by server.');
      throw XmppAuthenticationException();
    }

    await _messageSubscription?.cancel();
    _messageSubscription = _messageStream.stream.listen(
      (message) async {
        final chat = await _dbOpReturning<XmppDatabase, Chat?>(
          (db) async => db.getChat(message.chatJid),
        );
        if (chat?.muted ?? false) {
          return;
        }
        await _notificationService.sendMessageNotification(
          title: chat?.title ?? message.senderJid,
          body: message.body,
          extraConditions: [
            message.senderJid != myJid,
          ],
          payload: message.chatJid,
          threadKey: message.chatJid,
        );
      },
    );

    await _resolveMamSupportForAccount();
    _xmppLogger.info('Login successful. Initializing databases...');
    await _initDatabases(databasePrefix, databasePassphrase);
    unawaited(refreshSelfAvatarIfNeeded());
    if (messageStorageMode.isServerOnly) {
      await purgeMessageHistory();
    }
    unawaited(_verifyMamSupportOnLogin());

    return _connection.saltedPassword;
  }

  bool _isAuthenticationError(mox.XmppError error) {
    if (error is mox.NegotiatorReturnedError) {
      return _isAuthenticationError(error.error);
    }
    if (error is mox.SaslError) {
      return error is mox.SaslNotAuthorizedError ||
          error is mox.SaslCredentialsExpiredError ||
          error is mox.SaslAccountDisabledError;
    }
    if (error is mox.InvalidHandshakeCredentialsError) {
      return true;
    }
    return false;
  }

  Future<void> _initConnection({
    bool preHashed = false,
  }) async {
    _xmppLogger.info('Initializing connection object...');
    final storedResource = await _dbOpReturning<XmppStateStore, String?>(
      (ss) async => ss.read(key: resourceStorageKey) as String?,
    );
    final smNegotiator = mox.StreamManagementNegotiator();
    if (storedResource != null && storedResource.isNotEmpty) {
      smNegotiator.resource = storedResource;
    }
    final featureNegotiators = <mox.XmppFeatureNegotiatorBase>[
      mox.StartTlsNegotiator(),
      mox.CSINegotiator(),
      mox.RosterFeatureNegotiator(),
      mox.PresenceNegotiator(),
      SaslScramNegotiator(preHashed: preHashed),
      mox.CarbonsNegotiator(),
      if (_enableStreamManagement) smNegotiator,
      mox.Sasl2Negotiator(),
      mox.Bind2Negotiator()..tag = 'axichat',
      mox.FASTSaslNegotiator(),
    ];
    await _connection.registerFeatureNegotiators(featureNegotiators);

    await _connection.registerManagers(featureManagers);

    _streamResumptionAttempted = false;
    if (_enableStreamManagement) {
      final sm = _connection.getManager<XmppStreamManagementManager>();
      if (sm != null) {
        _streamResumptionAttempted = await _dbOpReturning<XmppStateStore, bool>(
          (ss) async => ss.read(key: sm.streamResumptionIDKey) != null,
        );
        if (_streamResumptionAttempted) {
          await _connection.loadStreamState();
        }
      }
    }
    await _dbOp<XmppStateStore>((ss) async {
      final fastToken = ss.read(key: fastTokenStorageKey) as String?;
      var userAgentId = ss.read(key: userAgentStorageKey) as String?;
      if (userAgentId == null) {
        userAgentId = uuid.v4();
        await ss.write(key: userAgentStorageKey, value: userAgentId);
      }
      _connection
        ..setFastToken(fastToken)
        ..setUserAgent(mox.UserAgent(
          software: appDisplayName,
          id: userAgentId,
        ));
    });
  }

  @override
  Future<XmppDatabase> _buildDatabase(
    String prefix,
    String passphrase,
  ) async {
    final effectiveMode = messageStorageMode;
    if (effectiveMode.isServerOnly) {
      return XmppDrift.inMemory();
    }
    if (_messageStorageMode.isServerOnly && !_mamSupported) {
      _xmppLogger.warning(
        'Server-only storage requested without MAM support; falling back to local storage.',
      );
    }
    return _databaseFactory(prefix, passphrase);
  }

  Future<void> _initializeAvatarEncryption(String passphrase) async {
    try {
      final salt = await _loadOrCreateAvatarSalt();
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
      _avatarEncryptionKey = await hkdf.deriveKey(
        secretKey: SecretKey(utf8.encode(passphrase)),
        nonce: salt,
        info: utf8.encode('axichat-avatar-v1'),
      );
    } catch (error, stackTrace) {
      _xmppLogger.severe(
        'Failed to initialize avatar encryption key.',
        error,
        stackTrace,
      );
      _avatarEncryptionKey = null;
    }
  }

  Future<List<int>> _loadOrCreateAvatarSalt() async {
    if (_avatarEncryptionSalt case final cached?) {
      return cached;
    }
    try {
      final stored = await _dbOpReturning<XmppStateStore, String?>(
        (ss) => ss.read(key: avatarEncryptionSaltKey) as String?,
      );
      if (stored != null) {
        final decoded = base64Decode(stored);
        _avatarEncryptionSalt = decoded;
        return decoded;
      }
    } on XmppAbortedException {
      rethrow;
    } on FormatException catch (error, stackTrace) {
      _xmppLogger.warning(
        'Stored avatar salt could not be decoded, regenerating.',
        error,
        stackTrace,
      );
    }
    final fresh = secureBytes(32);
    final encoded = base64Encode(fresh);
    await _dbOp<XmppStateStore>(
      (ss) async => ss.write(key: avatarEncryptionSaltKey, value: encoded),
      awaitDatabase: true,
    );
    _avatarEncryptionSalt = fresh;
    return fresh;
  }

  Future<void> _initDatabases(String prefix, String passphrase) async {
    await deferToError(
      defer: _reset,
      operation: () async {
        try {
          final shouldNotify = _hasInitializedDatabases;
          _xmppLogger.info('Opening databases...');
          if (!_stateStore.isCompleted) {
            _stateStore.complete(await _stateStoreFactory(prefix, passphrase));
          }
          if (!_database.isCompleted) {
            _database.complete(await _buildDatabase(prefix, passphrase));
          }
          _hasInitializedDatabases = true;
          if (shouldNotify) {
            _notifyDatabaseReloaded();
          }
          await _initializeAvatarEncryption(passphrase);
        } on Exception catch (e) {
          _xmppLogger.severe('Failed to create databases:', e);
          throw XmppDatabaseCreationException(e);
        }
      },
    );
    await _seedDemoChatsIfNeeded();

    // try {
    //   await _initializeOmemoManagerIfNeeded();
    // } on mox.OmemoManagerNotInitializedError catch (error, stackTrace) {
    //   _xmppLogger.severe(
    //     'OMEMO manager refused to initialize after database unlock.',
    //     error,
    //     stackTrace,
    //   );
    // } catch (error, stackTrace) {
    //   _xmppLogger.severe(
    //     'Failed to initialize OMEMO manager after database unlock.',
    //     error,
    //     stackTrace,
    //   );
    // }
  }

  Future<void> _seedDemoChatsIfNeeded() async {
    if (_demoSeedAttempted || !kEnableDemoChats) return;
    _demoSeedAttempted = true;
    if (_myJid == null) {
      try {
        _myJid = mox.JID.fromString(kDemoSelfJid);
      } on Exception catch (error, stackTrace) {
        _xmppLogger.fine('Failed to apply demo JID', error, stackTrace);
      }
    }
    try {
      List<DemoChatScript>? scripts;
      await _dbOp<XmppDatabase>((db) async {
        final existingChats = await db.getChats(start: 0, end: 1);
        if (existingChats.isNotEmpty) {
          if (_demoOfflineMode) {
            scripts = DemoChats.scripts(
              openJid: DemoChats.defaultOpenJid,
            );
          }
          return;
        }
        scripts = DemoChats.scripts(
          openJid: DemoChats.defaultOpenJid,
        );
        for (final script in scripts!) {
          final messages = script.messages;
          final chat = script.chat;
          await db.createChat(chat);
          if (messages.isEmpty) continue;
          for (final message in messages) {
            await db.saveMessage(message, chatType: chat.type);
          }
          final latestMessage = messages.first;
          await db.updateChat(
            chat.copyWith(
              unreadCount: 0,
              lastChangeTimestamp:
                  latestMessage.timestamp ?? chat.lastChangeTimestamp,
              lastMessage: latestMessage.body,
            ),
          );
          final roomState = script.roomState;
          if (chat.type == ChatType.groupChat && roomState != null) {
            for (final occupant in roomState.occupants.values) {
              updateOccupantFromPresence(
                roomJid: chat.jid,
                occupantId: occupant.occupantId,
                nick: occupant.nick,
                realJid: occupant.realJid,
                affiliation: occupant.affiliation,
                role: occupant.role,
                isPresent: occupant.isPresent,
              );
            }
          }
        }
      }, awaitDatabase: true);
      if (scripts != null) {
        _seedDemoRoomOccupants(scripts!);
        await _seedDemoReactions(scripts!);
        await _seedDemoAvatars(scripts!);
      }
    } on Exception catch (error, stackTrace) {
      _xmppLogger.fine('Skipping demo chat seed', error, stackTrace);
    }
  }

  void _seedDemoRoomOccupants(List<DemoChatScript> scripts) {
    if (!_demoOfflineMode) return;
    for (final script in scripts) {
      final chat = script.chat;
      if (chat.type != ChatType.groupChat) continue;
      final roomState = script.roomState;
      if (roomState == null) continue;
      for (final occupant in roomState.occupants.values) {
        updateOccupantFromPresence(
          roomJid: chat.jid,
          occupantId: occupant.occupantId,
          nick: occupant.nick,
          realJid: occupant.realJid,
          affiliation: occupant.affiliation,
          role: occupant.role,
          isPresent: occupant.isPresent,
        );
      }
    }
  }

  static const _demoReactionThumbsUp = '👍';
  static const _demoReactionFire = '🔥';
  static const _demoReactionHeart = '❤️';
  static const _demoReactionLaugh = '😂';
  static const _demoReactionSparkles = '✨';
  static const _demoReactionMind = '🧠';
  static const _demoReactionScroll = '📜';
  static const _demoReactionMoney = '💰';
  static const _demoReactionClap = '👏';

  static const _demoFounderBareJids = <String>[
    kDemoSelfJid,
    'washington@axi.im',
    'jefferson@axi.im',
    'adams@axi.im',
    'madison@axi.im',
    'hamilton@axi.im',
  ];

  Future<void> _seedDemoReactions(List<DemoChatScript> scripts) async {
    if (!_demoOfflineMode) return;
    await _dbOp<XmppDatabase>(
      (db) async {
        for (final script in scripts) {
          final chat = script.chat;
          final messages = script.messages;
          if (messages.length < 2) continue;

          final existingReactions = await db.getReactionsForChat(chat.jid);
          bool hasReactionsForMessage(String messageId) {
            for (final reaction in existingReactions) {
              if (reaction.messageID == messageId) return true;
            }
            return false;
          }

          if (chat.type == ChatType.groupChat) {
            final franklinMessage = messages
                .where(
                  (message) =>
                      (_nickFromSender(message.senderJid) ?? '')
                          .toLowerCase() ==
                      'franklin',
                )
                .firstOrNull;
            if (franklinMessage != null &&
                !hasReactionsForMessage(franklinMessage.stanzaID)) {
              const reactors = _demoFounderBareJids;
              await db.replaceReactions(
                messageId: franklinMessage.stanzaID,
                senderJid: reactors[0],
                emojis: const [
                  _demoReactionClap,
                  _demoReactionFire,
                  _demoReactionHeart,
                  _demoReactionLaugh,
                  _demoReactionSparkles,
                ],
              );
              await db.replaceReactions(
                messageId: franklinMessage.stanzaID,
                senderJid: reactors[1],
                emojis: const [
                  _demoReactionClap,
                  _demoReactionFire,
                  _demoReactionThumbsUp,
                ],
              );
              await db.replaceReactions(
                messageId: franklinMessage.stanzaID,
                senderJid: reactors[2],
                emojis: const [
                  _demoReactionClap,
                  _demoReactionHeart,
                  _demoReactionScroll,
                ],
              );
              await db.replaceReactions(
                messageId: franklinMessage.stanzaID,
                senderJid: reactors[3],
                emojis: const [
                  _demoReactionClap,
                  _demoReactionFire,
                  _demoReactionThumbsUp,
                ],
              );
              await db.replaceReactions(
                messageId: franklinMessage.stanzaID,
                senderJid: reactors[4],
                emojis: const [
                  _demoReactionClap,
                  _demoReactionMind,
                  _demoReactionThumbsUp,
                ],
              );
              await db.replaceReactions(
                messageId: franklinMessage.stanzaID,
                senderJid: reactors[5],
                emojis: const [
                  _demoReactionClap,
                  _demoReactionMoney,
                  _demoReactionFire,
                ],
              );
            }

            final madisonMessages = messages.where(
              (message) =>
                  (_nickFromSender(message.senderJid) ?? '').toLowerCase() ==
                  'madison',
            );
            final madisonSecondMessage = madisonMessages.length >= 2
                ? madisonMessages.elementAt(1)
                : null;
            if (madisonSecondMessage != null &&
                !hasReactionsForMessage(madisonSecondMessage.stanzaID)) {
              await db.replaceReactions(
                messageId: madisonSecondMessage.stanzaID,
                senderJid: kDemoSelfJid,
                emojis: const [
                  _demoReactionThumbsUp,
                  _demoReactionMind,
                ],
              );
              await db.replaceReactions(
                messageId: madisonSecondMessage.stanzaID,
                senderJid: 'washington@axi.im',
                emojis: const [
                  _demoReactionClap,
                ],
              );
            }
            continue;
          }

          final targetMessage = messages[messages.length - 2];
          if (hasReactionsForMessage(targetMessage.stanzaID)) continue;

          final senderBare = _safeBareJid(targetMessage.senderJid);
          final reactor = senderBare == kDemoSelfJid ? chat.jid : kDemoSelfJid;
          await db.replaceReactions(
            messageId: targetMessage.stanzaID,
            senderJid: reactor,
            emojis: const [_demoReactionThumbsUp],
          );
        }
      },
      awaitDatabase: true,
    );
  }

  Future<void> _seedDemoAvatars(List<DemoChatScript> scripts) async {
    if (!_demoOfflineMode) return;
    if (avatarEncryptionKey == null) {
      _xmppLogger.fine(
        'Skipping demo avatar seed; encryption key unavailable.',
      );
      return;
    }
    final avatarAssets = DemoChats.avatarAssets();
    if (avatarAssets.isEmpty) return;
    for (final script in scripts) {
      final avatar = avatarAssets[script.chat.jid];
      if (avatar == null) continue;
      await _seedDemoAvatarForJid(
        jid: script.chat.jid,
        avatar: avatar,
      );
    }
    final selfAvatar = avatarAssets[kDemoSelfJid];
    if (selfAvatar != null) {
      await _seedDemoAvatarForJid(
        jid: kDemoSelfJid,
        avatar: selfAvatar,
      );
    }
  }

  static const ui.Color _demoWashingtonBackground = ui.Color(0xFF0A84FF);
  static const ui.Color _demoJeffersonBackground = ui.Color(0xFFFFD60A);
  static const ui.Color _demoAdamsBackground = ui.Color(0xFFFF3B30);
  static const ui.Color _demoMadisonBackground = ui.Color(0xFF34C759);
  static const ui.Color _demoHamiltonBackground = ui.Color(0xFFAF52DE);
  static const ui.Color _demoFranklinBackground = ui.Color(0xFFFFFFFF);

  ui.Color? _demoAvatarBackgroundForJid(String jid) {
    final normalized = jid.trim().toLowerCase();
    return switch (normalized) {
      kDemoSelfJid => _demoFranklinBackground,
      'washington@axi.im' => _demoWashingtonBackground,
      'jefferson@axi.im' => _demoJeffersonBackground,
      'adams@axi.im' => _demoAdamsBackground,
      'madison@axi.im' => _demoMadisonBackground,
      'hamilton@axi.im' => _demoHamiltonBackground,
      _ => null,
    };
  }

  Future<Uint8List> _applyDemoAvatarBackground({
    required Uint8List bytes,
    required ui.Color background,
  }) async {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      final canvas = img.Image(
        width: decoded.width,
        height: decoded.height,
        numChannels: 4,
        format: img.Format.uint8,
      );
      img.fill(canvas, color: _imgColor(background.toARGB32()));
      img.compositeImage(canvas, decoded);
      final output = Uint8List.fromList(img.encodePng(canvas, level: 4));
      if (output.isEmpty) return bytes;
      return output;
    } on Exception {
      return bytes;
    }
  }

  img.Color _imgColor(int argb) => img.ColorUint8.rgba(
        (argb >> 16) & 0xFF,
        (argb >> 8) & 0xFF,
        argb & 0xFF,
        (argb >> 24) & 0xFF,
      );

  Future<void> _seedDemoAvatarForJid({
    required String jid,
    required DemoContactAvatar avatar,
  }) async {
    try {
      final data = await rootBundle.load(avatar.assetPath);
      if (data.lengthInBytes == 0) return;
      final background = _demoAvatarBackgroundForJid(jid);
      final raw = data.buffer.asUint8List();
      final bytes = background == null
          ? raw
          : await _applyDemoAvatarBackground(
              bytes: raw, background: background);
      final avatarPath = await _writeAvatarFile(bytes: bytes);
      await _storeAvatar(
        jid: jid,
        path: avatarPath,
        hash: avatar.hash,
      );
    } catch (error, stackTrace) {
      _xmppLogger.fine(
        'Failed to seed demo avatar from ${avatar.assetPath}',
        error,
        stackTrace,
      );
    }
  }

  Future<void> burn() async {
    await _dbOp<XmppStateStore>((ss) async {
      _xmppLogger.info('Wiping state store...');
      await ss.deleteAll(burn: true);
    });

    await _dbOp<XmppDatabase>((db) async {
      _xmppLogger.info('Wiping database...');
      await db.deleteAll();
      await db.close();
      await db.deleteFile();
    });
  }

  @override
  Future<void> disconnect() async {
    _xmppLogger.info('Logging out...');
    if (messageStorageMode.isServerOnly) {
      await purgeMessageHistory(awaitDatabase: false);
    }
    await _reset();
    _xmppLogger.info('Logged out.');
  }

  Future<void> setClientState([bool active = true]) async {
    if (!connected) return;

    if (_connection.getManager<mox.CSIManager>() case final csi?) {
      if (active) {
        _xmppLogger.info('Setting CSI to active...');
        await csi.setActive();
      } else {
        _xmppLogger.info('Setting CSI to inactive...');
        await csi.setInactive();
      }
    }
  }

  @override
  Future<void> _reset([Exception? e]) async {
    if (!needsReset) return;

    _xmppLogger.info('Resetting${e != null ? ' due to $e' : ''}...');
    _demoSeedAttempted = false;
    _demoOfflineMode = false;
    _resetStableKeyCache();
    _updateHttpUploadSupport(const HttpUploadSupport(supported: false));
    _updateMamSupport(false);
    _mamSupportOverride = null;

    resetEventHandlers();

    try {
      await _connection.setShouldReconnect(false);
    } catch (error, stackTrace) {
      _xmppLogger.fine(
        'Failed to disable reconnection policy before reset.',
        error,
        stackTrace,
      );
    }

    await _eventSubscription?.cancel();
    _eventSubscription = null;

    await _messageSubscription?.cancel();
    _messageSubscription = null;

    await _omemoActivitySubscription?.cancel();
    _omemoActivitySubscription = null;

    if (connected) {
      try {
        await _connection.setShouldReconnect(false);
        await _connection.disconnect();
        _xmppLogger.info('Gracefully disconnected.');
      } catch (e, s) {
        _xmppLogger.severe(
            'Graceful disconnect failed. Closing forcefully...', e, s);
      }
    }
    if (withForeground) {
      await _connection.reset();
    }
    _connection = await _connectionFactory();

    if (!_stateStore.isCompleted) {
      _xmppLogger.warning('Cancelling state store initialization...');
      _stateStore.completeError(XmppAbortedException());
    } else {
      _xmppLogger.info('Closing state store...');
      await _stateStore.value?.close();
    }
    _stateStore = ImpatientCompleter(Completer<XmppStateStore>());

    if (!_database.isCompleted) {
      _xmppLogger.warning('Cancelling database initialization...');
      _database.completeError(XmppAbortedException());
    } else {
      _xmppLogger.info('Closing database...');
      await _database.value?.close();
    }
    _database = ImpatientCompleter(Completer<XmppDatabase>());

    _myJid = null;
    _synchronousConnection = Completer<void>();
    _streamResumptionAttempted = false;
    _avatarEncryptionKey = null;
    _avatarEncryptionSalt = null;
    _databasePrefix = null;
    _databasePassphrase = null;

    await super._reset();

    final residuals = <String>[];
    if (_messageStream.hasListener) residuals.add('messageStream');
    // if (_omemoManager.isCompleted) residuals.add('omemoManager');
    if (_myJid != null) residuals.add('myJid');
    if (_eventSubscription != null) residuals.add('eventSubscription');
    if (_messageSubscription != null) residuals.add('messageSubscription');
    if (_omemoActivitySubscription != null) {
      residuals.add('omemoActivitySubscription');
    }
    if (_stateStore.isCompleted) residuals.add('stateStore');
    if (_database.isCompleted) residuals.add('database');
    if (_synchronousConnection.isCompleted) {
      residuals.add('synchronousConnection');
    }

    if (residuals.isNotEmpty) {
      _xmppLogger.severe(
        'Reset left residual state: ${residuals.join(', ')}',
      );
    }

    assert(residuals.isEmpty);
  }

  Future<void> close() async {
    await _reset();
    if (!_httpUploadSupportController.isClosed) {
      await _httpUploadSupportController.close();
    }
    if (!_mamSupportController.isClosed) {
      await _mamSupportController.close();
    }
    if (!_databaseReloadController.isClosed) {
      await _databaseReloadController.close();
    }
    if (!_selfAvatarController.isClosed) {
      await _selfAvatarController.close();
    }
    _instance = null;
  }

  Completer<T> _getDatabaseCompleter<T>() => switch (T) {
        == XmppStateStore => _stateStore.completer as Completer<T>,
        == XmppDatabase => _database.completer as Completer<T>,
        _ => throw UnimplementedError('No database of type: $T exists.'),
      };

  @override
  Future<V> _dbOpReturning<D extends Database, V>(
      FutureOr<V> Function(D) operation) async {
    _xmppLogger.info('Retrieving completer for $D...');

    try {
      _xmppLogger.info('Awaiting completer for $D...');
      final db = await _getDatabaseCompleter<D>().future;
      _xmppLogger.info('Completed completer for $D.');
      return await operation(db);
    } on XmppAbortedException catch (e, s) {
      _xmppLogger.warning('Owner called reset before $D initialized.', e, s);
      rethrow;
    } on XmppException {
      rethrow;
    } on Exception catch (e, s) {
      _xmppLogger.severe('Unexpected exception during operation on $D.', e, s);
      throw XmppUnknownException(e);
    }
  }

  @override
  Future<void> _dbOp<T extends Database>(
    FutureOr<void> Function(T) operation, {
    bool awaitDatabase = false,
  }) async {
    _xmppLogger.info('Retrieving completer for $T...');

    final completer = _getDatabaseCompleter<T>();

    if (!awaitDatabase && !completer.isCompleted) return;

    try {
      _xmppLogger.info('Awaiting completer for $T...');
      final db = await completer.future;
      _xmppLogger.info('Completed completer for $T.');
      return await operation(db);
    } on XmppAbortedException catch (_) {
      return;
    } on XmppException {
      rethrow;
    } on Exception catch (e, s) {
      _xmppLogger.severe('Unexpected exception during operation on $T.', e, s);
      throw XmppUnknownException(e);
    }
  }

  @override
  List<int> secureBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  bool _hasHttpUploadIdentity(mox.DiscoInfo info) {
    final hasIdentity = info.identities.any(
      (identity) => identity.category == 'store' && identity.type == 'file',
    );
    return hasIdentity && info.features.contains(mox.httpFileUploadXmlns);
  }

  int? _httpUploadMaxFileSize(mox.DiscoInfo info) {
    for (final form in info.extendedInfo) {
      for (final field in form.fields) {
        if (field.varAttr == 'max-file-size') {
          return int.tryParse(field.values.first);
        }
      }
    }
    return null;
  }

  void _updateHttpUploadSupport(HttpUploadSupport support) {
    if (_httpUploadSupport == support) return;
    _httpUploadSupport = support;
    _httpUploadSupportController.add(support);
  }

  Future<void> _refreshHttpUploadSupport() async {
    final uploadManager = _connection.getManager<mox.HttpFileUploadManager>();
    final discoManager = _connection.getManager<mox.DiscoManager>();
    if (uploadManager == null || discoManager == null) {
      _xmppLogger.fine(
        'HTTP upload discovery skipped: manager missing (upload=$uploadManager, disco=$discoManager).',
      );
      _updateHttpUploadSupport(const HttpUploadSupport(supported: false));
      return;
    }
    try {
      final supported = await uploadManager.isSupported();
      String? entityJid;
      int? maxSize;
      final discoResult = await discoManager.performDiscoSweep();
      if (discoResult.isType<List<mox.DiscoInfo>>()) {
        final infos = discoResult.get<List<mox.DiscoInfo>>();
        for (final info in infos) {
          if (_hasHttpUploadIdentity(info)) {
            entityJid = info.jid.toString();
            maxSize = _httpUploadMaxFileSize(info);
            break;
          }
        }
      }
      final resolvedSupport = HttpUploadSupport(
        supported: supported && entityJid != null,
        entityJid: entityJid,
        maxFileSizeBytes: maxSize,
      );
      _xmppLogger.fine(
        'HTTP upload supported=${resolvedSupport.supported} entity=${entityJid ?? 'none'} maxSize=${maxSize ?? -1}B',
      );
      _updateHttpUploadSupport(resolvedSupport);
    } catch (error, stackTrace) {
      _xmppLogger.fine(
        'Failed to refresh HTTP upload support.',
        error,
        stackTrace,
      );
      _updateHttpUploadSupport(const HttpUploadSupport(supported: false));
    }
  }

  /// Register a callback to handle calendar sync messages
  void setCalendarSyncCallback(
      Future<void> Function(CalendarSyncMessage) callback) {
    _calendarSyncCallback = callback;
  }

  /// Clear any calendar sync callback to avoid calling disposed handlers.
  void clearCalendarSyncCallback() {
    _calendarSyncCallback = null;
  }

  static String generateResource() => 'axi.${generateRandomString(
        length: 7,
        seed: DateTime.now().millisecondsSinceEpoch,
      )}';
}

class XmppClientNegotiator extends mox.ClientToServerNegotiator {
  XmppClientNegotiator() : super();
}

class XmppResourceNegotiator extends mox.ResourceBindingNegotiator {
  XmppResourceNegotiator({required this.resource}) : super();

  final String resource;

  bool _attempted = false;

  @override
  Future<moxlib.Result<mox.NegotiatorState, mox.NegotiatorError>> negotiate(
      mox.XMLNode nonza) async {
    if (!_attempted) {
      final stanza = mox.XMLNode.xmlns(
        tag: 'iq',
        xmlns: mox.stanzaXmlns,
        attributes: {
          'type': 'set',
          'id': const Uuid().v4(),
        },
        children: [
          mox.XMLNode.xmlns(
            tag: 'bind',
            xmlns: mox.bindXmlns,
            children: [
              mox.XMLNode(
                tag: 'resource',
                text: resource,
              ),
            ],
          ),
        ],
      );

      _attempted = true;
      attributes.sendNonza(stanza);
      return const moxlib.Result(mox.NegotiatorState.ready);
    } else {
      if (nonza.tag != 'iq' || nonza.attributes['type'] != 'result') {
        return moxlib.Result(mox.ResourceBindingFailedError());
      }

      final bind = nonza.firstTag('bind')!;
      final rawJid = bind.firstTag('jid')!.innerText();
      final resource = mox.JID.fromString(rawJid).resource;
      attributes.setResource(resource);
      return const moxlib.Result(mox.NegotiatorState.done);
    }
  }

  @override
  void reset() {
    _attempted = false;
    super.reset();
  }
}

/// Stream management negotiator that tolerates missing managers and avoids null
/// dereferences during feature matching.
class XmppSocketWrapper implements mox.BaseSocketWrapper {
  XmppSocketWrapper({bool logTraffic = false})
      : _logIncomingOutgoing = logTraffic;

  static final _log = Logger('XmppSocketWrapper');
  static const _socketClosedWithErrorLog = 'Socket closed with error.';

  final bool _logIncomingOutgoing;
  final StreamController<String> _dataStream = StreamController.broadcast();
  final StreamController<mox.XmppSocketEvent> _eventStream =
      StreamController.broadcast();

  Socket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  bool _expectSocketClosure = false;
  bool _secure = false;

  @override
  bool isSecure() => _secure;

  @override
  bool managesKeepalives() => false;

  @override
  bool whitespacePingAllowed() => true;

  void destroy() {
    _socketSubscription?.cancel();
  }

  bool onBadCertificate(dynamic certificate, String domain) => false;

  Future<bool> _hostPortConnect(String host, int port) async {
    try {
      _log.finest('Attempting fallback connection to $host:$port...');
      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      _log.finest('Success!');
      return true;
    } on Exception catch (error) {
      _log.finest('Failure! $error');
      return false;
    }
  }

  @override
  Future<bool> connect(
    String domain, {
    String? host,
    int? port,
  }) async {
    _expectSocketClosure = false;
    _secure = false;

    final endpoint = serverLookup[domain];
    final overrideHost = host;
    final hasHostOverride = overrideHost != null && overrideHost.isNotEmpty;

    late final String resolvedHost;
    late final int resolvedPort;
    if (hasHostOverride) {
      resolvedHost = overrideHost;
      resolvedPort = port ?? 5222;
    } else {
      final target = endpoint;
      if (target == null) {
        _log.severe(
          'No static server mapping for $domain and no host override provided. DNS lookups are disabled.',
        );
        return false;
      }
      resolvedHost = target.host;
      resolvedPort = port ?? target.port;
    }

    _log.fine(
      'Connecting to $domain via direct endpoint $resolvedHost:$resolvedPort',
    );

    final connected = await _hostPortConnect(resolvedHost, resolvedPort);
    if (connected) {
      _setupStreams();
      return true;
    }

    _log.warning(
      'Failed to connect to $resolvedHost:$resolvedPort. DNS/SRV fallbacks are disabled.',
    );
    return false;
  }

  void _setupStreams() {
    final socket = _socket;
    if (socket == null) {
      _log.severe('Failed to setup streams as _socket is null');
      return;
    }

    _socketSubscription = socket.listen(
      (List<int> event) {
        final data = utf8.decode(event);
        if (_logIncomingOutgoing) {
          _log.finest('<== $data');
        }
        _dataStream.add(data);
      },
      onError: (Object error) {
        _log.severe(error.toString());
        _eventStream.add(mox.XmppSocketErrorEvent(error));
      },
      onDone: () {
        _socketSubscription = null;
      },
    );

    socket.done.then((_) {
      _eventStream.add(mox.XmppSocketClosureEvent(_expectSocketClosure));
      _expectSocketClosure = false;
    }).catchError((Object error, StackTrace stackTrace) {
      _log.fine(_socketClosedWithErrorLog, error, stackTrace);
      _eventStream.add(mox.XmppSocketErrorEvent(error));
      _eventStream.add(mox.XmppSocketClosureEvent(_expectSocketClosure));
      _expectSocketClosure = false;
    });
  }

  @override
  Future<bool> secure(String domain) async {
    if (_secure) {
      _log.warning('Connection is already marked as secure. Doing nothing');
      return true;
    }

    final socket = _socket;
    if (socket == null) {
      _log.severe('Failed to secure socket since _socket is null');
      return false;
    }

    try {
      _expectSocketClosure = true;
      _socket = await SecureSocket.secure(
        socket,
        host: domain,
        supportedProtocols: const [mox.xmppClientALPNId],
        onBadCertificate: (cert) => onBadCertificate(cert, domain),
      );

      _secure = true;
      _setupStreams();
      return true;
    } on Exception catch (error) {
      _log.severe('Failed to secure socket: $error');
      if (error is HandshakeException) {
        _eventStream.add(mox_tcp.XmppSocketTLSFailedEvent());
      }
      return false;
    }
  }

  @override
  void close() {
    _expectSocketClosure = true;

    final socket = _socket;
    if (socket == null) {
      _log.warning('Failed to close socket since _socket is null');
      return;
    }

    try {
      socket.close();
    } catch (error) {
      _log.warning('Closing socket threw exception: $error');
    }
  }

  @override
  void write(String data) {
    final socket = _socket;
    if (socket == null) {
      _log.severe('Failed to write to socket as _socket is null');
      return;
    }

    if (_logIncomingOutgoing) {
      _log.finest('==> $data');
    }

    try {
      socket.write(data);
    } on Exception catch (error) {
      _log.severe(error);
      _eventStream.add(mox.XmppSocketErrorEvent(error));
    }
  }

  @override
  Stream<String> getDataStream() => _dataStream.stream.asBroadcastStream();

  @override
  Stream<mox.XmppSocketEvent> getEventStream() =>
      _eventStream.stream.asBroadcastStream();

  @override
  void prepareDisconnect() {}
}

/// Custom Stream Management manager that adds persistent state storage.
///
/// This wrapper extends the base StreamManagementManager to persist stream state
/// to the database, enabling:
/// - Stream resumption after app restarts
/// - Reliable message delivery tracking across sessions
/// - Persistence of acknowledgment counters (c2s/s2c)
/// - Storage of stream resumption ID and location
///
/// This is essential for maintaining XMPP stream continuity and preventing
/// message loss during network disruptions or app lifecycle changes.
class XmppStreamManagementManager extends mox.StreamManagementManager {
  XmppStreamManagementManager({required this.owner})
      : super(ackTimeout: const Duration(minutes: 2));

  final XmppService owner;
  final _log = Logger('XmppStreamManagementManager');

  static const keyPrefix = 'stream_management';
  final clientToServerCountKey = XmppStateStore.registerKey('${keyPrefix}_c2s');
  final serverToClientCountKey = XmppStateStore.registerKey('${keyPrefix}_s2c');
  final streamResumptionIDKey =
      XmppStateStore.registerKey('${keyPrefix}_resID');
  final streamResumptionLocationKey =
      XmppStateStore.registerKey('${keyPrefix}_resLoc');

  Future<void> clearPersistedState() async {
    await owner._dbOp<XmppStateStore>(
      (ss) async {
        await ss.delete(key: clientToServerCountKey);
        await ss.delete(key: serverToClientCountKey);
        await ss.delete(key: streamResumptionIDKey);
        await ss.delete(key: streamResumptionLocationKey);
      },
      awaitDatabase: true,
    );
  }

  @override
  Future<void> commitState() async {
    await owner._dbOp<XmppStateStore>((ss) async {
      _log.info('Saving c2s: ${state.c2s}...');
      await ss.write(key: clientToServerCountKey, value: state.c2s);
      _log.info('Saving s2c: ${state.s2c}...');
      await ss.write(key: serverToClientCountKey, value: state.s2c);
      if (state.streamResumptionId case String resID) {
        await ss.write(key: streamResumptionIDKey, value: resID);
      }
      if (state.streamResumptionLocation case String resLoc) {
        await ss.write(key: streamResumptionLocationKey, value: resLoc);
      }
    });
  }

  @override
  Future<void> loadState() async {
    await owner._dbOp<XmppStateStore>((ss) async {
      var newState = state;
      if (ss.read(key: clientToServerCountKey) case int c2s) {
        _log.info('Loading c2s: ${state.c2s}...');
        newState = newState.copyWith(c2s: c2s);
      }
      if (ss.read(key: serverToClientCountKey) case int s2c) {
        _log.info('Loading s2c: ${state.s2c}...');
        newState = newState.copyWith(s2c: s2c);
      }
      if (ss.read(key: streamResumptionIDKey) case String resID) {
        newState = newState.copyWith(streamResumptionId: resID);
      }
      if (ss.read(key: streamResumptionLocationKey) case String resLoc) {
        newState = newState.copyWith(streamResumptionLocation: resLoc);
      }

      await setState(newState);
    });
  }

  Future<void> handleFailedResumption() async {
    _log.info(
      'Stream resumption was not accepted; clearing SM state.',
    );
    await resetState();
    await clearPersistedState();
  }

  // This is for delivery receipts in UI, not XEP-0198.
  @override
  bool shouldTriggerAckedEvent(mox.Stanza stanza) {
    return stanza.tag == 'message' &&
        stanza.id != null &&
        (stanza.firstTag('body') != null ||
            stanza.firstTag('x', xmlns: mox.oobDataXmlns) != null ||
            stanza.firstTag('file-sharing', xmlns: mox.sfsXmlns) != null ||
            stanza.firstTag(
                  'file-upload',
                  xmlns: mox.fileUploadNotificationXmlns,
                ) !=
                null ||
            stanza.firstTag('encrypted', xmlns: mox.omemoXmlns) != null);
  }
}

// PubSubManager wrapper lives in safe_pubsub_manager.dart.

/// Custom SASL SCRAM negotiator that adds support for pre-hashed passwords.
///
/// This wrapper is necessary for the app's security model where passwords can be
/// stored in a pre-hashed format rather than plaintext. This allows for:
/// - Secure password storage without keeping plaintext
/// - Faster reconnection using cached salted passwords
/// - Compatibility with the app's credential management system
class SaslScramNegotiator extends mox.SaslScramNegotiator {
  SaslScramNegotiator({
    this.preHashed = false,
  }) : super(10, '', '', mox.ScramHashType.sha512);

  final bool preHashed;

  String? get saltedPassword =>
      _saltedPassword != null ? base64Encode(_saltedPassword!) : null;
  List<int>? _saltedPassword;

  @override
  Future<List<int>> calculateSaltedPassword(String salt, int iterations) async {
    return _saltedPassword = preHashed
        ? base64Decode(attributes.getConnectionSettings().password)
        : await super.calculateSaltedPassword(salt, iterations);
  }
}
