// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:axichat/main.dart';
import 'package:flutter/foundation.dart';
import 'package:axichat/src/avatar/avatar_decode_safety.dart';
import 'package:axichat/src/calendar/models/calendar_acl.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_state.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_envelope.dart';
import 'package:axichat/src/calendar/interop/chat_calendar_support.dart';
import 'package:axichat/src/calendar/interop/calendar_task_ics_codec.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/defer.dart';
import 'package:axichat/src/common/event_manager.dart';
import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/anti_abuse_sync.dart' as anti_abuse;
import 'package:axichat/src/common/network_availability.dart';
import 'package:axichat/src/common/network_safety.dart';
import 'package:axichat/src/common/security_flags.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/draft_limits.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/demo/demo_chats.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/notifications/notification_payload.dart';
import 'package:axichat/src/xmpp/muc/muc_join_state.dart';
import 'package:axichat/src/xmpp/muc/occupant.dart';
import 'package:axichat/src/xmpp/muc/room_state.dart';
import 'package:axichat/src/storage/database.dart' hide DraftAttachmentRef;
import 'package:axichat/src/storage/impatient_completer.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/xmpp/pubsub/bookmarks_manager.dart';
import 'package:axichat/src/xmpp/pubsub/conversation_index_manager.dart';
import 'package:axichat/src/xmpp/pubsub/drafts_pubsub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/address_block_pubsub_manager.dart';
import 'package:axichat/src/xmpp/connection/foreground_socket.dart';
import 'package:axichat/src/xmpp/pubsub/message_collections_pubsub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_error_extensions.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_events.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_forms.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_hub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_support.dart';
import 'package:axichat/src/xmpp/pubsub/spam_pubsub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:crypto/crypto.dart' show sha1, sha256;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
import 'package:xml/xml_events.dart';

import 'package:axichat/src/calendar/sync/calendar_snapshot_codec.dart';

part 'stream/base_stream_service.dart';

part 'blocking/blocking_service.dart';

part 'pubsub/pubsub_service.dart';

part 'chats/chats_service.dart';

part 'avatar/avatar_service.dart';

part 'muc/muc_service.dart';

part 'muc/muc_join_bootstrap_manager.dart';

part 'message/message_service.dart';

part 'demo/demo_script_service.dart';

part 'message/message_stanza_manager.dart';

part 'message/xhtml_im_manager.dart';

part 'omemo/omemo_service.dart';

part 'presence/presence_service.dart';

part 'roster/roster_service.dart';

part 'connection/xmpp_connection.dart';

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

final class XmppMucCreateConflictException extends XmppMessageException {}

final class XmppForeignDomainException extends XmppMessageException {}

final class XmppRosterException extends XmppException {}

final class XmppPresenceException extends XmppException {}

final class XmppBlocklistException extends XmppException {}

final class XmppBlockUnsupportedException extends XmppException {}

final class XmppSpamReportUnsupportedException extends XmppException {}

final class XmppSpamReportException extends XmppException {}

final class ForegroundServiceUnavailableException extends XmppException {
  ForegroundServiceUnavailableException([super.wrapped]);
}

final class XmppAvatarException extends XmppException {
  XmppAvatarException([super.wrapped]);
}

final class XmppDisconnectedException extends XmppException {}

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

enum XmppPingExpectation {
  none,
  responseExpected;

  bool get expectsResponse => this == XmppPingExpectation.responseExpected;
}

final class XmppKeepAliveManager extends mox.XmppManagerBase {
  XmppKeepAliveManager() : super(managerId);

  static const String managerId = 'axi.keepalive';

  @override
  Future<bool> isSupported() async => true;

  XmppPingExpectation sendPing() {
    final attrs = getAttributes();
    final socket = attrs.getSocket();

    if (socket.managesKeepalives()) {
      logger.finest('Not sending ping as the socket manages it.');
      return XmppPingExpectation.none;
    }

    final stream = attrs.getManagerById<mox.StreamManagementManager>(
      mox.smManager,
    );
    if (stream != null && stream.isStreamManagementEnabled()) {
      logger.finest('Sending an ack ping as Stream Management is enabled');
      stream.sendAckRequestPing();
      return XmppPingExpectation.responseExpected;
    }

    if (socket.whitespacePingAllowed()) {
      logger.finest(
        'Sending a whitespace ping as Stream Management is not enabled',
      );
      attrs.getConnection().sendWhitespacePing();
      return XmppPingExpectation.none;
    }

    logger.warning(
      'Cannot send keepalives as SM is not available, the socket disallows whitespace pings and does not manage its own keepalives. Cannot guarantee that the connection survives.',
    );
    return XmppPingExpectation.none;
  }
}

final class XmppPingController {
  XmppPingController({required XmppService owner}) : _owner = owner;

  static const Duration _idlePingInterval = Duration(minutes: 2);
  static const Duration _minIdleDelay = Duration(seconds: 10);
  static const Duration _pingTimeout = Duration(seconds: 20);

  final XmppService _owner;

  Timer? _idleTimer;
  Timer? _pingTimeoutTimer;
  DateTime? _lastPingSentAt;

  void handleConnectionState(ConnectionState state) {
    if (state == ConnectionState.connected) {
      _scheduleIdleCheck();
      return;
    }
    stop();
  }

  void stop() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _pingTimeoutTimer?.cancel();
    _pingTimeoutTimer = null;
    _lastPingSentAt = null;
  }

  XmppTrafficTracker _trafficTracker() => _owner._connection.socketWrapper;

  void _scheduleIdleCheck() {
    _idleTimer?.cancel();
    if (_owner.connectionState != ConnectionState.connected) {
      return;
    }
    final delay = _nextIdleDelay();
    if (delay == Duration.zero) {
      _handleIdleCheck();
      return;
    }
    _idleTimer = Timer(delay, _handleIdleCheck);
  }

  Duration _nextIdleDelay() {
    final now = DateTime.timestamp();
    final tracker = _trafficTracker();
    final lastTraffic = _latestTraffic(
      tracker.lastIncomingAt,
      tracker.lastOutgoingAt,
      _lastPingSentAt,
    );
    if (lastTraffic == null) {
      return _idlePingInterval;
    }
    final elapsed = now.difference(lastTraffic);
    final remaining = _idlePingInterval - elapsed;
    if (remaining <= Duration.zero) {
      return Duration.zero;
    }
    if (remaining < _minIdleDelay) {
      return _minIdleDelay;
    }
    return remaining;
  }

  DateTime? _latestTraffic(
    DateTime? incoming,
    DateTime? outgoing,
    DateTime? pingSentAt,
  ) {
    if (incoming == null) {
      if (outgoing == null) {
        return pingSentAt;
      }
      if (pingSentAt == null) {
        return outgoing;
      }
      return outgoing.isAfter(pingSentAt) ? outgoing : pingSentAt;
    }
    if (outgoing == null) {
      if (pingSentAt == null) {
        return incoming;
      }
      return incoming.isAfter(pingSentAt) ? incoming : pingSentAt;
    }
    final candidate = incoming.isAfter(outgoing) ? incoming : outgoing;
    if (pingSentAt == null) {
      return candidate;
    }
    return candidate.isAfter(pingSentAt) ? candidate : pingSentAt;
  }

  void _handleIdleCheck() {
    _idleTimer = null;
    if (_owner.connectionState != ConnectionState.connected) {
      return;
    }
    final now = DateTime.timestamp();
    final tracker = _trafficTracker();
    final lastTraffic = _latestTraffic(
      tracker.lastIncomingAt,
      tracker.lastOutgoingAt,
      _lastPingSentAt,
    );
    if (lastTraffic != null &&
        now.difference(lastTraffic) < _idlePingInterval) {
      _scheduleIdleCheck();
      return;
    }
    _sendPing();
  }

  void _sendPing() {
    final manager = _owner._connection.getManager<XmppKeepAliveManager>();
    if (manager == null) {
      _scheduleIdleCheck();
      return;
    }
    final expectation = manager.sendPing();
    _lastPingSentAt = DateTime.timestamp();
    if (expectation.expectsResponse) {
      _schedulePingTimeout();
    } else {
      _pingTimeoutTimer?.cancel();
      _pingTimeoutTimer = null;
    }
    _scheduleIdleCheck();
  }

  void _schedulePingTimeout() {
    _pingTimeoutTimer?.cancel();
    final sentAt = _lastPingSentAt;
    if (sentAt == null) {
      return;
    }
    _pingTimeoutTimer = Timer(_pingTimeout, () {
      _pingTimeoutTimer = null;
      if (_owner.connectionState != ConnectionState.connected) {
        return;
      }
      final tracker = _trafficTracker();
      final lastIncoming = tracker.lastIncomingAt;
      if (lastIncoming != null && lastIncoming.isAfter(sentAt)) {
        return;
      }
      fireAndForget(
        () => _owner.requestReconnect(ReconnectTrigger.autoFailure),
        operationName: 'XmppService.pingTimeoutReconnect',
      );
    });
  }
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

// Hardcode the socket endpoints so we never block on DNS when dialing the XMPP
// server. The `domain` parameter is still passed through for TLS/SASL SNI.
final serverLookup = <String, IOEndpoint>{
  'nz.axichat.com': const IOEndpoint('167.160.14.12', 5222),
  'axi.im': const IOEndpoint('152.53.171.135', 5222),
  'hookipa.net': const IOEndpoint('31.172.31.205', 5222),
  'xmpp.social': const IOEndpoint('31.172.31.205', 5222),
  'trashserver.net': const IOEndpoint('5.1.72.136', 5222),
  'conversations.im': const IOEndpoint('78.47.177.120', 5222),
  'draugr.de': const IOEndpoint('23.88.8.69', 5222),
  'jix.im': const IOEndpoint('51.77.59.5', 5222),
};

typedef ConnectionState = mox.XmppConnectionState;

abstract interface class XmppBase {
  XmppBase();

  late XmppConnection _connection;
  bool _hasInitializedConnection = false;

  void _setConnection(XmppConnection connection) {
    _connection = connection;
    _hasInitializedConnection = true;
  }

  XmppBase get owner;

  String? get myJid;

  String? get resource;

  String? get username;

  mox.JID? get _myJid;

  PubSubSupport get pubSubSupport;

  Stream<PubSubSupport> get pubSubSupportStream;

  bool get autoDownloadImages;

  bool get autoDownloadVideos;

  bool get autoDownloadDocuments;

  bool get autoDownloadArchives;

  AttachmentAutoDownload get defaultChatAttachmentAutoDownload =>
      autoDownloadImages ||
          autoDownloadVideos ||
          autoDownloadDocuments ||
          autoDownloadArchives
      ? AttachmentAutoDownload.allowed
      : AttachmentAutoDownload.blocked;

  void updateAttachmentAutoDownloadSettings({
    required bool imagesEnabled,
    required bool videosEnabled,
    required bool documentsEnabled,
    required bool archivesEnabled,
  });

  bool allowsAutoDownloadMetadata(FileMetadataData metadata);

  Future<PubSubSupport> refreshPubSubSupport({bool force = false});

  CapabilityDecision decidePubSubSupport({
    required bool supported,
    required String featureLabel,
  });

  Future<CapabilityDecision> decideFeatureSupport({
    required String jid,
    required String feature,
    required String featureLabel,
  });

  RegisteredStateKey get selfAvatarPathKey;

  RegisteredStateKey get selfAvatarHashKey;

  RegisteredStateKey get selfAvatarPendingPublishKey;

  SecretKey? get avatarEncryptionKey;

  Avatar? get cachedSelfAvatar;

  Stream<Avatar?> get selfAvatarStream;

  bool get selfAvatarHydrating;

  Stream<bool> get selfAvatarHydratingStream;

  List<int> secureBytes(int length);

  Future<XmppDatabase> get database;

  Future<Avatar?> getOwnAvatar();

  Stream<void> get databaseReloadStream;

  int get lifecycleEpoch;

  bool get needsReset => false;

  EventManager<mox.XmppEvent>? _eventManagerInstance;

  EventManager<mox.XmppEvent> get _eventManager =>
      _eventManagerInstance ??= _buildEventManager();

  EventManager<mox.XmppEvent> _buildEventManager() {
    final manager = EventManager<mox.XmppEvent>();
    resetBootstrapOperations();
    configureEventHandlers(manager);
    return manager;
  }

  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {}

  void resetBootstrapOperations() {}

  void registerBootstrapOperation(XmppBootstrapOperation operation) {}

  Future<void> runBootstrapOperations(XmppBootstrapTrigger trigger) async {}

  Future<bool> requestLifecycleResumeReconnect() async => false;

  void resetEventHandlers() {
    _eventManagerInstance?.unregisterAllHandlers();
    _eventManagerInstance = null;
    resetBootstrapOperations();
  }

  List<String> get discoFeatures => const <String>[];

  List<mox.XmppManagerBase> get featureManagers => [];

  List<mox.XmppManagerBase> get pubSubFeatureManagers =>
      const <mox.XmppManagerBase>[];

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

  Stream<XmppOperationEvent> get xmppOperationStream;

  void emitXmppOperation(XmppOperationEvent event) {}

  Stream<mox.OmemoActivityEvent> get omemoActivityStream;

  void emitOmemoActivity(mox.OmemoActivityEvent event) {}

  bool get demoOfflineMode;
}

class _AxiEntityCapabilitiesManager extends mox.EntityCapabilitiesManager {
  _AxiEntityCapabilitiesManager(
    super.capabilityHashBase, {
    required bool Function(mox.JID jid) shouldIgnoreJid,
  }) : _shouldIgnoreJid = shouldIgnoreJid;

  final bool Function(mox.JID jid) _shouldIgnoreJid;

  @override
  // ignore: invalid_use_of_visible_for_testing_member
  Future<mox.StanzaHandlerData> onPresence(
    mox.Stanza stanza,
    mox.StanzaHandlerData state,
  ) async {
    final from = stanza.from;
    if (from != null) {
      try {
        final jid = mox.JID.fromString(from);
        if (_shouldIgnoreJid(jid)) {
          return state;
        }
      } on Exception {
        // Fall through and let the base manager handle malformed JIDs.
      }
    }
    // ignore: invalid_use_of_visible_for_testing_member
    return super.onPresence(stanza, state);
  }
}

enum XmppBootstrapTrigger { fullNegotiation, resumedNegotiation, manualRefresh }

final class XmppBootstrapOperation {
  const XmppBootstrapOperation({
    required this.key,
    required this.priority,
    required this.triggers,
    required this.operationName,
    required this.run,
    this.lane,
  });

  final Object key;
  final int priority;
  final Set<XmppBootstrapTrigger> triggers;
  final String operationName;
  final Future<void> Function() run;
  final Object? lane;
}

enum _XmppBootstrapOperationOutcome { success, failed, aborted, skipped }

final class _XmppBootstrapPass {
  _XmppBootstrapPass();

  final Map<Object, Future<void>> tasks = <Object, Future<void>>{};
  final Map<Object, _XmppBootstrapOperationOutcome> completedOperations =
      <Object, _XmppBootstrapOperationOutcome>{};
  final Map<Object, Map<int, _XmppBootstrapOperationOutcome>> laneOutcomes =
      <Object, Map<int, _XmppBootstrapOperationOutcome>>{};
  Future<void> scheduler = Future<void>.value();
  int queuedRuns = 0;
}

class XmppService extends XmppBase
    with
        BaseStreamService,
        AvatarService,
        PubSubService,
        BlockingService,
        MessageService,
        MucService,
        ChatsService,
        DemoScriptService,
        // OmemoService,
        RosterService,
        PresenceService {
  XmppService._(
    this._connectionFactory,
    this._stateStoreFactory,
    this._databaseFactory,
    this._notificationService,
    this._capability,
  ) {
    _pingController = XmppPingController(owner: this);
  }

  static XmppService? _instance;
  static const bool _enableStreamManagement = true;
  static const String _capabilityHashBase = 'https://axichat.im/caps';
  static const NotificationPayloadCodec _notificationPayloadCodec =
      NotificationPayloadCodec();
  final Map<String, String> _notificationPayloadCache = <String, String>{};
  final Map<String, String> _notificationPayloadLowerCache = <String, String>{};
  bool _notificationPayloadCacheReady = false;
  Future<void>? _notificationPayloadCacheFuture;
  static const int _notificationPayloadLookupStart = 0;
  static const int _notificationPayloadLookupEnd = 0;

  factory XmppService({
    required FutureOr<XmppConnection> Function() buildConnection,
    required FutureOr<XmppStateStore> Function(String, String) buildStateStore,
    required FutureOr<XmppDatabase> Function(String, String) buildDatabase,
    NotificationService? notificationService,
    Capability capability = const Capability(),
  }) => _instance ??= XmppService._(
    buildConnection,
    buildStateStore,
    buildDatabase,
    notificationService ?? NotificationService(),
    capability,
  );

  final Logger _xmppLogger = Logger('XmppService');
  var _stateStore = ImpatientCompleter(Completer<XmppStateStore>());
  var _database = ImpatientCompleter(Completer<XmppDatabase>());
  StreamController<void> _databaseReloadController =
      StreamController<void>.broadcast(sync: true);
  var _lifecycleEpoch = 0;
  var _activeDbOperations = 0;
  Completer<void>? _dbOperationsDrained;
  @override
  String? _databasePrefix;

  final FutureOr<XmppConnection> Function() _connectionFactory;
  final FutureOr<XmppStateStore> Function(String, String) _stateStoreFactory;
  final FutureOr<XmppDatabase> Function(String, String) _databaseFactory;
  final NotificationService _notificationService;
  final Capability _capability;
  AppLocalizations? _localizations;
  var _autoDownloadImages = true;
  var _autoDownloadVideos = false;
  var _autoDownloadDocuments = false;
  var _autoDownloadArchives = false;

  AppLocalizations get localizations =>
      _localizations ?? lookupAppLocalizations(const ui.Locale('en'));

  void updateLocalizations(AppLocalizations localizations) {
    _localizations = localizations;
  }

  bool get mamSupported => _mamSupportResolved && _mamSupported;

  String? get saltedPassword => _connection.saltedPassword;

  Stream<bool> get mamSupportStream => _mamSupportController.stream;

  @override
  bool get autoDownloadImages => _autoDownloadImages;

  @override
  bool get autoDownloadVideos => _autoDownloadVideos;

  @override
  bool get autoDownloadDocuments => _autoDownloadDocuments;

  @override
  bool get autoDownloadArchives => _autoDownloadArchives;

  @override
  void updateAttachmentAutoDownloadSettings({
    required bool imagesEnabled,
    required bool videosEnabled,
    required bool documentsEnabled,
    required bool archivesEnabled,
  }) {
    _autoDownloadImages = imagesEnabled;
    _autoDownloadVideos = videosEnabled;
    _autoDownloadDocuments = documentsEnabled;
    _autoDownloadArchives = archivesEnabled;
  }

  @override
  bool allowsAutoDownloadMetadata(FileMetadataData metadata) {
    return switch (metadata.downloadCategory) {
      FileMetadataDownloadCategory.image => _autoDownloadImages,
      FileMetadataDownloadCategory.video => _autoDownloadVideos,
      FileMetadataDownloadCategory.document => _autoDownloadDocuments,
      FileMetadataDownloadCategory.archive => _autoDownloadArchives,
    };
  }

  @override
  Stream<void> get databaseReloadStream => _databaseReloadController.stream;

  void _notifyDatabaseReloaded() {
    if (_databaseReloadController.isClosed) return;
    _databaseReloadController.add(null);
  }

  final fastTokenStorageKey = XmppStateStore.registerKey('fast_token');
  final userAgentStorageKey = XmppStateStore.registerKey('user_agent');
  final resourceStorageKey = XmppStateStore.registerKey('resource');

  StreamController<XmppOperationEvent> _xmppOperationController =
      StreamController<XmppOperationEvent>.broadcast();
  StreamController<mox.OmemoActivityEvent> _omemoActivityController =
      StreamController<mox.OmemoActivityEvent>.broadcast();
  StreamSubscription<mox.OmemoActivityEvent>? _omemoActivitySubscription;
  StreamSubscription<NetworkAvailability>? _networkAvailabilitySubscription;
  late final XmppPingController _pingController;

  @override
  XmppService get owner => this;

  @override
  Future<XmppDatabase> get database => _database.future;

  @override
  bool get isDatabaseReady => _database.isCompleted;

  @override
  bool get isStateStoreReady => _stateStore.isCompleted;

  @override
  int get lifecycleEpoch => _lifecycleEpoch;

  @override
  Stream<XmppOperationEvent> get xmppOperationStream =>
      _xmppOperationController.stream;

  @override
  void emitXmppOperation(XmppOperationEvent event) {
    if (_xmppOperationController.isClosed) return;
    if (kEnableDemoChats &&
        demoOfflineMode &&
        !_shouldAllowOperationEvent(event)) {
      return;
    }
    _handleDemoXmppOperationEvent(event);
    _xmppOperationController.add(event);
  }

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

  Future<String?> resolveNotificationPayload(String payload) async {
    final trimmed = payload.trim();
    if (trimmed.isEmpty ||
        !_notificationPayloadCodec.isPayloadLengthValid(trimmed)) {
      return null;
    }
    if (_notificationPayloadCacheReady) {
      final cached = _resolveCachedNotificationPayload(trimmed);
      if (cached != null) {
        if (await _chatExists(cached)) {
          return cached;
        }
        _invalidateNotificationPayloadCache();
      }
    }
    await _refreshNotificationPayloadCache();
    final resolved = _resolveCachedNotificationPayload(trimmed);
    if (resolved == null) {
      return null;
    }
    if (await _chatExists(resolved)) {
      return resolved;
    }
    _invalidateNotificationPayloadCache();
    return null;
  }

  String? _resolveCachedNotificationPayload(String payload) {
    final cached = _notificationPayloadCache[payload];
    if (cached != null) {
      return cached;
    }
    return _notificationPayloadLowerCache[payload.toLowerCase()];
  }

  void _invalidateNotificationPayloadCache() {
    _notificationPayloadCache.clear();
    _notificationPayloadLowerCache.clear();
    _notificationPayloadCacheReady = false;
  }

  Future<bool> _chatExists(String jid) async {
    final db = await database;
    return (await db.getChat(jid)) != null;
  }

  Future<void> _refreshNotificationPayloadCache() {
    final existing = _notificationPayloadCacheFuture;
    if (existing != null) {
      return existing;
    }
    final future = _loadNotificationPayloadCache();
    _notificationPayloadCacheFuture = future;
    return future.whenComplete(() {
      _notificationPayloadCacheFuture = null;
    });
  }

  Future<void> _loadNotificationPayloadCache() async {
    final db = await database;
    final chats = await db.getChats(
      start: _notificationPayloadLookupStart,
      end: _notificationPayloadLookupEnd,
    );
    final chatJids = chats.map((chat) => chat.jid);
    _buildNotificationPayloadCache(chatJids);
  }

  void _buildNotificationPayloadCache(Iterable<String> chatJids) {
    _notificationPayloadCache
      ..clear()
      ..addEntries(
        chatJids.map((jid) {
          final encoded = _notificationPayloadCodec.encodeChatJid(jid);
          if (encoded == null) {
            return null;
          }
          return MapEntry(encoded, jid);
        }).whereType<MapEntry<String, String>>(),
      );
    _notificationPayloadLowerCache
      ..clear()
      ..addEntries(
        chatJids.map((jid) {
          final normalized = jid.trim();
          if (normalized.isEmpty) {
            return null;
          }
          return MapEntry(normalized.toLowerCase(), normalized);
        }).whereType<MapEntry<String, String>>(),
      );
    _notificationPayloadCacheReady = true;
  }

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    manager.registerHandler<mox.ConnectionStateChangedEvent>((event) async {
      _setConnectionState(event.state);
    });
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<XmppOperationEvent>((event) async {
        emitXmppOperation(event);
      })
      ..registerHandler<mox.StanzaAckedEvent>((event) async {
        if (event.stanza.id == null) return;
        await _dbOp<XmppDatabase>(
          (db) => db.markMessageAcked(event.stanza.id!),
        );
      })
      ..registerHandler<mox.ResourceBoundEvent>((event) async {
        _xmppLogger.info('Bound resource: ${event.resource}...');
        final currentJid = _myJid;
        if (currentJid != null) {
          final boundJid = currentJid.toBare().withResource(event.resource);
          _myJid = boundJid;
          if (_connection.hasConnectionSettings) {
            final settings = _connection.connectionSettings;
            _connection.connectionSettings = XmppConnectionSettings(
              jid: boundJid,
              password: settings.password,
            );
          }
        }

        await _dbOp<XmppStateStore>(
          (ss) => ss.write(key: resourceStorageKey, value: event.resource),
        );
      })
      ..registerHandler<mox.NewFASTTokenReceivedEvent>((event) async {
        _xmppLogger.fine('Saving FAST token.');
        await _dbOp<XmppStateStore>(
          (ss) => ss.write(key: fastTokenStorageKey, value: event.token.token),
        );
        _xmppLogger.fine('FAST token persisted.');
      })
      ..registerHandler<mox.NonRecoverableErrorEvent>((event) async {
        if (event.error is mox.StreamUndefinedConditionError) {
          final sm = _connection.getManager<XmppStreamManagementManager>();
          await sm?.resetState();
          await sm?.clearPersistedState();
          _reconnectBlocked = false;
          await _connection.setShouldReconnect(true);
          if (await _connection.reconnectionPolicy.canTriggerFailure()) {
            await _connection.reconnectionPolicy.onFailure();
          }
          return;
        }

        _reconnectBlocked = true;
        _sessionReconnectEnabled = false;
        try {
          await _connection.setShouldReconnect(false);
        } catch (error, stackTrace) {
          _xmppLogger.fine(
            _nonRecoverableReconnectDisableLog,
            error,
            stackTrace,
          );
        }
      });
  }

  @override
  List<mox.XmppManagerBase> get featureManagers {
    final managers = super.featureManagers
      ..addAll([
        XmppStreamManagementManager(owner: this),
        (mox.DiscoManager([
          mox.Identity(
            category: 'client',
            type: _capability.discoClient,
            name: appDisplayName,
          ),
        ])..addFeatures(discoFeatures)),
        XmppKeepAliveManager(),
        _AxiEntityCapabilitiesManager(
          _capabilityHashBase,
          shouldIgnoreJid: _shouldIgnoreEntityCapabilityJid,
        ),
        mox.CSIManager(),
        mox.StableIdManager(),
        mox.CryptographicHashManager(),
        mox.OccupantIdManager(),
        MucJoinBootstrapManager(),
      ]);

    return managers;
  }

  bool _shouldIgnoreEntityCapabilityJid(mox.JID jid) {
    if (jid.resource.isNotEmpty) {
      final local = jid.local.trim();
      if (local.isNotEmpty) {
        final jidDomain = jid.domain.trim().toLowerCase();
        final accountDomain = _myJid?.domain.trim().toLowerCase();
        if (accountDomain != null &&
            accountDomain.isNotEmpty &&
            jidDomain == accountDomain) {
          return true;
        }
        if (jidDomain == EndpointConfig.defaultDomain.trim().toLowerCase()) {
          return true;
        }
      }
      return false;
    }
    return _normalizeSupportedMucServiceHost(jid.domain) != null;
  }

  @override
  String? get username => _myJid?.local;

  @override
  String? get resource => _myJid?.resource;

  String? get boundResource => _connection.hasConnectionSettings
      ? _connection.connectionSettings.jid.resource
      : null;

  bool get connected => connectionState == mox.XmppConnectionState.connected;

  bool get hasConnectionSettings => _connection.hasConnectionSettings;

  bool get databasesInitialized =>
      _stateStore.isCompleted && _database.isCompleted;

  bool get hasInMemoryReconnectContext =>
      _sessionReconnectEnabled &&
      !_reconnectBlocked &&
      _synchronousConnection.isCompleted &&
      hasConnectionSettings &&
      databasesInitialized;

  BookmarksManager? get bookmarksManager =>
      _connection.getManager<BookmarksManager>();

  ConversationIndexManager? get conversationIndexManager =>
      _connection.getManager<ConversationIndexManager>();

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
  StreamController<ConnectionState> _connectivityStream =
      StreamController<ConnectionState>.broadcast();
  Completer<void> _streamNegotiationsDone = Completer<void>();
  _XmppBootstrapPass? _activeBootstrapPass;
  final LinkedHashMap<Object, XmppBootstrapOperation> _bootstrapOperations =
      LinkedHashMap<Object, XmppBootstrapOperation>();

  static const _connectivityNotificationUpdateOperationName =
      'XmppService.updateConnectivityNotification';
  static const _nonRecoverableReconnectDisableLog =
      'Failed to disable reconnection after non-recoverable error.';
  static const _reconnectEnableFailedLog =
      'Failed to enable reconnection before requesting reconnect.';

  void _setConnectionState(ConnectionState state) {
    if (_connectionState == state) {
      return;
    }

    _connectionState = state;
    if (state == ConnectionState.connected ||
        state == ConnectionState.notConnected ||
        state == ConnectionState.error) {
      if (_lifecycleResumeReconnectOwned) {
        _xmppLogger.info(
          'Clearing lifecycle-resume reconnect ownership at state=$state.',
        );
      }
      _lifecycleResumeReconnectOwned = false;
    }
    if (!_connectivityStream.isClosed) {
      _connectivityStream.add(state);
    }

    if (state != ConnectionState.connected) {
      _clearMamNegotiationState();
      _clearSelfAvatarNegotiationState();
      _activeBootstrapPass = null;
      if (_streamNegotiationsDone.isCompleted) {
        _streamNegotiationsDone = Completer<void>();
      }
    }

    if (withForeground) {
      _scheduleConnectivityNotificationUpdate(state);
    }
    _pingController.handleConnectionState(state);
    _emitSelfAvatarHydrating();
  }

  void _scheduleConnectivityNotificationUpdate(ConnectionState state) {
    fireAndForget(() async {
      try {
        await _connection.updateConnectivityNotification(state);
      } catch (error, stackTrace) {
        _xmppLogger.fine(_connectivityNotificationFailedLog, error, stackTrace);
      }
    }, operationName: _connectivityNotificationUpdateOperationName);
  }

  Future<void> _handleXmppEvent(mox.XmppEvent event) async {
    try {
      final manager = _eventManager;
      if (event is mox.StreamNegotiationsDoneEvent) {
        await _handleRootStreamNegotiationsDone(event);
        await manager.executeHandlers(event);
        return;
      }
      await manager.executeHandlers(event);
    } catch (error, stackTrace) {
      _xmppLogger.warning(
        'Unhandled XMPP event handler error for ${event.runtimeType}: ${error.runtimeType}.',
        error.runtimeType,
        stackTrace,
      );
    }
  }

  Future<void> _handleRootStreamNegotiationsDone(
    mox.StreamNegotiationsDoneEvent event,
  ) async {
    _hasMamNegotiatedStream = true;
    _mamNegotiationResumed = event.resumed;
    _mamGlobalSyncCompletedSinceConnect = false;
    _outboundPinMutationsByStanzaId.clear();
    try {
      if (_connection.carbonsEnabled != true) {
        _xmppLogger.info('Enabling carbons...');
        if (!await _connection.enableCarbons()) {
          _xmppLogger.warning('Failed to enable carbons.');
        }
      }
    } on Exception catch (error, stackTrace) {
      _xmppLogger.warning('Failed to enable carbons.', error, stackTrace);
    }
    final pass = _XmppBootstrapPass();
    _activeBootstrapPass = pass;
    unawaited(
      _runBootstrapOperations(
        event.resumed
            ? XmppBootstrapTrigger.resumedNegotiation
            : XmppBootstrapTrigger.fullNegotiation,
        pass: pass,
      ),
    );
    if (!_streamNegotiationsDone.isCompleted) {
      _streamNegotiationsDone.complete();
    }
    // Connection handling is automatic in moxxmpp v0.5.0.
  }

  @override
  void resetBootstrapOperations() {
    _bootstrapOperations.clear();
    _activeBootstrapPass = null;
  }

  @override
  void registerBootstrapOperation(XmppBootstrapOperation operation) {
    final existing = _bootstrapOperations[operation.key];
    if (existing != null) {
      throw StateError(
        'Duplicate XMPP bootstrap operation key: ${operation.key}',
      );
    }
    _bootstrapOperations[operation.key] = operation;
  }

  @override
  Future<void> runBootstrapOperations(XmppBootstrapTrigger trigger) async {
    await _runBootstrapOperations(trigger);
  }

  Future<void> _runBootstrapOperations(
    XmppBootstrapTrigger trigger, {
    _XmppBootstrapPass? pass,
  }) async {
    final operations =
        _bootstrapOperations.values
            .where((operation) => operation.triggers.contains(trigger))
            .toList(growable: false)
          ..sort((left, right) => left.priority.compareTo(right.priority));
    final activePass = pass ?? _activeBootstrapPass ?? _XmppBootstrapPass();
    _activeBootstrapPass ??= activePass;
    if (operations.isEmpty) {
      if (identical(_activeBootstrapPass, activePass) &&
          activePass.tasks.isEmpty) {
        _activeBootstrapPass = null;
      }
      return;
    }
    activePass.queuedRuns++;
    final scheduled = activePass.scheduler
        .then((_) async {
          var index = 0;
          while (index < operations.length) {
            final priority = operations[index].priority;
            final futures = <Future<void>>[];
            while (index < operations.length &&
                operations[index].priority == priority) {
              futures.add(
                _startBootstrapOperationIfAllowed(
                  activePass,
                  operations[index],
                ),
              );
              index++;
            }
            await Future.wait<void>(
              futures.map(
                (future) => future.catchError(
                  (Object _, StackTrace _) {},
                  test: (Object error) => error is Exception,
                ),
              ),
            );
          }
        })
        .whenComplete(() {
          activePass.queuedRuns--;
          _maybeClearActiveBootstrapPass(activePass);
        });
    activePass.scheduler = scheduled.catchError(
      (Object _, StackTrace _) {},
      test: (Object error) => error is Exception,
    );
    await scheduled;
  }

  Future<void> _startBootstrapOperationIfAllowed(
    _XmppBootstrapPass pass,
    XmppBootstrapOperation operation,
  ) {
    final completed = pass.completedOperations[operation.key];
    if (completed == _XmppBootstrapOperationOutcome.success ||
        completed == _XmppBootstrapOperationOutcome.aborted) {
      return Future<void>.value();
    }
    if (!_canRunBootstrapOperation(pass, operation)) {
      _recordBootstrapOutcome(
        pass: pass,
        operation: operation,
        outcome: _XmppBootstrapOperationOutcome.skipped,
      );
      _xmppLogger.fine(
        '${operation.operationName} skipped due to unmet lane prerequisites.',
      );
      return Future<void>.value();
    }
    return _startBootstrapOperation(pass, operation);
  }

  bool _canRunBootstrapOperation(
    _XmppBootstrapPass pass,
    XmppBootstrapOperation operation,
  ) {
    final lane = operation.lane;
    if (lane == null) {
      return true;
    }
    final lowerPriorities = _bootstrapOperations.values
        .where(
          (candidate) =>
              candidate.lane == lane && candidate.priority < operation.priority,
        )
        .map((candidate) => candidate.priority)
        .toSet();
    if (lowerPriorities.isEmpty) {
      return true;
    }
    final outcomes = pass.laneOutcomes[lane];
    if (outcomes == null) {
      return false;
    }
    for (final priority in lowerPriorities) {
      if (outcomes[priority] != _XmppBootstrapOperationOutcome.success) {
        return false;
      }
    }
    return true;
  }

  void _recordBootstrapOutcome({
    required _XmppBootstrapPass pass,
    required XmppBootstrapOperation operation,
    required _XmppBootstrapOperationOutcome outcome,
  }) {
    pass.completedOperations[operation.key] = outcome;
    final lane = operation.lane;
    if (lane == null) {
      return;
    }
    final laneOutcomes = pass.laneOutcomes.putIfAbsent(
      lane,
      () => <int, _XmppBootstrapOperationOutcome>{},
    );
    laneOutcomes[operation.priority] = outcome;
  }

  void _maybeClearActiveBootstrapPass(_XmppBootstrapPass pass) {
    if (!identical(_activeBootstrapPass, pass)) {
      return;
    }
    if (pass.tasks.isNotEmpty || pass.queuedRuns > 0) {
      return;
    }
    _activeBootstrapPass = null;
  }

  Future<void> _startBootstrapOperation(
    _XmppBootstrapPass pass,
    XmppBootstrapOperation operation,
  ) {
    final existing = pass.tasks[operation.key];
    if (existing != null) {
      return existing;
    }
    late final Future<void> future;
    future = Future<void>.microtask(() async {
      try {
        await operation.run();
        _recordBootstrapOutcome(
          pass: pass,
          operation: operation,
          outcome: _XmppBootstrapOperationOutcome.success,
        );
      } on XmppAbortedException {
        _recordBootstrapOutcome(
          pass: pass,
          operation: operation,
          outcome: _XmppBootstrapOperationOutcome.aborted,
        );
        _xmppLogger.fine('${operation.operationName} aborted.');
        rethrow;
      } on Exception catch (error, stackTrace) {
        _recordBootstrapOutcome(
          pass: pass,
          operation: operation,
          outcome: _XmppBootstrapOperationOutcome.failed,
        );
        _xmppLogger.fine(
          '${operation.operationName} failed.',
          error,
          stackTrace,
        );
        rethrow;
      } finally {
        final current = pass.tasks[operation.key];
        if (identical(current, future)) {
          pass.tasks.remove(operation.key);
        }
        _maybeClearActiveBootstrapPass(pass);
      }
    });
    pass.tasks[operation.key] = future;
    return future;
  }

  var _synchronousConnection = Completer<void>();
  bool _sessionReconnectEnabled = false;
  bool _connectInFlight = false;
  bool _reconnectBlocked = false;
  bool _lifecycleResumeReconnectOwned = false;
  var _foregroundServiceNotificationSent = false;
  var _connectionPasswordPreHashed = false;
  final Set<int> _timeoutErrorCodes = {60, 110, 10060};
  final int _staleConnectionTimeoutThreshold = 3;
  var _consecutiveConnectTimeouts = 0;
  DateTime? _lastForegroundSocketMigrationAttempt;
  Timer? _foregroundSocketMigrationTimer;
  var _nextReconnectRequestId = 0;
  var _nextForegroundMigrationAttemptId = 0;
  var _demoSeedAttempted = false;
  var _demoOfflineMode = false;

  Future<String> _reconnectStateSummary() async {
    final bool policyReconnecting = await _connection.isReconnecting();
    final bool policyShouldReconnect = await _connection.reconnectionPolicy
        .getShouldReconnect();
    final AppLifecycleState? lifecycleState =
        SchedulerBinding.instance.lifecycleState;
    return 'connectionState=$connectionState '
        'sessionReconnectEnabled=$_sessionReconnectEnabled '
        'reconnectBlocked=$_reconnectBlocked '
        'connectInFlight=$_connectInFlight '
        'lifecycleOwned=$_lifecycleResumeReconnectOwned '
        'policyReconnecting=$policyReconnecting '
        'policyShouldReconnect=$policyShouldReconnect '
        'lifecycle=$lifecycleState '
        'hasSettings=${_connection.hasConnectionSettings}';
  }

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
    _reconnectBlocked = false;
    _ensureNetworkAvailabilityListener();
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

          if (!_foregroundServiceNotificationSent) {
            try {
              await _notificationService
                  .sendBackgroundConnectionDisabledNotification();
            } catch (error, stackTrace) {
              _xmppLogger.warning(
                _foregroundNotificationFailedLog,
                error,
                stackTrace,
              );
            }
            _foregroundServiceNotificationSent = true;
          }

          final saltedPassword = await _establishConnection(
            connectionOverride: XmppConnection(),
            jid: jid,
            password: password,
            databasePrefix: databasePrefix,
            databasePassphrase: databasePassphrase,
            preHashed: preHashed,
            endpoint: endpoint,
          );
          _scheduleForegroundSocketMigration();
          return saltedPassword;
        }
      },
    );
  }

  static const _foregroundSocketMigrationDelay = Duration(seconds: 3);
  static const _foregroundSocketMigrationCooldown = Duration(seconds: 30);
  static const _foregroundSocketWarmupClientId =
      '${foregroundClientXmpp}_warmup';
  static const String _foregroundNotificationFailedLog =
      'Failed to send foreground migration notification.';
  static const String _foregroundMigrationFailedLog =
      'Foreground socket migration failed.';
  static const String _connectivityNotificationFailedLog =
      'Failed to update connectivity notification.';

  String _socketWrapperLabel([XmppConnection? connection]) {
    final socketWrapper = (connection ?? _connection).socketWrapper;
    if (socketWrapper is ForegroundSocketWrapper) {
      return 'foreground';
    }
    return socketWrapper.runtimeType.toString();
  }

  String _foregroundMigrationStateSummary({
    AppLifecycleState? lifecycleState,
    XmppConnection? connection,
  }) {
    final lifecycle =
        lifecycleState ?? SchedulerBinding.instance.lifecycleState;
    return 'socket=${_socketWrapperLabel(connection)} '
        'serviceActive=${foregroundServiceActive.value} '
        'connectionState=$connectionState '
        'lifecycle=$lifecycle '
        'sessionReconnectEnabled=$_sessionReconnectEnabled '
        'connectInFlight=$_connectInFlight '
        'reconnectBlocked=$_reconnectBlocked '
        'hasSettings=${_connection.hasConnectionSettings} '
        'messageSubscription=${_messageSubscription != null}';
  }

  void _logForegroundMigrationSkip(
    String reason, {
    AppLifecycleState? lifecycleState,
  }) {
    _xmppLogger.fine(
      'Skipping foreground socket migration: $reason. '
      '${_foregroundMigrationStateSummary(lifecycleState: lifecycleState)}',
    );
  }

  void _scheduleForegroundSocketMigration() {
    if (!withForeground) {
      _xmppLogger.fine(
        'Not scheduling foreground socket migration because withForeground is false.',
      );
      return;
    }
    if (!foregroundServiceActive.value) {
      _xmppLogger.fine(
        'Not scheduling foreground socket migration because foreground service is inactive.',
      );
      return;
    }
    final int migrationAttemptId = ++_nextForegroundMigrationAttemptId;
    _xmppLogger.info(
      'Scheduling foreground socket migration: attemptId=$migrationAttemptId '
      'delay=${_foregroundSocketMigrationDelay.inSeconds}s. '
      '${_foregroundMigrationStateSummary()}',
    );
    _foregroundSocketMigrationTimer?.cancel();
    _foregroundSocketMigrationTimer = Timer(
      _foregroundSocketMigrationDelay,
      () {
        _runForegroundSocketMigration(migrationAttemptId);
      },
    );
  }

  Future<void> _runForegroundSocketMigration(int migrationAttemptId) async {
    _foregroundSocketMigrationTimer = null;
    _xmppLogger.info(
      'Running scheduled foreground socket migration: '
      'attemptId=$migrationAttemptId. '
      '${_foregroundMigrationStateSummary()}',
    );
    try {
      await ensureForegroundSocketIfActive();
    } catch (error, stackTrace) {
      _xmppLogger.fine(_foregroundMigrationFailedLog, error, stackTrace);
    }
  }

  @override
  Future<void> resumeOfflineSession({
    required String jid,
    required String databasePrefix,
    required String databasePassphrase,
  }) async {
    _databasePrefix = databasePrefix;
    _reconnectBlocked = false;
    _ensureNetworkAvailabilityListener();
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
    _setConnection(await _connectionFactory());
    _configureSocketCallbacks();
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
    _notifyDatabaseReloaded();
    await _initializeAvatarEncryption(databasePassphrase);
    _demoOfflineMode = kEnableDemoChats && jid == kDemoSelfJid;
    _setConnectionState(ConnectionState.notConnected);
    await _seedDemoChatsIfNeeded();
  }

  Future<String?> _establishConnection({
    XmppConnection? connectionOverride,
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

    _connectionPasswordPreHashed = preHashed;
    _setConnection(connectionOverride ?? await _connectionFactory());
    _configureSocketCallbacks();
    _omemoActivitySubscription?.cancel();
    _omemoActivitySubscription = _connection.omemoActivityStream.listen(
      _omemoActivityController.add,
    );

    if (!_stateStore.isCompleted) {
      _stateStore.complete(
        await _stateStoreFactory(databasePrefix, databasePassphrase),
      );
    }

    _myJid = mox.JID.fromString(jid);
    final bareDomain = _myJid?.domain.trim();
    if (bareDomain != null && bareDomain.isNotEmpty && endpoint != null) {
      serverLookup[bareDomain] = IOEndpoint(endpoint.host, endpoint.port);
    }

    await _initConnection(preHashed: preHashed);

    await _eventSubscription?.cancel();
    _eventSubscription = _connection.asBroadcastStream().listen(
      _handleXmppEvent,
    );

    _connection.connectionSettings = XmppConnectionSettings(
      jid: _myJid!.toBare(),
      password: password,
    );

    _connectInFlight = true;
    late final moxlib.Result<bool, mox.XmppError> result;
    try {
      result = await _connection.connect(
        shouldReconnect: false,
        waitForConnection: true,
        waitUntilLogin: true,
      );
    } finally {
      _connectInFlight = false;
    }

    if (result.isType<mox.XmppError>()) {
      final error = result.get<mox.XmppError>();
      _xmppLogger.info('Login failed with error: $error');
      if (_isAuthenticationError(error)) {
        throw XmppAuthenticationException(error is Exception ? error : null);
      }
      throw XmppNetworkException(error is Exception ? error : null);
    }
    if (!result.get<bool>()) {
      _xmppLogger.info('Login rejected by server.');
      throw XmppAuthenticationException();
    }

    await _connection.setShouldReconnect(true);
    _sessionReconnectEnabled = true;

    await _messageSubscription?.cancel();
    _messageSubscription = _messageStream.stream.listen((message) async {
      if (_consumeSuppressedNotificationForMessage(message) ||
          message.displayed) {
        return;
      }
      final chat = await _dbOpReturning<XmppDatabase, Chat?>(
        (db) async => db.getChat(message.chatJid),
      );
      if (chat?.muted ?? false) {
        return;
      }
      final previewSetting = chat?.notificationPreviewSetting;
      final showPreview = NotificationPreviewSetting.resolveOverride(
        previewSetting,
        _notificationService.notificationPreviewsEnabled,
      );
      final threadKey =
          _notificationPayloadCodec.encodeChatJid(message.chatJid) ??
          message.chatJid.trim();
      if (threadKey.isEmpty) {
        return;
      }
      final isGroupConversation = chat?.type == ChatType.groupChat;
      await _notificationService.sendMessageNotification(
        title: chat?.displayName ?? message.senderJid,
        body: message.body,
        senderName: _notificationSenderName(chat: chat, message: message),
        senderKey: message.senderJid,
        conversationTitle: _notificationConversationTitle(
          chat: chat,
          message: message,
        ),
        sentAt: message.timestamp,
        isGroupConversation: isGroupConversation,
        extraConditions: [message.senderJid != myJid],
        payload: threadKey,
        threadKey: threadKey,
        showPreviewOverride: showPreview,
        channel: MessageNotificationChannel.chat,
      );
    });

    fireAndForget(
      _resolveMamSupportForAccount,
      operationName: 'XmppService.resolveMamSupportForAccount',
    );
    _xmppLogger.info('Login successful. Initializing databases...');
    await _initDatabases(databasePrefix, databasePassphrase);
    fireAndForget(
      _verifyMamSupportOnLogin,
      operationName: 'XmppService.verifyMamSupportOnLogin',
    );

    return _connection.saltedPassword;
  }

  String _notificationConversationTitle({
    required Chat? chat,
    required Message message,
  }) {
    final displayName = chat?.displayName.trim();
    if (displayName?.isNotEmpty == true) {
      return displayName!;
    }
    return _notificationAddressLabel(message.chatJid);
  }

  String _notificationSenderName({
    required Chat? chat,
    required Message message,
  }) {
    if (chat?.type == ChatType.groupChat) {
      final nick = _nickFromSender(message.senderJid)?.trim();
      if (nick?.isNotEmpty == true) {
        return nick!;
      }
    }
    if (chat?.type == ChatType.chat) {
      final displayName = chat?.displayName.trim();
      if (displayName?.isNotEmpty == true) {
        return displayName!;
      }
    }
    return _notificationAddressLabel(message.senderJid);
  }

  String _notificationAddressLabel(String address) {
    final label = addressDisplayLabel(address)?.trim();
    if (label?.isNotEmpty == true) {
      return label!;
    }
    final safeAddress = address.displaySafeJid?.trim();
    if (safeAddress?.isNotEmpty == true) {
      return safeAddress!;
    }
    return address.trim();
  }

  String? _nickFromSender(String senderJid) {
    return addressResourcePart(senderJid);
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

  Future<void> _initConnection({bool preHashed = false}) async {
    _xmppLogger.info('Initializing connection object...');
    final storedResource = await _dbOpReturning<XmppStateStore, String?>(
      (ss) async => ss.read(key: resourceStorageKey) as String?,
    );
    final storedMucServiceHost = await _dbOpReturning<XmppStateStore, String?>(
      (ss) async => ss.read(key: _mucServiceHostStorageKey) as String?,
    );
    _restoreMucServiceHost(storedMucServiceHost);
    final smNegotiator = mox.StreamManagementNegotiator();
    if (storedResource != null && storedResource.isNotEmpty) {
      smNegotiator.resource = storedResource;
    }
    final featureNegotiators = <mox.XmppFeatureNegotiatorBase>[
      XmppTlsRequirementNegotiator(),
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
    _connection
        .getManager<mox.MessageManager>()
        ?.registerMessageSendingCallback(
          messageDeliveryReceiptRequestSendingCallback,
        );
    await _prepareMucRoomsFromStateStore();

    if (_enableStreamManagement) {
      final sm = _connection.getManager<XmppStreamManagementManager>();
      if (sm != null && await sm.hasPersistedState()) {
        await _connection.loadStreamState();
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
        ..setUserAgent(
          mox.UserAgent(software: appDisplayName, id: userAgentId),
        );
    });
  }

  Future<XmppDatabase> _buildDatabase(String prefix, String passphrase) async {
    if (kEnableDemoChats) {
      final useSqlCipher = Platform.isAndroid;
      if (!useSqlCipher) {
        return XmppDrift.inMemory();
      }
      return _databaseFactory(prefix, passphrase);
    }
    return _databaseFactory(prefix, passphrase);
  }

  Future<void> _initDatabases(String prefix, String passphrase) async {
    await deferToError(
      defer: _reset,
      operation: () async {
        try {
          _xmppLogger.info('Opening databases...');
          if (!_stateStore.isCompleted) {
            _stateStore.complete(await _stateStoreFactory(prefix, passphrase));
          }
          if (!_database.isCompleted) {
            _database.complete(await _buildDatabase(prefix, passphrase));
          }
          _notifyDatabaseReloaded();
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
      final scripts = DemoChats.scripts();
      await _dbOp<XmppDatabase>((db) async {
        for (final script in scripts) {
          final existingChat = await db.getChat(script.chat.jid);
          if (existingChat != null) {
            var updated = existingChat;
            if (existingChat.jid == 'eliot@gmail.com') {
              updated = updated.copyWith(
                title: script.chat.title,
                contactDisplayName: script.chat.contactDisplayName,
                emailAddress: script.chat.emailAddress,
              );
            }
            if (script.chat.defaultTransport.isEmail &&
                !updated.defaultTransport.isEmail) {
              updated = updated.copyWith(
                transport: MessageTransport.email,
                emailAddress: script.chat.emailAddress,
              );
            }
            final latestSeededMessage = await _seedDemoMessagesForChat(
              db: db,
              script: script,
            );
            final latestSeededTimestamp = latestSeededMessage?.timestamp;
            if (latestSeededTimestamp != null &&
                updated.lastChangeTimestamp.isBefore(latestSeededTimestamp)) {
              updated = updated.copyWith(
                lastChangeTimestamp: latestSeededTimestamp,
                lastMessage: latestSeededMessage?.body,
              );
            }
            if (updated != existingChat) {
              await db.updateChat(updated);
            }
            continue;
          }
          await _seedDemoChat(db: db, script: script);
        }
      }, awaitDatabase: true);
      _seedDemoRoomOccupants(scripts);
      await _seedDemoReactions(scripts);
      await _seedDemoAvatars(scripts);
      await _seedDemoAttachmentMessages(scripts);
      await _seedDemoPinnedMessages(scripts);
    } on Exception catch (error, stackTrace) {
      _xmppLogger.fine('Skipping demo chat seed', error, stackTrace);
    }
  }

  Future<void> _seedDemoChat({
    required XmppDatabase db,
    required DemoChatScript script,
  }) async {
    final chat = script.chat;
    await db.createChat(chat);
    for (final attachment in script.attachments) {
      final seeded = await _seedDemoAttachment(attachment);
      if (seeded != null) {
        await db.saveFileMetadata(seeded);
      }
    }
    final latestMessage = await _seedDemoMessagesForChat(
      db: db,
      script: script,
    );
    if (latestMessage != null) {
      await db.updateChat(
        chat.copyWith(
          unreadCount: 0,
          lastChangeTimestamp:
              latestMessage.timestamp ?? chat.lastChangeTimestamp,
          lastMessage: latestMessage.body,
        ),
      );
    }
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

  Future<Message?> _seedDemoMessagesForChat({
    required XmppDatabase db,
    required DemoChatScript script,
  }) async {
    final messages = script.messages;
    if (messages.isEmpty) {
      return null;
    }
    Message latest = messages.first;
    for (final message in messages) {
      final existing = await db.getMessageByStanzaID(message.stanzaID);
      if (existing == null) {
        await db.saveMessage(message, chatType: script.chat.type);
      } else {
        final existingId = existing.id;
        if (existingId != null) {
          final seeded = message.copyWith(id: existingId);
          if (existing != seeded) {
            await db.updateMessage(seeded);
          }
        }
      }
      final latestTimestamp = latest.timestamp;
      final messageTimestamp = message.timestamp;
      if (latestTimestamp == null) {
        latest = message;
        continue;
      }
      if (messageTimestamp == null) {
        continue;
      }
      if (messageTimestamp.isAfter(latestTimestamp)) {
        latest = message;
      }
    }
    return latest;
  }

  Future<FileMetadataData?> _seedDemoAttachment(
    DemoAttachmentAsset attachment,
  ) async {
    final materialized = await materializeDemoAsset(
      assetPath: attachment.assetPath,
      fileName: attachment.fileName,
    );
    if (materialized == null) return null;
    return FileMetadataData(
      id: attachment.id,
      filename: attachment.fileName,
      path: materialized.path,
      mimeType: attachment.mimeType,
      sizeBytes: materialized.sizeBytes,
      width: materialized.width,
      height: materialized.height,
    );
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
  static const _demoReactionMind = '🧠';
  static const _demoReactionClap = '👏';

  static const _demoFranklinReactionSets = <List<String>>[
    <String>[_demoReactionThumbsUp],
    <String>[_demoReactionFire],
    <String>[_demoReactionLaugh],
    <String>[_demoReactionFire],
    <String>[_demoReactionThumbsUp, _demoReactionHeart],
    <String>[_demoReactionLaugh, _demoReactionFire],
  ];

  static const _demoFounderBareJids = <String>[
    kDemoSelfJid,
    'george@axi.im',
    'thomas@axi.im',
    'john@axi.im',
    'james@axi.im',
    'alex@axi.im',
  ];

  Future<void> _seedDemoReactions(List<DemoChatScript> scripts) async {
    if (!_demoOfflineMode) return;
    await _dbOp<XmppDatabase>((db) async {
      final updatedAt = DateTime.timestamp().toUtc();
      for (final script in scripts) {
        final chat = script.chat;
        final messages = script.messages;

        if (chat.defaultTransport.isEmail) {
          for (final message in messages) {
            await db.replaceReactions(
              messageId: message.stanzaID,
              senderJid: kDemoSelfJid,
              emojis: const [],
              updatedAt: updatedAt,
              identityVerified: true,
            );
            await db.replaceReactions(
              messageId: message.stanzaID,
              senderJid: chat.jid,
              emojis: const [],
              updatedAt: updatedAt,
              identityVerified: true,
            );
          }
          continue;
        }

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
                    (_nickFromSender(message.senderJid) ?? '').toLowerCase() ==
                    'ben',
              )
              .firstOrNull;
          if (franklinMessage != null &&
              !hasReactionsForMessage(franklinMessage.stanzaID)) {
            const reactors = _demoFounderBareJids;
            final reactionCount = math.min(reactors.length, 2);
            for (var i = 0; i < reactionCount; i += 1) {
              await db.replaceReactions(
                messageId: franklinMessage.stanzaID,
                senderJid: reactors[i],
                emojis: _demoFranklinReactionSets[i],
                updatedAt: updatedAt,
                identityVerified: true,
              );
            }
          }

          final groupBannerMessage = messages
              .where((message) => message.stanzaID == 'demo-group-banner-1')
              .firstOrNull;
          if (groupBannerMessage != null &&
              !hasReactionsForMessage(groupBannerMessage.stanzaID)) {
            await db.replaceReactions(
              messageId: groupBannerMessage.stanzaID,
              senderJid: kDemoSelfJid,
              emojis: const [_demoReactionThumbsUp, _demoReactionHeart],
              updatedAt: updatedAt,
              identityVerified: true,
            );
          }

          final madisonMessages = messages.where(
            (message) =>
                (_nickFromSender(message.senderJid) ?? '').toLowerCase() ==
                'james',
          );
          final madisonSecondMessage = madisonMessages.length >= 2
              ? madisonMessages.elementAt(1)
              : null;
          if (madisonSecondMessage != null &&
              !hasReactionsForMessage(madisonSecondMessage.stanzaID)) {
            await db.replaceReactions(
              messageId: madisonSecondMessage.stanzaID,
              senderJid: kDemoSelfJid,
              emojis: const [_demoReactionThumbsUp, _demoReactionMind],
              updatedAt: updatedAt,
              identityVerified: true,
            );
            await db.replaceReactions(
              messageId: madisonSecondMessage.stanzaID,
              senderJid: 'george@axi.im',
              emojis: const [_demoReactionClap],
              updatedAt: updatedAt,
              identityVerified: true,
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
          updatedAt: updatedAt,
          identityVerified: true,
        );
      }
    }, awaitDatabase: true);
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
      await _seedDemoAvatarForJid(jid: script.chat.jid, avatar: avatar);
    }
    final selfAvatar = avatarAssets[kDemoSelfJid];
    if (selfAvatar != null) {
      await _seedDemoAvatarForJid(jid: kDemoSelfJid, avatar: selfAvatar);
    }
  }

  static const ui.Color _demoWashingtonBackground = ui.Color(0xFF0A84FF);
  static const ui.Color _demoJeffersonBackground = ui.Color(0xFFFFD60A);
  static const ui.Color _demoAdamsBackground = ui.Color(0xFFFF3B30);
  static const ui.Color _demoMadisonBackground = ui.Color(0xFF34C759);
  static const ui.Color _demoHamiltonBackground = ui.Color(0xFFAF52DE);
  static const ui.Color _demoFranklinBackground = ui.Color(0xFFFFFFFF);

  Future<({String path, int sizeBytes, int? width, int? height})?>
  materializeDemoAsset({
    required String assetPath,
    required String fileName,
  }) async {
    if (!kEnableDemoChats) return null;
    try {
      final baseDir = await getApplicationSupportDirectory();
      final demoDir = Directory(p.join(baseDir.path, 'demo_attachments'));
      if (!await demoDir.exists()) {
        await demoDir.create(recursive: true);
      }
      final filePath = p.join(demoDir.path, fileName);
      final file = File(filePath);
      Uint8List data;
      if (await file.exists()) {
        data = await file.readAsBytes();
      } else {
        final bytes = await rootBundle.load(assetPath);
        data = bytes.buffer.asUint8List();
        await file.writeAsBytes(data, flush: true);
      }
      if (data.isEmpty) return null;
      img.Image? decoded;
      try {
        decoded = img.decodeImage(data);
      } on Exception catch (_) {
        decoded = null;
      }
      return (
        path: filePath,
        sizeBytes: data.length,
        width: decoded?.width,
        height: decoded?.height,
      );
    } on Exception catch (error, stackTrace) {
      _xmppLogger.fine(
        'Failed to materialize demo asset $assetPath',
        error,
        stackTrace,
      );
      return null;
    }
  }

  Future<void> _seedDemoAttachmentMessages(List<DemoChatScript> scripts) async {
    if (!kEnableDemoChats) return;
    await _dbOp<XmppDatabase>((db) async {
      for (final script in scripts) {
        if (script.attachments.isEmpty) continue;
        for (final attachment in script.attachments) {
          FileMetadataData? metadata = await db.getFileMetadata(attachment.id);
          metadata ??= await _seedDemoAttachment(attachment);
          if (metadata != null) {
            await db.saveFileMetadata(metadata);
          }
          final messageWithAttachment = script.messages.firstWhere(
            (message) => message.fileMetadataID == attachment.id,
            orElse: () =>
                const Message(stanzaID: '', senderJid: '', chatJid: ''),
          );
          if (messageWithAttachment.stanzaID.isEmpty) continue;
          final existing = await db.getMessageByStanzaID(
            messageWithAttachment.stanzaID,
          );
          if (existing != null) continue;
          await db.saveMessage(
            messageWithAttachment,
            chatType: script.chat.type,
          );
        }
      }
    }, awaitDatabase: true);
  }

  Future<void> _seedDemoPinnedMessages(List<DemoChatScript> scripts) async {
    if (!kEnableDemoChats) return;
    final seedPinnedAtBase = demoNow().toUtc();
    await _dbOp<XmppDatabase>((db) async {
      for (final script in scripts) {
        final pinnedIds = script.pinnedMessageStanzaIds;
        if (pinnedIds.isEmpty) {
          continue;
        }
        final existingEntries = await db.getPinnedMessages(script.chat.jid);
        final existingIds = existingEntries
            .map((entry) => entry.messageStanzaId)
            .toSet();
        final seededMessageIds = script.messages
            .map((message) => message.stanzaID)
            .toSet();
        for (var index = 0; index < pinnedIds.length; index += 1) {
          final stanzaId = pinnedIds[index].trim();
          if (stanzaId.isEmpty ||
              existingIds.contains(stanzaId) ||
              !seededMessageIds.contains(stanzaId)) {
            continue;
          }
          await db.upsertPinnedMessage(
            PinnedMessageEntry(
              messageStanzaId: stanzaId,
              chatJid: script.chat.jid,
              pinnedAt: seedPinnedAtBase.subtract(Duration(seconds: index)),
              active: true,
            ),
          );
          existingIds.add(stanzaId);
        }
      }
    }, awaitDatabase: true);
  }

  ui.Color? _demoAvatarBackgroundForJid(String jid) {
    final normalized = normalizedAddressValue(jid);
    if (normalized == null) {
      return null;
    }
    return switch (normalized) {
      kDemoSelfJid => _demoFranklinBackground,
      'george@axi.im' => _demoWashingtonBackground,
      'thomas@axi.im' => _demoJeffersonBackground,
      'john@axi.im' => _demoAdamsBackground,
      'james@axi.im' => _demoMadisonBackground,
      'alex@axi.im' => _demoHamiltonBackground,
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
              bytes: raw,
              background: background,
            );
      final avatarPath = await _writeAvatarFile(bytes: bytes);
      await _storeAvatar(jid: jid, path: avatarPath, hash: avatar.hash);
    } catch (error, stackTrace) {
      _xmppLogger.fine(
        'Failed to seed demo avatar from ${avatar.assetPath}',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<void> disconnect() async {
    _xmppLogger.info('Logging out...');
    await _reset();
    _xmppLogger.info('Logged out.');
  }

  Future<void> clearSessionTokens() async {
    final sm = _connection.getManager<XmppStreamManagementManager>();
    await sm?.resetState();
    await sm?.clearPersistedState();
    await _dbOp<XmppStateStore>(
      (ss) => ss.delete(key: fastTokenStorageKey),
      awaitDatabase: true,
    );
  }

  void _configureSocketCallbacks() {
    _connection.socketWrapper.registerConnectionCallbacks(
      onConnectSuccess: _resetConnectTimeoutTracking,
      onConnectError: _handleSocketConnectError,
    );
  }

  void _ensureNetworkAvailabilityListener() {
    if (_networkAvailabilitySubscription != null) {
      return;
    }
    _networkAvailabilitySubscription = NetworkAvailabilityService
        .instance
        .stream
        .listen((availability) {
          _xmppLogger.info(
            'Network availability event received: availability=$availability '
            'lifecycleOwned=$_lifecycleResumeReconnectOwned '
            'connectionState=$connectionState',
          );
          if (!availability.isAvailable) {
            return;
          }
          if (_lifecycleResumeReconnectOwned) {
            _xmppLogger.fine(
              'Skipping network-available reconnect because lifecycle resume owns current recovery.',
            );
            return;
          }
          fireAndForget(
            () => requestReconnect(ReconnectTrigger.networkAvailable),
            operationName: 'XmppService.reconnectOnNetworkAvailable',
          );
        });
  }

  Future<void> _stopNetworkAvailabilityListener() async {
    await _networkAvailabilitySubscription?.cancel();
    _networkAvailabilitySubscription = null;
  }

  void _resetConnectTimeoutTracking() {
    _consecutiveConnectTimeouts = 0;
  }

  void _handleSocketConnectError(SocketException error) {
    if (!_sessionReconnectEnabled) {
      return;
    }
    if (!_isTimeoutSocketError(error)) {
      _consecutiveConnectTimeouts = 0;
      return;
    }
    _consecutiveConnectTimeouts += 1;
    if (_consecutiveConnectTimeouts < _staleConnectionTimeoutThreshold) {
      return;
    }
    final timeoutCount = _consecutiveConnectTimeouts;
    _consecutiveConnectTimeouts = 0;
    _xmppLogger.warning(
      'Stale connection detected after $timeoutCount consecutive timeouts.',
    );
    if (!connected) {
      _setConnectionState(ConnectionState.notConnected);
    }
  }

  bool _isTimeoutSocketError(SocketException error) {
    final code = error.osError?.errorCode;
    if (code != null && _timeoutErrorCodes.contains(code)) {
      return true;
    }
    return error.message.toLowerCase().contains('timed out');
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

  Future<bool> requestReconnect(ReconnectTrigger trigger) async {
    final int requestId = ++_nextReconnectRequestId;
    _xmppLogger.info(
      'Reconnect request[$requestId] started: trigger=$trigger '
      '${await _reconnectStateSummary()}',
    );
    if (!_synchronousConnection.isCompleted) {
      _xmppLogger.info(
        'Reconnect request[$requestId] ignored: synchronous connection incomplete.',
      );
      return false;
    }
    if (!_connection.hasConnectionSettings) {
      _xmppLogger.info(
        'Reconnect request[$requestId] ignored: missing connection settings.',
      );
      return false;
    }
    if (!_sessionReconnectEnabled) {
      _xmppLogger.info(
        'Reconnect request[$requestId] ignored: session reconnect disabled.',
      );
      return false;
    }
    if (_reconnectBlocked) {
      _xmppLogger.info(
        'Reconnect request[$requestId] ignored: reconnect blocked.',
      );
      return false;
    }
    if (_connectInFlight) {
      _xmppLogger.info(
        'Reconnect request[$requestId] ignored: connect already in flight.',
      );
      return true;
    }
    if (connected) {
      _xmppLogger.info(
        'Reconnect request[$requestId] ignored: already connected.',
      );
      return true;
    }
    final bool reconnecting = await _connection.isReconnecting();
    if (reconnecting && !trigger.shouldBypassBackoff) {
      _xmppLogger.info(
        'Reconnect request[$requestId] ignored: policy already reconnecting and trigger does not bypass backoff.',
      );
      return true;
    }

    final bool shouldReconnect = await _connection.reconnectionPolicy
        .getShouldReconnect();
    if (!shouldReconnect) {
      try {
        await _connection.setShouldReconnect(true);
      } catch (error, stackTrace) {
        _xmppLogger.finer(_reconnectEnableFailedLog, error, stackTrace);
        _xmppLogger.info(
          'Reconnect request[$requestId] failed while enabling reconnection.',
        );
        return false;
      }
    }

    if (trigger.shouldBypassBackoff &&
        connectionState != ConnectionState.connecting) {
      _setConnectionState(ConnectionState.connecting);
    }

    await _connection.requestReconnect(trigger);
    _xmppLogger.info(
      'Reconnect request[$requestId] dispatched: trigger=$trigger '
      '${await _reconnectStateSummary()}',
    );
    return true;
  }

  @override
  Future<bool> requestLifecycleResumeReconnect() async {
    _xmppLogger.info(
      'Lifecycle-resume reconnect requested. '
      '${await _reconnectStateSummary()}',
    );
    _lifecycleResumeReconnectOwned = true;
    if (connected ||
        _hasMamNegotiatedStream ||
        _streamNegotiationsDone.isCompleted) {
      _xmppLogger.info(
        'Lifecycle-resume reconnect short-circuited because the stream is already connected or negotiated.',
      );
      return true;
    }
    try {
      final requested = await requestReconnect(ReconnectTrigger.resume);
      if (!requested) {
        _lifecycleResumeReconnectOwned = false;
        _xmppLogger.info(
          'Lifecycle-resume reconnect request was not accepted.',
        );
      }
      return requested;
    } on Exception {
      _lifecycleResumeReconnectOwned = false;
      rethrow;
    }
  }

  Future<void> ensureConnected({
    ReconnectTrigger trigger = ReconnectTrigger.immediateRetry,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (!hasConnectionSettings) return;
    if (connectionState == ConnectionState.connected) return;
    await requestReconnect(trigger);
    if (connectionState == ConnectionState.connected) return;
    await connectivityStream
        .firstWhere((state) => state == ConnectionState.connected)
        .timeout(timeout);
  }

  Future<bool> syncSessionState() async {
    if (!hasConnectionSettings) {
      return true;
    }
    if (!connected) {
      const negotiationTimeout = Duration(seconds: 20);
      final negotiationsDone = _waitForStreamNegotiationsDone(
        timeout: negotiationTimeout,
      );
      if (!await requestReconnect(ReconnectTrigger.immediateRetry)) {
        return false;
      }
      await negotiationsDone;
    }

    const mamHistoryPageSize = 50;
    final mamOutcome = await syncGlobalMamCatchUpForRefresh(
      pageSize: mamHistoryPageSize,
    );
    if (!_isAcceptableSessionSyncMamOutcome(mamOutcome)) {
      return false;
    }
    await runBootstrapOperations(XmppBootstrapTrigger.manualRefresh);
    await refreshSelfAvatarIfNeeded(force: true);
    return true;
  }

  Future<void> _waitForStreamNegotiationsDone({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (_hasMamNegotiatedStream) {
      return;
    }
    await _streamNegotiationsDone.future.timeout(timeout);
  }

  bool _isAcceptableSessionSyncMamOutcome(MamGlobalSyncOutcome outcome) {
    switch (outcome) {
      case MamGlobalSyncOutcome.completed:
      case MamGlobalSyncOutcome.skippedUnsupported:
      case MamGlobalSyncOutcome.skippedDenied:
      case MamGlobalSyncOutcome.skippedInFlight:
      case MamGlobalSyncOutcome.skippedResumed:
        return true;
      case MamGlobalSyncOutcome.failed:
        return false;
    }
  }

  Future<void> ensureForegroundSocketIfActive() async {
    _xmppLogger.info(
      'ensureForegroundSocketIfActive invoked. '
      '${_foregroundMigrationStateSummary()}',
    );
    if (!withForeground) {
      _logForegroundMigrationSkip('withForeground disabled');
      return;
    }
    if (!foregroundServiceActive.value) {
      _logForegroundMigrationSkip('foreground service inactive');
      return;
    }
    final lifecycleState = SchedulerBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) {
      _logForegroundMigrationSkip(
        'app lifecycle is not resumed',
        lifecycleState: lifecycleState,
      );
      return;
    }
    if (connectionState == ConnectionState.connecting) {
      _logForegroundMigrationSkip('connection already connecting');
      return;
    }
    if (_reconnectBlocked) {
      _logForegroundMigrationSkip('reconnect blocked');
      return;
    }
    if (!_sessionReconnectEnabled) {
      _logForegroundMigrationSkip('session reconnect disabled');
      return;
    }
    if (_connectInFlight) {
      _logForegroundMigrationSkip('connect already in flight');
      return;
    }
    if (await _connection.isReconnecting()) {
      _logForegroundMigrationSkip('connection already reconnecting');
      return;
    }
    final bool usingForegroundSocket =
        _connection.socketWrapper is ForegroundSocketWrapper;
    if (usingForegroundSocket) {
      _logForegroundMigrationSkip('already using foreground socket');
      return;
    }
    if (!_connection.hasConnectionSettings) {
      _logForegroundMigrationSkip('missing connection settings');
      return;
    }

    final lastAttempt = _lastForegroundSocketMigrationAttempt;
    final now = DateTime.now();
    if (lastAttempt != null &&
        now.difference(lastAttempt) < _foregroundSocketMigrationCooldown) {
      _xmppLogger.fine(
        'Skipping foreground socket migration: cooldown active for '
        '${_foregroundSocketMigrationCooldown - now.difference(lastAttempt)}. '
        '${_foregroundMigrationStateSummary(lifecycleState: lifecycleState)}',
      );
      return;
    }
    _lastForegroundSocketMigrationAttempt = now;

    final existingSettings = _connection.connectionSettings;
    final existingJid = existingSettings.jid.toBare();
    final existingPassword = existingSettings.password;

    var warmupAcquired = false;
    try {
      _xmppLogger.info(
        'Acquiring foreground warmup lease before XMPP migration. '
        '${_foregroundMigrationStateSummary(lifecycleState: lifecycleState)}',
      );
      await foregroundTaskBridge.acquire(
        clientId: _foregroundSocketWarmupClientId,
        config: buildForegroundServiceConfig(
          notificationText:
              toBeginningOfSentenceCase(ConnectionState.connecting.name) ??
              ConnectionState.connecting.name,
        ),
      );
      warmupAcquired = true;
    } on Exception catch (error, stackTrace) {
      _xmppLogger.warning(
        'Failed to acquire foreground warmup lease for XMPP migration.',
        error,
        stackTrace,
      );
      return;
    }

    final XmppConnection oldConnection = _connection;
    XmppConnection? foregroundAttemptConnection;
    try {
      _setConnectionState(ConnectionState.connecting);
      _xmppLogger.info(
        'Migrating XMPP connection to foreground socket. '
        'fromSocket=${_socketWrapperLabel(oldConnection)}',
      );
      await _clearSelfPresenceOnDisconnect();
      await _eventSubscription?.cancel();
      _eventSubscription = null;

      await _omemoActivitySubscription?.cancel();
      _omemoActivitySubscription = null;

      try {
        await oldConnection.setShouldReconnect(false);
      } on Exception catch (error, stackTrace) {
        _xmppLogger.fine(
          'Failed to disable reconnection before foreground migration.',
          error,
          stackTrace,
        );
      }

      try {
        await oldConnection.disconnect();
      } on Exception catch (error, stackTrace) {
        _xmppLogger.fine(
          'Graceful disconnect failed before foreground migration.',
          error,
          stackTrace,
        );
      }

      final XmppConnection nextConnection = await _connectionFactory();
      if (nextConnection.socketWrapper is! ForegroundSocketWrapper) {
        throw StateError(
          'Foreground socket migration skipped: connection factory did not supply foreground socket.',
        );
      }
      foregroundAttemptConnection = nextConnection;

      _setConnection(nextConnection);
      _configureSocketCallbacks();
      _omemoActivitySubscription = _connection.omemoActivityStream.listen(
        _omemoActivityController.add,
      );
      _myJid = existingJid;
      await _initConnection(preHashed: _connectionPasswordPreHashed);
      _eventSubscription = _connection.asBroadcastStream().listen(
        _handleXmppEvent,
      );
      _connection.connectionSettings = XmppConnectionSettings(
        jid: existingJid,
        password: existingPassword,
      );

      _connectInFlight = true;
      late final moxlib.Result<bool, mox.XmppError> result;
      try {
        result = await _connection.connect(
          shouldReconnect: false,
          waitForConnection: true,
          waitUntilLogin: true,
        );
      } finally {
        _connectInFlight = false;
      }
      if (result.isType<mox.XmppError>()) {
        final error = result.get<mox.XmppError>();
        if (_isAuthenticationError(error)) {
          throw XmppAuthenticationException(error is Exception ? error : null);
        }
        throw XmppNetworkException(error is Exception ? error : null);
      }
      if (!result.get<bool>()) {
        throw XmppAuthenticationException();
      }

      await _connection.setShouldReconnect(true);
      _xmppLogger.info(
        'Foreground socket migration completed. '
        '${_foregroundMigrationStateSummary(connection: _connection)}',
      );
      _foregroundSocketMigrationTimer?.cancel();
      _foregroundSocketMigrationTimer = null;
    } catch (error, stackTrace) {
      _xmppLogger.warning(
        'Foreground socket migration failed; reconnecting on direct socket.',
        error.runtimeType,
        stackTrace,
      );
      if (foregroundAttemptConnection != null) {
        await _disposeForegroundMigrationAttempt(foregroundAttemptConnection);
        foregroundAttemptConnection = null;
      }
      try {
        final XmppConnection fallbackConnection = XmppConnection();
        _setConnection(fallbackConnection);
        _configureSocketCallbacks();
        _omemoActivitySubscription = _connection.omemoActivityStream.listen(
          _omemoActivityController.add,
        );
        _myJid = existingJid;
        await _initConnection(preHashed: _connectionPasswordPreHashed);
        _eventSubscription = _connection.asBroadcastStream().listen(
          _handleXmppEvent,
        );
        _connection.connectionSettings = XmppConnectionSettings(
          jid: existingJid,
          password: existingPassword,
        );
        _connectInFlight = true;
        late final moxlib.Result<bool, mox.XmppError> result;
        try {
          result = await _connection.connect(
            shouldReconnect: false,
            waitForConnection: true,
            waitUntilLogin: true,
          );
        } finally {
          _connectInFlight = false;
        }
        if (result.isType<mox.XmppError>()) {
          final error = result.get<mox.XmppError>();
          if (_isAuthenticationError(error)) {
            throw XmppAuthenticationException(
              error is Exception ? error : null,
            );
          }
          throw XmppNetworkException(error is Exception ? error : null);
        }
        if (!result.get<bool>()) {
          throw XmppAuthenticationException();
        }
        await _connection.setShouldReconnect(true);
        _xmppLogger.info(
          'Foreground socket migration fell back to direct socket. '
          '${_foregroundMigrationStateSummary(connection: _connection)}',
        );
      } catch (fallbackError, fallbackStackTrace) {
        _xmppLogger.warning(
          'Direct socket reconnect failed during foreground migration: ${fallbackError.runtimeType}.',
          fallbackError.runtimeType,
          fallbackStackTrace,
        );
        if (fallbackError is XmppAuthenticationException) {
          _setConnectionState(ConnectionState.error);
          return;
        }
        try {
          await _connection.setShouldReconnect(true);
        } catch (error) {
          _xmppLogger.finer(
            'Failed to enable reconnection after foreground migration failure: ${error.runtimeType}.',
          );
        }
        await requestReconnect(ReconnectTrigger.foregroundMigration);
      }
    } finally {
      if (warmupAcquired) {
        try {
          await foregroundTaskBridge.release(_foregroundSocketWarmupClientId);
        } on Exception catch (error, stackTrace) {
          _xmppLogger.finer(
            'Failed to release foreground warmup lease.',
            error,
            stackTrace,
          );
        }
      }
    }
  }

  Future<void> _disposeForegroundMigrationAttempt(
    XmppConnection connection,
  ) async {
    try {
      await connection.setShouldReconnect(false);
    } on Exception catch (error, stackTrace) {
      _xmppLogger.fine(
        'Failed to disable reconnection for abandoned foreground migration attempt.',
        error,
        stackTrace,
      );
    }
    try {
      await connection.reset();
    } on Exception catch (error, stackTrace) {
      _xmppLogger.fine(
        'Failed to reset abandoned foreground migration attempt.',
        error,
        stackTrace,
      );
    }
    try {
      await connection.socketWrapper.closeStreams();
    } on Exception catch (error, stackTrace) {
      _xmppLogger.fine(
        'Failed to close streams for abandoned foreground migration attempt.',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<void> _reset([Exception? e]) async {
    if (!needsReset) return;

    final shouldSendUnavailablePresence =
        connected && _myJid != null && _synchronousConnection.isCompleted;
    if (shouldSendUnavailablePresence) {
      try {
        await sendUnavailablePresenceForDisconnect();
      } catch (error, stackTrace) {
        _xmppLogger.fine(
          'Failed to send unavailable presence before reset.',
          error,
          stackTrace,
        );
      }
    }

    _lifecycleEpoch += 1;
    _myJid = null;
    _synchronousConnection = Completer<void>();
    _setConnectionState(ConnectionState.notConnected);
    _pingController.stop();
    await _stopNetworkAvailabilityListener();
    await _clearSelfPresenceOnDisconnect();
    _connectInFlight = false;
    _consecutiveConnectTimeouts = 0;

    // Only disable session reconnect for fatal errors (auth/database).
    // Network errors should allow reconnection attempts.
    final isFatalError =
        e == null ||
        e is XmppAuthenticationException ||
        e is XmppDatabaseCreationException;
    if (isFatalError) {
      _sessionReconnectEnabled = false;
    }

    _xmppLogger.info(
      'Resetting${e == null ? '' : ' due to ${e.runtimeType}'}...',
    );
    _foregroundSocketMigrationTimer?.cancel();
    _foregroundSocketMigrationTimer = null;
    _demoSeedAttempted = false;
    _demoOfflineMode = false;
    _resetDemoScript();
    _resetStableKeyCache();
    _clearMamSupportState();
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

    await _closeManagerStreams();

    if (connected) {
      try {
        await _connection.setShouldReconnect(false);
        await _connection.disconnect();
        _xmppLogger.info('Gracefully disconnected.');
      } catch (e, s) {
        _xmppLogger.severe(
          'Graceful disconnect failed. Closing forcefully...',
          e,
          s,
        );
      }
    }
    if (withForeground) {
      await _connection.reset();
    }
    await _connection.socketWrapper.closeStreams();
    _setConnection(await _connectionFactory());
    _configureSocketCallbacks();
    if (_activeDbOperations != 0) {
      await _dbOperationsDrained?.future;
    }

    final previousStateStore = _stateStore;
    final previousDatabase = _database;
    _stateStore = ImpatientCompleter(Completer<XmppStateStore>());
    _database = ImpatientCompleter(Completer<XmppDatabase>());
    _notifyDatabaseReloaded();

    if (!previousStateStore.isCompleted) {
      _xmppLogger.warning('Cancelling state store initialization...');
      previousStateStore.completeError(XmppAbortedException());
    } else {
      _xmppLogger.info('Closing state store...');
      await previousStateStore.value?.close();
    }

    if (!previousDatabase.isCompleted) {
      _xmppLogger.warning('Cancelling database initialization...');
      previousDatabase.completeError(XmppAbortedException());
    } else {
      _xmppLogger.info('Closing database...');
      await previousDatabase.value?.close();
    }
    _databasePrefix = null;
    _cachedChatList = null;

    await super._reset();
    await _resetStreamControllers();

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
      _xmppLogger.severe('Reset left residual state: ${residuals.join(', ')}');
    }

    assert(residuals.isEmpty);
  }

  Future<void> _closeManagerStreams() async {
    await _connection.getManager<PubSubHubManager>()?.close();
  }

  Future<void> _resetStreamControllers() async {
    if (_databaseReloadController.isClosed) {
      _databaseReloadController = StreamController<void>.broadcast(sync: true);
    }
    if (_selfAvatarHydratingController.isClosed) {
      _selfAvatarHydratingController = StreamController<bool>.broadcast(
        sync: true,
      );
    }
    if (_xmppOperationController.isClosed) {
      _xmppOperationController =
          StreamController<XmppOperationEvent>.broadcast();
    }
    if (_omemoActivityController.isClosed) {
      _omemoActivityController =
          StreamController<mox.OmemoActivityEvent>.broadcast();
    }
    if (_spamSyncUpdateController.isClosed) {
      _spamSyncUpdateController =
          StreamController<anti_abuse.SpamSyncUpdate>.broadcast();
    }
    if (_addressBlockSyncUpdateController.isClosed) {
      _addressBlockSyncUpdateController =
          StreamController<anti_abuse.AddressBlockSyncUpdate>.broadcast();
    }
    if (_connectivityStream.isClosed) {
      _connectivityStream = StreamController<ConnectionState>.broadcast();
    }
    if (_streamNegotiationsDone.isCompleted) {
      _streamNegotiationsDone = Completer<void>();
    }
  }

  Future<void> _closeStreamControllers() async {
    if (!_databaseReloadController.isClosed) {
      await _databaseReloadController.close();
    }
    if (!_selfAvatarHydratingController.isClosed) {
      await _selfAvatarHydratingController.close();
    }
    if (!_xmppOperationController.isClosed) {
      await _xmppOperationController.close();
    }
    if (!_omemoActivityController.isClosed) {
      await _omemoActivityController.close();
    }
    if (!_spamSyncUpdateController.isClosed) {
      await _spamSyncUpdateController.close();
    }
    if (!_addressBlockSyncUpdateController.isClosed) {
      await _addressBlockSyncUpdateController.close();
    }
    if (!_connectivityStream.isClosed) {
      await _connectivityStream.close();
    }
  }

  Future<void> close() async {
    if (_hasInitializedConnection) {
      final connection = _connection;
      await connection.getManager<PubSubManager>()?.disposeSupport();
      await _reset();
    }
    await _closeStreamControllers();
    if (!_mamSupportController.isClosed) {
      await _mamSupportController.close();
    }
    if (!_messageStream.isClosed) {
      await _messageStream.close();
    }
    await _closeDemoScript();
    _instance = null;
  }

  Completer<T> _getDatabaseCompleter<T>() => switch (T) {
    == XmppStateStore => _stateStore.completer as Completer<T>,
    == XmppDatabase => _database.completer as Completer<T>,
    _ => throw UnimplementedError('No database of type: $T exists.'),
  };

  @override
  Future<V> _dbOpReturning<D extends Database, V>(
    FutureOr<V> Function(D) operation,
  ) async {
    _xmppLogger.fine('Retrieving completer for $D...');
    final operationEpoch = _lifecycleEpoch;

    try {
      if (operationEpoch != _lifecycleEpoch ||
          !_synchronousConnection.isCompleted ||
          _myJid == null) {
        throw XmppAbortedException();
      }
      _xmppLogger.fine('Awaiting completer for $D...');
      final db = await _getDatabaseCompleter<D>().future;
      _xmppLogger.fine('Completed completer for $D.');
      if (operationEpoch != _lifecycleEpoch ||
          !_synchronousConnection.isCompleted ||
          _myJid == null) {
        throw XmppAbortedException();
      }
      _activeDbOperations += 1;
      _dbOperationsDrained ??= Completer<void>();
      try {
        final value = await operation(db);
        if (operationEpoch != _lifecycleEpoch) {
          throw XmppAbortedException();
        }
        return value;
      } finally {
        if (_activeDbOperations != 0) {
          _activeDbOperations -= 1;
          if (_activeDbOperations == 0) {
            final dbOperationsDrained = _dbOperationsDrained;
            if (dbOperationsDrained != null &&
                !dbOperationsDrained.isCompleted) {
              dbOperationsDrained.complete();
            }
            _dbOperationsDrained = null;
          }
        }
      }
    } on XmppAbortedException catch (e, s) {
      _xmppLogger.finer('Owner called reset before $D initialized.', e, s);
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
    _xmppLogger.fine('Retrieving completer for $T...');
    final operationEpoch = _lifecycleEpoch;

    final completer = _getDatabaseCompleter<T>();

    if (!awaitDatabase && !completer.isCompleted) return;

    try {
      if (operationEpoch != _lifecycleEpoch ||
          !_synchronousConnection.isCompleted ||
          _myJid == null) {
        throw XmppAbortedException();
      }
      _xmppLogger.fine('Awaiting completer for $T...');
      final db = await completer.future;
      _xmppLogger.fine('Completed completer for $T.');
      if (operationEpoch != _lifecycleEpoch ||
          !_synchronousConnection.isCompleted ||
          _myJid == null) {
        throw XmppAbortedException();
      }
      _activeDbOperations += 1;
      _dbOperationsDrained ??= Completer<void>();
      try {
        await operation(db);
        if (operationEpoch != _lifecycleEpoch) {
          throw XmppAbortedException();
        }
      } finally {
        if (_activeDbOperations != 0) {
          _activeDbOperations -= 1;
          if (_activeDbOperations == 0) {
            final dbOperationsDrained = _dbOperationsDrained;
            if (dbOperationsDrained != null &&
                !dbOperationsDrained.isCompleted) {
              dbOperationsDrained.complete();
            }
            _dbOperationsDrained = null;
          }
        }
      }
      return;
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
    final random = math.Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static String generateResource() =>
      'axi.${generateRandomString(length: 7, seed: DateTime.now().millisecondsSinceEpoch)}';
}

class XmppClientNegotiator extends mox.ClientToServerNegotiator {
  XmppClientNegotiator() : super();
}

class XmppTlsRequirementNegotiator extends mox.XmppFeatureNegotiatorBase {
  XmppTlsRequirementNegotiator()
    : super(
        _tlsRequirementNegotiatorPriority,
        _tlsRequirementSendStreamHeader,
        _tlsRequirementNegotiatorXmlns,
        _tlsRequirementNegotiatorId,
      );

  @override
  bool matchesFeature(List<mox.XMLNode> features) =>
      _tlsRequirementMatchesAllFeatures;

  @override
  Future<moxlib.Result<mox.NegotiatorState, mox.NegotiatorError>> negotiate(
    mox.XMLNode nonza,
  ) async {
    if (attributes.getSocket().isSecure()) {
      return const moxlib.Result(mox.NegotiatorState.done);
    }
    if (!_hasStartTlsFeature(nonza)) {
      return moxlib.Result(_XmppTlsRequiredError());
    }
    return const moxlib.Result(mox.NegotiatorState.done);
  }

  bool _hasStartTlsFeature(mox.XMLNode nonza) {
    if (nonza.tag != _streamFeaturesTag) {
      return _tlsRequirementNonFeatureDefault;
    }
    return nonza.children.any(
      (feature) => feature.attributes['xmlns'] == mox.startTlsXmlns,
    );
  }
}

class _XmppTlsRequiredError extends mox.NegotiatorError {
  _XmppTlsRequiredError();

  @override
  bool isRecoverable() => _tlsRequirementErrorRecoverable;

  @override
  String toString() => _tlsRequirementErrorMessage;
}

class XmppResourceNegotiator extends mox.ResourceBindingNegotiator {
  XmppResourceNegotiator({required this.resource}) : super();

  final String resource;

  bool _attempted = false;

  @override
  Future<moxlib.Result<mox.NegotiatorState, mox.NegotiatorError>> negotiate(
    mox.XMLNode nonza,
  ) async {
    if (!_attempted) {
      final stanza = mox.XMLNode.xmlns(
        tag: 'iq',
        xmlns: mox.stanzaXmlns,
        attributes: {'type': 'set', 'id': const Uuid().v4()},
        children: [
          mox.XMLNode.xmlns(
            tag: 'bind',
            xmlns: mox.bindXmlns,
            children: [mox.XMLNode(tag: 'resource', text: resource)],
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

final class _ListConversionSink<T> implements Sink<List<T>> {
  _ListConversionSink(this._onData);

  final void Function(List<T>) _onData;

  @override
  void add(List<T> data) => _onData(data);

  @override
  void close() {}
}

final class _ChunkedConversionBuffer<S, T> {
  _ChunkedConversionBuffer(Converter<S, List<T>> converter) {
    _outputSink = _ListConversionSink<T>(_results.addAll);
    _inputSink = converter.startChunkedConversion(_outputSink);
  }

  final List<T> _results = List<T>.empty(growable: true);
  late Sink<List<T>> _outputSink;
  late Sink<S> _inputSink;

  void close() {
    _inputSink.close();
    _outputSink.close();
  }

  List<T> convert(S input) {
    _results.clear();
    _inputSink.add(input);
    return _results;
  }
}

enum _XmppStanzaGuardResult { allowed, oversize, depthExceeded, malformed }

final class _XmppStanzaSizeGuard {
  _XmppStanzaSizeGuard({
    required this.maxStanzaBytes,
    required this.maxStanzaDepth,
  });

  final int maxStanzaBytes;
  final int maxStanzaDepth;
  var _inStream = false;
  var _depth = 0;
  var _currentStanzaBytes = 0;
  _ChunkedConversionBuffer<String, XmlEvent> _eventBuffer =
      _ChunkedConversionBuffer<String, XmlEvent>(XmlEventDecoder());

  _XmppStanzaGuardResult evaluateChunk(String data) {
    final chunkBytes = utf8ByteLength(data);
    var stanzaTouched = _inStream && _depth > 0;
    var endedTopLevel = false;
    try {
      final events = _eventBuffer.convert(data);
      for (final event in events) {
        if (event is XmlStartElementEvent) {
          if (event.name == 'stream:stream') {
            _inStream = true;
            if (event.isSelfClosing) {
              _resetCounters();
            }
            continue;
          }
          if (_inStream) {
            _depth += 1;
            stanzaTouched = true;
            if (_depth > maxStanzaDepth) {
              return _XmppStanzaGuardResult.depthExceeded;
            }
            if (event.isSelfClosing) {
              _depth -= 1;
              if (_depth == 0) {
                endedTopLevel = true;
              }
            }
          }
          continue;
        }
        if (event is XmlEndElementEvent) {
          if (event.name == 'stream:stream') {
            _resetCounters();
            continue;
          }
          if (_inStream && _depth > 0) {
            _depth -= 1;
            if (_depth == 0) {
              endedTopLevel = true;
            }
          }
        }
      }
    } on Exception {
      return _XmppStanzaGuardResult.malformed;
    }

    if (stanzaTouched) {
      _currentStanzaBytes += chunkBytes;
      if (_currentStanzaBytes > maxStanzaBytes) {
        return _XmppStanzaGuardResult.oversize;
      }
    }

    if (_inStream && _depth == 0 && endedTopLevel) {
      _currentStanzaBytes = 0;
    }
    return _XmppStanzaGuardResult.allowed;
  }

  void reset() {
    _resetCounters();
    try {
      _eventBuffer.close();
    } on Exception {
      // ignore; stream parser may already be closed
    }
    _eventBuffer = _ChunkedConversionBuffer<String, XmlEvent>(
      XmlEventDecoder(),
    );
  }

  void _resetCounters() {
    _inStream = false;
    _depth = 0;
    _currentStanzaBytes = 0;
  }
}

abstract class XmppTrafficTracker {
  DateTime? get lastIncomingAt;
  DateTime? get lastOutgoingAt;
}

/// Stream management negotiator that tolerates missing managers and avoids null
/// dereferences during feature matching.
class XmppSocketWrapper implements mox.BaseSocketWrapper, XmppTrafficTracker {
  XmppSocketWrapper();

  static final _log = Logger('XmppSocketWrapper');
  static const _socketClosedWithErrorLog = 'Socket closed with error.';
  static const TlsProtocolVersion _minTlsProtocolVersion =
      TlsProtocolVersion.tls1_2;
  static const String _xmlDoctypeToken = '<!doctype';
  static const String _xmlEntityToken = '<!entity';
  static const int _xmlTokenCarryLength =
      _xmlDoctypeToken.length > _xmlEntityToken.length
      ? _xmlDoctypeToken.length - 1
      : _xmlEntityToken.length - 1;
  static const String _xmlForbiddenLog =
      'Blocked XML containing DTD/entity declaration.';
  static const String _xmlForbiddenError =
      'XML DTD/entity declarations are not supported.';
  static const String _stanzaOversizeError =
      'Incoming stanza exceeds size limit.';
  static const String _stanzaDepthError =
      'Incoming stanza exceeds nesting depth limit.';
  static const String _stanzaMalformedError =
      'Incoming stanza rejected due to parse error.';
  static const String _socketCancelFailedLog =
      'Failed to cancel socket subscription.';
  static const String _cancelSocketSubscriptionOperationName =
      'XmppService.cancelSocketSubscription';

  final StreamController<String> _dataStream = StreamController.broadcast();
  final StreamController<mox.XmppSocketEvent> _eventStream =
      StreamController.broadcast();
  final _XmppStanzaSizeGuard _stanzaSizeGuard = _XmppStanzaSizeGuard(
    maxStanzaBytes: maxXmppStanzaBytes,
    maxStanzaDepth: maxXmppStanzaDepth,
  );

  void Function()? _onConnectSuccess;
  void Function(SocketException error)? _onConnectError;
  Socket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  final Set<Socket> _expectedClosures = {};
  bool _secure = false;
  bool _streamsClosed = false;
  String _xmlTokenCarry = '';
  DateTime? _lastIncomingAt;
  DateTime? _lastOutgoingAt;

  @override
  bool isSecure() => _secure;

  @override
  bool managesKeepalives() => false;

  @override
  bool whitespacePingAllowed() => true;

  @override
  DateTime? get lastIncomingAt => _lastIncomingAt;

  @override
  DateTime? get lastOutgoingAt => _lastOutgoingAt;

  void _recordIncomingTraffic() {
    _lastIncomingAt = DateTime.timestamp();
  }

  void _recordOutgoingTraffic() {
    _lastOutgoingAt = DateTime.timestamp();
  }

  void registerConnectionCallbacks({
    void Function()? onConnectSuccess,
    void Function(SocketException error)? onConnectError,
  }) {
    _onConnectSuccess = onConnectSuccess;
    _onConnectError = onConnectError;
  }

  void destroy() {
    _cancelSocketSubscription(_socketSubscription);
  }

  bool onBadCertificate(dynamic certificate, String domain) => false;

  Future<bool> _hostPortConnect(String host, int port) async {
    try {
      _log.finest('Attempting direct socket connection...');
      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 15),
      );
      _onConnectSuccess?.call();
      _log.finest('Success!');
      return true;
    } on SocketException catch (error) {
      _onConnectError?.call(error);
      _log.finest('Socket connection failed: $error');
      return false;
    } on Exception catch (error) {
      _log.finest('Socket connection failed: $error');
      return false;
    }
  }

  Future<bool> _axiImDnsARecordFallback({
    required int port,
    required String failedHost,
  }) async {
    try {
      final records = await InternetAddress.lookup(
        'axi.im',
        type: InternetAddressType.IPv4,
      );
      final seenHosts = <String>{};
      for (final record in records) {
        final host = record.address;
        if (host == failedHost || !seenHosts.add(host)) {
          continue;
        }
        _log.fine('Attempting axi.im DNS A fallback endpoint $host:$port...');
        if (await _hostPortConnect(host, port)) {
          return true;
        }
      }
    } on SocketException catch (error) {
      _log.warning('axi.im DNS A fallback lookup failed: $error');
    } on Exception catch (error) {
      _log.warning('axi.im DNS A fallback failed: $error');
    }
    return false;
  }

  @override
  Future<bool> connect(String domain, {String? host, int? port}) async {
    _dropSocket(expectClosure: true);
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
          'No static server mapping and no host override provided. DNS lookups are disabled.',
        );
        return false;
      }
      resolvedHost = target.host;
      resolvedPort = port ?? target.port;
    }

    _log.fine('Connecting via direct endpoint...');

    final connected = await _hostPortConnect(resolvedHost, resolvedPort);
    if (connected) {
      _setupStreams();
      return true;
    }

    if (domain == 'axi.im') {
      _log.warning(
        'Direct axi.im endpoint failed. Trying DNS A record fallback...',
      );
      final fallbackConnected = await _axiImDnsARecordFallback(
        port: resolvedPort,
        failedHost: resolvedHost,
      );
      if (fallbackConnected) {
        _setupStreams();
        return true;
      }
    }

    _log.warning(
      'Socket connection failed. DNS/SRV fallbacks are disabled for all domains except axi.im A fallback.',
    );
    return false;
  }

  void _setupStreams() {
    if (_streamsClosed) {
      _log.warning('Ignoring stream setup because the wrapper is closed.');
      return;
    }
    final socket = _socket;
    if (socket == null) {
      _log.severe('Failed to setup streams as _socket is null');
      return;
    }
    _xmlTokenCarry = '';
    _stanzaSizeGuard.reset();

    final StreamSubscription<dynamic>? priorSubscription = _socketSubscription;
    if (priorSubscription != null) {
      _cancelSocketSubscription(priorSubscription);
    }

    _socketSubscription = socket.listen(
      (List<int> event) {
        _recordIncomingTraffic();
        final data = utf8.decode(event);
        if (_containsForbiddenXml(data)) {
          _log.warning(_xmlForbiddenLog);
          _addSocketEvent(
            mox.XmppSocketErrorEvent(const FormatException(_xmlForbiddenError)),
          );
          _dropSocket(expectClosure: false);
          return;
        }
        final guardResult = _stanzaSizeGuard.evaluateChunk(data);
        if (guardResult != _XmppStanzaGuardResult.allowed) {
          switch (guardResult) {
            case _XmppStanzaGuardResult.oversize:
              _log.warning(
                'Blocked inbound stanza exceeding $maxXmppStanzaBytes bytes.',
              );
              _addSocketEvent(
                mox.XmppSocketErrorEvent(
                  const FormatException(_stanzaOversizeError),
                ),
              );
              break;
            case _XmppStanzaGuardResult.depthExceeded:
              _log.warning(
                'Blocked inbound stanza exceeding $maxXmppStanzaDepth depth.',
              );
              _addSocketEvent(
                mox.XmppSocketErrorEvent(
                  const FormatException(_stanzaDepthError),
                ),
              );
              break;
            case _XmppStanzaGuardResult.malformed:
              _log.warning('Blocked inbound stanza due to parse error.');
              _addSocketEvent(
                mox.XmppSocketErrorEvent(
                  const FormatException(_stanzaMalformedError),
                ),
              );
              break;
            case _XmppStanzaGuardResult.allowed:
              break;
          }
          _dropSocket(expectClosure: false);
          return;
        }
        _addSocketData(data);
      },
      onError: (Object error) {
        _log.severe(error.toString());
        _addSocketEvent(mox.XmppSocketErrorEvent(error));
      },
      onDone: () {
        _socketSubscription = null;
      },
    );

    _trackSocketDone(socket);
  }

  Future<void> _trackSocketDone(Socket socket) async {
    try {
      await socket.done;
      _markSocketClosed(socket);
      _addSocketEvent(
        mox.XmppSocketClosureEvent(_expectedClosures.remove(socket)),
      );
    } on Exception catch (error, stackTrace) {
      _log.fine(_socketClosedWithErrorLog, error, stackTrace);
      _addSocketEvent(mox.XmppSocketErrorEvent(error));
      _markSocketClosed(socket);
      _addSocketEvent(
        mox.XmppSocketClosureEvent(_expectedClosures.remove(socket)),
      );
    }
  }

  bool _containsForbiddenXml(String data) {
    final combined = (_xmlTokenCarry + data).toLowerCase();
    final hasForbidden =
        combined.contains(_xmlDoctypeToken) ||
        combined.contains(_xmlEntityToken);
    if (combined.length <= _xmlTokenCarryLength) {
      _xmlTokenCarry = combined;
    } else {
      _xmlTokenCarry = combined.substring(
        combined.length - _xmlTokenCarryLength,
      );
    }
    return hasForbidden;
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
      _expectedClosures.add(socket);
      final context = SecurityContext(withTrustedRoots: true)
        ..minimumTlsProtocolVersion = _minTlsProtocolVersion
        ..allowLegacyUnsafeRenegotiation = false;
      _socket = await SecureSocket.secure(
        socket,
        host: domain,
        context: context,
        supportedProtocols: const [mox.xmppClientALPNId],
        onBadCertificate: (cert) => onBadCertificate(cert, domain),
      );

      _secure = true;
      _setupStreams();
      return true;
    } on Exception catch (error) {
      _log.severe('Failed to secure socket: $error');
      if (error is HandshakeException) {
        _addSocketEvent(mox_tcp.XmppSocketTLSFailedEvent());
      }
      return false;
    }
  }

  @override
  void close() {
    final socket = _socket;
    if (socket == null) {
      _log.warning('Failed to close socket since _socket is null');
      return;
    }

    try {
      _expectedClosures.add(socket);
      socket.close();
    } catch (error) {
      _log.warning('Closing socket threw exception: $error');
    }
    _markSocketClosed(socket);
  }

  Future<void> closeStreams() async {
    if (_streamsClosed) return;

    _streamsClosed = true;
    await _shutdownSocket();
    await _dataStream.close();
    await _eventStream.close();
  }

  @override
  void write(String data) {
    final socket = _socket;
    if (socket == null) {
      _log.severe('Failed to write to socket as _socket is null');
      return;
    }

    _recordOutgoingTraffic();
    try {
      socket.write(data);
    } on Exception catch (error) {
      _log.severe(error);
      _addSocketEvent(mox.XmppSocketErrorEvent(error));
    }
  }

  @override
  Stream<String> getDataStream() => _dataStream.stream.asBroadcastStream();

  @override
  Stream<mox.XmppSocketEvent> getEventStream() =>
      _eventStream.stream.asBroadcastStream();

  @override
  void prepareDisconnect() {
    _dropSocket(expectClosure: true);
  }

  void _addSocketData(String data) {
    if (_streamsClosed) {
      return;
    }
    _dataStream.add(data);
  }

  void _addSocketEvent(mox.XmppSocketEvent event) {
    if (_streamsClosed) {
      return;
    }
    _eventStream.add(event);
  }

  void _dropSocket({required bool expectClosure}) {
    final socket = _socket;
    if (socket == null) return;
    if (expectClosure) {
      _expectedClosures.add(socket);
    }
    _socket = null;
    _secure = false;
    final subscription = _socketSubscription;
    _socketSubscription = null;
    if (subscription != null) {
      _cancelSocketSubscription(subscription);
    }
    try {
      socket.destroy();
    } catch (error) {
      _log.warning('Closing socket threw exception: $error');
    }
  }

  Future<void> _shutdownSocket() async {
    final socket = _socket;
    _socket = null;
    _secure = false;

    final subscription = _socketSubscription;
    _socketSubscription = null;
    if (subscription != null) {
      try {
        await subscription.cancel();
      } catch (error, stackTrace) {
        _log.fine(_socketCancelFailedLog, error, stackTrace);
      }
    }

    if (socket == null) {
      return;
    }

    try {
      socket.destroy();
    } catch (error) {
      _log.warning('Closing socket threw exception: $error');
    }
  }

  void _cancelSocketSubscription(StreamSubscription<dynamic>? subscription) {
    if (subscription == null) return;
    fireAndForget(() async {
      try {
        await subscription.cancel();
      } catch (error, stackTrace) {
        _log.fine(_socketCancelFailedLog, error, stackTrace);
      }
    }, operationName: _cancelSocketSubscriptionOperationName);
  }

  void _markSocketClosed(Socket socket) {
    if (!identical(_socket, socket)) {
      return;
    }
    _socket = null;
    _secure = false;
    _socketSubscription = null;
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
  final streamResumptionIDKey = XmppStateStore.registerKey(
    '${keyPrefix}_resID',
  );
  final streamResumptionLocationKey = XmppStateStore.registerKey(
    '${keyPrefix}_resLoc',
  );

  Future<void> clearPersistedState() async {
    await owner._dbOp<XmppStateStore>((ss) async {
      await ss.delete(key: clientToServerCountKey);
      await ss.delete(key: serverToClientCountKey);
      await ss.delete(key: streamResumptionIDKey);
      await ss.delete(key: streamResumptionLocationKey);
    }, awaitDatabase: true);
  }

  @override
  Future<void> commitState() async {
    await owner._dbOp<XmppStateStore>((ss) async {
      _log.fine('Saving c2s: ${state.c2s}...');
      await ss.write(key: clientToServerCountKey, value: state.c2s);
      _log.fine('Saving s2c: ${state.s2c}...');
      await ss.write(key: serverToClientCountKey, value: state.s2c);
      final resumptionId = state.streamResumptionId;
      if (resumptionId != null) {
        await ss.write(key: streamResumptionIDKey, value: resumptionId);
      } else {
        await ss.delete(key: streamResumptionIDKey);
      }
      final resumptionLocation = state.streamResumptionLocation;
      if (resumptionLocation != null) {
        await ss.write(
          key: streamResumptionLocationKey,
          value: resumptionLocation,
        );
      } else {
        await ss.delete(key: streamResumptionLocationKey);
      }
    });
  }

  @override
  Future<void> loadState() async {
    await owner._dbOp<XmppStateStore>((ss) async {
      var newState = state;
      if (ss.read(key: clientToServerCountKey) case int c2s) {
        _log.fine('Loading c2s: ${state.c2s}...');
        newState = newState.copyWith(c2s: c2s);
      }
      if (ss.read(key: serverToClientCountKey) case int s2c) {
        _log.fine('Loading s2c: ${state.s2c}...');
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

  Future<bool> hasPersistedState() async {
    return owner._dbOpReturning<XmppStateStore, bool>(
      (ss) async => ss.read(key: streamResumptionIDKey) != null,
    );
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

// PubSubManager wrapper lives in pubsub/pubsub_manager.dart.

/// Custom SASL SCRAM negotiator that adds support for pre-hashed passwords.
///
/// This wrapper is necessary for the app's security model where passwords can be
/// stored in a pre-hashed format rather than plaintext. This allows for:
/// - Secure password storage without keeping plaintext
/// - Faster reconnection using cached salted passwords
/// - Compatibility with the app's credential management system
class SaslScramNegotiator extends mox.SaslScramNegotiator {
  SaslScramNegotiator({this.preHashed = false})
    : super(10, '', '', mox.ScramHashType.sha512);

  final bool preHashed;

  @override
  bool matchesFeature(List<mox.XMLNode> features) {
    if (!super.matchesFeature(features)) {
      return false;
    }
    return attributes.getSocket().isSecure();
  }

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
