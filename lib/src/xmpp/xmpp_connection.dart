part of 'package:axichat/src/xmpp/xmpp_service.dart';

class XmppConnection extends mox.XmppConnection {
  XmppConnection({
    XmppReconnectionPolicy? reconnectionPolicy,
    XmppConnectivityManager? connectivityManager,
    XmppClientNegotiator? negotiationsHandler,
    this.socketWrapper,
  }) : super(
          reconnectionPolicy:
              reconnectionPolicy ?? XmppReconnectionPolicy.exponential(),
          connectivityManager:
              connectivityManager ?? XmppConnectivityManager.pingDns(),
          negotiationsHandler: negotiationsHandler ?? XmppClientNegotiator(),
          socket: socketWrapper ?? XmppSocketWrapper(),
        );

  final XmppSocketWrapper? socketWrapper;

  // Check if we have a connectionSettings as it is marked [late] in mox.
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
      case == mox.ChatStateManager:
        return getManagerById(mox.chatStateManager);
      case == mox.CarbonsManager:
        return getManagerById(mox.carbonsManager);
      case == mox.BlockingManager:
        return getManagerById(mox.blockingManager);
      case == mox.CSIManager:
        return getManagerById(mox.csiManager);
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
      );
      return true;
    }

    return false;
  }

  Future<bool> sendChatMarker({
    required String to,
    required String stanzaID,
    required mox.ChatMarker marker,
  }) async {
    if (getManager<mox.MessageManager>() case final mm?) {
      await mm.sendMessage(
        mox.JID.fromString(to),
        mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
          mox.ChatMarkerData(marker, stanzaID),
        ]),
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
  }) async {
    if (getManager<mox.ChatStateManager>() case final cm?) {
      return await cm.sendChatState(
        state,
        jid,
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

  bool get reachedMaxAttempts => _reconnectionAttempts >= strategy.maxAttempts;

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
  Future<bool> canTryReconnecting() async =>
      !_reconnectionInProgress && !reachedMaxAttempts;

  // Have to do Future based API to match mox implementation.
  @override
  Future<bool> getShouldReconnect() async => _shouldReconnect;

  // Have to do Future based API to match mox implementation.
  @override
  Future<void> setShouldReconnect(bool value) async => _shouldReconnect = value;

  @override
  Future<bool> canTriggerFailure() async =>
      await canTryReconnecting() && await getShouldReconnect();

  @override
  Future<void> onFailure() async {
    if (!await canTriggerFailure()) return;
    _reconnectionInProgress = true;
    try {
      await Future.delayed(strategy.delay(_reconnectionAttempts));
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

  final String host;
  final int port;
}

class XmppConnectivityManager extends mox.ConnectivityManager {
  XmppConnectivityManager._(
    this.endpoints, {
    Duration? pollInterval,
    Duration? waitTimeout,
  })  : _pollInterval = pollInterval ?? timeoutDuration,
        _waitTimeout = waitTimeout ?? const Duration(minutes: 1);

  final List<IOEndpoint> endpoints;

  final Duration _pollInterval;
  final Duration? _waitTimeout;

  static final _log = Logger('XmppConnectivityManager');

  // fdns1.dismail.de, fdns2.dismail.de, 1.1.1.1
  XmppConnectivityManager.pingDns()
      : this._(const [
          IOEndpoint('116.203.32.217', 853),
          IOEndpoint('159.69.114.157', 853),
          IOEndpoint('1.1.1.1', 853),
        ]);

  static const timeoutDuration = Duration(seconds: 5);

  @override
  Future<bool> hasConnection() => _pingEndpoints();

  @override
  Future<void> waitForConnection() async {
    final stopwatch = Stopwatch()..start();
    var connected = await hasConnection();
    while (!connected) {
      final timeout = _waitTimeout;
      if (timeout != null && stopwatch.elapsed >= timeout) {
        _log.warning(
          'Gave up waiting for connectivity after ${timeout.inSeconds} seconds.',
        );
        break;
      }
      await Future.delayed(_pollInterval);
      connected = await hasConnection();
    }
  }

  Future<bool> _pingEndpoints() async {
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
