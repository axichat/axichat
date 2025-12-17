part of 'package:axichat/src/xmpp/xmpp_service.dart';

final class _ConnectionDomainProvider {
  String? _domain;

  String? provide() => _domain;

  void updateFromJid(mox.JID jid) {
    final domain = jid.domain.trim();
    _domain = domain.isEmpty ? null : domain;
  }
}

class XmppConnection extends mox.XmppConnection {
  XmppConnection({
    XmppReconnectionPolicy? reconnectionPolicy,
    XmppConnectivityManager? connectivityManager,
    XmppClientNegotiator? negotiationsHandler,
    XmppSocketWrapper? socketWrapper,
  }) : this._internal(
          reconnectionPolicy:
              reconnectionPolicy ?? XmppReconnectionPolicy.exponential(),
          connectivityManager: connectivityManager,
          negotiationsHandler: negotiationsHandler ?? XmppClientNegotiator(),
          socketWrapper: socketWrapper ?? XmppSocketWrapper(),
          domainProvider: _ConnectionDomainProvider(),
        );

  XmppConnection._internal({
    required XmppReconnectionPolicy reconnectionPolicy,
    required XmppConnectivityManager? connectivityManager,
    required XmppClientNegotiator negotiationsHandler,
    required this.socketWrapper,
    required _ConnectionDomainProvider domainProvider,
  })  : _domainProvider = domainProvider,
        _reconnectionPolicy = reconnectionPolicy,
        super(
          reconnectionPolicy: reconnectionPolicy,
          connectivityManager: connectivityManager ??
              XmppConnectivityManager.forXmppConnection(
                domainProvider: domainProvider.provide,
                shouldContinue: reconnectionPolicy.getShouldReconnect,
              ),
          negotiationsHandler: negotiationsHandler,
          socket: socketWrapper,
        );

  final _ConnectionDomainProvider _domainProvider;
  final XmppSocketWrapper socketWrapper;
  final XmppReconnectionPolicy _reconnectionPolicy;

  // Check if we have a connectionSettings as it is marked [late] in mox.
  bool get hasConnectionSettings => _hasConnectionSettings;
  bool _hasConnectionSettings = false;

  @override
  XmppConnectionSettings get connectionSettings =>
      super.connectionSettings as XmppConnectionSettings;

  @override
  set connectionSettings(covariant XmppConnectionSettings connectionSettings) {
    _hasConnectionSettings = true;
    _domainProvider.updateFromJid(connectionSettings.jid);
    super.connectionSettings = connectionSettings;
  }

  Future<void> updateConnectivityNotification(ConnectionState state) async {
    if (socketWrapper case final ForegroundSocketWrapper wrapper) {
      wrapper.updateConnectionState(state);
    }
  }

  Future<void> setShouldReconnect(bool value) =>
      reconnectionPolicy.setShouldReconnect(value);

  T? getManager<T extends mox.XmppManagerBase>() {
    switch (T) {
      case == mox.MessageManager:
        return getManagerById(mox.messageManager);
      case == mox.OmemoManager:
        return getManagerById(mox.omemoManager);
      case == mox.DiscoManager:
        return getManagerById(mox.discoManager);
      case == mox.PubSubManager:
        return getManagerById(mox.pubsubManager);
      case == XmppPresenceManager:
        return getManagerById(mox.presenceManager);
      case == XmppStreamManagementManager:
        return getManagerById(mox.smManager);
      case == mox.StreamManagementManager:
        return getManagerById(mox.smManager);
      case == mox.ChatStateManager:
        return getManagerById(mox.chatStateManager);
      case == mox.CarbonsManager:
        return getManagerById(mox.carbonsManager);
      case == mox.MAMManager:
        return getManagerById(mox.mamManager);
      case == mox.MUCManager:
        return getManagerById(mox.mucManager);
      case == MUCManager:
        return getManagerById(mox.mucManager);
      case == mox.BlockingManager:
        return getManagerById(mox.blockingManager);
      case == mox.CSIManager:
        return getManagerById(mox.csiManager);
      case == mox.HttpFileUploadManager:
        return getManagerById(mox.httpFileUploadManager);
      case == mox.FileUploadNotificationManager:
        return getManagerById(mox.fileUploadNotificationManager);
      case == mox.UserAvatarManager:
        return getManagerById(mox.userAvatarManager);
      case == mox.VCardManager:
        return getManagerById(mox.vcardManager);
      case == BookmarksManager:
        return getManagerById(BookmarksManager.managerId);
      case == ConversationIndexManager:
        return getManagerById(ConversationIndexManager.managerId);
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
      case == SaslScramNegotiator:
        return getNegotiatorById(mox.saslScramSha512Negotiator);
      default:
        return null;
    }
  }

  String? get saltedPassword =>
      getNegotiator<SaslScramNegotiator>()?.saltedPassword;

  Future<void>? loadStreamState() =>
      getManager<XmppStreamManagementManager>()?.loadState();

  Future<moxlib.Result<mox.StanzaError, mox.DiscoInfo>>? discoInfoQuery(
          String jid) =>
      getManager<mox.DiscoManager>()?.discoInfoQuery(mox.JID.fromString(jid));

  bool? get carbonsEnabled => getManager<mox.CarbonsManager>()?.isEnabled;

  Future<bool> enableCarbons() async =>
      await (getManager<mox.CarbonsManager>()?.enableCarbons()) ?? false;

  Future<bool> sendMessage(mox.MessageEvent packet) async {
    if (getManager<mox.MessageManager>() case final mm?) {
      await mm.sendMessage(
        packet.to,
        packet.extensions,
        type: packet.type ?? 'chat',
      );
      return true;
    }

    return false;
  }

  Future<bool> sendChatMarker({
    required String to,
    required String stanzaID,
    required mox.ChatMarker marker,
    String messageType = 'chat',
  }) async {
    if (getManager<mox.MessageManager>() case final mm?) {
      await mm.sendMessage(
        mox.JID.fromString(to),
        mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
          mox.ChatMarkerData(marker, stanzaID),
        ]),
        type: messageType,
      );
      return true;
    }

    return false;
  }

  Future<void> sendPresence({
    Presence? presence,
    String? status,
    String? to,
    bool trackDirected = false,
  }) async {
    if (getManager<XmppPresenceManager>() case final pm?) {
      await pm.sendPresence(
        show: presence?.name,
        status: status,
        to: to != null ? mox.JID.fromString(to) : null,
        trackDirected: trackDirected,
      );
      return;
    }

    throw XmppPresenceException();
  }

  Future<void> sendChatState({
    required String jid,
    required mox.ChatState state,
    String messageType = 'chat',
  }) async {
    if (getManager<mox.ChatStateManager>() case final cm?) {
      return await cm.sendChatState(
        state,
        jid,
        messageType: messageType,
      );
    }
  }

  Future<moxlib.Result<mox.RosterRequestResult, mox.RosterError>?>
      requestRoster() async => await getRosterManager()?.requestRoster();

  Future<bool> addToRoster(String jid, {String? title}) async {
    if (getRosterManager() case final rm?) {
      return await rm.addToRoster(jid, title ?? mox.JID.fromString(jid).local);
    }

    return false;
  }

  Future<bool> preApproveSubscription(String jid) async {
    if (getPresenceManager() case final pm?) {
      final to = mox.JID.fromString(jid);
      return await pm.preApproveSubscription(to);
    }

    return false;
  }

  Future<bool> requestSubscription(String jid) async {
    if (getPresenceManager() case final pm?) {
      final to = mox.JID.fromString(jid);
      await pm.requestSubscription(to);
      return true;
    }

    return false;
  }

  Future<mox.RosterRemovalResult> removeFromRoster(String jid) async {
    if (getRosterManager() case final rm?) {
      return await rm.removeFromRoster(jid);
    }

    return mox.RosterRemovalResult.error;
  }

  Future<bool> acceptSubscriptionRequest(String jid) async {
    if (getPresenceManager() case final pm?) {
      final from = mox.JID.fromString(jid);
      await pm.acceptSubscriptionRequest(from);
      return true;
    }

    return false;
  }

  Future<bool> rejectSubscriptionRequest(String jid) async {
    if (getPresenceManager() case final pm?) {
      final from = mox.JID.fromString(jid);
      await pm.rejectSubscriptionRequest(from);
      return true;
    }

    return false;
  }

  Future<List<String>?> requestBlocklist() async {
    if (getManager<mox.BlockingManager>() case final bm?) {
      if (!await bm.isSupported()) throw XmppBlockUnsupportedException();
      return await bm.getBlocklist();
    }
    return null;
  }

  Future<void> block(String jid) async {
    if (getManager<mox.BlockingManager>() case final bm?) {
      if (!await bm.isSupported()) throw XmppBlockUnsupportedException();
      if (!await bm.block([jid])) throw XmppBlocklistException();
    }
  }

  Future<void> unblock(String jid) async {
    if (getManager<mox.BlockingManager>() case final bm?) {
      if (!await bm.isSupported()) throw XmppBlockUnsupportedException();
      if (!await bm.unblock([jid])) throw XmppBlocklistException();
    }
  }

  Future<void> unblockAll() async {
    if (getManager<mox.BlockingManager>() case final bm?) {
      if (!await bm.isSupported()) throw XmppBlockUnsupportedException();
      if (!await bm.unblockAll()) throw XmppBlocklistException();
    }
  }

  void setFastToken(String? value) =>
      getNegotiator<mox.FASTSaslNegotiator>()?.fastToken = value;

  void setUserAgent(mox.UserAgent value) =>
      getNegotiator<mox.Sasl2Negotiator>()?.userAgent = value;

  Future<void> reset() async {
    if (await FlutterForegroundTask.isRunningService) {
      if (socketWrapper case final ForegroundSocketWrapper socket) {
        socket.reset();
      }
    }
  }

  Future<void> triggerImmediateReconnect() =>
      _reconnectionPolicy.triggerImmediateReconnect();
}

class XmppConnectionSettings extends mox.ConnectionSettings {
  XmppConnectionSettings({required super.jid, required super.password});
}

class XmppReconnectionPolicy implements mox.ReconnectionPolicy {
  XmppReconnectionPolicy._(this.strategy);

  final RetryOptions strategy;

  XmppReconnectionPolicy.exponential() : this._(const RetryOptions());

  bool _reconnectionInProgress = false;
  bool _shouldReconnect = false;

  int _reconnectionAttempts = 0;
  Timer? _backoffTimer;

  @override
  mox.PerformReconnectFunction? performReconnect;

  @override
  void register(mox.PerformReconnectFunction performReconnect) =>
      this.performReconnect = performReconnect;

  // Have to do Future based API to match mox implementation.
  @override
  Future<bool> getIsReconnecting() async => _reconnectionInProgress;

  // Have to do Future based API to match mox implementation.
  @override
  Future<bool> canTryReconnecting() async => !_reconnectionInProgress;

  // Have to do Future based API to match mox implementation.
  @override
  Future<bool> getShouldReconnect() async => _shouldReconnect;

  // Have to do Future based API to match mox implementation.
  @override
  Future<void> setShouldReconnect(bool value) async {
    _shouldReconnect = value;
    if (!value) {
      _cancelBackoff();
      _reconnectionInProgress = false;
    }
  }

  @override
  Future<bool> canTriggerFailure() async =>
      await canTryReconnecting() &&
      await getShouldReconnect() &&
      _markReconnecting();

  bool _markReconnecting() {
    _reconnectionInProgress = true;
    return true;
  }

  @override
  Future<void> onFailure() async {
    if (!await getIsReconnecting()) return;
    _cancelBackoff();
    _backoffTimer = Timer(
      strategy.delay(_reconnectionAttempts),
      () => unawaited(_fireBackoffReconnect()),
    );
  }

  Future<void> triggerImmediateReconnect() async {
    if (!await getShouldReconnect()) return;
    final hasBackoff = _backoffTimer != null;
    _cancelBackoff();
    if (hasBackoff) {
      await _fireBackoffReconnect();
      return;
    }

    if (!await canTryReconnecting()) return;
    _reconnectionInProgress = true;
    try {
      await _reconnect();
    } finally {
      _reconnectionInProgress = false;
    }
  }

  void _cancelBackoff() {
    _backoffTimer?.cancel();
    _backoffTimer = null;
  }

  Future<void> _fireBackoffReconnect() async {
    _cancelBackoff();
    try {
      if (!await getShouldReconnect()) return;
      if (!await getIsReconnecting()) return;
      await _reconnect();
    } finally {
      _reconnectionInProgress = false;
    }
  }

  Future<void> _reconnect() async {
    _reconnectionAttempts++;
    if (performReconnect case final reconnect?) {
      await reconnect();
    }
  }

  @override
  Future<void> onSuccess() async {
    _reconnectionAttempts = 0;
    await reset();
  }

  @override
  Future<void> reset() async {
    _cancelBackoff();
    _reconnectionInProgress = false;
    // _shouldReconnect = false;
  }
}

class IOEndpoint {
  const IOEndpoint(this.host, this.port);

  final String host;
  final int port;
}

class XmppConnectivityManager extends mox.ConnectivityManager {
  XmppConnectivityManager._(
    this._endpoints, {
    required String? Function() domainProvider,
    Duration? pollInterval,
    Duration? waitTimeout,
    this.shouldContinue,
  })  : _domainProvider = domainProvider,
        _pollInterval = pollInterval ?? timeoutDuration,
        _waitTimeout = waitTimeout ?? const Duration(minutes: 1);

  final List<IOEndpoint> _endpoints;
  final String? Function() _domainProvider;
  final Future<bool> Function()? shouldContinue;

  final Duration _pollInterval;
  final Duration? _waitTimeout;

  static final _log = Logger('XmppConnectivityManager');

  XmppConnectivityManager.forXmppConnection({
    required String? Function() domainProvider,
    required Future<bool> Function() shouldContinue,
    Duration? pollInterval,
    Duration? waitTimeout,
  }) : this._(
          const [],
          domainProvider: domainProvider,
          pollInterval: pollInterval,
          waitTimeout: waitTimeout,
          shouldContinue: shouldContinue,
        );

  static const timeoutDuration = Duration(seconds: 5);
  static const _offlineErrnos = <int>{
    50, // ENETDOWN (macOS)
    51, // ENETUNREACH (macOS)
    64, // EHOSTDOWN (macOS)
    65, // EHOSTUNREACH (macOS)
    101, // ENETUNREACH (Linux)
    113, // EHOSTUNREACH (Linux)
    10050, // WSAENETDOWN (Windows)
    10051, // WSAENETUNREACH (Windows)
    10065, // WSAEHOSTUNREACH (Windows)
  };

  @override
  Future<bool> hasConnection() {
    final endpoints = _resolveEndpoints();
    if (endpoints.isEmpty) {
      return Future.value(true);
    }
    return _pingEndpoints(endpoints);
  }

  @override
  Future<void> waitForConnection() async {
    if (shouldContinue != null && !await shouldContinue!()) return;

    final stopwatch = Stopwatch()..start();
    var hasWarned = false;
    while (!await hasConnection()) {
      if (shouldContinue != null && !await shouldContinue!()) return;

      final timeout = _waitTimeout;
      if (timeout != null && stopwatch.elapsed >= timeout && !hasWarned) {
        _log.warning(
          'Connectivity still unavailable after ${timeout.inSeconds} seconds. Holding reconnection until connectivity resumes.',
        );
        hasWarned = true;
      }
      await Future.delayed(_pollInterval);
    }
  }

  List<IOEndpoint> _resolveEndpoints() {
    final rawDomain = _domainProvider();
    if (rawDomain == null) return _endpoints;
    final domain = rawDomain.trim().toLowerCase();
    if (domain.isEmpty) return _endpoints;
    final endpoint = serverLookup[domain];
    if (endpoint == null) return _endpoints;
    return [endpoint];
  }

  bool _isOfflineSocketError(SocketException error) {
    final code = error.osError?.errorCode;
    if (code != null && _offlineErrnos.contains(code)) {
      return true;
    }
    final message = error.message.toLowerCase();
    return message.contains('network is unreachable') ||
        message.contains('no route to host') ||
        message.contains('not connected');
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
      } on SocketException catch (error) {
        socket?.destroy();
        if (!_isOfflineSocketError(error)) {
          return true;
        }
      }
    }
    return false;
  }
}
