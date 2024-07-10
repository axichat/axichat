import 'dart:async';
import 'dart:io';

import 'package:chat/src/common/capability.dart';
import 'package:chat/src/common/policy.dart';
import 'package:chat/src/storage/credential_store.dart';
import 'package:chat/src/storage/database.dart';
import 'package:chat/src/storage/impatient_completer.dart';
import 'package:chat/src/storage/models.dart';
import 'package:chat/src/storage/state_store.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:moxxmpp_socket_tcp/moxxmpp_socket_tcp.dart' as mox_tcp;
import 'package:retry/retry.dart' show RetryOptions;

part 'blocking_service.dart';
part 'presence_service.dart';
part 'roster_service.dart';

sealed class XmppException implements Exception {
  XmppException([this.wrapped]) : super();

  final Exception? wrapped;
}

final class XmppAuthenticationException extends XmppException {}

final class XmppUserNotFoundException extends XmppException {
  XmppUserNotFoundException([super.wrapped]);
}

final class XmppDatabaseCreationException extends XmppException {
  XmppDatabaseCreationException([super.wrapped]);
}

final class XmppUnknownException extends XmppException {
  XmppUnknownException([super.wrapped]);
}

final class XmppAbortedException extends XmppException {}

final class XmppRosterException extends XmppException {}

final class XmppPresenceException extends XmppException {}

final class XmppBlocklistException extends XmppException {}

final class XmppBlockUnsupportedException extends XmppException {}

final _devServerLookup = <String, IOEndpoint>{
  'draugr.de': IOEndpoint(
    InternetAddress('23.88.8.69', type: InternetAddressType.IPv4),
    5222,
  ),
  'jix.im': IOEndpoint(
    InternetAddress('51.77.59.5', type: InternetAddressType.IPv4),
    5222,
  )
};

abstract class XmppBase {
  XmppBase(this.domain);

  final String domain;
  late XmppConnection _connection;
  var _stateStore = ImpatientCompleter(Completer<XmppStateStore>());
  var _database = ImpatientCompleter(Completer<XmppDatabase>());

  XmppBase get owner;

  User? get user;

  Future<bool> login(String? username, String? password);
  Future<void> logout();

  Future _dbOp<T extends Database>(
    FutureOr Function(T) operation, {
    bool awaitDatabase = false,
  });
}

class XmppService extends XmppBase
    with RosterService, PresenceService, BlockingService {
  XmppService._(
    super.domain,
    this._buildConnection,
    this._buildCredentialStore,
    this._buildStateStore,
    this._buildDatabase,
    this._capability,
    this._policy,
  ) {
    _connection = _buildConnection();
  }

  static XmppService? _instance;

  factory XmppService(
    String domain, {
    required XmppConnection Function() buildConnection,
    required FutureOr<CredentialStore> Function() buildCredentialStore,
    required FutureOr<XmppStateStore> Function(String, String) buildStateStore,
    required FutureOr<XmppDatabase> Function(String, String) buildDatabase,
    required Capability capability,
    required Policy policy,
  }) =>
      _instance ??= XmppService._(
        domain,
        buildConnection,
        buildCredentialStore,
        buildStateStore,
        buildDatabase,
        capability,
        policy,
      );

  @override
  final _log = Logger('XmppService');

  final XmppConnection Function() _buildConnection;
  final FutureOr<CredentialStore> Function() _buildCredentialStore;
  final FutureOr<XmppStateStore> Function(String, String) _buildStateStore;
  final FutureOr<XmppDatabase> Function(String, String) _buildDatabase;
  final Capability _capability;
  final Policy _policy;

  final usernameStorageKey = CredentialStore.registerKey('username');
  final passwordStorageKey = CredentialStore.registerKey('password');

  final resourceStorageKey = XmppStateStore.registerKey('last_resource');
  final fastTokenStorageKey = XmppStateStore.registerKey('fast_token');
  final userAgentStorageKey = XmppStateStore.registerKey('user_agent');

  Completer<CredentialStore> _credentialStore = Completer<CredentialStore>();

  @override
  XmppService get owner => this;

  @override
  User? get user => _connection.hasConnectionSettings
      ? _connection.connectionSettings.user
      : null;

  bool get databasesInitialized =>
      _credentialStore.isCompleted &&
      _stateStore.isCompleted &&
      _database.isCompleted;

  bool get needsReset =>
      user != null ||
      _eventSubscription != null ||
      _credentialStore.isCompleted ||
      _stateStore.isCompleted ||
      _database.isCompleted;

  StreamSubscription<mox.XmppEvent>? _eventSubscription;

  void _onEvent(mox.XmppEvent event) async {
    switch (event) {
      case mox.StreamNegotiationsDoneEvent event:
        if (event.resumed) return;
        final carbonsManager = _connection.getManager<mox.CarbonsManager>()!;
        if (!carbonsManager.isEnabled) {
          _log.info('Enabling carbons...');
          if (!await carbonsManager.enableCarbons()) {
            _log.warning('Failed to enable carbons.');
          }
        }
        _log.info('Fetching roster...');
        await _connection.getRosterManager()?.requestRoster();
        _log.info('Fetching blocklist...');
        await requestBlocklist();
      case mox.ResourceBoundEvent event:
        _log.info('Saving resource...');
        await _dbOp<XmppStateStore>((ss) async {
          await ss.write(key: resourceStorageKey, value: event.resource);
          _log.info('Saved resource: ${event.resource}.');
        });
      case mox.NewFASTTokenReceivedEvent event:
        _log.info('Saving FAST token...');
        await _dbOp<XmppStateStore>((ss) async {
          await ss.write(key: fastTokenStorageKey, value: event.token.token);
          _log.info('Saved FAST token: ${event.token.token}.');
        });
      case mox.SubscriptionRequestReceivedEvent event:
        final requester = event.from.toBare().toString();
        _log.info('Subscription request received from $requester');
        await _dbOp<XmppDatabase>((db) async {
          final item = await db.rosterAccessor.selectOne(requester);
          if (item != null) {
            _log.info('Accepting subscription request from $requester...');
            try {
              await _acceptSubscriptionRequest(item);
            } on XmppRosterException catch (_) {}
            return;
          }
          _log.info('Adding subscription request from $requester...');
          db.invitesAccessor.insertOne(Invite(
            jid: requester,
            myJid: user!.jid.toString(),
            title: event.from.local,
          ));
        });
      case mox.BlocklistBlockPushEvent event:
        await _dbOp<XmppDatabase>((db) async {
          for (final blocked in event.items) {
            _log.info('Adding $blocked to blocklist...');
            await db.blocklistAccessor.insertOne(BlocklistData(jid: blocked));
          }
        });
      case mox.BlocklistUnblockPushEvent event:
        await _dbOp<XmppDatabase>((db) async {
          for (final unblocked in event.items) {
            _log.info('Removing $unblocked from blocklist...');
            await db.blocklistAccessor.deleteOne(unblocked);
          }
        });
      case mox.BlocklistUnblockAllPushEvent _:
        await _dbOp<XmppDatabase>((db) async {
          _log.info('Removing entire blocklist...');
          await db.blocklistAccessor.deleteAll();
        });
    }
  }

  @override
  Future<bool> login(
    String? username,
    String? password, [
    bool saveCredentials = true,
  ]) async {
    assert((username == null) == (password == null));

    if (needsReset) await _reset();

    await _deferResetToError(() async {
      _log.info('Attempting login...');

      _credentialStore.complete(_buildCredentialStore());

      if (username != null && password != null) {
        _log.info('New username and password provided. '
            'Attempting to authenticate directly with server...');

        bool attemptResumeStream = false;
        await _dbOp<CredentialStore>((cs) async {
          final databasePassphraseStorageKey = CredentialStore.registerKey(
              '${storagePrefixFor(username!)}_database_passphrase');
          final databasePassphrase =
              await cs.read(key: databasePassphraseStorageKey);

          if (databasePassphrase case final passphrase?) {
            _log.info('User has authenticated in the past. '
                'Opening state store for potential stream resumption...');
            if (!_stateStore.isCompleted) {
              _stateStore
                  .complete(await _buildStateStore(username!, passphrase));
            }
            attemptResumeStream = true;
          }
        });

        await _initConnection(attemptResumeStream);

        final newUser = User(
          jid: mox.JID.fromString('$username@$domain'),
          password: password!,
        );

        _eventSubscription = _connection.asBroadcastStream().listen(_onEvent);

        _connection.connectionSettings = XmppConnectionSettings(user: newUser);
        final result = await _connection.connect(
          shouldReconnect: false,
          waitForConnection: true,
          waitUntilLogin: true,
        );

        if (result.isType<mox.XmppError>()) {
          _log.info('Login rejected by server.');
          throw XmppAuthenticationException();
        }

        _log.info('Login successful. Initializing databases...');

        await _dbOp<CredentialStore>((cs) async {
          if (saveCredentials) {
            _log.info('Saving username and password...');
            await cs.write(key: usernameStorageKey, value: username);
            await cs.write(key: passwordStorageKey, value: password);
          }

          final databasePassphraseStorageKey = CredentialStore.registerKey(
              '${storagePrefixFor(username!)}_database_passphrase');
          var databasePassphrase =
              await cs.read(key: databasePassphraseStorageKey);

          if (databasePassphrase == null || databasePassphrase.isEmpty) {
            assert(!databasesInitialized);
            _log.info('Generating new database passphrase...');
            databasePassphrase = generatePassphrase();
            cs.write(
              key: databasePassphraseStorageKey,
              value: databasePassphrase,
            );
          }

          await _initDatabases(username!, databasePassphrase);
        });

        return;
      }

      _log.info('No username or password provided. '
          'Attempting to log in from stored user...');

      String? databasePassphrase;
      await _dbOp<CredentialStore>((cs) async {
        username = await cs.read(key: usernameStorageKey);
        password = await cs.read(key: passwordStorageKey);

        assert((username == null) == (password == null));

        if (username == null ||
            username!.isEmpty ||
            password == null ||
            password!.isEmpty) {
          _log.info('No saved user. Should redirect to login screen.');
          throw XmppUserNotFoundException();
        }

        final databasePassphraseStorageKey = CredentialStore.registerKey(
            '${storagePrefixFor(username!)}_database_passphrase');
        databasePassphrase = await cs.read(key: databasePassphraseStorageKey);

        if (databasePassphrase == null || databasePassphrase!.isEmpty) {
          assert(!databasesInitialized);
          _log.info('Generating new database passphrase...');
          databasePassphrase = generatePassphrase();
          cs.write(
            key: databasePassphraseStorageKey,
            value: databasePassphrase,
          );
        }
      });

      await _initDatabases(username!, databasePassphrase!);
      await _initConnection();

      final newUser = User(
        jid: mox.JID.fromString('$username@$domain'),
        password: password!,
      );

      _eventSubscription = _connection.asBroadcastStream().listen(_onEvent);

      _connection.connectionSettings = XmppConnectionSettings(user: newUser);
      _connection.connect();

      return;
    });
    return true;
  }

  Future<void> _initConnection([bool attemptResumeStream = true]) async {
    _log.info('Initializing connection object...');
    await _connection.registerFeatureNegotiators([
      mox.ResourceBindingNegotiator(),
      mox.StartTlsNegotiator(),
      mox.StreamManagementNegotiator(),
      mox.CSINegotiator(),
      mox.RosterFeatureNegotiator(),
      mox.PresenceNegotiator(),
      mox.SaslScramNegotiator(10, '', '', mox.ScramHashType.sha512),
      mox.SaslScramNegotiator(9, '', '', mox.ScramHashType.sha256),
      mox.SaslScramNegotiator(8, '', '', mox.ScramHashType.sha1),
      mox.SaslPlainNegotiator(),
      mox.Sasl2Negotiator(),
      mox.Bind2Negotiator(),
      mox.FASTSaslNegotiator(),
    ]);
    await _connection.registerManagers([
      XmppStreamManagementManager(owner: this),
      mox.DiscoManager([
        mox.Identity(
          category: 'client',
          type: _capability.discoClient,
          name: 'Axichat',
        ),
      ]),
      mox.RosterManager(XmppRosterStateManager(owner: this)),
      mox.PingManager(const Duration(minutes: 3)),
      mox.MessageManager(),
      XmppPresenceManager(owner: this),
      // mox.EntityCapabilitiesManager(),
      mox.CSIManager(),
      mox.CarbonsManager(),
      mox.PubSubManager(),
      mox.UserAvatarManager(),
      mox.StableIdManager(),
      mox.MessageDeliveryReceiptManager(),
      mox.ChatMarkerManager(),
      mox.OOBManager(),
      mox.SFSManager(),
      mox.MessageRepliesManager(),
      mox.BlockingManager(),
      mox.ChatStateManager(),
      mox.HttpFileUploadManager(),
      mox.FileUploadNotificationManager(),
      mox.EmeManager(),
      mox.CryptographicHashManager(),
      mox.DelayedDeliveryManager(),
      mox.MessageRetractionManager(),
      mox.LastMessageCorrectionManager(),
      mox.MessageReactionsManager(),
      mox.StickersManager(),
      mox.MessageProcessingHintManager(),
      mox.MUCManager(),
      mox.VCardManager(),
      mox.OccupantIdManager(),
    ]);

    if (attemptResumeStream) {
      _log.info('Attempting to resume stream...');
      await _connection.getStreamManagementManager()!.loadState();
      await _dbOp<XmppStateStore>((ss) {
        _log.info('Loaded resource: ${ss.read(key: resourceStorageKey)}');
        _connection
          ..getNegotiator<mox.StreamManagementNegotiator>()!.resource =
              ss.read(key: resourceStorageKey) as String? ?? ''
          ..getNegotiator<mox.FASTSaslNegotiator>()!.fastToken =
              ss.read(key: fastTokenStorageKey) as String?
          ..getNegotiator<mox.Sasl2Negotiator>()!.userAgent = mox.UserAgent(
            software: 'Axichat',
            id: ss.read(key: userAgentStorageKey) as String? ??
                () {
                  final id = uuid.v4();
                  ss.write(key: userAgentStorageKey, value: id);
                  return id;
                }(),
          );
      });
    }
  }

  Future<void> _initDatabases(String username, String passphrase) async {
    await _deferResetToError(() async {
      try {
        _log.info('Opening databases...');
        if (!_stateStore.isCompleted) {
          _stateStore.complete(await _buildStateStore(username, passphrase));
        }
        if (!_database.isCompleted) {
          _database.complete(await _buildDatabase(username, passphrase));
        }
      } on Exception catch (e) {
        _log.severe('Failed to create databases:', e);
        throw XmppDatabaseCreationException(e);
      }
    });
  }

  Future<void> _wipeDatabases(String username, String passphrase) async {
    await _dbOp<CredentialStore>((cs) async {
      _log.info('Wiping credential store...');
      await cs.deleteAll(burn: true);
    });

    await _dbOp<XmppStateStore>((ss) async {
      _log.info('Wiping state store...');
      await ss.deleteAll(burn: true);
    });

    await _dbOp<XmppDatabase>((db) async {
      _log.info('Wiping database...');
      await db.deleteAll();
      await db.close();
      (await dbFilePathFor(username)).delete();
    });
  }

  @override
  Future<void> logout({bool burn = false}) async {
    _log.info('Logging out...');
    await _deferReset(() async {
      final username = user!.username;

      String? passphrase;
      await _dbOp<CredentialStore>((cs) async {
        await cs.delete(key: usernameStorageKey);
        await cs.delete(key: passwordStorageKey);

        final databasePassphraseStorageKey = CredentialStore.registerKey(
            '${storagePrefixFor(username)}_database_passphrase');
        passphrase = await cs.read(key: databasePassphraseStorageKey);
      });

      if (!burn || passphrase == null) return;

      await _wipeDatabases(username, passphrase!);
    });
    _log.info('Logged out.');
  }

  Future<void> _reset() async {
    if (!needsReset) return;

    _log.info('Resetting...');

    _eventSubscription?.cancel();
    _eventSubscription = null;

    try {
      await _connection.disconnect();
      _log.info('Gracefully disconnected.');
    } catch (e, s) {
      _log.severe('Graceful disconnect failed. Closing forcefully...', e, s);
    }
    _connection = _buildConnection();

    if (!_credentialStore.isCompleted) {
      _log.warning('Cancelling credential store initialization...');
      _credentialStore.completeError(XmppAbortedException());
    } else {
      _log.info('Closing credential store...');
      await (await _credentialStore.future).close();
    }
    _credentialStore = Completer<CredentialStore>();

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

    assert(!needsReset);
  }

  Future<void> close() async {
    await _reset();
    _instance = null;
  }

  Future<T> _deferReset<T>(FutureOr<T> Function() operation) async {
    try {
      return await operation();
    } finally {
      await _reset();
    }
  }

  Future<T> _deferResetToError<T>(FutureOr<T> Function() operation) async {
    try {
      return await operation();
    } catch (e) {
      await _reset();
      rethrow;
    }
  }

  @override
  Future _dbOp<T extends Database>(
    FutureOr Function(T) operation, {
    bool awaitDatabase = false,
  }) async {
    _log.info('Retrieving completer for $T...');

    late final Completer<T> completer;
    switch (T) {
      case == CredentialStore:
        completer = _credentialStore as Completer<T>;
      case == XmppStateStore:
        completer = _stateStore.completer as Completer<T>;
      case == XmppDatabase:
        completer = _database.completer as Completer<T>;
      default:
        throw UnimplementedError('No database of type: $T exists.');
    }

    if (!awaitDatabase && !completer.isCompleted) return;
    try {
      _log.info('Awaiting completer for $T...');
      final db = await completer.future;
      _log.info('Completed completer for $T.');
      return await operation(db);
    } on XmppAbortedException catch (_) {
      _log.warning('Owner called reset before $T initialized.');
    } on XmppException {
      rethrow;
    } on Exception catch (e, s) {
      _log.severe('Unexpected exception during operation on $T.', e, s);
      throw XmppUnknownException(e);
    }
  }
}

class User {
  User({required this.jid, required this.password});

  final mox.JID jid;
  final String password;

  String? displayName;

  String get username => jid.local;
  String get domain => jid.domain;
}

class XmppConnection extends mox.XmppConnection {
  XmppConnection({
    XmppReconnectionPolicy? reconnectionPolicy,
    XmppConnectivityManager? connectivityManager,
    XmppClientNegotiator? negotiationsHandler,
    XmppSocketWrapper? socketWrapper,
  }) : super(
          reconnectionPolicy ?? XmppReconnectionPolicy.exponential(),
          connectivityManager ?? XmppConnectivityManager.pingDns(),
          negotiationsHandler ?? XmppClientNegotiator(),
          socketWrapper ?? XmppSocketWrapper(),
        );

  // Check if we have a connectionSettings as it is marked 'late' in mox.
  bool get hasConnectionSettings => _hasConnectionSettings;
  bool _hasConnectionSettings = false;

  @override
  XmppConnectionSettings get connectionSettings =>
      super.connectionSettings as XmppConnectionSettings;

  @override
  set connectionSettings(covariant XmppConnectionSettings connectionSettings) {
    _hasConnectionSettings = true;
    super.connectionSettings = connectionSettings;
  }

  T? getManager<T extends mox.XmppManagerBase>() {
    switch (T) {
      case == XmppPresenceManager:
        return getManagerById(mox.presenceManager);
      case == mox.CarbonsManager:
        return getManagerById(mox.carbonsManager);
      case == mox.BlockingManager:
        return getManagerById(mox.blockingManager);
      default:
        return null;
    }
  }

  T? getNegotiator<T extends mox.XmppFeatureNegotiatorBase>() {
    switch (T) {
      case == mox.StreamManagementNegotiator:
        return getNegotiatorById(mox.streamManagementNegotiator);
      case == mox.FASTSaslNegotiator:
        return getNegotiatorById(mox.saslFASTNegotiator);
      case == mox.Sasl2Negotiator:
        return getNegotiatorById(mox.sasl2Negotiator);
      default:
        return null;
    }
  }
}

class XmppConnectionSettings extends mox.ConnectionSettings {
  XmppConnectionSettings({required this.user})
      : super(jid: user.jid, password: user.password);

  final User user;

  @override
  String? get host {
    final endpoint = _devServerLookup[jid.domain];
    return endpoint?.host.address;
  }

  @override
  int? get port {
    final endpoint = _devServerLookup[jid.domain];
    return endpoint?.port;
  }
}

class XmppReconnectionPolicy implements mox.ReconnectionPolicy {
  XmppReconnectionPolicy._(this.strategy);

  final RetryOptions strategy;

  XmppReconnectionPolicy.exponential() : this._(const RetryOptions());

  bool _reconnectionInProgress = false;
  bool _shouldReconnect = false;

  int _reconnectionAttempts = 0;
  bool get reachedMaxAttempts => _reconnectionAttempts >= strategy.maxAttempts;

  @override
  mox.PerformReconnectFunction? performReconnect;

  @override
  void register(mox.PerformReconnectFunction performReconnect) =>
      this.performReconnect = performReconnect;

  // Have to do Future based API to match mox implementation.
  @override
  Future<bool> getIsReconnecting() async => _reconnectionInProgress;

  @override
  Future<bool> canTryReconnecting() async =>
      !_reconnectionInProgress && !reachedMaxAttempts;

  @override
  Future<bool> getShouldReconnect() async => _shouldReconnect;

  @override
  Future<void> setShouldReconnect(bool value) async => _shouldReconnect = value;

  @override
  Future<bool> canTriggerFailure() async =>
      await canTryReconnecting() && await getShouldReconnect();

  @override
  Future<void> onFailure() async {
    if (!await canTriggerFailure()) return;

    await Future.delayed(
      strategy.delay(_reconnectionAttempts),
      _reconnect,
    );
  }

  Future<void> _reconnect() async {
    _reconnectionInProgress = true;
    _reconnectionAttempts++;
    if (performReconnect case final reconnect?) {
      await reconnect();
    }
  }

  @override
  Future<void> onSuccess() => reset();

  @override
  Future<void> reset() async {
    _reconnectionInProgress = false;
    // _shouldReconnect = false;
    _reconnectionAttempts = 0;
  }
}

class IOEndpoint {
  const IOEndpoint(this.host, this.port);

  final InternetAddress host;
  final int port;
}

class XmppConnectivityManager extends mox.ConnectivityManager {
  XmppConnectivityManager._(this.endpoints);

  final List<IOEndpoint> endpoints;

  // fdns1.dismail.de, fdns2.dismail.de
  XmppConnectivityManager.pingDns()
      : this._([
          IOEndpoint(
            InternetAddress('116.203.32.217', type: InternetAddressType.IPv4),
            853,
          ),
          IOEndpoint(
            InternetAddress('159.69.114.157', type: InternetAddressType.IPv4),
            853,
          ),
        ]);

  static const timeoutDuration = Duration(seconds: 5);

  @override
  Future<bool> hasConnection() => compute(_pingEndpoints, endpoints);

  @override
  Future<void> waitForConnection() async {
    bool connected = false;
    while (!connected) {
      await Future.delayed(timeoutDuration);
      connected = await hasConnection();
    }
  }

  Future<bool> _pingEndpoints(List<IOEndpoint> endpoints) async {
    for (final endpoint in endpoints) {
      Socket? socket;
      try {
        socket = await Socket.connect(
          endpoint.host,
          endpoint.port,
          timeout: timeoutDuration,
        );
        socket.destroy();
        return true;
      } on SocketException catch (_) {
        socket?.destroy();
      }
    }
    return false;
  }
}

class XmppClientNegotiator extends mox.ClientToServerNegotiator {
  XmppClientNegotiator() : super();
}

class XmppSocketWrapper extends mox_tcp.TCPSocketWrapper {
  XmppSocketWrapper() : super(false);

  @override
  bool onBadCertificate(certificate, String domain) {
    // TODO: implement onBadCertificate
    // for (final endpoint in _devServerLookup.values) {
    //   if (endpoint.host.host == domain) return true;
    // }
    // return false;
    return true;
  }
}

class XmppStreamManagementManager extends mox.StreamManagementManager {
  XmppStreamManagementManager({required this.owner}) : super();

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
                null);
  }
}
