import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:async/async.dart';
import 'package:axichat/main.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/defer.dart';
import 'package:axichat/src/common/event_manager.dart';
import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/database_extensions.dart';
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
}

class XmppService extends XmppBase
    with
        BaseStreamService,
        MessageService,
        OmemoService,
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
    this._policy,
  );

  static XmppService? _instance;

  factory XmppService({
    required FutureOr<XmppConnection> Function() buildConnection,
    required FutureOr<XmppStateStore> Function(String, String) buildStateStore,
    required FutureOr<XmppDatabase> Function(String, String) buildDatabase,
    NotificationService? notificationService,
    Capability capability = const Capability(),
    Policy policy = const Policy(),
  }) =>
      _instance ??= XmppService._(
        buildConnection,
        buildStateStore,
        buildDatabase,
        notificationService ?? NotificationService(),
        capability,
        policy,
      );

  @override
  final _log = Logger('XmppService');

  var _stateStore = ImpatientCompleter(Completer<XmppStateStore>());
  var _database = ImpatientCompleter(Completer<XmppDatabase>());

  final FutureOr<XmppConnection> Function() _buildConnection;
  final FutureOr<XmppStateStore> Function(String, String) _buildStateStore;
  final FutureOr<XmppDatabase> Function(String, String) _buildDatabase;
  final NotificationService _notificationService;
  final Capability _capability;
  final Policy _policy;

  final fastTokenStorageKey = XmppStateStore.registerKey('fast_token');
  final userAgentStorageKey = XmppStateStore.registerKey('user_agent');
  final resourceStorageKey = XmppStateStore.registerKey('resource');

  @override
  XmppService get owner => this;

  @override
  Future<XmppDatabase> get database => _database.future;

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
      await _dbOp<XmppDatabase>((db) async {
        await db.markMessageAcked(event.stanza.id!);
      });
    })
    ..registerHandler<mox.StreamNegotiationsDoneEvent>((event) async {
      if (_connection.carbonsEnabled != true) {
        _log.info('Enabling carbons...');
        if (!await _connection.enableCarbons()) {
          _log.warning('Failed to enable carbons.');
        }
      }
      await _omemoManager.value?.commitDevice(await _device);
      if (await _ensureOmemoDevicePublished() case final result?) {
        _log.severe('Failed to publish OMEMO device. $result');
      }
      if (event.resumed) return;
      await _omemoManager.value?.onNewConnection();
    })
    ..registerHandler<mox.ResourceBoundEvent>((event) async {
      _log.info('Bound resource: ${event.resource}...');

      await _dbOp<XmppStateStore>((ss) async {
        await ss.write(key: resourceStorageKey, value: event.resource);
      });
    })
    ..registerHandler<mox.NewFASTTokenReceivedEvent>((event) async {
      _log.info('Saving FAST token...');
      await _dbOp<XmppStateStore>((ss) async {
        await ss.write(key: fastTokenStorageKey, value: event.token.token);
        _log.info('Saved FAST token: ${event.token.token}.');
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
        _log.info('Attempting login...');
        _connection = await _buildConnection();

        if (!_stateStore.isCompleted) {
          _stateStore.complete(
              await _buildStateStore(databasePrefix, databasePassphrase));
        }

        _myJid = mox.JID.fromString(jid);

        await _initConnection(preHashed: preHashed);

        _eventSubscription = _connection
            .asBroadcastStream()
            .listen(_eventManager.executeHandlers);

        _messageSubscription = _messageStream.stream.listen(
          (message) async {
            await _notificationService.sendNotification(
              title: message.senderJid,
              body: message.body,
              extraConditions: [
                message.senderJid != myJid,
                !await _dbOpReturning<XmppDatabase, bool>((db) async {
                  return (await db.getChat(message.chatJid))?.muted ?? false;
                }),
              ],
            );
          },
        );

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
          _log.info('Login rejected by server.');
          throw XmppAuthenticationException();
        }

        _log.info('Login successful. Initializing databases...');
        await _initDatabases(databasePrefix, databasePassphrase);

        return _connection.saltedPassword;
      },
    );
  }

  Future<void> _initConnection({bool preHashed = false}) async {
    _log.info('Initializing connection object...');
    final resource = await _dbOpReturning<XmppStateStore, String?>((ss) {
      return ss.read(key: resourceStorageKey) as String?;
    });
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
    await _connection.registerManagers(featureManagers);

    await _connection.loadStreamState();
    await _dbOp<XmppStateStore>((ss) {
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
          _log.info('Opening databases...');
          if (!_stateStore.isCompleted) {
            _stateStore.complete(await _buildStateStore(prefix, passphrase));
          }
          if (!_database.isCompleted) {
            _database.complete(await _buildDatabase(prefix, passphrase));
          }
        } on Exception catch (e) {
          _log.severe('Failed to create databases:', e);
          throw XmppDatabaseCreationException(e);
        }
      },
    );
  }

  Future<void> burn() async {
    await _dbOp<XmppStateStore>((ss) async {
      _log.info('Wiping state store...');
      await ss.deleteAll(burn: true);
    });

    await _dbOp<XmppDatabase>((db) async {
      _log.info('Wiping database...');
      await db.deleteAll();
      await db.close();
      await db.deleteFile();
    });
  }

  @override
  Future<void> disconnect() async {
    _log.info('Logging out...');
    await _reset();
    _log.info('Logged out.');
  }

  Future<void> setClientState([bool active = true]) async {
    if (!connected) return;

    if (_connection.getManager<mox.CSIManager>() case final csi?) {
      if (active) {
        _log.info('Setting CSI to active...');
        await csi.setActive();
      } else {
        _log.info('Setting CSI to inactive...');
        await csi.setInactive();
      }
    }
  }

  @override
  Future<void> _reset([Exception? e]) async {
    if (!needsReset) return;

    _log.info('Resetting${e != null ? ' due to $e' : ''}...');

    _eventManager.unregisterAllHandlers();

    await _eventSubscription?.cancel();
    _eventSubscription = null;

    await _messageSubscription?.cancel();
    _messageSubscription = null;

    if (connected) {
      try {
        await _connection.setShouldReconnect(false);
        await _connection.disconnect();
        _log.info('Gracefully disconnected.');
      } catch (e, s) {
        _log.severe('Graceful disconnect failed. Closing forcefully...', e, s);
      }
    }
    if (withForeground) {
      await _connection.reset();
    }
    _connection = await _buildConnection();

    if (!_stateStore.isCompleted) {
      _log.warning('Cancelling state store initialization...');
      _stateStore.completeError(XmppAbortedException());
    } else {
      _log.info('Closing state store...');
      await _stateStore.value?.close();
    }
    _stateStore = ImpatientCompleter(Completer<XmppStateStore>());

    if (!_database.isCompleted) {
      _log.warning('Cancelling database initialization...');
      _database.completeError(XmppAbortedException());
    } else {
      _log.info('Closing database...');
      await _database.value?.close();
    }
    _database = ImpatientCompleter(Completer<XmppDatabase>());

    _myJid = null;
    _synchronousConnection = Completer<void>();

    await super._reset();
    assert(!needsReset);
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
    _log.info('Retrieving completer for $D...');

    try {
      _log.info('Awaiting completer for $D...');
      final db = await _getDatabaseCompleter<D>().future;
      _log.info('Completed completer for $D.');
      return await operation(db);
    } on XmppAbortedException catch (e, s) {
      _log.warning('Owner called reset before $D initialized.', e, s);
      rethrow;
    } on XmppException {
      rethrow;
    } on Exception catch (e, s) {
      _log.severe('Unexpected exception during operation on $D.', e, s);
      throw XmppUnknownException(e);
    }
  }

  @override
  Future<void> _dbOp<T extends Database>(
    FutureOr<void> Function(T) operation, {
    bool awaitDatabase = false,
  }) async {
    _log.info('Retrieving completer for $T...');

    final completer = _getDatabaseCompleter<T>();

    if (!awaitDatabase && !completer.isCompleted) return;

    try {
      _log.info('Awaiting completer for $T...');
      final db = await completer.future;
      _log.info('Completed completer for $T.');
      return await operation(db);
    } on XmppAbortedException catch (_) {
      return;
    } on XmppException {
      rethrow;
    } on Exception catch (e, s) {
      _log.severe('Unexpected exception during operation on $T.', e, s);
      throw XmppUnknownException(e);
    }
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

class PubSubManager extends mox.PubSubManager {
  @override
  Future<moxlib.Result<mox.PubSubError, mox.PubSubItem>> getItem(
    mox.JID jid,
    String node,
    String? id,
  ) async {
    final result = await getAttributes().sendStanza(
      mox.StanzaDetails(
        mox.Stanza.iq(
          type: 'get',
          to: jid.toString(),
          children: [
            mox.XMLNode.xmlns(
              tag: 'pubsub',
              xmlns: mox.pubsubXmlns,
              children: [
                mox.XMLNode(
                  tag: 'items',
                  attributes: <String, String>{'node': node},
                  children: id != null
                      ? [
                          mox.XMLNode(
                            tag: 'item',
                            attributes: <String, String>{'id': id},
                          ),
                        ]
                      : [],
                ),
              ],
            ),
          ],
        ),
        shouldEncrypt: false,
      ),
    );

    if (result!.attributes['type'] != 'result') {
      return moxlib.Result(mox.getPubSubError(result));
    }

    final pubsub = result.firstTag('pubsub', xmlns: mox.pubsubXmlns);
    if (pubsub == null) return moxlib.Result(mox.getPubSubError(result));

    final itemElement = pubsub.firstTag('items')?.firstTag('item');
    if (itemElement == null) return moxlib.Result(mox.NoItemReturnedError());

    final item = mox.PubSubItem(
      id: itemElement.attributes['id']! as String,
      payload: itemElement.children[0],
      node: node,
    );

    return moxlib.Result(item);
  }
}

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
