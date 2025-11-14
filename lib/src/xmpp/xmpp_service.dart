import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:axichat/main.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/defer.dart';
import 'package:axichat/src/common/event_manager.dart';
import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/impatient_completer.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:dnsolve/dnsolve.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:logging/logging.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:moxxmpp_socket_tcp/moxxmpp_socket_tcp.dart' as mox_tcp;
import 'package:omemo_dart/omemo_dart.dart'
    show RatchetMapKey, OmemoDataPackage; // For persistence types only
import 'package:omemo_dart/omemo_dart.dart' as omemo;
import 'package:path/path.dart' as p;
import 'package:retry/retry.dart' show RetryOptions;
import 'package:stream_transform/stream_transform.dart';
import 'package:uuid/uuid.dart';

part 'base_stream_service.dart';
part 'blocking_service.dart';
part 'chats_service.dart';
part 'message_service.dart';
part 'omemo_service.dart';
part 'presence_service.dart';
part 'roster_service.dart';
part 'xmpp_connection.dart';

sealed class XmppException implements Exception {
  XmppException([this.wrapped]) : super();

  final Exception? wrapped;
}

final class XmppAuthenticationException extends XmppException {}

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

final class XmppRosterException extends XmppException {}

final class XmppPresenceException extends XmppException {}

final class XmppBlocklistException extends XmppException {}

final class XmppBlockUnsupportedException extends XmppException {}

final class ForegroundServiceUnavailableException extends XmppException {
  ForegroundServiceUnavailableException([super.wrapped]);
}

final serverLookup = <String, IOEndpoint>{
  'nz.axichat.com': IOEndpoint(
    InternetAddress('167.160.14.12', type: InternetAddressType.IPv4),
    5222,
  ),
  'axi.im': IOEndpoint(
    InternetAddress('167.160.14.12', type: InternetAddressType.IPv4),
    5222,
  ),
  'hookipa.net': IOEndpoint(
    InternetAddress('31.172.31.205', type: InternetAddressType.IPv4),
    5222,
  ),
  'xmpp.social': IOEndpoint(
    InternetAddress('31.172.31.205', type: InternetAddressType.IPv4),
    5222,
  ),
  'trashserver.net': IOEndpoint(
    InternetAddress('5.1.72.136', type: InternetAddressType.IPv4),
    5222,
  ),
  'conversations.im': IOEndpoint(
    InternetAddress('78.47.177.120', type: InternetAddressType.IPv4),
    5222,
  ),
  'draugr.de': IOEndpoint(
    InternetAddress('23.88.8.69', type: InternetAddressType.IPv4),
    5222,
  ),
  'jix.im': IOEndpoint(
    InternetAddress('51.77.59.5', type: InternetAddressType.IPv4),
    5222,
  )
};

typedef ConnectionState = mox.XmppConnectionState;

abstract interface class XmppBase {
  XmppBase();

  late XmppConnection _connection;

  XmppBase get owner;

  String? get myJid;

  String? get resource;

  String? get username;

  mox.JID? get _myJid;

  Future<XmppDatabase> get database;

  bool get needsReset => false;

  EventManager<mox.XmppEvent> get _eventManager =>
      EventManager<mox.XmppEvent>();

  List<mox.XmppManagerBase> get featureManagers => [];

  ConnectionState get connectionState;

  Stream<ConnectionState> get connectivityStream;

  Future<String?> connect({
    required String jid,
    required String password,
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
}

class XmppService extends XmppBase
    with
        BaseStreamService,
        MessageService,
        // OmemoService,
        RosterService,
        PresenceService,
        ChatsService,
        BlockingService {
  XmppService._(
    this._buildConnection,
    this._buildStateStore,
    this._buildDatabase,
    this._notificationService,
    this._capability,
  );

  static XmppService? _instance;

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
  var _database = ImpatientCompleter(Completer<XmppDatabase>());

  final FutureOr<XmppConnection> Function() _buildConnection;
  final FutureOr<XmppStateStore> Function(String, String) _buildStateStore;
  final FutureOr<XmppDatabase> Function(String, String) _buildDatabase;
  final NotificationService _notificationService;
  final Capability _capability;

  // Calendar sync message callback
  Future<void> Function(CalendarSyncMessage)? _calendarSyncCallback;

  final fastTokenStorageKey = XmppStateStore.registerKey('fast_token');
  final userAgentStorageKey = XmppStateStore.registerKey('user_agent');
  final resourceStorageKey = XmppStateStore.registerKey('resource');

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
  void emitOmemoActivity(mox.OmemoActivityEvent event) {
    _omemoActivityController.add(event);
  }

  @override
  String? get myJid => _myJid?.toBare().toString();

  @override
  mox.JID? _myJid;

  @override
  EventManager<mox.XmppEvent> get _eventManager => super._eventManager
    ..registerHandler<mox.ConnectionStateChangedEvent>((event) {
      _connectionState = event.state;
      _connectivityStream.add(event.state);
      if (withForeground) {
        _connection.updateConnectivityNotification(event.state);
      }
    })
    ..registerHandler<mox.StanzaAckedEvent>((event) async {
      if (event.stanza.id == null) return;
      await _dbOp<XmppDatabase>((db) => db.markMessageAcked(event.stanza.id!));
    })
    ..registerHandler<mox.StreamNegotiationsDoneEvent>((event) async {
      if (_connection.carbonsEnabled != true) {
        _xmppLogger.info('Enabling carbons...');
        if (!await _connection.enableCarbons()) {
          _xmppLogger.warning('Failed to enable carbons.');
        }
      }
      // Device publishing is now handled internally by OmemoManager
      // when it's initialized with the device
      if (event.resumed) return;
      // Connection handling is now automatic in moxxmpp v0.5.0
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
        await _connection
            .getManager<XmppStreamManagementManager>()
            ?.resetState();
        if (await _connection.reconnectionPolicy.canTriggerFailure()) {
          await _connection.reconnectionPolicy.onFailure();
        }
      }
    });

  @override
  List<mox.XmppManagerBase> get featureManagers => super.featureManagers
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
      mox.PubSubManager(),
      mox.CSIManager(),
      // mox.UserAvatarManager(),
      mox.StableIdManager(),
      mox.CryptographicHashManager(),
      // mox.VCardManager(),
      mox.OccupantIdManager(),
    ]);

  @override
  String? get username => _myJid?.local;

  @override
  String? get resource => _myJid?.resource;

  String? get boundResource => _connection.hasConnectionSettings
      ? _connection.connectionSettings.jid.resource
      : null;

  bool get connected => connectionState == mox.XmppConnectionState.connected;

  bool get databasesInitialized =>
      _stateStore.isCompleted && _database.isCompleted;

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

  @override
  Future<String?> connect({
    required String jid,
    required String password,
    required String databasePrefix,
    required String databasePassphrase,
    bool preHashed = false,
  }) async {
    if (_synchronousConnection.isCompleted) {
      throw XmppAlreadyConnectedException();
    }
    if (needsReset) await _reset();
    _synchronousConnection.complete();

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
          );
        }
      },
    );
  }

  Future<String?> _establishConnection({
    required String jid,
    required String password,
    required String databasePrefix,
    required String databasePassphrase,
    required bool preHashed,
  }) async {
    _xmppLogger.info(
      foregroundServiceActive.value
          ? 'Attempting login with foreground service socket...'
          : 'Attempting login with direct socket...',
    );

    _connection = await _buildConnection();
    _omemoActivitySubscription?.cancel();
    _omemoActivitySubscription =
        _connection.omemoActivityStream.listen(_omemoActivityController.add);

    if (!_stateStore.isCompleted) {
      _stateStore.complete(
        await _buildStateStore(databasePrefix, databasePassphrase),
      );
    }

    _myJid = mox.JID.fromString(jid);

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

    if (result.isType<mox.XmppError>() || !result.get<bool>()) {
      _xmppLogger.info('Login rejected by server.');
      throw XmppAuthenticationException();
    }

    await _messageSubscription?.cancel();
    _messageSubscription = _messageStream.stream.listen(
      (message) async {
        await _notificationService.sendNotification(
          title: message.senderJid,
          body: message.body,
          extraConditions: [
            message.senderJid != myJid,
            !await _dbOpReturning<XmppDatabase, bool>((db) async =>
                (await db.getChat(message.chatJid))?.muted ?? false),
          ],
          payload: message.chatJid,
        );
      },
    );

    _xmppLogger.info('Login successful. Initializing databases...');
    await _initDatabases(databasePrefix, databasePassphrase);

    return _connection.saltedPassword;
  }

  Future<void> _initConnection({bool preHashed = false}) async {
    _xmppLogger.info('Initializing connection object...');
    final resource = await _dbOpReturning<XmppStateStore, String?>(
        (ss) async => ss.read(key: resourceStorageKey) as String?);
    await _connection.registerFeatureNegotiators([
      mox.StartTlsNegotiator(),
      mox.CSINegotiator(),
      mox.RosterFeatureNegotiator(),
      mox.PresenceNegotiator(),
      SaslScramNegotiator(preHashed: preHashed),
      mox.CarbonsNegotiator(),
      mox.StreamManagementNegotiator()..resource = resource ?? '',
      mox.Sasl2Negotiator(),
      mox.Bind2Negotiator()..tag = 'axichat',
      mox.FASTSaslNegotiator(),
    ]);

    // Initialize OMEMO manager before registering managers
    // await _completeOmemoManager();

    await _connection.registerManagers(featureManagers);

    await _connection.loadStreamState();
    await _dbOp<XmppStateStore>((ss) async {
      _connection
        ..setFastToken(ss.read(key: fastTokenStorageKey) as String?)
        ..setUserAgent(mox.UserAgent(
          software: appDisplayName,
          id: ss.read(key: userAgentStorageKey) as String? ??
              () {
                final id = uuid.v4();
                ss.write(key: userAgentStorageKey, value: id);
                return id;
              }(),
        ));
    });
  }

  Future<void> _initDatabases(String prefix, String passphrase) async {
    await deferToError(
      defer: _reset,
      operation: () async {
        try {
          _xmppLogger.info('Opening databases...');
          if (!_stateStore.isCompleted) {
            _stateStore.complete(await _buildStateStore(prefix, passphrase));
          }
          if (!_database.isCompleted) {
            _database.complete(await _buildDatabase(prefix, passphrase));
          }
        } on Exception catch (e) {
          _xmppLogger.severe('Failed to create databases:', e);
          throw XmppDatabaseCreationException(e);
        }
      },
    );

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

    _eventManager.unregisterAllHandlers();

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
    _connection = await _buildConnection();

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

class XmppSocketWrapper extends mox_tcp.TCPSocketWrapper {
  XmppSocketWrapper() : super(false);

  @override
  Future<List<mox_tcp.MoxSrvRecord>> srvQuery(
    String domain,
    bool dnssec,
  ) async {
    final response = await DNSolve().lookup(
      domain,
      dnsSec: true,
      type: RecordType.srv,
    );

    return response.answer?.srvs
            ?.map((e) =>
                mox_tcp.MoxSrvRecord(e.priority, e.weight, e.target!, e.port))
            .toList() ??
        [];
  }
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

// PubSubManager wrapper removed - moxxmpp v0.5.0's base implementation works correctly

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
