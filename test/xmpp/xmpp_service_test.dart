import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:axichat/main.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/storage/chat_calendar_storage.dart';
import 'package:axichat/src/calendar/storage/storage_builders.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_state.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_state_store.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/xmpp/pubsub/conversation_index_manager.dart';
import 'package:axichat/src/xmpp/connection/foreground_socket.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_forms.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/settings_pubsub_manager.dart';
import 'package:axichat/src/xmpp/muc/occupant.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:moxxmpp/src/managers/attributes.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks.dart';

class MockPresenceManager extends Mock implements XmppPresenceManager {}

class MockUserAvatarManager extends Mock implements mox.UserAvatarManager {}

class MockPubSubManager extends Mock implements mox.PubSubManager {}

class MockDiscoManager extends Mock implements mox.DiscoManager {}

class FakeJid extends Fake implements mox.JID {}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

class _InMemoryStorage implements Storage {
  final Map<String, dynamic> _store = <String, dynamic>{};

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> close() async => _store.clear();

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  dynamic read(String key) => _store[key];

  @override
  Future<void> write(String key, dynamic value) async {
    _store[key] = value;
  }
}

void _stubStateStoreValues(Map<String, Object?> values) {
  when(() => mockStateStore.read(key: any(named: 'key'))).thenAnswer((
    invocation,
  ) {
    final key = invocation.namedArguments[#key] as RegisteredStateKey;
    return values[key.value];
  });
  when(() => mockStateStore.writeAll(data: any(named: 'data'))).thenAnswer((
    invocation,
  ) async {
    final data =
        invocation.namedArguments[#data] as Map<RegisteredStateKey, Object?>;
    for (final entry in data.entries) {
      values[entry.key.value] = entry.value;
    }
    return true;
  });
  when(
    () => mockStateStore.write(
      key: any(named: 'key'),
      value: any(named: 'value'),
    ),
  ).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key] as RegisteredStateKey;
    values[key.value] = invocation.namedArguments[#value];
    return true;
  });
  when(() => mockStateStore.delete(key: any(named: 'key'))).thenAnswer((
    invocation,
  ) async {
    final key = invocation.namedArguments[#key] as RegisteredStateKey;
    values.remove(key.value);
    return true;
  });
}

Uint8List _validPngBytes() => Uint8List.fromList(const <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class _FakeForegroundBridge implements ForegroundTaskBridge {
  final Set<String> acquiredClients = <String>{};
  final Map<String, ForegroundTaskMessageHandler> _listeners =
      <String, ForegroundTaskMessageHandler>{};

  @override
  Future<bool> isRunning() async => acquiredClients.isNotEmpty;

  @override
  Future<void> acquire({
    required String clientId,
    ForegroundServiceConfig? config,
  }) async {
    acquiredClients.add(clientId);
  }

  @override
  Future<void> release(String clientId) async {
    acquiredClients.remove(clientId);
  }

  @override
  Future<void> send(List<Object> parts) async {}

  @override
  void registerListener(String clientId, ForegroundTaskMessageHandler handler) {
    _listeners[clientId] = handler;
  }

  @override
  void unregisterListener(String clientId) {
    _listeners.remove(clientId);
  }
}

class RecordingMamManager extends mox.MAMManager {
  int queryCount = 0;
  mox.JID? lastTo;
  mox.MAMQueryOptions? lastOptions;
  mox.ResultSetManagement? lastRsm;
  Duration? lastTimeout;

  @override
  Future<mox.MAMQueryResult?> queryArchive({
    mox.JID? to,
    mox.MAMQueryOptions? options,
    mox.ResultSetManagement? rsm,
    Duration? timeout,
  }) async {
    queryCount += 1;
    lastTo = to;
    lastOptions = options;
    lastRsm = rsm;
    lastTimeout = timeout;
    return const mox.MAMQueryResult(
      messages: <mox.MAMMessage>[],
      complete: true,
    );
  }
}

class MamQueryCall {
  const MamQueryCall({
    required this.to,
    required this.withJid,
    required this.start,
    required this.before,
    required this.after,
    required this.max,
  });

  final String? to;
  final String? withJid;
  final DateTime? start;
  final String? before;
  final String? after;
  final int? max;
}

class ScriptedMamPage {
  const ScriptedMamPage({
    this.events = const <mox.XmppEvent>[],
    required this.complete,
    this.first,
    this.last,
    this.count,
    this.release,
    this.pumpTimes = 20,
  });

  final List<mox.XmppEvent> events;
  final bool complete;
  final String? first;
  final String? last;
  final int? count;
  final Future<void>? release;
  final int pumpTimes;
}

class ScriptedMamManager extends mox.MAMManager {
  ScriptedMamManager({
    required this.eventStreamController,
    List<ScriptedMamPage> pages = const <ScriptedMamPage>[],
  }) : _pages = ListQueue<ScriptedMamPage>.of(pages);

  final StreamController<mox.XmppEvent> eventStreamController;
  final ListQueue<ScriptedMamPage> _pages;
  final List<MamQueryCall> calls = <MamQueryCall>[];
  final Completer<void> firstQueryStarted = Completer<void>();

  int get queryCount => calls.length;

  @override
  Future<mox.MAMQueryResult?> queryArchive({
    mox.JID? to,
    mox.MAMQueryOptions? options,
    mox.ResultSetManagement? rsm,
    Duration? timeout,
  }) async {
    calls.add(
      MamQueryCall(
        to: to?.toString(),
        withJid: options?.withJid?.toString(),
        start: options?.start,
        before: rsm?.before,
        after: rsm?.after,
        max: rsm?.max,
      ),
    );
    if (!firstQueryStarted.isCompleted) {
      firstQueryStarted.complete();
    }
    if (_pages.isEmpty) {
      throw Exception('Unexpected MAM query');
    }
    final page = _pages.removeFirst();
    for (final event in page.events) {
      eventStreamController.add(event);
    }
    await pumpEventQueue(times: page.pumpTimes);
    final release = page.release;
    if (release != null) {
      await release;
    }
    return mox.MAMQueryResult(
      messages: const <mox.MAMMessage>[],
      complete: page.complete,
      rsm: mox.ResultSetManagement(
        first: page.first,
        last: page.last,
        count: page.count,
      ),
    );
  }
}

class BlockingMamManager extends RecordingMamManager {
  final Completer<void> queryStarted = Completer<void>();
  final Completer<void> finishQuery = Completer<void>();

  @override
  Future<mox.MAMQueryResult?> queryArchive({
    mox.JID? to,
    mox.MAMQueryOptions? options,
    mox.ResultSetManagement? rsm,
    Duration? timeout,
  }) async {
    queryCount += 1;
    lastTo = to;
    lastOptions = options;
    lastRsm = rsm;
    lastTimeout = timeout;
    if (!queryStarted.isCompleted) {
      queryStarted.complete();
    }
    await finishQuery.future;
    return const mox.MAMQueryResult(
      messages: <mox.MAMMessage>[],
      complete: true,
    );
  }
}

class RecordingAvatarPubSubManager extends PubSubManager {
  int publishCount = 0;
  final Map<String, int> _getItemsCountsByNode = <String, int>{};
  final Map<String, int> _getItemCountsByNode = <String, int>{};
  final Map<String, mox.XMLNode> _publishedItems = <String, mox.XMLNode>{};

  int getItemsCount(String node) => _getItemsCountsByNode[node] ?? 0;

  int getItemCount(String node) => _getItemCountsByNode[node] ?? 0;

  @override
  Future<moxlib.Result<mox.PubSubError, bool>> configureNode(
    mox.JID jid,
    String node,
    AxiPubSubNodeConfig config,
  ) async => const moxlib.Result(true);

  @override
  Future<String?> createNode(mox.JID jid, {String? nodeId}) async =>
      nodeId ?? 'created-node';

  @override
  Future<String?> createNodeWithConfig(
    mox.JID jid,
    mox.NodeConfig config, {
    String? nodeId,
  }) async => nodeId ?? 'created-node';

  @override
  Future<moxlib.Result<mox.PubSubError, bool>> publish(
    mox.JID jid,
    String node,
    mox.XMLNode payload, {
    String? id,
    mox.PubSubPublishOptions? options,
    bool autoCreate = false,
    mox.NodeConfig? createNodeConfig,
  }) async {
    publishCount += 1;
    final itemId = id ?? 'item-$publishCount';
    _publishedItems[_publishedKey(node, itemId)] = payload;
    return const moxlib.Result(true);
  }

  @override
  Future<moxlib.Result<mox.PubSubError, mox.PubSubItem>> getItem(
    mox.JID jid,
    String node,
    String id, {
    String? subId,
  }) async {
    _getItemCountsByNode[node] = getItemCount(node) + 1;
    final payload = _publishedItems[_publishedKey(node, id)];
    if (payload == null) {
      return moxlib.Result(mox.ItemNotFoundError());
    }
    return moxlib.Result(mox.PubSubItem(id: id, node: node, payload: payload));
  }

  @override
  Future<moxlib.Result<mox.PubSubError, List<mox.PubSubItem>>> getItems(
    mox.JID jid,
    String node, {
    int? maxItems,
    String? subId,
  }) async {
    _getItemsCountsByNode[node] = getItemsCount(node) + 1;
    final items = _publishedItems.entries
        .where((entry) => entry.key.startsWith('$node|'))
        .map(
          (entry) => mox.PubSubItem(
            id: entry.key.split('|').last,
            node: node,
            payload: entry.value,
          ),
        )
        .toList(growable: false);
    if (items.isEmpty) {
      return moxlib.Result(mox.ItemNotFoundError());
    }
    if (maxItems == null || items.length <= maxItems) {
      return moxlib.Result(items);
    }
    return moxlib.Result(items.take(maxItems).toList(growable: false));
  }

  String _publishedKey(String node, String id) => '$node|$id';
}

class MissingInitialAvatarDataPubSubManager
    extends RecordingAvatarPubSubManager {
  @override
  Future<moxlib.Result<mox.PubSubError, mox.PubSubItem>> getItem(
    mox.JID jid,
    String node,
    String id, {
    String? subId,
  }) async {
    if (node == mox.userAvatarDataXmlns && publishCount <= 2) {
      _getItemCountsByNode[node] = getItemCount(node) + 1;
      return moxlib.Result(mox.ItemNotFoundError());
    }
    return super.getItem(jid, node, id, subId: subId);
  }
}

class _FirstPublishBlockingAvatarPubSub extends RecordingAvatarPubSubManager {
  final Completer<void> firstPublishStarted = Completer<void>();
  final Completer<void> allowFirstPublish = Completer<void>();
  var _blockedFirstPublish = false;

  @override
  Future<moxlib.Result<mox.PubSubError, bool>> publish(
    mox.JID jid,
    String node,
    mox.XMLNode payload, {
    String? id,
    mox.PubSubPublishOptions? options,
    bool autoCreate = false,
    mox.NodeConfig? createNodeConfig,
  }) async {
    if (!_blockedFirstPublish) {
      _blockedFirstPublish = true;
      firstPublishStarted.complete();
      await allowFirstPublish.future;
    }
    return super.publish(
      jid,
      node,
      payload,
      id: id,
      options: options,
      autoCreate: autoCreate,
      createNodeConfig: createNodeConfig,
    );
  }
}

class _AvatarDataLookupBlockingPubSub extends RecordingAvatarPubSubManager {
  final Completer<void> dataGetStarted = Completer<void>();
  final Completer<void> allowDataGet = Completer<void>();
  var _blockedDataGet = false;

  @override
  Future<moxlib.Result<mox.PubSubError, mox.PubSubItem>> getItem(
    mox.JID jid,
    String node,
    String id, {
    String? subId,
  }) async {
    if (node == mox.userAvatarDataXmlns && !_blockedDataGet) {
      _blockedDataGet = true;
      dataGetStarted.complete();
      await allowDataGet.future;
    }
    return super.getItem(jid, node, id, subId: subId);
  }
}

class FailingAvatarPubSubManager extends RecordingAvatarPubSubManager {
  @override
  Future<moxlib.Result<mox.PubSubError, bool>> publish(
    mox.JID jid,
    String node,
    mox.XMLNode payload, {
    String? id,
    mox.PubSubPublishOptions? options,
    bool autoCreate = false,
    mox.NodeConfig? createNodeConfig,
  }) async {
    publishCount += 1;
    return moxlib.Result(mox.UnknownPubSubError());
  }
}

class RecordingSettingsPubSubTransport extends PubSubManager {
  int publishCount = 0;
  int subscribeCount = 0;
  final Map<String, mox.XMLNode> publishedItems = <String, mox.XMLNode>{};

  @override
  Future<moxlib.Result<mox.PubSubError, bool>> configureNode(
    mox.JID jid,
    String node,
    AxiPubSubNodeConfig config,
  ) async => const moxlib.Result(true);

  @override
  Future<String?> createNode(mox.JID jid, {String? nodeId}) async =>
      nodeId ?? 'created-node';

  @override
  Future<String?> createNodeWithConfig(
    mox.JID jid,
    mox.NodeConfig config, {
    String? nodeId,
  }) async => nodeId ?? 'created-node';

  @override
  Future<moxlib.Result<mox.PubSubError, mox.SubscriptionInfo>> subscribe(
    mox.JID jid,
    String node,
  ) async {
    subscribeCount += 1;
    return moxlib.Result(
      mox.SubscriptionInfo(
        jid: jid.toBare().toString(),
        node: node,
        state: mox.SubscriptionState.subscribed,
      ),
    );
  }

  @override
  Future<moxlib.Result<mox.PubSubError, bool>> publish(
    mox.JID jid,
    String node,
    mox.XMLNode payload, {
    String? id,
    mox.PubSubPublishOptions? options,
    bool autoCreate = false,
    mox.NodeConfig? createNodeConfig,
  }) async {
    publishCount += 1;
    final itemId = id ?? 'item-$publishCount';
    publishedItems['$node|$itemId'] = payload;
    return const moxlib.Result(true);
  }

  @override
  Future<moxlib.Result<mox.PubSubError, mox.PubSubItem>> getItem(
    mox.JID jid,
    String node,
    String id, {
    String? subId,
  }) async {
    final payload = publishedItems['$node|$id'];
    if (payload == null) {
      return moxlib.Result(mox.ItemNotFoundError());
    }
    return moxlib.Result(mox.PubSubItem(id: id, node: node, payload: payload));
  }

  @override
  Future<moxlib.Result<mox.PubSubError, List<mox.PubSubItem>>> getItems(
    mox.JID jid,
    String node, {
    int? maxItems,
    String? subId,
  }) async {
    final items = publishedItems.entries
        .where((entry) => entry.key.startsWith('$node|'))
        .map(
          (entry) => mox.PubSubItem(
            id: entry.key.split('|').last,
            node: node,
            payload: entry.value,
          ),
        )
        .toList(growable: false);
    if (items.isEmpty) {
      return moxlib.Result(mox.ItemNotFoundError());
    }
    if (maxItems == null || items.length <= maxItems) {
      return moxlib.Result(items);
    }
    return moxlib.Result(items.take(maxItems).toList(growable: false));
  }

  @override
  Future<moxlib.Result<mox.PubSubError, bool>> retract(
    mox.JID host,
    String node,
    String itemId, {
    bool notify = false,
    String? reason,
  }) async {
    publishedItems.remove('$node|$itemId');
    return const moxlib.Result(true);
  }
}

Future<SettingsPubSubManager> registerSettingsPubSubManager({
  required XmppConnection connection,
  required PubSubManager pubSubManager,
}) async {
  T? lookupManagerById<T extends mox.XmppManagerBase>(String id) {
    if (id == mox.pubsubManager) {
      return pubSubManager as T;
    }
    return null;
  }

  final attributes = XmppManagerAttributes(
    sendStanza: (details) async => await connection.sendStanza(details),
    sendNonza: (_) {},
    getManagerById: lookupManagerById,
    sendEvent: (_) {},
    getConnectionSettings: () => connection.connectionSettings,
    getFullJID: () => connection.connectionSettings.jid,
    getSocket: () => connection.socketWrapper,
    getConnection: () => connection,
    getNegotiatorById: <T extends mox.XmppFeatureNegotiatorBase>(String _) =>
        null,
  );

  pubSubManager.register(attributes);
  if (!pubSubManager.initialized) {
    await pubSubManager.postRegisterCallback();
  }

  final settingsManager = SettingsPubSubManager()..register(attributes);
  await settingsManager.postRegisterCallback();
  return settingsManager;
}

void stubSettingsSyncStateStore(Map<String, Object?> storeData) {
  when(() => mockStateStore.read(key: any(named: 'key'))).thenAnswer((
    invocation,
  ) {
    final key = invocation.namedArguments[#key]! as RegisteredStateKey;
    return storeData[key.value];
  });
  when(
    () => mockStateStore.write(
      key: any(named: 'key'),
      value: any(named: 'value'),
    ),
  ).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key]! as RegisteredStateKey;
    storeData[key.value] = invocation.namedArguments[#value];
    return true;
  });
}

void stubUnsafeBootstrapManagersUnavailable() {
  when(() => mockConnection.getManager<mox.DiscoManager>()).thenReturn(null);
  when(() => mockConnection.getManager<mox.PubSubManager>()).thenReturn(null);
}

Future<void> _openXmppStateStore(String name) async {
  final tempDir = await Directory.systemTemp.createTemp(name);
  Hive.init(tempDir.path);
  await Hive.openBox(XmppStateStore.boxName);
  addTearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });
}

String _calendarEnvelope(CalendarSyncMessage message) =>
    jsonEncode({'calendar_sync': message.toJson()});

CalendarTask _task({
  required String id,
  required String title,
  required DateTime timestamp,
}) {
  return CalendarTask(
    id: id,
    title: title,
    createdAt: timestamp,
    modifiedAt: timestamp,
  );
}

CalendarSyncMessage _taskUpdate({
  required CalendarTask task,
  required String operation,
  DateTime? timestamp,
}) {
  return CalendarSyncMessage(
    type: CalendarSyncType.update,
    timestamp: timestamp ?? task.modifiedAt,
    taskId: task.id,
    operation: operation,
    data: task.toJson(),
  );
}

CalendarSyncMessage _inlineSnapshot({
  required CalendarModel model,
  required DateTime timestamp,
  int snapshotVersion = 1,
  String? checksum,
}) {
  final snapshotChecksum = checksum ?? model.calculateChecksum();
  return CalendarSyncMessage(
    type: CalendarSyncType.snapshot,
    timestamp: timestamp,
    data: model.toJson(),
    checksum: snapshotChecksum,
    isSnapshot: true,
    snapshotChecksum: snapshotChecksum,
    snapshotVersion: snapshotVersion,
  );
}

mox.MessageEvent _personalCalendarMamEvent({
  required String selfBare,
  required String stanzaId,
  required DateTime timestamp,
  required CalendarSyncMessage message,
}) {
  final jid = mox.JID.fromString(selfBare);
  return mox.MessageEvent(
    jid,
    jid,
    false,
    mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
      mox.MessageBodyData(_calendarEnvelope(message)),
      mox.MessageIdData(stanzaId),
      mox.DelayedDeliveryData(jid, timestamp),
    ]),
    id: stanzaId,
    isFromMAM: true,
  );
}

mox.MessageEvent _directCalendarMamEvent({
  required String peerBare,
  required String selfBare,
  required String stanzaId,
  required DateTime timestamp,
  required CalendarSyncMessage message,
}) {
  final peerJid = mox.JID.fromString(peerBare);
  return mox.MessageEvent(
    peerJid,
    mox.JID.fromString(selfBare),
    false,
    mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
      mox.MessageBodyData(_calendarEnvelope(message)),
      mox.MessageIdData(stanzaId),
      mox.DelayedDeliveryData(peerJid, timestamp),
    ]),
    id: stanzaId,
    isFromMAM: true,
  );
}

mox.MessageEvent _groupCalendarMamEvent({
  required String roomJid,
  required String senderOccupantId,
  required String selfBare,
  required String stanzaId,
  required DateTime timestamp,
  required CalendarSyncMessage message,
}) {
  return mox.MessageEvent(
    mox.JID.fromString(senderOccupantId),
    mox.JID.fromString(selfBare),
    false,
    mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
      mox.MessageBodyData(_calendarEnvelope(message)),
      mox.MessageIdData(stanzaId),
      mox.DelayedDeliveryData(mox.JID.fromString(roomJid), timestamp),
    ]),
    id: stanzaId,
    isFromMAM: true,
    type: 'groupchat',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeUserAgent());
    registerFallbackValue(FakeStanzaDetails());
    registerFallbackValue(FakeMessageEvent());
    registerFallbackValue(FakeJid());
    registerFallbackValue(ReconnectTrigger.resume);
    registerFallbackValue(MessageNotificationChannel.chat);
    registerOmemoFallbacks();
  });

  late XmppService xmppService;
  late XmppDatabase database;
  late StreamController<mox.XmppEvent> eventStreamController;

  setUp(() {
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockNotificationService = MockNotificationService();
    database = XmppDrift(
      file: File(''),
      passphrase: '',
      executor: NativeDatabase.memory(),
    );
    eventStreamController = StreamController<mox.XmppEvent>.broadcast();

    prepareMockConnection();

    when(
      () => mockConnection.asBroadcastStream(),
    ).thenAnswer((_) => eventStreamController.stream);
  });

  tearDown(() async {
    await eventStreamController.close();
    await database.close();
    resetMocktailState();
  });

  test(
    'connection-backed getters are safe before initializing a connection',
    () async {
      xmppService = XmppService(
        buildConnection: () => mockConnection,
        buildStateStore: (_, _) => mockStateStore,
        buildDatabase: (_, _) => database,
        notificationService: mockNotificationService,
      );
      addTearDown(() async {
        await xmppService.close();
      });

      expect(xmppService.hasConnectionSettings, isFalse);
      expect(xmppService.boundResource, isNull);
      expect(xmppService.saltedPassword, isNull);
      expect(xmppService.bookmarksManager, isNull);
      expect(xmppService.conversationIndexManager, isNull);
      expect(xmppService.pubSubSupport, isNotNull);
      expect(() => xmppService.pubSubSupportStream, returnsNormally);
    },
  );

  group('XmppService event handler', () {
    late mox.MessageEvent messageEvent;
    late Message message;

    setUp(() async {
      xmppService = XmppService(
        buildConnection: () => mockConnection,
        buildStateStore: (_, _) => mockStateStore,
        buildDatabase: (_, _) => database,
        notificationService: mockNotificationService,
      );
      await connectSuccessfully(xmppService);

      when(
        () => mockNotificationService.sendNotification(
          title: any(named: 'title'),
          body: any(named: 'body'),
          extraConditions: any(named: 'extraConditions'),
          allowForeground: any(named: 'allowForeground'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      messageEvent = generateRandomMessageEvent();
      message = Message.fromMox(messageEvent);
    });

    tearDown(() async {
      await xmppService.close();
      await pumpEventQueue();
    });

    tearDown(() {
      resetMocktailState();
    });

    test('When stream negotiations complete, requests the roster.', () async {
      when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
      when(() => mockConnection.requestRoster()).thenAnswer((_) async => null);
      when(
        () => mockConnection.requestBlocklist(),
      ).thenAnswer((_) async => null);

      verifyNever(() => mockConnection.requestRoster());

      eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));

      await pumpEventQueue();

      verify(() => mockConnection.requestRoster()).called(1);
    });

    test(
      'When stream negotiations resume, does not request the roster.',
      () async {
        when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
        when(
          () => mockConnection.requestRoster(),
        ).thenAnswer((_) async => null);
        when(
          () => mockConnection.requestBlocklist(),
        ).thenAnswer((_) async => null);

        verifyNever(() => mockConnection.requestRoster());

        eventStreamController.add(mox.StreamNegotiationsDoneEvent(true));

        await pumpEventQueue();

        verifyNever(() => mockConnection.requestRoster());
      },
    );

    test(
      'When stream negotiations complete, requests the blocklist.',
      () async {
        when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
        when(
          () => mockConnection.requestRoster(),
        ).thenAnswer((_) async => null);
        when(
          () => mockConnection.requestBlocklist(),
        ).thenAnswer((_) async => null);

        verifyNever(() => mockConnection.requestBlocklist());

        eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));

        await pumpEventQueue();

        verify(() => mockConnection.requestBlocklist()).called(1);
      },
    );

    test('When stream negotiations resume, requests the blocklist.', () async {
      when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
      when(() => mockConnection.requestRoster()).thenAnswer((_) async => null);
      when(
        () => mockConnection.requestBlocklist(),
      ).thenAnswer((_) async => null);

      verifyNever(() => mockConnection.requestBlocklist());

      eventStreamController.add(mox.StreamNegotiationsDoneEvent(true));

      await pumpEventQueue();

      verify(() => mockConnection.requestBlocklist()).called(1);
    });

    test(
      'When stream negotiations complete, connecting state becomes connected.',
      () async {
        final states = <ConnectionState>[];
        final subscription = xmppService.connectivityStream.listen(states.add);
        addTearDown(subscription.cancel);

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connecting,
            mox.XmppConnectionState.notConnected,
          ),
        );
        await pumpEventQueue();

        expect(xmppService.connectionState, ConnectionState.connecting);

        eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
        await pumpEventQueue();

        expect(xmppService.connectionState, ConnectionState.connected);
        expect(
          states,
          containsAllInOrder([
            ConnectionState.connecting,
            ConnectionState.connected,
          ]),
        );
        verify(() => mockConnection.completeReconnect()).called(1);
      },
    );

    test(
      'When stream negotiations complete, does not manually send initial presence.',
      () async {
        final presenceManager = MockPresenceManager();
        when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
        when(
          () => mockConnection.requestRoster(),
        ).thenAnswer((_) async => null);
        when(
          () => mockConnection.requestBlocklist(),
        ).thenAnswer((_) async => null);
        when(
          () => mockConnection.getManager<XmppPresenceManager>(),
        ).thenReturn(presenceManager);

        eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));

        await pumpEventQueue();

        verifyNever(() => presenceManager.sendInitialPresence());
      },
    );

    test(
      'When stream negotiations resume, does not manually send initial presence.',
      () async {
        final presenceManager = MockPresenceManager();
        when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
        when(
          () => mockConnection.requestRoster(),
        ).thenAnswer((_) async => null);
        when(
          () => mockConnection.requestBlocklist(),
        ).thenAnswer((_) async => null);
        when(
          () => mockConnection.getManager<XmppPresenceManager>(),
        ).thenReturn(presenceManager);
        eventStreamController.add(mox.StreamNegotiationsDoneEvent(true));

        await pumpEventQueue();

        verifyNever(() => presenceManager.sendInitialPresence());
      },
    );

    test('When a resource is bound, stores the bound resource.', () async {
      when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
      when(() => mockConnection.requestRoster()).thenAnswer((_) async => null);
      when(
        () => mockConnection.requestBlocklist(),
      ).thenAnswer((_) async => null);
      await connectSuccessfully(xmppService);

      eventStreamController.add(mox.ResourceBoundEvent('axi-res'));

      await pumpEventQueue();

      expect(xmppService.resource, equals('axi-res'));
      verify(
        () => mockStateStore.write(
          key: xmppService.resourceStorageKey,
          value: 'axi-res',
        ),
      ).called(1);
    });

    test('disconnect delegates graceful presence to mox disconnect.', () async {
      final presenceManager = MockPresenceManager();
      when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
      when(
        () => mockConnection.getManager<XmppPresenceManager>(),
      ).thenReturn(presenceManager);
      when(
        () => presenceManager.sendUnavailablePresenceForDisconnect(),
      ).thenAnswer((_) async {});
      when(() => mockConnection.disconnect()).thenAnswer((_) async {});

      await connectSuccessfully(xmppService);
      eventStreamController.add(
        mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.connected,
          mox.XmppConnectionState.connecting,
        ),
      );
      await pumpEventQueue();
      clearInteractions(presenceManager);
      clearInteractions(mockConnection);

      await xmppService.disconnect();

      verifyNever(() => presenceManager.sendUnavailablePresenceForDisconnect());
      verify(() => mockConnection.disconnect()).called(1);
    });

    test(
      'disconnect tears down mox when service state is already notConnected.',
      () async {
        final presenceManager = MockPresenceManager();
        when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
        when(
          () => mockConnection.getManager<XmppPresenceManager>(),
        ).thenReturn(presenceManager);
        when(
          () => presenceManager.sendUnavailablePresenceForDisconnect(),
        ).thenAnswer((_) async {});
        when(() => mockConnection.disconnect()).thenAnswer((_) async {});
        when(
          () => mockConnection.getConnectionState(),
        ).thenAnswer((_) async => mox.XmppConnectionState.connected);

        await connectSuccessfully(xmppService);
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.notConnected,
            mox.XmppConnectionState.connected,
          ),
        );
        await pumpEventQueue();
        clearInteractions(mockConnection);

        await xmppService.disconnect();

        verify(() => mockConnection.disconnect()).called(1);
      },
    );

    test(
      'disconnect still resets when mox connection state probe fails.',
      () async {
        when(
          () => mockConnection.getConnectionState(),
        ).thenThrow(Exception('state failed'));
        when(() => mockConnection.disconnect()).thenAnswer((_) async {});

        await xmppService.disconnect();

        verifyNever(() => mockConnection.disconnect());
        expect(xmppService.connectionState, ConnectionState.notConnected);
      },
    );

    test(
      'saveSelfAvatar stores locally before stream-ready and publishes after negotiations complete.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-save-self-avatar-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final pubsubManager = RecordingAvatarPubSubManager();
        final stateStoreValues = <String, Object?>{};
        final events = <XmppOperationEvent>[];
        final subscription = xmppService.xmppOperationStream.listen(events.add);
        addTearDown(subscription.cancel);
        try {
          when(() => mockStateStore.read(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            return stateStoreValues[key.value];
          });
          when(
            () => mockStateStore.writeAll(data: any(named: 'data')),
          ).thenAnswer((invocation) async {
            final data =
                invocation.namedArguments[#data]
                    as Map<RegisteredStateKey, Object?>;
            for (final entry in data.entries) {
              stateStoreValues[entry.key.value] = entry.value;
            }
            return true;
          });
          when(
            () => mockStateStore.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            ),
          ).thenAnswer((invocation) async {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            stateStoreValues[key.value] = invocation.namedArguments[#value];
            return true;
          });
          when(() => mockStateStore.delete(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) async {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            stateStoreValues.remove(key.value);
            return true;
          });
          when(
            () => mockConnection.getManager<PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(null);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);

          final result = await xmppService.saveSelfAvatar(
            AvatarUploadPayload(
              bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: 'saved-avatar-hash',
            ),
          );

          expect(result.hash, 'saved-avatar-hash');
          expect((await xmppService.getOwnAvatar())?.hash, 'saved-avatar-hash');
          expect(pubsubManager.publishCount, equals(0));
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNotNull,
          );

          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue(times: 20);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await pumpEventQueue(times: 20);

          expect(pubsubManager.publishCount, equals(2));
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNull,
          );
          final publishEvents = events
              .where(
                (event) => event.kind == XmppOperationKind.selfAvatarPublish,
              )
              .toList(growable: false);
          expect(publishEvents, hasLength(2));
          expect(publishEvents.first.stage, XmppOperationStage.start);
          expect(publishEvents.last.stage, XmppOperationStage.end);
          expect(publishEvents.last.isSuccess, isTrue);
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'pending self avatar is cleared without upload when metadata and data already match.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-save-self-avatar-already-published-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final pubsubManager = RecordingAvatarPubSubManager();
        final stateStoreValues = <String, Object?>{};
        final avatarBytes = _validPngBytes();
        final avatarHash = sha1.convert(avatarBytes).toString();
        final metadataPayload =
            (mox.XmlBuilder.withNamespace(
                  'metadata',
                  mox.userAvatarMetadataXmlns,
                )..child(
                  (mox.XmlBuilder('info')
                        ..attr('id', avatarHash)
                        ..attr('bytes', avatarBytes.length.toString())
                        ..attr('type', 'image/png')
                        ..attr('width', '1')
                        ..attr('height', '1'))
                      .build(),
                ))
                .build();
        final dataPayload = (mox.XmlBuilder.withNamespace(
          'data',
          mox.userAvatarDataXmlns,
        )..text(base64Encode(avatarBytes))).build();

        try {
          _stubStateStoreValues(stateStoreValues);
          when(
            () => mockConnection.getManager<PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(null);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);
          await pubsubManager.publish(
            mox.JID.fromString('jid@axi.im'),
            mox.userAvatarMetadataXmlns,
            metadataPayload,
            id: avatarHash,
          );
          await pubsubManager.publish(
            mox.JID.fromString('jid@axi.im'),
            mox.userAvatarDataXmlns,
            dataPayload,
            id: avatarHash,
          );
          pubsubManager.publishCount = 0;

          final result = await xmppService.saveSelfAvatar(
            AvatarUploadPayload(
              bytes: avatarBytes,
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: avatarHash,
            ),
          );

          expect(result.hash, avatarHash);
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNotNull,
          );

          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue(times: 20);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await pumpEventQueue(times: 20);

          expect(pubsubManager.publishCount, equals(0));
          expect(
            pubsubManager.getItemCount(mox.userAvatarDataXmlns),
            equals(1),
          );
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNull,
          );
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'pending self avatar hydrates local cache when remote data already matches.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-save-self-avatar-hydrate-published-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final pubsubManager = RecordingAvatarPubSubManager();
        final stateStoreValues = <String, Object?>{};
        final avatarBytes = _validPngBytes();
        final avatarHash = sha1.convert(avatarBytes).toString();
        final metadataPayload =
            (mox.XmlBuilder.withNamespace(
                  'metadata',
                  mox.userAvatarMetadataXmlns,
                )..child(
                  (mox.XmlBuilder('info')
                        ..attr('id', avatarHash)
                        ..attr('bytes', avatarBytes.length.toString())
                        ..attr('type', 'image/png')
                        ..attr('width', '1')
                        ..attr('height', '1'))
                      .build(),
                ))
                .build();
        final dataPayload = (mox.XmlBuilder.withNamespace(
          'data',
          mox.userAvatarDataXmlns,
        )..text(base64Encode(avatarBytes))).build();

        try {
          _stubStateStoreValues(stateStoreValues);
          when(
            () => mockConnection.getManager<PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(null);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);
          await pubsubManager.publish(
            mox.JID.fromString('jid@axi.im'),
            mox.userAvatarMetadataXmlns,
            metadataPayload,
            id: avatarHash,
          );
          await pubsubManager.publish(
            mox.JID.fromString('jid@axi.im'),
            mox.userAvatarDataXmlns,
            dataPayload,
            id: avatarHash,
          );
          pubsubManager.publishCount = 0;

          final result = await xmppService.saveSelfAvatar(
            AvatarUploadPayload(
              bytes: avatarBytes,
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: avatarHash,
            ),
          );
          await File(result.path).delete();

          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue(times: 20);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await pumpEventQueue(times: 20);

          expect(pubsubManager.publishCount, equals(0));
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNull,
          );
          final stored = await xmppService.getOwnAvatar();
          expect(stored?.hash, avatarHash);
          final storedBytes = await xmppService.loadAvatarBytes(stored!.path);
          expect(storedBytes, orderedEquals(avatarBytes));
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'pending self avatar hydration does not overwrite newer pending avatar.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-save-self-avatar-hydrate-stale-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final pubsubManager = _AvatarDataLookupBlockingPubSub();
        final stateStoreValues = <String, Object?>{};
        final oldBytes = _validPngBytes();
        final oldHash = sha1.convert(oldBytes).toString();
        final newBytes = Uint8List.fromList(<int>[..._validPngBytes(), 0]);
        final newHash = sha1.convert(newBytes).toString();
        final metadataPayload =
            (mox.XmlBuilder.withNamespace(
                  'metadata',
                  mox.userAvatarMetadataXmlns,
                )..child(
                  (mox.XmlBuilder('info')
                        ..attr('id', oldHash)
                        ..attr('bytes', oldBytes.length.toString())
                        ..attr('type', 'image/png')
                        ..attr('width', '1')
                        ..attr('height', '1'))
                      .build(),
                ))
                .build();
        final dataPayload = (mox.XmlBuilder.withNamespace(
          'data',
          mox.userAvatarDataXmlns,
        )..text(base64Encode(oldBytes))).build();

        try {
          _stubStateStoreValues(stateStoreValues);
          when(
            () => mockConnection.getManager<PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(null);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);
          await pubsubManager.publish(
            mox.JID.fromString('jid@axi.im'),
            mox.userAvatarMetadataXmlns,
            metadataPayload,
            id: oldHash,
          );
          await pubsubManager.publish(
            mox.JID.fromString('jid@axi.im'),
            mox.userAvatarDataXmlns,
            dataPayload,
            id: oldHash,
          );
          pubsubManager.publishCount = 0;

          final oldResult = await xmppService.saveSelfAvatar(
            AvatarUploadPayload(
              bytes: oldBytes,
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: oldHash,
            ),
          );
          expect(oldResult.hash, oldHash);

          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pubsubManager.dataGetStarted.future;

          final newResult = await xmppService.saveSelfAvatar(
            AvatarUploadPayload(
              bytes: newBytes,
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: newHash,
            ),
          );
          expect(newResult.hash, newHash);

          pubsubManager.allowDataGet.complete();
          await pumpEventQueue(times: 20);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await pumpEventQueue(times: 20);

          expect(pubsubManager.publishCount, equals(2));
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNull,
          );
          expect((await xmppService.getOwnAvatar())?.hash, newHash);
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'pending self avatar publishes when metadata matches but data is missing.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-save-self-avatar-metadata-without-data-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final pubsubManager = RecordingAvatarPubSubManager();
        final stateStoreValues = <String, Object?>{};
        final avatarBytes = _validPngBytes();
        final metadataPayload =
            (mox.XmlBuilder.withNamespace(
                  'metadata',
                  mox.userAvatarMetadataXmlns,
                )..child(
                  (mox.XmlBuilder('info')
                        ..attr('id', 'saved-avatar-hash')
                        ..attr('bytes', avatarBytes.length.toString())
                        ..attr('type', 'image/png')
                        ..attr('width', '1')
                        ..attr('height', '1'))
                      .build(),
                ))
                .build();

        try {
          _stubStateStoreValues(stateStoreValues);
          when(
            () => mockConnection.getManager<PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(null);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);
          await pubsubManager.publish(
            mox.JID.fromString('jid@axi.im'),
            mox.userAvatarMetadataXmlns,
            metadataPayload,
            id: 'saved-avatar-hash',
          );
          pubsubManager.publishCount = 0;

          final result = await xmppService.saveSelfAvatar(
            AvatarUploadPayload(
              bytes: avatarBytes,
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: 'saved-avatar-hash',
            ),
          );

          expect(result.hash, 'saved-avatar-hash');
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNotNull,
          );

          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue(times: 20);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await pumpEventQueue(times: 20);

          expect(pubsubManager.publishCount, equals(2));
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNull,
          );
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'missing metadata repair uses pending self avatar without duplicate upload.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-save-self-avatar-missing-metadata-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final metadataPubsubManager = MockPubSubManager();
        final publishPubsubManager = RecordingAvatarPubSubManager();
        final userAvatarManager = MockUserAvatarManager();
        final stateStoreValues = <String, Object?>{};
        final metadataGate = Completer<void>();

        try {
          _stubStateStoreValues(stateStoreValues);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(metadataPubsubManager);
          when(
            () => mockConnection.getManager<PubSubManager>(),
          ).thenReturn(publishPubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(userAvatarManager);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);
          when(
            () => metadataPubsubManager.getItems(
              any(),
              mox.userAvatarMetadataXmlns,
              maxItems: any(named: 'maxItems'),
            ),
          ).thenAnswer((_) async {
            await metadataGate.future;
            return moxlib.Result<mox.PubSubError, List<mox.PubSubItem>>(
              mox.ItemNotFoundError(),
            );
          });

          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue();

          final result = await xmppService.saveSelfAvatar(
            AvatarUploadPayload(
              bytes: _validPngBytes(),
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: 'saved-avatar-hash',
            ),
          );

          expect(result.hash, 'saved-avatar-hash');
          expect(publishPubsubManager.publishCount, equals(0));
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNotNull,
          );

          metadataGate.complete();
          await pumpEventQueue(times: 20);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await pumpEventQueue(times: 20);

          expect(publishPubsubManager.publishCount, equals(2));
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNull,
          );
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'pending self avatar publishes when metadata verification times out.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-save-self-avatar-metadata-timeout-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final metadataPubsubManager = MockPubSubManager();
        final publishPubsubManager = RecordingAvatarPubSubManager();
        final userAvatarManager = MockUserAvatarManager();
        final stateStoreValues = <String, Object?>{};
        final avatarBytes = _validPngBytes();
        final avatarHash = sha1.convert(avatarBytes).toString();

        try {
          _stubStateStoreValues(stateStoreValues);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(metadataPubsubManager);
          when(
            () => mockConnection.getManager<PubSubManager>(),
          ).thenReturn(publishPubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(userAvatarManager);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);
          when(
            () => metadataPubsubManager.getItems(
              any(),
              mox.userAvatarMetadataXmlns,
              maxItems: any(named: 'maxItems'),
            ),
          ).thenThrow(TimeoutException('metadata verification timed out'));

          final result = await xmppService.saveSelfAvatar(
            AvatarUploadPayload(
              bytes: avatarBytes,
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: avatarHash,
            ),
          );

          expect(result.hash, avatarHash);
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNotNull,
          );

          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue(times: 20);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await pumpEventQueue(times: 20);

          expect(publishPubsubManager.publishCount, equals(2));
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNull,
          );
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'pending self avatar publish failure emits operation failure event.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-save-self-avatar-publish-failure-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final pubsubManager = FailingAvatarPubSubManager();
        final userAvatarManager = MockUserAvatarManager();
        final stateStoreValues = <String, Object?>{};
        final events = <XmppOperationEvent>[];
        final subscription = xmppService.xmppOperationStream.listen(events.add);
        addTearDown(subscription.cancel);

        try {
          _stubStateStoreValues(stateStoreValues);
          when(
            () => mockConnection.getManager<PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(userAvatarManager);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);

          final result = await xmppService.saveSelfAvatar(
            AvatarUploadPayload(
              bytes: _validPngBytes(),
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: 'saved-avatar-hash',
            ),
          );

          expect(result.hash, 'saved-avatar-hash');
          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue(times: 20);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await pumpEventQueue(times: 20);

          final publishEvents = events
              .where(
                (event) => event.kind == XmppOperationKind.selfAvatarPublish,
              )
              .toList(growable: false);
          expect(publishEvents, hasLength(2));
          expect(publishEvents.first.stage, XmppOperationStage.start);
          expect(publishEvents.last.stage, XmppOperationStage.end);
          expect(publishEvents.last.isSuccess, isFalse);
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNotNull,
          );
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'pending self avatar clears after legacy cache path migration.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-save-self-avatar-legacy-pending-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        final avatarRoot = Directory(p.join(supportDir.path, 'avatars'));
        await avatarRoot.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final pubsubManager = RecordingAvatarPubSubManager();
        final userAvatarManager = MockUserAvatarManager();
        final stateStoreValues = <String, Object?>{};
        final avatarBytes = _validPngBytes();
        final avatarHash = sha1.convert(avatarBytes).toString();
        final legacyPath = p.join(avatarRoot.path, 'legacy-avatar.png');
        await File(legacyPath).writeAsBytes(avatarBytes, flush: true);

        try {
          _stubStateStoreValues(stateStoreValues);
          stateStoreValues[xmppService.selfAvatarPendingPublishKey.value] =
              jsonEncode(<String, Object?>{
                'path': legacyPath,
                'hash': avatarHash,
                'mime': 'image/png',
                'width': 1,
                'height': 1,
                'public': true,
                'jid': 'jid@axi.im',
              });
          when(
            () => mockConnection.getManager<PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(userAvatarManager);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);

          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue(times: 20);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await pumpEventQueue(times: 20);

          expect(pubsubManager.publishCount, equals(2));
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNull,
          );
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'missing metadata repair does not clear newer pending self avatar.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-self-avatar-repair-newer-pending-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final pubsubManager = _FirstPublishBlockingAvatarPubSub();
        final userAvatarManager = MockUserAvatarManager();
        final stateStoreValues = <String, Object?>{};
        final oldBytes = Uint8List.fromList(
          img.encodePng(img.Image(width: 1, height: 1)),
        );
        final oldHash = sha1.convert(oldBytes).toString();
        final newBytes = Uint8List.fromList(<int>[..._validPngBytes(), 0]);
        final newHash = sha1.convert(newBytes).toString();

        try {
          _stubStateStoreValues(stateStoreValues);
          when(
            () => mockConnection.getManager<PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(userAvatarManager);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);

          final oldResult = await xmppService.saveSelfAvatar(
            AvatarUploadPayload(
              bytes: oldBytes,
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: oldHash,
            ),
          );
          expect(oldResult.hash, oldHash);
          final repairBytes = await xmppService.loadAvatarBytes(oldResult.path);
          expect(repairBytes, isNotNull);
          expect(img.decodeImage(repairBytes!), isNotNull);
          stateStoreValues[xmppService.selfAvatarPendingPublishKey.value] =
              null;

          final repairFuture = xmppService.refreshSelfAvatarIfNeeded(
            force: true,
          );
          await pumpEventQueue(times: 10);
          await pubsubManager.firstPublishStarted.future.timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              fail(
                'Repair publish did not start. '
                'publishCount=${pubsubManager.publishCount} '
                'metadataGetItems=${pubsubManager.getItemsCount(mox.userAvatarMetadataXmlns)} '
                'pending=${stateStoreValues[xmppService.selfAvatarPendingPublishKey.value]} '
                'ownHash=${stateStoreValues[xmppService.selfAvatarHashKey.value]}',
              );
            },
          );

          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue(times: 10);

          final newResult = await xmppService.saveSelfAvatar(
            AvatarUploadPayload(
              bytes: newBytes,
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: newHash,
            ),
          );
          expect(newResult.hash, newHash);
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNotNull,
          );

          pubsubManager.allowFirstPublish.complete();
          await repairFuture;
          await pumpEventQueue(times: 20);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await pumpEventQueue(times: 20);

          expect(pubsubManager.publishCount, equals(4));
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNull,
          );
          expect((await xmppService.getOwnAvatar())?.hash, newHash);
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'publishAvatar verifies metadata and avatar data before reporting success.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-avatar-publish-verify-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final pubsubManager = RecordingAvatarPubSubManager();

        try {
          when(
            () => mockConnection.getManager<PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(null);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);

          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue();

          await xmppService.publishAvatar(
            AvatarUploadPayload(
              bytes: _validPngBytes(),
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: 'saved-avatar-hash',
            ),
          );

          expect(pubsubManager.publishCount, equals(2));
          expect(
            pubsubManager.getItemCount(mox.userAvatarDataXmlns),
            equals(1),
          );
          expect(
            pubsubManager.getItemCount(mox.userAvatarMetadataXmlns),
            equals(1),
          );
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'publishAvatar repairs acknowledged data publish that is not retrievable.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-avatar-publish-repair-data-verify-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final pubsubManager = MissingInitialAvatarDataPubSubManager();

        try {
          when(
            () => mockConnection.getManager<PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(null);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);

          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue();

          final result = await xmppService.publishAvatar(
            AvatarUploadPayload(
              bytes: _validPngBytes(),
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: 'saved-avatar-hash',
            ),
          );

          expect(result.hash, 'saved-avatar-hash');
          expect(pubsubManager.publishCount, equals(4));
          expect(
            pubsubManager.getItemCount(mox.userAvatarDataXmlns),
            greaterThanOrEqualTo(2),
          );
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'saveSelfAvatar still publishes after stream ready when a non-bootstrap self refresh is already running.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-save-self-avatar-running-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final metadataPubsubManager = MockPubSubManager();
        final publishPubsubManager = RecordingAvatarPubSubManager();
        final userAvatarManager = MockUserAvatarManager();
        final stateStoreValues = <String, Object?>{};
        final metadataGate = Completer<void>();
        final metadataPayload =
            (mox.XmlBuilder.withNamespace(
                  'metadata',
                  mox.userAvatarMetadataXmlns,
                )..child(
                  (mox.XmlBuilder('info')
                        ..attr('id', 'avatar-hash')
                        ..attr('bytes', '3')
                        ..attr('type', 'image/png')
                        ..attr('width', '1')
                        ..attr('height', '1'))
                      .build(),
                ))
                .build();
        final metadataItem = mox.PubSubItem(
          id: 'avatar-hash',
          node: mox.userAvatarMetadataXmlns,
          payload: metadataPayload,
        );
        try {
          when(() => mockStateStore.read(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            return stateStoreValues[key.value];
          });
          when(
            () => mockStateStore.writeAll(data: any(named: 'data')),
          ).thenAnswer((invocation) async {
            final data =
                invocation.namedArguments[#data]
                    as Map<RegisteredStateKey, Object?>;
            for (final entry in data.entries) {
              stateStoreValues[entry.key.value] = entry.value;
            }
            return true;
          });
          when(
            () => mockStateStore.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            ),
          ).thenAnswer((invocation) async {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            stateStoreValues[key.value] = invocation.namedArguments[#value];
            return true;
          });
          when(() => mockStateStore.delete(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) async {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            stateStoreValues.remove(key.value);
            return true;
          });
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(metadataPubsubManager);
          when(
            () => mockConnection.getManager<PubSubManager>(),
          ).thenReturn(publishPubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(userAvatarManager);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);
          when(
            () => metadataPubsubManager.getItems(
              any(),
              mox.userAvatarMetadataXmlns,
              maxItems: any(named: 'maxItems'),
            ),
          ).thenAnswer((_) async {
            await metadataGate.future;
            return moxlib.Result<mox.PubSubError, List<mox.PubSubItem>>(
              <mox.PubSubItem>[metadataItem],
            );
          });
          when(
            () => userAvatarManager.getUserAvatarData(any(), any()),
          ).thenAnswer(
            (_) async =>
                const moxlib.Result<mox.AvatarError, mox.UserAvatarData>(
                  mox.UserAvatarData('AQID', 'avatar-hash'),
                ),
          );

          final refreshFuture = xmppService.refreshSelfAvatarIfNeeded(
            force: true,
          );
          await pumpEventQueue();

          expect(xmppService.selfAvatarHydrating, isTrue);

          final result = await xmppService.saveSelfAvatar(
            AvatarUploadPayload(
              bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: 'saved-avatar-hash',
            ),
          );

          expect(result.hash, 'saved-avatar-hash');
          expect(publishPubsubManager.publishCount, equals(0));
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNotNull,
          );

          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue();

          expect(publishPubsubManager.publishCount, equals(0));

          metadataGate.complete();
          await refreshFuture;
          await pumpEventQueue(times: 20);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await pumpEventQueue(times: 20);

          expect(publishPubsubManager.publishCount, equals(2));
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNull,
          );
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'saveSelfAvatar still publishes after stream ready when a bootstrap self refresh is already running.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-save-self-avatar-bootstrap-running-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final metadataPubsubManager = MockPubSubManager();
        final publishPubsubManager = RecordingAvatarPubSubManager();
        final userAvatarManager = MockUserAvatarManager();
        final stateStoreValues = <String, Object?>{};
        final metadataGate = Completer<void>();
        final metadataPayload =
            (mox.XmlBuilder.withNamespace(
                  'metadata',
                  mox.userAvatarMetadataXmlns,
                )..child(
                  (mox.XmlBuilder('info')
                        ..attr('id', 'avatar-hash')
                        ..attr('bytes', '3')
                        ..attr('type', 'image/png')
                        ..attr('width', '1')
                        ..attr('height', '1'))
                      .build(),
                ))
                .build();
        final metadataItem = mox.PubSubItem(
          id: 'avatar-hash',
          node: mox.userAvatarMetadataXmlns,
          payload: metadataPayload,
        );
        try {
          when(() => mockStateStore.read(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            return stateStoreValues[key.value];
          });
          when(
            () => mockStateStore.writeAll(data: any(named: 'data')),
          ).thenAnswer((invocation) async {
            final data =
                invocation.namedArguments[#data]
                    as Map<RegisteredStateKey, Object?>;
            for (final entry in data.entries) {
              stateStoreValues[entry.key.value] = entry.value;
            }
            return true;
          });
          when(
            () => mockStateStore.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            ),
          ).thenAnswer((invocation) async {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            stateStoreValues[key.value] = invocation.namedArguments[#value];
            return true;
          });
          when(() => mockStateStore.delete(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) async {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            stateStoreValues.remove(key.value);
            return true;
          });
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(metadataPubsubManager);
          when(
            () => mockConnection.getManager<PubSubManager>(),
          ).thenReturn(publishPubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(userAvatarManager);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);
          when(
            () => metadataPubsubManager.getItems(
              any(),
              mox.userAvatarMetadataXmlns,
              maxItems: any(named: 'maxItems'),
            ),
          ).thenAnswer((_) async {
            await metadataGate.future;
            return moxlib.Result<mox.PubSubError, List<mox.PubSubItem>>(
              <mox.PubSubItem>[metadataItem],
            );
          });
          when(
            () => userAvatarManager.getUserAvatarData(any(), any()),
          ).thenAnswer(
            (_) async =>
                const moxlib.Result<mox.AvatarError, mox.UserAvatarData>(
                  mox.UserAvatarData('AQID', 'avatar-hash'),
                ),
          );

          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue();

          expect(xmppService.selfAvatarHydrating, isTrue);

          final result = await xmppService.saveSelfAvatar(
            AvatarUploadPayload(
              bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: 'saved-avatar-hash',
            ),
          );

          expect(result.hash, 'saved-avatar-hash');
          expect(publishPubsubManager.publishCount, equals(0));
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNotNull,
          );

          metadataGate.complete();
          await pumpEventQueue(times: 20);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await pumpEventQueue(times: 20);

          expect(publishPubsubManager.publishCount, equals(2));
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNull,
          );
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'saveSelfAvatar stores locally immediately when already stream-ready even if publish fails.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-save-self-avatar-connected-failure-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final pubsubManager = FailingAvatarPubSubManager();
        final stateStoreValues = <String, Object?>{};
        try {
          when(() => mockStateStore.read(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            return stateStoreValues[key.value];
          });
          when(
            () => mockStateStore.writeAll(data: any(named: 'data')),
          ).thenAnswer((invocation) async {
            final data =
                invocation.namedArguments[#data]
                    as Map<RegisteredStateKey, Object?>;
            for (final entry in data.entries) {
              stateStoreValues[entry.key.value] = entry.value;
            }
            return true;
          });
          when(
            () => mockStateStore.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            ),
          ).thenAnswer((invocation) async {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            stateStoreValues[key.value] = invocation.namedArguments[#value];
            return true;
          });
          when(() => mockStateStore.delete(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) async {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            stateStoreValues.remove(key.value);
            return true;
          });
          when(
            () => mockConnection.getManager<PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(null);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);

          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue(times: 10);

          final result = await xmppService.saveSelfAvatar(
            AvatarUploadPayload(
              bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: 'saved-avatar-hash',
            ),
          );

          expect(result.hash, 'saved-avatar-hash');
          expect((await xmppService.getOwnAvatar())?.hash, 'saved-avatar-hash');
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNotNull,
          );
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'Caches a signup self avatar draft after stream ready and publishes it immediately.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-avatar-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final stateStoreValues = <String, Object?>{};
        final pubsubManager = RecordingAvatarPubSubManager();
        final userAvatarManager = MockUserAvatarManager();
        try {
          when(() => mockStateStore.read(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            return stateStoreValues[key.value];
          });
          when(
            () => mockStateStore.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            ),
          ).thenAnswer((invocation) async {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            stateStoreValues[key.value] = invocation.namedArguments[#value];
            return true;
          });
          when(() => mockStateStore.delete(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) async {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            stateStoreValues.remove(key.value);
            return true;
          });

          when(
            () => mockConnection.getManager<PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(userAvatarManager);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);

          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue();

          expect(pubsubManager.publishCount, equals(0));

          await xmppService.cacheSelfAvatarDraft(
            AvatarUploadPayload(
              bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: 'signup-avatar-hash',
            ),
          );

          await pumpEventQueue();

          expect(pubsubManager.publishCount, equals(2));
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNull,
          );
          expect(
            (await xmppService.getOwnAvatar())?.hash,
            'signup-avatar-hash',
          );
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'selfAvatarStream replays persisted self avatar state from storage.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-avatar-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final stateStoreValues = <String, Object?>{};
        final stateStoreWatchController = StreamController<Object?>.broadcast();
        try {
          when(() => mockStateStore.read(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            return stateStoreValues[key.value];
          });
          when(
            () => mockStateStore.writeAll(data: any(named: 'data')),
          ).thenAnswer((invocation) async {
            final data =
                invocation.namedArguments[#data]
                    as Map<RegisteredStateKey, Object?>;
            for (final entry in data.entries) {
              stateStoreValues[entry.key.value] = entry.value;
            }
            stateStoreWatchController.add(null);
            return true;
          });
          when(
            () => mockStateStore.watch<Object?>(key: any(named: 'key')),
          ).thenAnswer((_) => stateStoreWatchController.stream);

          final selfAvatarEvents = <Avatar?>[];
          final selfAvatarSubscription = xmppService.selfAvatarStream.listen(
            selfAvatarEvents.add,
          );

          await xmppService.storeAvatarBytesForJid(
            jid: mox.JID.fromString(jid).toBare().toString(),
            bytes: Uint8List.fromList(<int>[
              0x89,
              0x50,
              0x4E,
              0x47,
              0x0D,
              0x0A,
              0x1A,
              0x0A,
              0x00,
            ]),
            hash: 'self-avatar-hash',
          );
          await pumpEventQueue();

          expect(
            selfAvatarEvents.whereType<Avatar>().last.hash,
            'self-avatar-hash',
          );
          expect((await xmppService.getOwnAvatar())?.hash, 'self-avatar-hash');

          await selfAvatarSubscription.cancel();
        } finally {
          await stateStoreWatchController.close();
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'Shows self avatar hydrating only while the negotiated refresh is running.',
      () async {
        final pubsubManager = MockPubSubManager();
        final userAvatarManager = MockUserAvatarManager();
        final metadataGate = Completer<void>();
        final metadataPayload =
            (mox.XmlBuilder.withNamespace(
                  'metadata',
                  mox.userAvatarMetadataXmlns,
                )..child(
                  (mox.XmlBuilder('info')
                        ..attr('id', 'avatar-hash')
                        ..attr('bytes', '3')
                        ..attr('type', 'image/png')
                        ..attr('width', '1')
                        ..attr('height', '1'))
                      .build(),
                ))
                .build();
        final metadataItem = mox.PubSubItem(
          id: 'avatar-hash',
          node: mox.userAvatarMetadataXmlns,
          payload: metadataPayload,
        );
        var metadataCalls = 0;

        when(
          () => mockStateStore.read(key: any(named: 'key')),
        ).thenReturn(null);
        await xmppService.close();
        database = XmppDrift(
          file: File(''),
          passphrase: '',
          executor: NativeDatabase.memory(),
        );
        xmppService = XmppService(
          buildConnection: () => mockConnection,
          buildStateStore: (_, _) => mockStateStore,
          buildDatabase: (_, _) => database,
          notificationService: mockNotificationService,
        );
        await connectSuccessfully(xmppService);
        when(() => mockConnection.hasConnectionSettings).thenReturn(true);
        when(
          () => mockConnection.getManager<mox.PubSubManager>(),
        ).thenReturn(pubsubManager);
        when(
          () => mockConnection.getManager<mox.UserAvatarManager>(),
        ).thenReturn(userAvatarManager);
        when(
          () => mockConnection.getManager<mox.VCardManager>(),
        ).thenReturn(null);

        when(
          () => pubsubManager.getItems(
            any(),
            mox.userAvatarMetadataXmlns,
            maxItems: any(named: 'maxItems'),
          ),
        ).thenAnswer((_) async {
          metadataCalls += 1;
          await metadataGate.future;
          return moxlib.Result<mox.PubSubError, List<mox.PubSubItem>>(
            <mox.PubSubItem>[metadataItem],
          );
        });
        when(
          () => userAvatarManager.getUserAvatarData(any(), any()),
        ).thenAnswer(
          (_) async => const moxlib.Result<mox.AvatarError, mox.UserAvatarData>(
            mox.UserAvatarData('AQID', 'avatar-hash'),
          ),
        );

        expect(xmppService.selfAvatarHydrating, isFalse);

        eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
        await pumpEventQueue();

        expect(metadataCalls, equals(1));
        expect(xmppService.selfAvatarHydrating, isTrue);

        eventStreamController.add(mox.StreamNegotiationsDoneEvent(true));
        await pumpEventQueue();

        expect(metadataCalls, equals(1));
        expect(xmppService.selfAvatarHydrating, isTrue);

        metadataGate.complete();
        await pumpEventQueue(times: 20);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await pumpEventQueue(times: 20);

        expect(metadataCalls, equals(1));
        expect(xmppService.selfAvatarHydrating, isFalse);
      },
    );

    test('Runs proactive self avatar refresh again after reconnect.', () async {
      final pubsubManager = MockPubSubManager();
      final userAvatarManager = MockUserAvatarManager();
      final metadataGates = <Completer<void>>[
        Completer<void>(),
        Completer<void>(),
      ];
      final metadataPayload =
          (mox.XmlBuilder.withNamespace('metadata', mox.userAvatarMetadataXmlns)
                ..child(
                  (mox.XmlBuilder('info')
                        ..attr('id', 'avatar-hash')
                        ..attr('bytes', '3')
                        ..attr('type', 'image/png')
                        ..attr('width', '1')
                        ..attr('height', '1'))
                      .build(),
                ))
              .build();
      final metadataItem = mox.PubSubItem(
        id: 'avatar-hash',
        node: mox.userAvatarMetadataXmlns,
        payload: metadataPayload,
      );
      var metadataCalls = 0;

      when(() => mockStateStore.read(key: any(named: 'key'))).thenReturn(null);
      await xmppService.close();
      database = XmppDrift(
        file: File(''),
        passphrase: '',
        executor: NativeDatabase.memory(),
      );
      xmppService = XmppService(
        buildConnection: () => mockConnection,
        buildStateStore: (_, _) => mockStateStore,
        buildDatabase: (_, _) => database,
        notificationService: mockNotificationService,
      );
      await connectSuccessfully(xmppService);
      when(() => mockConnection.hasConnectionSettings).thenReturn(true);
      when(
        () => mockConnection.getManager<mox.PubSubManager>(),
      ).thenReturn(pubsubManager);
      when(
        () => mockConnection.getManager<mox.UserAvatarManager>(),
      ).thenReturn(userAvatarManager);
      when(
        () => mockConnection.getManager<mox.VCardManager>(),
      ).thenReturn(null);

      when(
        () => pubsubManager.getItems(
          any(),
          mox.userAvatarMetadataXmlns,
          maxItems: any(named: 'maxItems'),
        ),
      ).thenAnswer((_) async {
        final gateIndex = metadataCalls;
        metadataCalls += 1;
        await metadataGates[gateIndex].future;
        return moxlib.Result<mox.PubSubError, List<mox.PubSubItem>>(
          <mox.PubSubItem>[metadataItem],
        );
      });
      when(() => userAvatarManager.getUserAvatarData(any(), any())).thenAnswer(
        (_) async => const moxlib.Result<mox.AvatarError, mox.UserAvatarData>(
          mox.UserAvatarData('AQID', 'avatar-hash'),
        ),
      );

      expect(xmppService.selfAvatarHydrating, isFalse);

      eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
      await pumpEventQueue();

      expect(metadataCalls, equals(1));
      expect(xmppService.selfAvatarHydrating, isTrue);

      metadataGates.first.complete();
      await pumpEventQueue(times: 20);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await pumpEventQueue(times: 20);

      expect(xmppService.selfAvatarHydrating, isFalse);

      eventStreamController.add(
        mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.connected,
          mox.XmppConnectionState.connecting,
        ),
      );
      await pumpEventQueue();

      eventStreamController.add(
        mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.notConnected,
          mox.XmppConnectionState.connected,
        ),
      );
      await pumpEventQueue();

      eventStreamController.add(
        mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.connected,
          mox.XmppConnectionState.notConnected,
        ),
      );
      await pumpEventQueue();

      expect(xmppService.selfAvatarHydrating, isFalse);

      eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
      await pumpEventQueue();

      expect(metadataCalls, equals(2));
      expect(xmppService.selfAvatarHydrating, isTrue);

      metadataGates.last.complete();
      await pumpEventQueue(times: 20);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await pumpEventQueue(times: 20);

      expect(xmppService.selfAvatarHydrating, isFalse);
    });

    test(
      'Drops stale self avatar refresh results after reconnect while a new refresh is running.',
      () async {
        final pubsubManager = MockPubSubManager();
        final userAvatarManager = MockUserAvatarManager();
        final metadataItems = <mox.PubSubItem>[
          mox.PubSubItem(
            id: 'old-hash',
            node: mox.userAvatarMetadataXmlns,
            payload:
                (mox.XmlBuilder.withNamespace(
                      'metadata',
                      mox.userAvatarMetadataXmlns,
                    )..child(
                      (mox.XmlBuilder('info')
                            ..attr('id', 'old-hash')
                            ..attr('bytes', '3')
                            ..attr('type', 'image/png')
                            ..attr('width', '1')
                            ..attr('height', '1'))
                          .build(),
                    ))
                    .build(),
          ),
          mox.PubSubItem(
            id: 'new-hash',
            node: mox.userAvatarMetadataXmlns,
            payload:
                (mox.XmlBuilder.withNamespace(
                      'metadata',
                      mox.userAvatarMetadataXmlns,
                    )..child(
                      (mox.XmlBuilder('info')
                            ..attr('id', 'new-hash')
                            ..attr('bytes', '3')
                            ..attr('type', 'image/png')
                            ..attr('width', '1')
                            ..attr('height', '1'))
                          .build(),
                    ))
                    .build(),
          ),
        ];
        final dataGates = <Completer<void>>[
          Completer<void>(),
          Completer<void>(),
        ];
        var metadataCalls = 0;
        var avatarDataCalls = 0;

        when(
          () => mockStateStore.read(key: any(named: 'key')),
        ).thenReturn(null);
        await xmppService.close();
        database = XmppDrift(
          file: File(''),
          passphrase: '',
          executor: NativeDatabase.memory(),
        );
        xmppService = XmppService(
          buildConnection: () => mockConnection,
          buildStateStore: (_, _) => mockStateStore,
          buildDatabase: (_, _) => database,
          notificationService: mockNotificationService,
        );
        await connectSuccessfully(xmppService);
        when(() => mockConnection.hasConnectionSettings).thenReturn(true);
        when(
          () => mockConnection.getManager<mox.PubSubManager>(),
        ).thenReturn(pubsubManager);
        when(
          () => mockConnection.getManager<mox.UserAvatarManager>(),
        ).thenReturn(userAvatarManager);
        when(
          () => mockConnection.getManager<mox.VCardManager>(),
        ).thenReturn(null);
        when(
          () => pubsubManager.getItems(
            any(),
            mox.userAvatarMetadataXmlns,
            maxItems: any(named: 'maxItems'),
          ),
        ).thenAnswer((_) async {
          final metadataItem = metadataItems[metadataCalls];
          metadataCalls += 1;
          return moxlib.Result<mox.PubSubError, List<mox.PubSubItem>>(
            <mox.PubSubItem>[metadataItem],
          );
        });
        when(
          () => userAvatarManager.getUserAvatarData(any(), any()),
        ).thenAnswer((_) async {
          final callIndex = avatarDataCalls;
          avatarDataCalls += 1;
          await dataGates[callIndex].future;
          return moxlib.Result<mox.AvatarError, mox.UserAvatarData>(
            callIndex == 0
                ? const mox.UserAvatarData('AQID', 'old-hash')
                : const mox.UserAvatarData('BAUG', 'new-hash'),
          );
        });

        eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
        await pumpEventQueue();

        expect(metadataCalls, equals(1));
        expect(avatarDataCalls, equals(1));
        expect(xmppService.selfAvatarHydrating, isTrue);

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.connecting,
          ),
        );
        await pumpEventQueue();

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.notConnected,
            mox.XmppConnectionState.connected,
          ),
        );
        await pumpEventQueue();

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.notConnected,
          ),
        );
        await pumpEventQueue();

        eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
        await pumpEventQueue();

        expect(metadataCalls, equals(2));
        expect(avatarDataCalls, equals(2));
        expect(xmppService.selfAvatarHydrating, isTrue);

        dataGates.first.complete();
        await pumpEventQueue();

        expect(xmppService.selfAvatarHydrating, isTrue);
        expect(xmppService.cachedSelfAvatar, isNull);

        dataGates.last.complete();
        await xmppService.selfAvatarHydratingStream
            .firstWhere((hydrating) => !hydrating)
            .timeout(const Duration(seconds: 1));

        expect(xmppService.selfAvatarHydrating, isFalse);
        expect(xmppService.cachedSelfAvatar?.hash, equals('new-hash'));
      },
    );

    test(
      'refreshAvatarsForConversationIndex skips self avatar byte downloads when the cached hash matches.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-refresh-conversation-avatar-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final stateStoreValues = <String, Object?>{};
        final pubsubManager = MockPubSubManager();
        final userAvatarManager = MockUserAvatarManager();
        final metadataPayload =
            (mox.XmlBuilder.withNamespace(
                  'metadata',
                  mox.userAvatarMetadataXmlns,
                )..child(
                  (mox.XmlBuilder('info')
                        ..attr('id', 'avatar-hash')
                        ..attr('bytes', '3')
                        ..attr('type', 'image/png')
                        ..attr('width', '1')
                        ..attr('height', '1'))
                      .build(),
                ))
                .build();
        final metadataItem = mox.PubSubItem(
          id: 'avatar-hash',
          node: mox.userAvatarMetadataXmlns,
          payload: metadataPayload,
        );
        var metadataCalls = 0;
        var avatarDataCalls = 0;

        try {
          when(() => mockStateStore.read(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            return stateStoreValues[key.value];
          });
          when(
            () => mockStateStore.writeAll(data: any(named: 'data')),
          ).thenAnswer((invocation) async {
            final data =
                invocation.namedArguments[#data]
                    as Map<RegisteredStateKey, Object?>;
            for (final entry in data.entries) {
              stateStoreValues[entry.key.value] = entry.value;
            }
            return true;
          });
          when(
            () => mockStateStore.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            ),
          ).thenAnswer((invocation) async {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            stateStoreValues[key.value] = invocation.namedArguments[#value];
            return true;
          });
          when(() => mockStateStore.delete(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) async {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            stateStoreValues.remove(key.value);
            return true;
          });

          await xmppService.close();
          database = XmppDrift(
            file: File(''),
            passphrase: '',
            executor: NativeDatabase.memory(),
          );
          xmppService = XmppService(
            buildConnection: () => mockConnection,
            buildStateStore: (_, _) => mockStateStore,
            buildDatabase: (_, _) => database,
            notificationService: mockNotificationService,
          );
          await connectSuccessfully(xmppService);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(userAvatarManager);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(
            () => pubsubManager.getItems(
              any(),
              mox.userAvatarMetadataXmlns,
              maxItems: any(named: 'maxItems'),
            ),
          ).thenAnswer((_) async {
            metadataCalls += 1;
            return moxlib.Result<mox.PubSubError, List<mox.PubSubItem>>(
              <mox.PubSubItem>[metadataItem],
            );
          });
          when(
            () => userAvatarManager.getUserAvatarData(any(), any()),
          ).thenAnswer((_) async {
            avatarDataCalls += 1;
            return const moxlib.Result<mox.AvatarError, mox.UserAvatarData>(
              mox.UserAvatarData('AQID', 'avatar-hash'),
            );
          });

          await xmppService.storeAvatarBytesForJid(
            jid: mox.JID.fromString(jid).toBare().toString(),
            bytes: Uint8List.fromList(const <int>[
              0x89,
              0x50,
              0x4E,
              0x47,
              0x0D,
              0x0A,
              0x1A,
              0x0A,
              0x00,
            ]),
            hash: 'avatar-hash',
          );

          expect(
            await xmppService.refreshAvatarsForConversationIndex(),
            isTrue,
          );
          await pumpEventQueue(times: 20);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await pumpEventQueue(times: 20);

          expect(metadataCalls, equals(1));
          expect(avatarDataCalls, equals(0));
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'syncSessionState forces a self avatar byte download when the cached hash matches.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-sync-session-avatar-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final stateStoreValues = <String, Object?>{};
        final pubsubManager = MockPubSubManager();
        final userAvatarManager = MockUserAvatarManager();
        final discoManager = MockDiscoManager();
        final mamManager = RecordingMamManager();
        final metadataPayload =
            (mox.XmlBuilder.withNamespace(
                  'metadata',
                  mox.userAvatarMetadataXmlns,
                )..child(
                  (mox.XmlBuilder('info')
                        ..attr('id', 'avatar-hash')
                        ..attr('bytes', '3')
                        ..attr('type', 'image/png')
                        ..attr('width', '1')
                        ..attr('height', '1'))
                      .build(),
                ))
                .build();
        final metadataItem = mox.PubSubItem(
          id: 'avatar-hash',
          node: mox.userAvatarMetadataXmlns,
          payload: metadataPayload,
        );
        var metadataCalls = 0;
        var avatarDataCalls = 0;

        try {
          when(() => mockStateStore.read(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            return stateStoreValues[key.value];
          });
          when(
            () => mockStateStore.writeAll(data: any(named: 'data')),
          ).thenAnswer((invocation) async {
            final data =
                invocation.namedArguments[#data]
                    as Map<RegisteredStateKey, Object?>;
            for (final entry in data.entries) {
              stateStoreValues[entry.key.value] = entry.value;
            }
            return true;
          });
          when(
            () => mockStateStore.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            ),
          ).thenAnswer((invocation) async {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            stateStoreValues[key.value] = invocation.namedArguments[#value];
            return true;
          });
          when(() => mockStateStore.delete(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) async {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            stateStoreValues.remove(key.value);
            return true;
          });

          await xmppService.close();
          database = XmppDrift(
            file: File(''),
            passphrase: '',
            executor: NativeDatabase.memory(),
          );
          xmppService = XmppService(
            buildConnection: () => mockConnection,
            buildStateStore: (_, _) => mockStateStore,
            buildDatabase: (_, _) => database,
            notificationService: mockNotificationService,
          );
          await connectSuccessfully(xmppService);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(userAvatarManager);
          when(
            () => mockConnection.getManager<mox.DiscoManager>(),
          ).thenReturn(discoManager);
          when(
            () => mockConnection.getManager<mox.MAMManager>(),
          ).thenReturn(mamManager);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          await xmppService.setMamSupportOverride(true);
          when(() => discoManager.discoItemsQuery(any())).thenAnswer(
            (_) async =>
                const moxlib.Result<mox.StanzaError, List<mox.DiscoItem>>(
                  <mox.DiscoItem>[],
                ),
          );
          when(() => discoManager.discoInfoQuery(any())).thenAnswer(
            (_) async => moxlib.Result<mox.StanzaError, mox.DiscoInfo>(
              mox.DiscoInfo(
                const <String>[mox.mamXmlns],
                const <mox.Identity>[],
                const <mox.DataForm>[],
                null,
                mox.JID.fromString(jid),
              ),
            ),
          );
          when(
            () => pubsubManager.getItems(
              any(),
              mox.userAvatarMetadataXmlns,
              maxItems: any(named: 'maxItems'),
            ),
          ).thenAnswer((_) async {
            metadataCalls += 1;
            return moxlib.Result<mox.PubSubError, List<mox.PubSubItem>>(
              <mox.PubSubItem>[metadataItem],
            );
          });
          when(
            () => userAvatarManager.getUserAvatarData(any(), any()),
          ).thenAnswer((_) async {
            avatarDataCalls += 1;
            return const moxlib.Result<mox.AvatarError, mox.UserAvatarData>(
              mox.UserAvatarData('AQID', 'avatar-hash'),
            );
          });

          await xmppService.storeAvatarBytesForJid(
            jid: mox.JID.fromString(jid).toBare().toString(),
            bytes: Uint8List.fromList(const <int>[
              0x89,
              0x50,
              0x4E,
              0x47,
              0x0D,
              0x0A,
              0x1A,
              0x0A,
              0x00,
            ]),
            hash: 'avatar-hash',
          );

          eventStreamController.add(
            mox.ConnectionStateChangedEvent(
              mox.XmppConnectionState.connected,
              mox.XmppConnectionState.notConnected,
            ),
          );
          await pumpEventQueue(times: 20);
          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue(times: 20);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await pumpEventQueue(times: 20);

          metadataCalls = 0;
          avatarDataCalls = 0;
          mamManager.queryCount = 0;

          expect(await xmppService.syncSessionState(), isTrue);
          await pumpEventQueue(times: 20);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await pumpEventQueue(times: 20);

          expect(mamManager.queryCount, greaterThanOrEqualTo(1));
          expect(metadataCalls, equals(1));
          expect(avatarDataCalls, equals(1));
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'Explicit forced self avatar refreshes the self avatar once.',
      () async {
        final pubsubManager = MockPubSubManager();
        final userAvatarManager = MockUserAvatarManager();
        final metadataPayload =
            (mox.XmlBuilder.withNamespace(
                  'metadata',
                  mox.userAvatarMetadataXmlns,
                )..child(
                  (mox.XmlBuilder('info')
                        ..attr('id', 'avatar-hash')
                        ..attr('bytes', '3')
                        ..attr('type', 'image/png')
                        ..attr('width', '1')
                        ..attr('height', '1'))
                      .build(),
                ))
                .build();
        final metadataItem = mox.PubSubItem(
          id: 'avatar-hash',
          node: mox.userAvatarMetadataXmlns,
          payload: metadataPayload,
        );
        var metadataCalls = 0;

        when(
          () => mockStateStore.read(key: any(named: 'key')),
        ).thenReturn(null);
        await xmppService.close();
        database = XmppDrift(
          file: File(''),
          passphrase: '',
          executor: NativeDatabase.memory(),
        );
        xmppService = XmppService(
          buildConnection: () => mockConnection,
          buildStateStore: (_, _) => mockStateStore,
          buildDatabase: (_, _) => database,
          notificationService: mockNotificationService,
        );
        await connectSuccessfully(xmppService);
        when(() => mockConnection.hasConnectionSettings).thenReturn(true);
        when(
          () => mockConnection.getManager<mox.PubSubManager>(),
        ).thenReturn(pubsubManager);
        when(
          () => mockConnection.getManager<mox.UserAvatarManager>(),
        ).thenReturn(userAvatarManager);
        when(
          () => mockConnection.getManager<mox.VCardManager>(),
        ).thenReturn(null);
        when(
          () => pubsubManager.getItems(
            any(),
            mox.userAvatarMetadataXmlns,
            maxItems: any(named: 'maxItems'),
          ),
        ).thenAnswer((_) async {
          metadataCalls += 1;
          return moxlib.Result<mox.PubSubError, List<mox.PubSubItem>>(
            <mox.PubSubItem>[metadataItem],
          );
        });
        when(
          () => userAvatarManager.getUserAvatarData(any(), any()),
        ).thenAnswer(
          (_) async => const moxlib.Result<mox.AvatarError, mox.UserAvatarData>(
            mox.UserAvatarData('AQID', 'avatar-hash'),
          ),
        );

        await xmppService.refreshSelfAvatarIfNeeded(force: true);
        await pumpEventQueue(times: 20);

        expect(metadataCalls, equals(1));
      },
    );

    test('Given a standard text message, writes it to the database.', () async {
      final beforeMessage = await database.getMessageByStanzaID(
        messageEvent.id!,
      );
      expect(beforeMessage, isNull);

      clearInteractions(mockConnection);

      eventStreamController.add(messageEvent);

      await pumpEventQueue();

      final afterMessage = await database.getMessageByStanzaID(
        messageEvent.id!,
      );
      expect(afterMessage?.stanzaID, equals(messageEvent.id!));
      expect(afterMessage?.body, equals(messageEvent.text));
      verifyNever(() => mockConnection.getManager<ConversationIndexManager>());
    });

    test(
      'Given a standard text message from the bare account domain, writes it to the database.',
      () async {
        const stanzaId = 'server-domain-message';
        const body = 'Welcome to the server';
        final systemMessageEvent = mox.MessageEvent(
          mox.JID.fromString('axi.im'),
          mox.JID.fromString(jid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData(body),
            const mox.MessageIdData(stanzaId),
          ]),
          id: stanzaId,
        );

        final beforeMessage = await database.getMessageByStanzaID(stanzaId);
        expect(beforeMessage, isNull);

        eventStreamController.add(systemMessageEvent);

        await pumpEventQueue();

        final afterMessage = await database.getMessageByStanzaID(stanzaId);
        final chat = await database.getChat('axi.im');
        expect(afterMessage?.stanzaID, equals(stanzaId));
        expect(afterMessage?.body, equals(body));
        expect(afterMessage?.chatJid, equals('axi.im'));
        expect(afterMessage?.senderJid, equals('axi.im'));
        expect(chat?.title, equals('axi.im'));
      },
    );

    test(
      'Given a headline message from the bare account domain, writes it to the database.',
      () async {
        const stanzaId = 'server-domain-headline';
        const body = 'Account created';
        final systemMessageEvent = mox.MessageEvent(
          mox.JID.fromString('axi.im'),
          mox.JID.fromString(jid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData(body),
            const mox.MessageIdData(stanzaId),
          ]),
          id: stanzaId,
          type: 'headline',
        );

        final beforeMessage = await database.getMessageByStanzaID(stanzaId);
        expect(beforeMessage, isNull);

        eventStreamController.add(systemMessageEvent);

        await pumpEventQueue();

        final afterMessage = await database.getMessageByStanzaID(stanzaId);
        final chat = await database.getChat('axi.im');
        expect(afterMessage?.stanzaID, equals(stanzaId));
        expect(afterMessage?.body, equals(body));
        expect(afterMessage?.chatJid, equals('axi.im'));
        expect(afterMessage?.senderJid, equals('axi.im'));
        expect(chat?.title, equals('axi.im'));
      },
    );

    test(
      'Given archived duplicate welcome messages from the bare account domain, trims and stores only one.',
      () async {
        const trimmedBody = 'Welcome to Axichat';
        final timestamp = DateTime.utc(2026, 3, 1, 12, 0, 0);

        mox.MessageEvent buildWelcomeEvent(String stanzaId, String body) {
          return mox.MessageEvent(
            mox.JID.fromString('axi.im'),
            mox.JID.fromString(jid),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              mox.MessageBodyData(body),
              mox.MessageIdData(stanzaId),
              mox.DelayedDeliveryData(mox.JID.fromString('axi.im'), timestamp),
            ]),
            id: stanzaId,
            isFromMAM: true,
          );
        }

        eventStreamController.add(
          buildWelcomeEvent('welcome-message-1', '  $trimmedBody \n'),
        );
        eventStreamController.add(
          buildWelcomeEvent('welcome-message-2', '\t$trimmedBody  '),
        );

        await pumpEventQueue(times: 20);

        final messages = await database.getChatMessages(
          'axi.im',
          start: 0,
          end: 10,
        );
        expect(messages, hasLength(1));
        expect(messages.single.body, equals(trimmedBody));
      },
    );

    test(
      'Given an archived inbound direct message, increments the chat unread count.',
      () async {
        const peerJid = 'peer@example.com';
        const stanzaId = 'mam-inbound-unread';
        final timestamp = DateTime.utc(2026, 3, 1, 12, 0, 0);
        final event = mox.MessageEvent(
          mox.JID.fromString(peerJid),
          mox.JID.fromString(jid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData('Missed while offline'),
            const mox.MessageIdData(stanzaId),
            mox.DelayedDeliveryData(mox.JID.fromString(peerJid), timestamp),
          ]),
          id: stanzaId,
          isFromMAM: true,
        );

        eventStreamController.add(event);

        await pumpEventQueue(times: 20);

        final chat = await database.getChat(peerJid);
        expect(chat?.unreadCount, equals(1));
      },
    );

    test(
      'Given a message from a non-server bare domain, does not label the chat with that domain.',
      () async {
        const stanzaId = 'other-domain-message';
        const body = 'External bare-domain message';
        final systemMessageEvent = mox.MessageEvent(
          mox.JID.fromString('example.com'),
          mox.JID.fromString(jid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData(body),
            const mox.MessageIdData(stanzaId),
          ]),
          id: stanzaId,
        );

        eventStreamController.add(systemMessageEvent);

        await pumpEventQueue();

        final chat = await database.getChat('example.com');
        expect(chat?.title, isEmpty);
      },
    );

    test('Given a standard text message, notifies the user.', () async {
      eventStreamController.add(messageEvent);

      await pumpEventQueue();

      verify(
        () => mockNotificationService.sendMessageNotification(
          title: any(named: 'title'),
          body: messageEvent.text,
          senderName: any(named: 'senderName'),
          senderKey: any(named: 'senderKey'),
          conversationTitle: any(named: 'conversationTitle'),
          sentAt: any(named: 'sentAt'),
          isGroupConversation: any(named: 'isGroupConversation'),
          extraConditions: any(named: 'extraConditions'),
          allowForeground: any(named: 'allowForeground'),
          payload: any(named: 'payload'),
          threadKey: any(named: 'threadKey'),
          showPreviewOverride: any(named: 'showPreviewOverride'),
          channel: MessageNotificationChannel.chat,
        ),
      ).called(1);
    });

    test(
      'Given a connection change, emits the corresponding connection state.',
      () async {
        expectLater(
          xmppService.connectivityStream,
          emitsInOrder([
            ConnectionState.connecting,
            ConnectionState.connected,
            ConnectionState.error,
            ConnectionState.notConnected,
            ConnectionState.error,
            ConnectionState.connected,
            ConnectionState.connecting,
          ]),
        );

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.notConnected,
            mox.XmppConnectionState.notConnected,
          ),
        );
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connecting,
            mox.XmppConnectionState.notConnected,
          ),
        );
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.connecting,
          ),
        );
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.error,
            mox.XmppConnectionState.connected,
          ),
        );
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.notConnected,
            mox.XmppConnectionState.error,
          ),
        );
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.error,
            mox.XmppConnectionState.notConnected,
          ),
        );
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.error,
          ),
        );
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connecting,
            mox.XmppConnectionState.connected,
          ),
        );
      },
    );

    test(
      'Given a stanza acknowledgement, marks the correct message in the database acked.',
      () async {
        await database.saveMessage(message);

        final beforeAcked = await database.getMessageByStanzaID(
          message.stanzaID,
        );
        expect(beforeAcked?.acked, isFalse);

        eventStreamController.add(
          mox.StanzaAckedEvent(
            mox.Stanza(tag: 'message', id: message.stanzaID),
          ),
        );

        await pumpEventQueue();

        final afterAcked = await database.getMessageByStanzaID(
          message.stanzaID,
        );
        expect(afterAcked?.acked, isTrue);
      },
    );

    test(
      'Given a displayed chat marker, marks the correct message in the database displayed.',
      () async {
        final outgoing = message.copyWith(senderJid: xmppService.myJid!);
        await database.saveMessage(outgoing);

        final beforeDisplayed = await database.getMessageByStanzaID(
          outgoing.stanzaID,
        );
        expect(beforeDisplayed?.acked, isFalse);

        eventStreamController.add(
          mox.ChatMarkerEvent(
            mox.JID.fromString(outgoing.chatJid),
            mox.ChatMarker.displayed,
            outgoing.stanzaID,
          ),
        );

        await pumpEventQueue();

        final afterDisplayed = await database.getMessageByStanzaID(
          outgoing.stanzaID,
        );
        expect(afterDisplayed?.displayed, isTrue);
        expect(afterDisplayed?.received, isTrue);
        expect(afterDisplayed?.acked, isTrue);
      },
    );

    test(
      'Given a delivery receipt, marks the correct message in the database received.',
      () async {
        final outgoing = message.copyWith(senderJid: xmppService.myJid!);
        await database.saveMessage(outgoing);

        final beforeReceived = await database.getMessageByStanzaID(
          outgoing.stanzaID,
        );
        expect(beforeReceived?.received, isFalse);

        eventStreamController.add(
          mox.DeliveryReceiptReceivedEvent(
            from: mox.JID.fromString(outgoing.chatJid),
            id: outgoing.stanzaID,
          ),
        );

        await pumpEventQueue();

        final afterReceived = await database.getMessageByStanzaID(
          outgoing.stanzaID,
        );
        expect(afterReceived?.received, isTrue);
      },
    );

    test(
      'When stream negotiations complete on a fresh login, runs global and calendar MAM catch-up.',
      () async {
        final mamManager = RecordingMamManager();
        stubUnsafeBootstrapManagersUnavailable();
        await xmppService.setMamSupportOverride(true);
        when(() => mockConnection.carbonsEnabled).thenReturn(false);
        when(
          () => mockConnection.enableCarbons(),
        ).thenAnswer((_) async => true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.connecting,
          ),
        );
        eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));

        await pumpEventQueue(times: 20);

        expect(mamManager.queryCount, 2);
        expect(mamManager.lastTo, isNull);
        expect(mamManager.lastOptions?.withJid, isNotNull);
      },
    );

    test('When stream negotiations resume, runs a MAM catch-up.', () async {
      final mamManager = RecordingMamManager();
      stubUnsafeBootstrapManagersUnavailable();
      await xmppService.setMamSupportOverride(true);
      when(() => mockConnection.carbonsEnabled).thenReturn(true);
      when(
        () => mockConnection.getManager<mox.MAMManager>(),
      ).thenReturn(mamManager);

      eventStreamController.add(
        mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.connected,
          mox.XmppConnectionState.connecting,
        ),
      );
      eventStreamController.add(mox.StreamNegotiationsDoneEvent(true));

      await pumpEventQueue(times: 20);

      expect(mamManager.queryCount, 1);
      expect(mamManager.lastTo, isNull);
      expect(mamManager.lastOptions?.withJid, isNull);
    });

    test('Calendar MAM skips unsupported accounts without querying', () async {
      final mamManager = ScriptedMamManager(
        eventStreamController: eventStreamController,
      );
      await xmppService.setMamSupportOverride(false);
      when(
        () => mockConnection.getManager<mox.MAMManager>(),
      ).thenReturn(mamManager);

      expect(
        await xmppService.rehydrateCalendarFromMam(),
        CalendarMamOutcome.skippedUnsupported,
      );

      expect(mamManager.calls, isEmpty);
    });

    test('Calendar MAM skips duplicate runs while one is in flight', () async {
      final release = Completer<void>();
      final mamManager = ScriptedMamManager(
        eventStreamController: eventStreamController,
        pages: [ScriptedMamPage(complete: true, release: release.future)],
      );
      await xmppService.setMamSupportOverride(true);
      when(
        () => mockConnection.getManager<mox.MAMManager>(),
      ).thenReturn(mamManager);

      final firstRun = xmppService.rehydrateCalendarFromMam();
      await mamManager.firstQueryStarted.future;

      expect(
        await xmppService.rehydrateCalendarFromMam(),
        CalendarMamOutcome.skippedInFlight,
      );
      expect(mamManager.queryCount, 1);

      release.complete();
      expect(await firstRun, CalendarMamOutcome.completed);
      expect(mamManager.queryCount, 1);
    });

    test(
      'Personal calendar MAM skips after global MAM preserves complete coverage',
      () async {
        await _openXmppStateStore('axichat_personal_global_calendar_mam');
        HydratedBloc.storage = _InMemoryStorage();
        final selfBare = mox.JID
            .fromString(xmppService.myJid!)
            .toBare()
            .toString();
        final timestamp = DateTime.utc(2026, 5, 3, 12);
        final task = _task(
          id: 'personal-global-task',
          title: 'Personal global task',
          timestamp: timestamp,
        );
        await const CalendarSyncState()
            .markCoverageComplete(calendarJid: selfBare, archiveJid: selfBare)
            .write();
        final mamManager = ScriptedMamManager(
          eventStreamController: eventStreamController,
          pages: [
            ScriptedMamPage(
              events: [
                _personalCalendarMamEvent(
                  selfBare: selfBare,
                  stanzaId: 'personal-global-calendar',
                  timestamp: timestamp,
                  message: _taskUpdate(task: task, operation: 'add'),
                ),
              ],
              complete: true,
              first: 'global-first',
              last: 'global-last',
              count: 1,
            ),
          ],
        );
        await xmppService.setMamSupportOverride(true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        expect(
          await xmppService.syncGlobalMamCatchUp(),
          MamGlobalSyncOutcome.completed,
        );
        expect(
          jsonEncode(HydratedBloc.storage.read(authStoragePrefix)),
          contains('Personal global task'),
        );
        expect(
          await xmppService.rehydrateCalendarFromMam(),
          CalendarMamOutcome.skippedCoveredByGlobal,
        );
        expect(mamManager.queryCount, 1);
      },
    );

    test(
      'Direct chat calendar MAM skips after global MAM covers that chat',
      () async {
        const peerJid = 'peer@example.com';
        await _openXmppStateStore('axichat_direct_global_calendar_mam');
        final storage = _InMemoryStorage();
        HydratedBloc.storage = storage;
        final selfBare = mox.JID
            .fromString(xmppService.myJid!)
            .toBare()
            .toString();
        final timestamp = DateTime.utc(2026, 5, 3, 13);
        final task = _task(
          id: 'direct-global-task',
          title: 'Direct global task',
          timestamp: timestamp,
        );
        await const ChatCalendarSyncStateStore().write(
          peerJid,
          const CalendarSyncState().markCoverageComplete(
            calendarJid: peerJid,
            archiveJid: peerJid,
          ),
        );
        final mamManager = ScriptedMamManager(
          eventStreamController: eventStreamController,
          pages: [
            ScriptedMamPage(
              events: [
                _directCalendarMamEvent(
                  peerBare: peerJid,
                  selfBare: selfBare,
                  stanzaId: 'direct-global-calendar',
                  timestamp: timestamp,
                  message: _taskUpdate(task: task, operation: 'add'),
                ),
              ],
              complete: true,
              first: 'direct-global-first',
              last: 'direct-global-last',
              count: 1,
            ),
          ],
        );
        await xmppService.setMamSupportOverride(true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        expect(
          await xmppService.syncGlobalMamCatchUp(),
          MamGlobalSyncOutcome.completed,
        );
        expect(
          await xmppService.rehydrateChatCalendarFromMam(
            chatJid: peerJid,
            chatType: ChatType.chat,
          ),
          CalendarMamOutcome.skippedCoveredByGlobal,
        );
        expect(mamManager.queryCount, 1);
        final model = ChatCalendarStorage(storage: storage).readModel(peerJid);
        expect(model.tasks[task.id]?.title, 'Direct global task');
      },
    );

    test(
      'Group calendar MAM still queries the room after global MAM',
      () async {
        const roomJid = 'room@conference.axi.im';
        const selfNick = 'me';
        const senderNick = 'alice';
        const senderOccupantId = '$roomJid/$senderNick';
        await _openXmppStateStore('axichat_group_after_global_calendar_mam');
        final storage = _InMemoryStorage();
        HydratedBloc.storage = storage;
        final selfBare = mox.JID
            .fromString(xmppService.myJid!)
            .toBare()
            .toString();
        final timestamp = DateTime.utc(2026, 5, 3, 14);
        final task = _task(
          id: 'group-after-global-task',
          title: 'Group after global task',
          timestamp: timestamp,
        );
        final mamManager = ScriptedMamManager(
          eventStreamController: eventStreamController,
          pages: [
            const ScriptedMamPage(
              complete: true,
              first: 'global-first',
              last: 'global-last',
              count: 0,
            ),
            ScriptedMamPage(
              events: [
                _groupCalendarMamEvent(
                  roomJid: roomJid,
                  senderOccupantId: senderOccupantId,
                  selfBare: selfBare,
                  stanzaId: 'group-after-global-calendar',
                  timestamp: timestamp,
                  message: _taskUpdate(task: task, operation: 'add'),
                ),
              ],
              complete: true,
              first: 'group-first',
              last: 'group-last',
              count: 1,
            ),
          ],
        );
        await xmppService.setMucServiceHost('conference.axi.im');
        await xmppService.setMamSupportOverride(true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: '$roomJid/$selfNick',
          nick: selfNick,
          realJid: xmppService.myJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: senderOccupantId,
          nick: senderNick,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
        );

        expect(
          await xmppService.syncGlobalMamCatchUp(),
          MamGlobalSyncOutcome.completed,
        );
        expect(
          await xmppService.rehydrateChatCalendarFromMam(
            chatJid: roomJid,
            chatType: ChatType.groupChat,
          ),
          CalendarMamOutcome.completed,
        );

        expect(mamManager.queryCount, 2);
        expect(mamManager.calls.last.to, roomJid);
        expect(mamManager.calls.last.withJid, isNull);
        final model = ChatCalendarStorage(storage: storage).readModel(roomJid);
        expect(model.tasks[task.id]?.title, 'Group after global task');
      },
    );

    test('Personal calendar MAM runs when coverage is unknown', () async {
      await _openXmppStateStore('axichat_personal_unknown_calendar_mam');
      HydratedBloc.storage = _InMemoryStorage();
      final selfBare = mox.JID
          .fromString(xmppService.myJid!)
          .toBare()
          .toString();
      final timestamp = DateTime.utc(2026, 5, 3, 15);
      final task = _task(
        id: 'personal-unknown-task',
        title: 'Personal unknown task',
        timestamp: timestamp,
      );
      final mamManager = ScriptedMamManager(
        eventStreamController: eventStreamController,
        pages: [
          ScriptedMamPage(
            events: [
              _personalCalendarMamEvent(
                selfBare: selfBare,
                stanzaId: 'personal-unknown-calendar',
                timestamp: timestamp,
                message: _taskUpdate(task: task, operation: 'add'),
              ),
            ],
            complete: true,
            first: 'personal-first',
            last: 'personal-last',
            count: 1,
          ),
        ],
      );
      await xmppService.setMamSupportOverride(true);
      when(
        () => mockConnection.getManager<mox.MAMManager>(),
      ).thenReturn(mamManager);

      expect(
        await xmppService.rehydrateCalendarFromMam(),
        CalendarMamOutcome.completed,
      );

      expect(mamManager.queryCount, 1);
      expect(mamManager.calls.single.to, isNull);
      expect(mamManager.calls.single.withJid, selfBare);
      expect(CalendarSyncState.read().hasCompleteCoverage, isTrue);
      expect(
        jsonEncode(HydratedBloc.storage.read(authStoragePrefix)),
        contains('Personal unknown task'),
      );
    });

    test('Direct chat calendar MAM runs when coverage is incomplete', () async {
      const peerJid = 'peer@example.com';
      await _openXmppStateStore('axichat_direct_incomplete_calendar_mam');
      final storage = _InMemoryStorage();
      HydratedBloc.storage = storage;
      await const ChatCalendarSyncStateStore().write(
        peerJid,
        const CalendarSyncState(
          coverageStatus: CalendarArchiveCoverageStatus.incomplete,
        ),
      );
      final selfBare = mox.JID
          .fromString(xmppService.myJid!)
          .toBare()
          .toString();
      final timestamp = DateTime.utc(2026, 5, 3, 16);
      final task = _task(
        id: 'direct-incomplete-task',
        title: 'Direct incomplete task',
        timestamp: timestamp,
      );
      final mamManager = ScriptedMamManager(
        eventStreamController: eventStreamController,
        pages: [
          ScriptedMamPage(
            events: [
              _directCalendarMamEvent(
                peerBare: peerJid,
                selfBare: selfBare,
                stanzaId: 'direct-incomplete-calendar',
                timestamp: timestamp,
                message: _taskUpdate(task: task, operation: 'add'),
              ),
            ],
            complete: true,
            first: 'direct-first',
            last: 'direct-last',
            count: 1,
          ),
        ],
      );
      await xmppService.setMamSupportOverride(true);
      when(
        () => mockConnection.getManager<mox.MAMManager>(),
      ).thenReturn(mamManager);

      expect(
        await xmppService.rehydrateChatCalendarFromMam(
          chatJid: peerJid,
          chatType: ChatType.chat,
        ),
        CalendarMamOutcome.completed,
      );

      expect(mamManager.queryCount, 1);
      expect(mamManager.calls.single.to, isNull);
      expect(mamManager.calls.single.withJid, peerJid);
      expect(
        const ChatCalendarSyncStateStore().read(peerJid).hasCompleteCoverage,
        isTrue,
      );
      final model = ChatCalendarStorage(storage: storage).readModel(peerJid);
      expect(model.tasks[task.id]?.title, 'Direct incomplete task');
    });

    test(
      'Global MAM preserves complete coverage for chat calendars it updates.',
      () async {
        const peerJid = 'peer@example.com';
        const stanzaId = 'chat-calendar-global-mam';
        final timestamp = DateTime.utc(2026, 5, 1, 12);
        final stateStoreValues = <String, Object?>{};
        final mamManager = BlockingMamManager();
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat_calendar_mam',
        );
        Hive.init(tempDir.path);
        await Hive.openBox(XmppStateStore.boxName);
        addTearDown(() async {
          await Hive.deleteFromDisk();
          await tempDir.delete(recursive: true);
        });
        HydratedBloc.storage = _InMemoryStorage();
        _stubStateStoreValues(stateStoreValues);
        await xmppService.setMamSupportOverride(true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        await const ChatCalendarSyncStateStore().write(
          peerJid,
          const CalendarSyncState().markCoverageComplete(
            calendarJid: peerJid,
            archiveJid: peerJid,
          ),
        );
        expect(
          const ChatCalendarSyncStateStore().read(peerJid).hasCompleteCoverage,
          isTrue,
        );

        final task = CalendarTask(
          id: 'global-mam-task',
          title: 'Global MAM task',
          createdAt: timestamp,
          modifiedAt: timestamp,
        );
        final syncEnvelope = jsonEncode({
          'calendar_sync': CalendarSyncMessage(
            type: CalendarSyncType.update,
            timestamp: timestamp,
            taskId: task.id,
            operation: 'add',
            data: task.toJson(),
          ).toJson(),
        });
        final syncEvent = mox.MessageEvent(
          mox.JID.fromString(peerJid),
          mox.JID.fromString(jid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            mox.MessageBodyData(syncEnvelope),
            const mox.MessageIdData(stanzaId),
            mox.DelayedDeliveryData(mox.JID.fromString(peerJid), timestamp),
          ]),
          id: stanzaId,
          isFromMAM: true,
        );

        final syncFuture = xmppService.syncGlobalMamCatchUp();
        await mamManager.queryStarted.future;
        eventStreamController.add(syncEvent);
        await pumpEventQueue(times: 20);

        expect(
          const ChatCalendarSyncStateStore().read(peerJid).coverageStatus,
          CalendarArchiveCoverageStatus.incomplete,
        );

        mamManager.finishQuery.complete();
        expect(await syncFuture, MamGlobalSyncOutcome.completed);

        final state = const ChatCalendarSyncStateStore().read(peerJid);
        expect(state.hasCompleteCoverage, isTrue);
        expect(state.lastHandledStanzaId, equals(stanzaId));
      },
    );

    test(
      'Global MAM leaves calendar coverage incomplete after handling failure',
      () async {
        const stanzaId = 'malformed-global-calendar-envelope';
        final timestamp = DateTime.utc(2026, 5, 1, 12);
        final selfJid = xmppService.myJid!;
        final mamManager = BlockingMamManager();
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat_calendar_global_mam_incomplete',
        );
        Hive.init(tempDir.path);
        await Hive.openBox(XmppStateStore.boxName);
        addTearDown(() async {
          await Hive.deleteFromDisk();
          await tempDir.delete(recursive: true);
        });
        await CalendarSyncState()
            .markCoverageComplete(calendarJid: selfJid, archiveJid: selfJid)
            .write();
        await xmppService.setMamSupportOverride(true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        final syncFuture = xmppService.syncGlobalMamCatchUp();
        await mamManager.queryStarted.future;
        eventStreamController.add(
          mox.MessageEvent(
            mox.JID.fromString(selfJid),
            mox.JID.fromString(selfJid),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData('{"calendar_sync":'),
              const mox.MessageIdData(stanzaId),
              mox.DelayedDeliveryData(mox.JID.fromString(selfJid), timestamp),
            ]),
            id: stanzaId,
            isFromMAM: true,
          ),
        );
        await pumpEventQueue(times: 20);

        mamManager.finishQuery.complete();

        expect(await syncFuture, MamGlobalSyncOutcome.completed);
        expect(
          CalendarSyncState.read().coverageStatus,
          CalendarArchiveCoverageStatus.incomplete,
        );
      },
    );

    test(
      'Personal calendar MAM still runs after global MAM calendar handling fails',
      () async {
        await _openXmppStateStore(
          'axichat_personal_global_calendar_mam_failed',
        );
        HydratedBloc.storage = _InMemoryStorage();
        final selfBare = mox.JID
            .fromString(xmppService.myJid!)
            .toBare()
            .toString();
        final timestamp = DateTime.utc(2026, 5, 3, 14, 30);
        final task = _task(
          id: 'personal-after-failed-global-task',
          title: 'Personal after failed global task',
          timestamp: timestamp,
        );
        await const CalendarSyncState()
            .markCoverageComplete(calendarJid: selfBare, archiveJid: selfBare)
            .write();
        final mamManager = ScriptedMamManager(
          eventStreamController: eventStreamController,
          pages: [
            ScriptedMamPage(
              events: [
                mox.MessageEvent(
                  mox.JID.fromString(selfBare),
                  mox.JID.fromString(selfBare),
                  false,
                  mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
                    const mox.MessageBodyData('{"calendar_sync":'),
                    const mox.MessageIdData('failed-global-calendar'),
                    mox.DelayedDeliveryData(
                      mox.JID.fromString(selfBare),
                      timestamp,
                    ),
                  ]),
                  id: 'failed-global-calendar',
                  isFromMAM: true,
                ),
              ],
              complete: true,
              first: 'failed-global-first',
              last: 'failed-global-last',
              count: 1,
            ),
            ScriptedMamPage(
              events: [
                _personalCalendarMamEvent(
                  selfBare: selfBare,
                  stanzaId: 'calendar-after-failed-global',
                  timestamp: timestamp.add(const Duration(minutes: 1)),
                  message: _taskUpdate(task: task, operation: 'add'),
                ),
              ],
              complete: true,
              first: 'calendar-after-failed-global-first',
              last: 'calendar-after-failed-global-last',
              count: 1,
            ),
          ],
        );
        await xmppService.setMamSupportOverride(true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        expect(
          await xmppService.syncGlobalMamCatchUp(),
          MamGlobalSyncOutcome.completed,
        );
        expect(
          await xmppService.rehydrateCalendarFromMam(),
          CalendarMamOutcome.completed,
        );

        final state = CalendarSyncState.read();
        expect(mamManager.queryCount, 2);
        expect(mamManager.calls.last.withJid, selfBare);
        expect(state.hasCompleteCoverage, isTrue);
        expect(state.lastHandledStanzaId, 'calendar-after-failed-global');
        expect(
          jsonEncode(HydratedBloc.storage.read(authStoragePrefix)),
          contains('Personal after failed global task'),
        );
      },
    );

    test('Calendar MAM catch-up resumes after the stored archive id', () async {
      final mamManager = RecordingMamManager();
      final cursorTimestamp = DateTime.utc(2026, 5, 1, 12);
      final selfJid = xmppService.myJid!;
      final tempDir = await Directory.systemTemp.createTemp(
        'axichat_calendar_mam_cursor',
      );
      Hive.init(tempDir.path);
      await Hive.openBox(XmppStateStore.boxName);
      addTearDown(() async {
        await Hive.deleteFromDisk();
        await tempDir.delete(recursive: true);
      });
      await CalendarSyncState(
        lastHandledTimestamp: cursorTimestamp,
        lastHandledStanzaId: 'calendar-cursor-id',
        lastArchiveResumeId: 'calendar-archive-page-id',
        calendarJid: selfJid,
        archiveJid: selfJid,
        coverageStatus: CalendarArchiveCoverageStatus.incomplete,
      ).write();
      await xmppService.setMamSupportOverride(true);
      when(
        () => mockConnection.getManager<mox.MAMManager>(),
      ).thenReturn(mamManager);

      expect(
        await xmppService.rehydrateCalendarFromMam(),
        CalendarMamOutcome.completed,
      );

      expect(mamManager.queryCount, 1);
      expect(mamManager.lastOptions?.start, cursorTimestamp);
      expect(mamManager.lastRsm?.after, 'calendar-archive-page-id');
    });

    test('Stale calendar catch-up paginates until MAM completion', () async {
      await _openXmppStateStore('axichat_calendar_mam_stale_many_updates');
      HydratedBloc.storage = _InMemoryStorage();
      final selfBare = mox.JID
          .fromString(xmppService.myJid!)
          .toBare()
          .toString();
      final cursorTimestamp = DateTime.utc(2026, 5, 1, 12);
      await CalendarSyncState(
        lastHandledTimestamp: cursorTimestamp,
        lastHandledStanzaId: 'calendar-cursor-id',
        lastArchiveResumeId: 'calendar-archive-page-id',
        calendarJid: selfBare,
        archiveJid: selfBare,
        coverageStatus: CalendarArchiveCoverageStatus.incomplete,
      ).write();
      final pageEvents = <List<mox.XmppEvent>>[
        <mox.XmppEvent>[],
        <mox.XmppEvent>[],
        <mox.XmppEvent>[],
      ];
      for (var index = 0; index < 121; index += 1) {
        final timestamp = cursorTimestamp.add(Duration(minutes: index + 1));
        final task = _task(
          id: 'stale-task-$index',
          title: 'Stale task $index',
          timestamp: timestamp,
        );
        pageEvents[index ~/ 45].add(
          _personalCalendarMamEvent(
            selfBare: selfBare,
            stanzaId: 'stale-calendar-$index',
            timestamp: timestamp,
            message: _taskUpdate(task: task, operation: 'add'),
          ),
        );
      }
      final mamManager = ScriptedMamManager(
        eventStreamController: eventStreamController,
        pages: [
          ScriptedMamPage(
            events: pageEvents[0],
            complete: false,
            first: 'page-1-first',
            last: 'page-1-last',
            count: 121,
            pumpTimes: 180,
          ),
          ScriptedMamPage(
            events: pageEvents[1],
            complete: false,
            first: 'page-2-first',
            last: 'page-2-last',
            count: 121,
            pumpTimes: 180,
          ),
          ScriptedMamPage(
            events: pageEvents[2],
            complete: true,
            first: 'page-3-first',
            last: 'page-3-last',
            count: 121,
            pumpTimes: 180,
          ),
        ],
      );
      await xmppService.setMamSupportOverride(true);
      when(
        () => mockConnection.getManager<mox.MAMManager>(),
      ).thenReturn(mamManager);

      expect(
        await xmppService.rehydrateCalendarFromMam(),
        CalendarMamOutcome.completed,
      );

      expect(mamManager.queryCount, 3);
      expect(mamManager.calls.first.start, cursorTimestamp);
      expect(mamManager.calls.first.after, 'calendar-archive-page-id');
      expect(mamManager.calls[1].after, 'page-1-last');
      expect(mamManager.calls[2].after, 'page-2-last');
      final state = CalendarSyncState.read();
      expect(state.hasCompleteCoverage, isTrue);
      expect(state.lastHandledStanzaId, 'stale-calendar-120');
      expect(state.lastArchiveResumeId, 'page-3-last');
      final stored = HydratedBloc.storage.read(authStoragePrefix);
      expect(jsonEncode(stored), contains('Stale task 120'));
    });

    test(
      'Stale calendar catch-up applies snapshot before later updates',
      () async {
        await _openXmppStateStore('axichat_calendar_mam_stale_snapshot');
        HydratedBloc.storage = _InMemoryStorage();
        final selfBare = mox.JID
            .fromString(xmppService.myJid!)
            .toBare()
            .toString();
        final cursorTimestamp = DateTime.utc(2026, 5, 1, 12);
        await CalendarSyncState(
          lastHandledTimestamp: cursorTimestamp,
          lastHandledStanzaId: 'snapshot-cursor-id',
          lastArchiveResumeId: 'snapshot-resume-id',
          calendarJid: selfBare,
          archiveJid: selfBare,
          coverageStatus: CalendarArchiveCoverageStatus.incomplete,
        ).write();
        final snapshotTime = cursorTimestamp.add(const Duration(minutes: 1));
        final updateTime = cursorTimestamp.add(const Duration(minutes: 2));
        final snapshotTask = _task(
          id: 'snapshot-range-task',
          title: 'Snapshot title',
          timestamp: snapshotTime,
        );
        final updatedTask = snapshotTask.copyWith(
          title: 'Later update title',
          modifiedAt: updateTime,
        );
        final snapshotModel = CalendarModel.empty().addTask(snapshotTask);
        final mamManager = ScriptedMamManager(
          eventStreamController: eventStreamController,
          pages: [
            ScriptedMamPage(
              events: [
                _personalCalendarMamEvent(
                  selfBare: selfBare,
                  stanzaId: 'snapshot-in-range',
                  timestamp: snapshotTime,
                  message: _inlineSnapshot(
                    model: snapshotModel,
                    timestamp: snapshotTime,
                  ),
                ),
                _personalCalendarMamEvent(
                  selfBare: selfBare,
                  stanzaId: 'snapshot-later-update',
                  timestamp: updateTime,
                  message: _taskUpdate(
                    task: updatedTask,
                    operation: 'update',
                    timestamp: updateTime,
                  ),
                ),
              ],
              complete: true,
              first: 'snapshot-page-first',
              last: 'snapshot-page-last',
              count: 2,
            ),
          ],
        );
        await xmppService.setMamSupportOverride(true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        expect(
          await xmppService.rehydrateCalendarFromMam(),
          CalendarMamOutcome.completed,
        );

        final stored = jsonEncode(HydratedBloc.storage.read(authStoragePrefix));
        final state = CalendarSyncState.read();
        expect(stored, contains('Later update title'));
        expect(state.hasCompleteCoverage, isTrue);
        expect(state.lastHandledStanzaId, 'snapshot-later-update');
        expect(state.lastArchiveResumeId, 'snapshot-page-last');
      },
    );

    test(
      'Backfill stops at newest usable snapshot and preserves newest resume id',
      () async {
        await _openXmppStateStore('axichat_calendar_mam_snapshot_backfill');
        HydratedBloc.storage = _InMemoryStorage();
        final selfBare = mox.JID
            .fromString(xmppService.myJid!)
            .toBare()
            .toString();
        final newerTime = DateTime.utc(2026, 5, 4, 12);
        final snapshotTime = newerTime.subtract(const Duration(hours: 1));
        final newerTask = _task(
          id: 'newer-page-task',
          title: 'Newer page task',
          timestamp: newerTime,
        );
        final snapshotTask = _task(
          id: 'snapshot-backfill-task',
          title: 'Snapshot backfill task',
          timestamp: snapshotTime,
        );
        final mamManager = ScriptedMamManager(
          eventStreamController: eventStreamController,
          pages: [
            ScriptedMamPage(
              events: [
                _personalCalendarMamEvent(
                  selfBare: selfBare,
                  stanzaId: 'newer-page-update',
                  timestamp: newerTime,
                  message: _taskUpdate(task: newerTask, operation: 'add'),
                ),
              ],
              complete: false,
              first: 'newer-page-first',
              last: 'newer-page-last',
              count: 3,
            ),
            ScriptedMamPage(
              events: [
                _personalCalendarMamEvent(
                  selfBare: selfBare,
                  stanzaId: 'newest-usable-snapshot',
                  timestamp: snapshotTime,
                  message: _inlineSnapshot(
                    model: CalendarModel.empty().addTask(snapshotTask),
                    timestamp: snapshotTime,
                  ),
                ),
              ],
              complete: false,
              first: 'snapshot-page-first',
              last: 'snapshot-page-last',
              count: 3,
            ),
            const ScriptedMamPage(
              complete: true,
              first: 'older-page-first',
              last: 'older-page-last',
              count: 3,
            ),
          ],
        );
        await xmppService.setMamSupportOverride(true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        expect(
          await xmppService.rehydrateCalendarFromMam(),
          CalendarMamOutcome.completed,
        );

        expect(mamManager.queryCount, 2);
        final stored = jsonEncode(HydratedBloc.storage.read(authStoragePrefix));
        final state = CalendarSyncState.read();
        expect(stored, contains('Newer page task'));
        expect(stored, contains('Snapshot backfill task'));
        expect(state.hasCompleteCoverage, isTrue);
        expect(state.lastArchiveResumeId, 'newer-page-last');
      },
    );

    test('Backfill without a snapshot runs until archive completion', () async {
      await _openXmppStateStore('axichat_calendar_mam_no_snapshot');
      HydratedBloc.storage = _InMemoryStorage();
      final warnings = <CalendarSyncWarning>[];
      final subscription = xmppService.calendarSyncWarningStream.listen(
        warnings.add,
      );
      addTearDown(subscription.cancel);
      final selfBare = mox.JID
          .fromString(xmppService.myJid!)
          .toBare()
          .toString();
      final firstTime = DateTime.utc(2026, 5, 4, 13);
      final secondTime = firstTime.subtract(const Duration(minutes: 1));
      final firstTask = _task(
        id: 'no-snapshot-task-1',
        title: 'No snapshot task 1',
        timestamp: firstTime,
      );
      final secondTask = _task(
        id: 'no-snapshot-task-2',
        title: 'No snapshot task 2',
        timestamp: secondTime,
      );
      final mamManager = ScriptedMamManager(
        eventStreamController: eventStreamController,
        pages: [
          ScriptedMamPage(
            events: [
              _personalCalendarMamEvent(
                selfBare: selfBare,
                stanzaId: 'no-snapshot-update-1',
                timestamp: firstTime,
                message: _taskUpdate(task: firstTask, operation: 'add'),
              ),
            ],
            complete: false,
            first: 'no-snapshot-page-1-first',
            last: 'no-snapshot-page-1-last',
            count: 2,
          ),
          ScriptedMamPage(
            events: [
              _personalCalendarMamEvent(
                selfBare: selfBare,
                stanzaId: 'no-snapshot-update-2',
                timestamp: secondTime,
                message: _taskUpdate(task: secondTask, operation: 'add'),
              ),
            ],
            complete: true,
            first: 'no-snapshot-page-2-first',
            last: 'no-snapshot-page-2-last',
            count: 2,
          ),
        ],
      );
      await xmppService.setMamSupportOverride(true);
      when(
        () => mockConnection.getManager<mox.MAMManager>(),
      ).thenReturn(mamManager);

      expect(
        await xmppService.rehydrateCalendarFromMam(),
        CalendarMamOutcome.completed,
      );

      expect(mamManager.queryCount, 2);
      expect(CalendarSyncState.read().hasCompleteCoverage, isTrue);
      expect(warnings, isEmpty);
      final stored = jsonEncode(HydratedBloc.storage.read(authStoragePrefix));
      expect(stored, contains('No snapshot task 1'));
      expect(stored, contains('No snapshot task 2'));
    });

    test(
      'Brand-new completed empty calendar archive does not emit warning',
      () async {
        await _openXmppStateStore('axichat_calendar_mam_empty_complete');
        HydratedBloc.storage = _InMemoryStorage();
        final warnings = <CalendarSyncWarning>[];
        final subscription = xmppService.calendarSyncWarningStream.listen(
          warnings.add,
        );
        addTearDown(subscription.cancel);
        final mamManager = ScriptedMamManager(
          eventStreamController: eventStreamController,
          pages: const [ScriptedMamPage(complete: true, count: 0)],
        );
        await xmppService.setMamSupportOverride(true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        expect(
          await xmppService.rehydrateCalendarFromMam(),
          CalendarMamOutcome.completed,
        );

        expect(mamManager.queryCount, 1);
        expect(warnings, isEmpty);
        expect(CalendarSyncState.read().hasCompleteCoverage, isTrue);
      },
    );

    test(
      'Fresh local state incomplete calendar archive warns without sync envelopes',
      () async {
        await _openXmppStateStore('axichat_calendar_mam_empty_incomplete');
        HydratedBloc.storage = _InMemoryStorage();
        final warnings = <CalendarSyncWarning>[];
        final subscription = xmppService.calendarSyncWarningStream.listen(
          warnings.add,
        );
        addTearDown(subscription.cancel);
        final mamManager = ScriptedMamManager(
          eventStreamController: eventStreamController,
          pages: const [ScriptedMamPage(complete: false, count: 1)],
        );
        await xmppService.setMamSupportOverride(true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        expect(
          await xmppService.rehydrateCalendarFromMam(),
          CalendarMamOutcome.incomplete,
        );

        expect(mamManager.queryCount, 1);
        expect(
          warnings.map((warning) => warning.type),
          contains(CalendarSyncWarningType.archiveIncomplete),
        );
        expect(
          CalendarSyncState.read().coverageStatus,
          CalendarArchiveCoverageStatus.incomplete,
        );
      },
    );

    test(
      'Incomplete calendar archive emits warning after processing sync envelope',
      () async {
        await _openXmppStateStore('axichat_calendar_mam_update_incomplete');
        HydratedBloc.storage = _InMemoryStorage();
        final warnings = <CalendarSyncWarning>[];
        final subscription = xmppService.calendarSyncWarningStream.listen(
          warnings.add,
        );
        addTearDown(subscription.cancel);
        final selfBare = mox.JID
            .fromString(xmppService.myJid!)
            .toBare()
            .toString();
        final timestamp = DateTime.utc(2026, 5, 4, 15);
        final task = _task(
          id: 'incomplete-update-task',
          title: 'Incomplete archive update',
          timestamp: timestamp,
        );
        final mamManager = ScriptedMamManager(
          eventStreamController: eventStreamController,
          pages: [
            ScriptedMamPage(
              events: [
                _personalCalendarMamEvent(
                  selfBare: selfBare,
                  stanzaId: 'incomplete-update',
                  timestamp: timestamp,
                  message: _taskUpdate(task: task, operation: 'add'),
                ),
              ],
              complete: false,
              count: 1,
            ),
          ],
        );
        await xmppService.setMamSupportOverride(true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        expect(
          await xmppService.rehydrateCalendarFromMam(),
          CalendarMamOutcome.incomplete,
        );

        final state = CalendarSyncState.read();
        final stored = jsonEncode(HydratedBloc.storage.read(authStoragePrefix));
        expect(mamManager.queryCount, 1);
        expect(state.coverageStatus, CalendarArchiveCoverageStatus.incomplete);
        expect(state.lastHandledStanzaId, 'incomplete-update');
        expect(
          warnings.map((warning) => warning.type),
          contains(CalendarSyncWarningType.archiveIncomplete),
        );
        expect(stored, contains('Incomplete archive update'));
      },
    );

    test(
      'Unsupported snapshot leaves calendar MAM incomplete without advancing page resume',
      () async {
        await _openXmppStateStore('axichat_calendar_mam_bad_snapshot');
        HydratedBloc.storage = _InMemoryStorage();
        final warnings = <CalendarSyncWarning>[];
        final subscription = xmppService.calendarSyncWarningStream.listen(
          warnings.add,
        );
        addTearDown(subscription.cancel);
        final selfBare = mox.JID
            .fromString(xmppService.myJid!)
            .toBare()
            .toString();
        final timestamp = DateTime.utc(2026, 5, 4, 14);
        final task = _task(
          id: 'unsupported-snapshot-task',
          title: 'Unsupported snapshot task',
          timestamp: timestamp,
        );
        final mamManager = ScriptedMamManager(
          eventStreamController: eventStreamController,
          pages: [
            ScriptedMamPage(
              events: [
                _personalCalendarMamEvent(
                  selfBare: selfBare,
                  stanzaId: 'unsupported-calendar-snapshot',
                  timestamp: timestamp,
                  message: _inlineSnapshot(
                    model: CalendarModel.empty().addTask(task),
                    timestamp: timestamp,
                    snapshotVersion: 999,
                  ),
                ),
              ],
              complete: false,
              first: 'bad-snapshot-first',
              last: 'bad-snapshot-last',
              count: 2,
            ),
            const ScriptedMamPage(
              complete: true,
              first: 'older-after-bad-snapshot-first',
              last: 'older-after-bad-snapshot-last',
              count: 2,
            ),
          ],
        );
        await xmppService.setMamSupportOverride(true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        expect(
          await xmppService.rehydrateCalendarFromMam(),
          CalendarMamOutcome.incomplete,
        );

        final state = CalendarSyncState.read();
        final stored = jsonEncode(HydratedBloc.storage.read(authStoragePrefix));
        expect(mamManager.queryCount, 1);
        expect(state.coverageStatus, CalendarArchiveCoverageStatus.incomplete);
        expect(state.lastHandledStanzaId, 'unsupported-calendar-snapshot');
        expect(state.lastArchiveResumeId, isNot('bad-snapshot-last'));
        expect(
          warnings.map((warning) => warning.type),
          contains(CalendarSyncWarningType.archiveIncomplete),
        );
        expect(stored, isNot(contains('Unsupported snapshot task')));
      },
    );

    test(
      'Unsupported chat snapshot leaves calendar MAM incomplete without advancing page resume',
      () async {
        const peerJid = 'peer@example.com';
        await _openXmppStateStore('axichat_chat_calendar_mam_bad_snapshot');
        final storage = _InMemoryStorage();
        HydratedBloc.storage = storage;
        final selfBare = mox.JID
            .fromString(xmppService.myJid!)
            .toBare()
            .toString();
        final timestamp = DateTime.utc(2026, 5, 4, 14, 30);
        final task = _task(
          id: 'unsupported-chat-snapshot-task',
          title: 'Unsupported chat snapshot task',
          timestamp: timestamp,
        );
        final mamManager = ScriptedMamManager(
          eventStreamController: eventStreamController,
          pages: [
            ScriptedMamPage(
              events: [
                _directCalendarMamEvent(
                  peerBare: peerJid,
                  selfBare: selfBare,
                  stanzaId: 'unsupported-chat-calendar-snapshot',
                  timestamp: timestamp,
                  message: _inlineSnapshot(
                    model: CalendarModel.empty().addTask(task),
                    timestamp: timestamp,
                    snapshotVersion: 999,
                  ),
                ),
              ],
              complete: false,
              first: 'bad-chat-snapshot-first',
              last: 'bad-chat-snapshot-last',
              count: 2,
            ),
            const ScriptedMamPage(
              complete: true,
              first: 'older-after-bad-chat-snapshot-first',
              last: 'older-after-bad-chat-snapshot-last',
              count: 2,
            ),
          ],
        );
        await xmppService.setMamSupportOverride(true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        expect(
          await xmppService.rehydrateChatCalendarFromMam(
            chatJid: peerJid,
            chatType: ChatType.chat,
          ),
          CalendarMamOutcome.incomplete,
        );

        final state = const ChatCalendarSyncStateStore().read(peerJid);
        final model = ChatCalendarStorage(storage: storage).readModel(peerJid);
        expect(mamManager.queryCount, 1);
        expect(state.coverageStatus, CalendarArchiveCoverageStatus.incomplete);
        expect(state.lastHandledStanzaId, 'unsupported-chat-calendar-snapshot');
        expect(state.lastArchiveResumeId, isNot('bad-chat-snapshot-last'));
        expect(model.tasks, isEmpty);
      },
    );

    test(
      'Calendar MAM page failure keeps applied updates but not page resume id',
      () async {
        await _openXmppStateStore('axichat_calendar_mam_page_failure_resume');
        HydratedBloc.storage = _InMemoryStorage();
        final selfBare = mox.JID
            .fromString(xmppService.myJid!)
            .toBare()
            .toString();
        final timestamp = DateTime.utc(2026, 5, 4, 15);
        final task = _task(
          id: 'page-failure-valid-task',
          title: 'Page failure valid task',
          timestamp: timestamp,
        );
        final mamManager = ScriptedMamManager(
          eventStreamController: eventStreamController,
          pages: [
            ScriptedMamPage(
              events: [
                _personalCalendarMamEvent(
                  selfBare: selfBare,
                  stanzaId: 'page-failure-valid-update',
                  timestamp: timestamp,
                  message: _taskUpdate(task: task, operation: 'add'),
                ),
                mox.MessageEvent(
                  mox.JID.fromString(selfBare),
                  mox.JID.fromString(selfBare),
                  false,
                  mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
                    const mox.MessageBodyData('{"calendar_sync":'),
                    const mox.MessageIdData('page-failure-malformed'),
                    mox.DelayedDeliveryData(
                      mox.JID.fromString(selfBare),
                      timestamp.add(const Duration(minutes: 1)),
                    ),
                  ]),
                  id: 'page-failure-malformed',
                  isFromMAM: true,
                ),
              ],
              complete: true,
              first: 'page-failure-first',
              last: 'page-failure-last',
              count: 2,
            ),
          ],
        );
        await xmppService.setMamSupportOverride(true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        expect(
          await xmppService.rehydrateCalendarFromMam(),
          CalendarMamOutcome.incomplete,
        );

        final stored = jsonEncode(HydratedBloc.storage.read(authStoragePrefix));
        final state = CalendarSyncState.read();
        expect(stored, contains('Page failure valid task'));
        expect(state.coverageStatus, CalendarArchiveCoverageStatus.incomplete);
        expect(state.lastArchiveResumeId, isNot('page-failure-last'));
      },
    );

    test(
      'Calendar MAM keeps coverage incomplete when page handling fails',
      () async {
        const stanzaId = 'malformed-calendar-envelope';
        final timestamp = DateTime.utc(2026, 5, 1, 12);
        final selfJid = xmppService.myJid!;
        final mamManager = BlockingMamManager();
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat_calendar_mam_incomplete',
        );
        Hive.init(tempDir.path);
        await Hive.openBox(XmppStateStore.boxName);
        addTearDown(() async {
          await Hive.deleteFromDisk();
          await tempDir.delete(recursive: true);
        });
        await xmppService.setMamSupportOverride(true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        final syncFuture = xmppService.rehydrateCalendarFromMam();
        await mamManager.queryStarted.future;
        eventStreamController.add(
          mox.MessageEvent(
            mox.JID.fromString(selfJid),
            mox.JID.fromString(selfJid),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData('{"calendar_sync":'),
              const mox.MessageIdData(stanzaId),
              mox.DelayedDeliveryData(mox.JID.fromString(selfJid), timestamp),
            ]),
            id: stanzaId,
            isFromMAM: true,
          ),
        );
        await pumpEventQueue(times: 20);

        mamManager.finishQuery.complete();

        expect(await syncFuture, CalendarMamOutcome.incomplete);
        expect(
          CalendarSyncState.read().coverageStatus,
          CalendarArchiveCoverageStatus.incomplete,
        );
      },
    );

    test(
      'Group calendar MAM applies participant envelopes and completes coverage',
      () async {
        const roomJid = 'room@conference.axi.im';
        const selfNick = 'me';
        const senderNick = 'alice';
        const senderOccupantId = '$roomJid/$senderNick';
        const stanzaId = 'group-calendar-mam-envelope';
        final timestamp = DateTime.utc(2026, 5, 2, 13);
        final storage = _InMemoryStorage();
        final mamManager = BlockingMamManager();
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat_group_calendar_mam',
        );
        Hive.init(tempDir.path);
        await Hive.openBox(XmppStateStore.boxName);
        addTearDown(() async {
          await Hive.deleteFromDisk();
          await tempDir.delete(recursive: true);
        });
        HydratedBloc.storage = storage;
        await xmppService.setMucServiceHost('conference.axi.im');
        await xmppService.setMamSupportOverride(true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: '$roomJid/$selfNick',
          nick: selfNick,
          realJid: xmppService.myJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: senderOccupantId,
          nick: senderNick,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
        );

        final task = CalendarTask(
          id: 'group-calendar-task',
          title: 'Group calendar task',
          createdAt: timestamp,
          modifiedAt: timestamp,
        );
        final syncEnvelope = jsonEncode({
          'calendar_sync': CalendarSyncMessage(
            type: CalendarSyncType.update,
            timestamp: timestamp,
            taskId: task.id,
            operation: 'add',
            data: task.toJson(),
          ).toJson(),
        });

        final syncFuture = xmppService.rehydrateChatCalendarFromMam(
          chatJid: roomJid,
          chatType: ChatType.groupChat,
        );
        await mamManager.queryStarted.future;
        eventStreamController.add(
          mox.MessageEvent(
            mox.JID.fromString(senderOccupantId),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              mox.MessageBodyData(syncEnvelope),
              const mox.MessageIdData(stanzaId),
              mox.DelayedDeliveryData(mox.JID.fromString(roomJid), timestamp),
            ]),
            id: stanzaId,
            isFromMAM: true,
            type: 'groupchat',
          ),
        );
        await pumpEventQueue(times: 20);
        mamManager.finishQuery.complete();

        expect(await syncFuture, CalendarMamOutcome.completed);
        final model = ChatCalendarStorage(storage: storage).readModel(roomJid);
        expect(model.tasks[task.id]?.title, 'Group calendar task');
        final state = const ChatCalendarSyncStateStore().read(roomJid);
        expect(state.hasCompleteCoverage, isTrue);
        expect(state.lastHandledStanzaId, stanzaId);
      },
    );

    test('MAM calendar envelopes bypass the live inbound rate limit', () async {
      const envelopeCount = 121;
      final storage = _InMemoryStorage();
      final tempDir = await Directory.systemTemp.createTemp(
        'axichat_calendar_mam_rate_limit',
      );
      Hive.init(tempDir.path);
      await Hive.openBox(XmppStateStore.boxName);
      addTearDown(() async {
        await Hive.deleteFromDisk();
        await tempDir.delete(recursive: true);
      });
      HydratedBloc.storage = storage;

      final selfBare = mox.JID.fromString(xmppService.myJid!).toBare();
      final baseTimestamp = DateTime.utc(2026, 5, 2, 12);
      for (var index = 0; index < envelopeCount; index += 1) {
        final timestamp = baseTimestamp.add(Duration(seconds: index));
        final task = CalendarTask(
          id: 'mam-calendar-task-$index',
          title: 'MAM calendar task $index',
          createdAt: timestamp,
          modifiedAt: timestamp,
        );
        final stanzaId = 'mam-calendar-envelope-$index';
        final syncEnvelope = jsonEncode({
          'calendar_sync': CalendarSyncMessage(
            type: CalendarSyncType.update,
            timestamp: timestamp,
            taskId: task.id,
            operation: 'update',
            data: task.toJson(),
          ).toJson(),
        });
        eventStreamController.add(
          mox.MessageEvent(
            selfBare,
            selfBare,
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              mox.MessageBodyData(syncEnvelope),
              mox.MessageIdData(stanzaId),
              mox.DelayedDeliveryData(selfBare, timestamp),
            ]),
            id: stanzaId,
            isFromMAM: true,
          ),
        );
      }

      await pumpEventQueue(times: 300);

      final state = CalendarSyncState.read();
      expect(
        state.lastHandledStanzaId,
        'mam-calendar-envelope-${envelopeCount - 1}',
      );
    });

    test(
      'Calendar sync outbound messages are stored in the XMPP archive',
      () async {
        const peerJid = 'peer@example.com';
        const snapshotUrl = 'https://files.example.com/calendar.snapshot';
        const snapshotName = 'calendar.snapshot';
        final timestamp = DateTime.utc(2026, 5, 4, 16);
        final task = _task(
          id: 'outbound-archive-task',
          title: 'Outbound archive task',
          timestamp: timestamp,
        );
        final envelope = _calendarEnvelope(
          _taskUpdate(task: task, operation: 'add'),
        );
        when(() => mockConnection.generateId()).thenReturn('calendar-outbound');
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => true);

        await xmppService.sendCalendarSyncMessage(
          jid: peerJid,
          outbound: CalendarSyncOutbound(
            envelope: envelope,
            attachment: const CalendarSyncAttachment(
              url: snapshotUrl,
              fileName: snapshotName,
              mimeType: 'application/vnd.axichat.calendar.snapshot+json',
            ),
          ),
        );

        final sent =
            verify(
                  () => mockConnection.sendMessage(captureAny()),
                ).captured.single
                as mox.MessageEvent;
        final storedMessages = await database.getChatMessages(
          peerJid,
          start: 0,
          end: 10,
        );
        expect(storedMessages, isEmpty);
        expect(sent.to.toString(), peerJid);
        expect(sent.encrypted, isFalse);
        expect(sent.text, envelope);
        expect(
          sent.extensions.get<mox.MessageProcessingHintData>()?.hints.contains(
            mox.MessageProcessingHint.store,
          ),
          isTrue,
        );
        expect(sent.extensions.get<mox.OOBData>()?.url, snapshotUrl);
        expect(sent.extensions.get<mox.OOBData>()?.desc, snapshotName);
      },
    );

    test('Read-only task shares persist the task owner map.', () async {
      const peerJid = 'peer@example.com';
      const taskId = 'shared-read-only-task';
      final createdAt = DateTime.utc(2026, 5, 2, 12);
      final stateStoreValues = <String, Object?>{};
      var generatedIds = 0;
      _stubStateStoreValues(stateStoreValues);
      when(() => mockConnection.generateId()).thenAnswer((_) {
        generatedIds += 1;
        return 'local-share-$generatedIds';
      });

      final task = CalendarTask(
        id: taskId,
        title: 'Owner title',
        createdAt: createdAt,
        modifiedAt: createdAt,
      );
      await xmppService.sendLocalOnlyMessage(
        jid: peerJid,
        text: 'shared task',
        calendarTaskIcs: task,
      );

      final rawOwnerMap = stateStoreValues.values
          .whereType<String>()
          .firstWhere((value) => value.contains(taskId));
      final decoded = jsonDecode(rawOwnerMap) as Map<String, dynamic>;
      expect((decoded[peerJid] as Map<String, dynamic>)[taskId], 'jid@axi.im');
    });

    test('Loaded read-only task owners block peer calendar updates.', () async {
      const peerJid = 'peer@example.com';
      const taskId = 'shared-read-only-task';
      const stanzaId = 'blocked-read-only-calendar-sync';
      final createdAt = DateTime.utc(2026, 5, 2, 12);
      final stateStoreValues = <String, Object?>{};
      final tempDir = await Directory.systemTemp.createTemp(
        'axichat_calendar_read_only',
      );
      final storage = _InMemoryStorage();
      Hive.init(tempDir.path);
      await Hive.openBox(XmppStateStore.boxName);
      addTearDown(() async {
        await Hive.deleteFromDisk();
        await tempDir.delete(recursive: true);
      });
      HydratedBloc.storage = storage;
      stateStoreValues['calendar_read_only_task_owners_v1'] = jsonEncode({
        peerJid: {taskId: 'jid@axi.im'},
      });
      _stubStateStoreValues(stateStoreValues);

      final task = CalendarTask(
        id: taskId,
        title: 'Owner title',
        createdAt: createdAt,
        modifiedAt: createdAt,
      );
      final peerTask = task.copyWith(
        title: 'Peer edit',
        modifiedAt: createdAt.add(const Duration(minutes: 1)),
      );
      final syncEnvelope = jsonEncode({
        'calendar_sync': CalendarSyncMessage(
          type: CalendarSyncType.update,
          timestamp: peerTask.modifiedAt,
          taskId: taskId,
          operation: 'update',
          data: peerTask.toJson(),
        ).toJson(),
      });
      eventStreamController.add(
        mox.MessageEvent(
          mox.JID.fromString(peerJid),
          mox.JID.fromString(jid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            mox.MessageBodyData(syncEnvelope),
            mox.MessageIdData(stanzaId),
            mox.DelayedDeliveryData(
              mox.JID.fromString(peerJid),
              peerTask.modifiedAt,
            ),
          ]),
          id: stanzaId,
        ),
      );
      await pumpEventQueue(times: 20);

      final model = ChatCalendarStorage(storage: storage).readModel(peerJid);
      expect(model.tasks[taskId], isNull);
      final state = const ChatCalendarSyncStateStore().read(peerJid);
      expect(state.lastHandledStanzaId, stanzaId);
    });

    test('Read-only task owners are enforced for snapshots.', () async {
      const peerJid = 'peer@example.com';
      const taskId = 'shared-read-only-task';
      const stanzaId = 'blocked-read-only-calendar-snapshot';
      final createdAt = DateTime.utc(2026, 5, 2, 12);
      final stateStoreValues = <String, Object?>{};
      final tempDir = await Directory.systemTemp.createTemp(
        'axichat_calendar_read_only_snapshot',
      );
      final storage = _InMemoryStorage();
      Hive.init(tempDir.path);
      await Hive.openBox(XmppStateStore.boxName);
      addTearDown(() async {
        await Hive.deleteFromDisk();
        await tempDir.delete(recursive: true);
      });
      HydratedBloc.storage = storage;
      stateStoreValues['calendar_read_only_task_owners_v1'] = jsonEncode({
        peerJid: {taskId: 'jid@axi.im'},
      });
      _stubStateStoreValues(stateStoreValues);

      final ownerTask = CalendarTask(
        id: taskId,
        title: 'Owner title',
        createdAt: createdAt,
        modifiedAt: createdAt,
      );
      final peerTask = ownerTask.copyWith(
        title: 'Peer snapshot edit',
        modifiedAt: createdAt.add(const Duration(minutes: 1)),
      );
      final storageHandle = ChatCalendarStorage(storage: storage);
      await storageHandle.writeModel(
        peerJid,
        CalendarModel.empty().addTask(ownerTask),
      );
      final snapshotModel = CalendarModel.empty().addTask(peerTask);
      final checksum = snapshotModel.calculateChecksum();
      final syncEnvelope = jsonEncode({
        'calendar_sync': CalendarSyncMessage(
          type: CalendarSyncType.snapshot,
          timestamp: peerTask.modifiedAt,
          data: snapshotModel.toJson(),
          checksum: checksum,
          isSnapshot: true,
          snapshotChecksum: checksum,
        ).toJson(),
      });

      eventStreamController.add(
        mox.MessageEvent(
          mox.JID.fromString(peerJid),
          mox.JID.fromString(jid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            mox.MessageBodyData(syncEnvelope),
            mox.MessageIdData(stanzaId),
            mox.DelayedDeliveryData(
              mox.JID.fromString(peerJid),
              peerTask.modifiedAt,
            ),
          ]),
          id: stanzaId,
        ),
      );
      await pumpEventQueue(times: 20);

      final model = storageHandle.readModel(peerJid);
      expect(model.tasks[taskId]?.title, 'Owner title');
      final state = const ChatCalendarSyncStateStore().read(peerJid);
      expect(state.lastHandledStanzaId, stanzaId);

      const deleteStanzaId = 'blocked-read-only-calendar-snapshot-delete';
      final deleteTime = peerTask.modifiedAt.add(const Duration(minutes: 1));
      final deleteSnapshotBase = CalendarModel.empty().copyWith(
        deletedTaskIds: {taskId: deleteTime},
      );
      final deleteSnapshotModel = deleteSnapshotBase.copyWith(
        checksum: deleteSnapshotBase.calculateChecksum(),
      );
      final deleteChecksum = deleteSnapshotModel.calculateChecksum();
      final deleteEnvelope = jsonEncode({
        'calendar_sync': CalendarSyncMessage(
          type: CalendarSyncType.snapshot,
          timestamp: deleteTime,
          data: deleteSnapshotModel.toJson(),
          checksum: deleteChecksum,
          isSnapshot: true,
          snapshotChecksum: deleteChecksum,
        ).toJson(),
      });
      eventStreamController.add(
        mox.MessageEvent(
          mox.JID.fromString(peerJid),
          mox.JID.fromString(jid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            mox.MessageBodyData(deleteEnvelope),
            mox.MessageIdData(deleteStanzaId),
            mox.DelayedDeliveryData(mox.JID.fromString(peerJid), deleteTime),
          ]),
          id: deleteStanzaId,
        ),
      );
      await pumpEventQueue(times: 20);

      final modelAfterDelete = storageHandle.readModel(peerJid);
      expect(modelAfterDelete.tasks[taskId]?.title, 'Owner title');
      final stateAfterDelete = const ChatCalendarSyncStateStore().read(peerJid);
      expect(stateAfterDelete.lastHandledStanzaId, deleteStanzaId);
    });

    test(
      'When enabling carbons throws on a fresh login, still runs MAM catch-up.',
      () async {
        final mamManager = RecordingMamManager();
        final presenceManager = MockPresenceManager();
        stubUnsafeBootstrapManagersUnavailable();
        await xmppService.setMamSupportOverride(true);
        when(() => mockConnection.carbonsEnabled).thenReturn(false);
        when(
          () => mockConnection.enableCarbons(),
        ).thenThrow(Exception('carbons failed'));
        when(
          () => mockConnection.getManager<XmppPresenceManager>(),
        ).thenReturn(presenceManager);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.connecting,
          ),
        );
        eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));

        await pumpEventQueue(times: 20);

        verifyNever(() => presenceManager.sendInitialPresence());
        expect(mamManager.queryCount, 2);
      },
    );
  });

  group('connect', () {
    bool builtStateStore = false;
    bool builtDatabase = false;

    XmppStateStore buildStateStore(String _, String _) {
      builtStateStore = true;
      return mockStateStore;
    }

    XmppDatabase buildDatabase(String _, String _) {
      builtDatabase = true;
      return database;
    }

    setUp(() {
      builtStateStore = false;
      builtDatabase = false;
      xmppService = XmppService(
        buildConnection: () => mockConnection,
        buildStateStore: buildStateStore,
        buildDatabase: buildDatabase,
        notificationService: mockNotificationService,
      );
    });

    tearDown(() async {
      await xmppService.close();
    });

    tearDown(() {
      resetMocktailState();
    });

    test('Given valid credentials, initialises the databases.', () async {
      await connectSuccessfully(xmppService);

      expect(builtStateStore, true);
      expect(builtDatabase, true);
    });

    test('Given valid credentials, registers all feature managers.', () async {
      await connectSuccessfully(xmppService);

      verify(
        () => mockConnection.registerManagers(
          any(
            that: predicate<List<mox.XmppManagerBase>>(
              (items) => items.indexed.every((e) {
                final (index, manager) = e;
                return manager.runtimeType ==
                    xmppService.featureManagers[index].runtimeType;
              }),
            ),
          ),
        ),
      ).called(1);
    });

    test('Uses the Axichat entity capabilities manager wrapper.', () {
      final runtimeTypes = xmppService.featureManagers
          .map((manager) => manager.runtimeType.toString())
          .toList(growable: false);

      expect(runtimeTypes, contains('_AxiEntityCapabilitiesManager'));
      expect(runtimeTypes, isNot(contains('EntityCapabilitiesManager')));
    });

    test(
      'Given invalid credentials, throws an XmppAuthenticationException.',
      () async {
        await expectLater(
          () => connectUnsuccessfully(xmppService),
          throwsA(isA<XmppAuthenticationException>()),
        );

        await pumpEventQueue();

        expect(builtDatabase, false);
      },
    );

    test(
      'Given an unspecified SASL failure, throws an XmppAuthenticationException.',
      () async {
        await expectLater(
          () => connectUnsuccessfully(
            xmppService,
            error: mox.SaslUnspecifiedError(),
          ),
          throwsA(isA<XmppAuthenticationException>()),
        );

        await pumpEventQueue();

        expect(builtDatabase, false);
      },
    );

    test(
      'Attempting to connect when already connected throws an XmppAlreadyConnectedException.',
      () async {
        await connectSuccessfully(xmppService);
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.notConnected,
          ),
        );
        await pumpEventQueue();

        await expectLater(
          () => xmppService.connect(
            jid: jid,
            password: password,
            databasePrefix: '',
            databasePassphrase: '',
          ),
          throwsA(isA<XmppAlreadyConnectedException>()),
        );
      },
    );
  });

  group('disconnect', () {
    setUp(() async {
      xmppService = XmppService(
        buildConnection: () => mockConnection,
        buildStateStore: (_, _) => mockStateStore,
        buildDatabase: (_, _) => database,
        notificationService: mockNotificationService,
      );
      await connectSuccessfully(xmppService);
    });

    tearDown(() async {
      await xmppService.close();
      await pumpEventQueue();
    });

    test(
      'Disconnect does not surface database stream errors to live subscriptions.',
      () async {
        final errors = <Object>[];
        final subscriptions = <StreamSubscription<dynamic>>[
          (xmppService as ChatsService).chatsStream().listen(
            (_) {},
            onError: errors.add,
          ),
          (xmppService as MessageService).draftsStream().listen(
            (_) {},
            onError: errors.add,
          ),
          (xmppService as RosterService).rosterStream().listen(
            (_) {},
            onError: errors.add,
          ),
          (xmppService as RosterService).invitesStream().listen(
            (_) {},
            onError: errors.add,
          ),
        ];

        await pumpEventQueue();
        await xmppService.disconnect();
        await pumpEventQueue();

        expect(errors, isEmpty);
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
  });

  group('reconnect admission', () {
    late XmppReconnectionPolicy reconnectionPolicy;
    late List<ReconnectTrigger> reconnectTriggers;

    setUp(() async {
      reconnectionPolicy = XmppReconnectionPolicy.exponential();
      reconnectTriggers = <ReconnectTrigger>[];
      when(
        () => mockConnection.reconnectionPolicy,
      ).thenReturn(reconnectionPolicy);
      when(
        () => mockConnection.isReconnecting(),
      ).thenAnswer((_) async => false);
      when(() => mockConnection.setShouldReconnect(any())).thenAnswer((
        invocation,
      ) async {
        await reconnectionPolicy.setShouldReconnect(
          invocation.positionalArguments.first as bool,
        );
      });
      when(() => mockConnection.requestReconnect(any())).thenAnswer((
        invocation,
      ) async {
        reconnectTriggers.add(
          invocation.positionalArguments.first as ReconnectTrigger,
        );
        return ReconnectRequestOutcome.dispatched;
      });

      xmppService = XmppService(
        buildConnection: () => mockConnection,
        buildStateStore: (_, _) => mockStateStore,
        buildDatabase: (_, _) => database,
        notificationService: mockNotificationService,
      );
      await connectSuccessfully(xmppService);
    });

    tearDown(() async {
      await xmppService.close();
      await pumpEventQueue();
    });

    test('requestReconnect returns true when already connected.', () async {
      eventStreamController.add(
        mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.connected,
          mox.XmppConnectionState.notConnected,
        ),
      );
      await pumpEventQueue();

      expect(
        await xmppService.requestReconnect(ReconnectTrigger.networkAvailable),
        isTrue,
      );
      expect(reconnectTriggers, isEmpty);
    });

    test(
      'unexpected stream disconnect requests auto reconnect even when lower policy is disabled.',
      () async {
        await reconnectionPolicy.setShouldReconnect(false);

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.notConnected,
            mox.XmppConnectionState.connected,
          ),
        );
        await pumpEventQueue(times: 10);

        expect(xmppService.connectionState, ConnectionState.notConnected);
        expect(await reconnectionPolicy.getShouldReconnect(), isTrue);
        expect(await reconnectionPolicy.getIsReconnecting(), isTrue);
      },
    );

    test(
      'requestReconnect returns true when lower reconnect is already active.',
      () async {
        await reconnectionPolicy.setShouldReconnect(true);
        expect(await reconnectionPolicy.canTriggerFailure(), isTrue);
        when(
          () => mockConnection.isReconnecting(),
        ).thenAnswer((_) => reconnectionPolicy.getIsReconnecting());

        expect(
          await xmppService.requestReconnect(ReconnectTrigger.autoFailure),
          isTrue,
        );
        expect(reconnectTriggers, isEmpty);
      },
    );

    test(
      'requestReconnect reflects an accepted lower reconnect as connecting.',
      () async {
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.notConnected,
            mox.XmppConnectionState.connected,
          ),
        );
        await pumpEventQueue();

        when(() => mockConnection.isReconnecting()).thenAnswer((_) async {
          return true;
        });
        when(
          () => mockConnection.requestReconnect(ReconnectTrigger.resume),
        ).thenAnswer((_) async {
          reconnectTriggers.add(ReconnectTrigger.resume);
          return ReconnectRequestOutcome.joinedActiveCycle;
        });
        final states = <ConnectionState>[];
        final subscription = xmppService.connectivityStream.listen(states.add);
        addTearDown(subscription.cancel);

        expect(
          await xmppService.requestReconnect(ReconnectTrigger.resume),
          isTrue,
        );
        await pumpEventQueue();

        expect(xmppService.connectionState, ConnectionState.connecting);
        expect(states, [ConnectionState.connecting]);
        expect(reconnectTriggers, [ReconnectTrigger.resume]);
      },
    );

    test(
      'requestReconnect returns true when connect already in flight.',
      () async {
        final settings = XmppConnectionSettings(
          jid: mox.JID.fromString(jid).withResource('test-resource'),
          password: password,
        );
        final connectCompleter =
            Completer<moxlib.Result<bool, mox.XmppError>>();

        await xmppService.close();
        await pumpEventQueue();

        when(
          () => mockNotificationService.notificationPreviewsEnabled,
        ).thenReturn(false);
        when(
          () => mockStateStore.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockStateStore.writeAll(data: any(named: 'data')),
        ).thenAnswer((_) async => true);
        when(
          () => mockStateStore.delete(key: any(named: 'key')),
        ).thenAnswer((_) async => true);
        when(
          () => mockStateStore.read(key: any(named: 'key')),
        ).thenReturn(null);
        when(() => mockConnection.connectionSettings).thenReturn(settings);
        when(() => mockConnection.hasConnectionSettings).thenReturn(true);
        when(
          () => mockConnection.connect(
            shouldReconnect: false,
            waitForConnection: true,
            waitUntilLogin: true,
          ),
        ).thenAnswer((_) => connectCompleter.future);

        xmppService = XmppService(
          buildConnection: () => mockConnection,
          buildStateStore: (_, _) => mockStateStore,
          buildDatabase: (_, _) => database,
          notificationService: mockNotificationService,
        );

        final connectFuture = xmppService.connect(
          jid: jid,
          password: password,
          databasePrefix: '',
          databasePassphrase: '',
        );
        await pumpEventQueue();

        expect(
          await xmppService.requestReconnect(ReconnectTrigger.networkAvailable),
          isTrue,
        );
        verifyNever(() => mockConnection.requestReconnect(any()));

        connectCompleter.complete(
          const moxlib.Result<bool, mox.XmppError>(true),
        );
        await connectFuture;
        await pumpEventQueue();
      },
    );

    test(
      'pauseAutomaticReconnect disables lower reconnect and clears connecting state.',
      () async {
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connecting,
            mox.XmppConnectionState.notConnected,
          ),
        );
        await pumpEventQueue();
        await reconnectionPolicy.setShouldReconnect(true);

        await xmppService.pauseAutomaticReconnect();

        expect(xmppService.connectionState, ConnectionState.notConnected);
        expect(await reconnectionPolicy.getShouldReconnect(), isFalse);
      },
    );

    test(
      'networkAvailable and autoFailure stay ignored while automatic reconnect is paused.',
      () async {
        await xmppService.pauseAutomaticReconnect();
        reconnectTriggers.clear();

        expect(
          await xmppService.requestReconnect(ReconnectTrigger.networkAvailable),
          isFalse,
        );
        expect(
          await xmppService.requestReconnect(ReconnectTrigger.autoFailure),
          isFalse,
        );

        expect(reconnectTriggers, isEmpty);
        expect(await reconnectionPolicy.getShouldReconnect(), isFalse);
      },
    );

    test('resume clears pause and dispatches reconnect normally.', () async {
      await xmppService.pauseAutomaticReconnect();
      reconnectTriggers.clear();

      expect(
        await xmppService.requestReconnect(ReconnectTrigger.resume),
        isTrue,
      );

      expect(reconnectTriggers, [ReconnectTrigger.resume]);
      expect(await reconnectionPolicy.getShouldReconnect(), isTrue);
    });

    test('connected resume request does not clear reconnect pause.', () async {
      eventStreamController.add(
        mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.connected,
          mox.XmppConnectionState.notConnected,
        ),
      );
      await pumpEventQueue();
      await xmppService.pauseAutomaticReconnect();
      reconnectTriggers.clear();

      expect(
        await xmppService.requestReconnect(ReconnectTrigger.resume),
        isTrue,
      );

      expect(reconnectTriggers, isEmpty);
      expect(await reconnectionPolicy.getShouldReconnect(), isFalse);
      expect(
        await xmppService.requestReconnect(ReconnectTrigger.networkAvailable),
        isFalse,
      );
    });

    test(
      'connected active client state restores reconnect without dispatching.',
      () async {
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.notConnected,
          ),
        );
        await pumpEventQueue();
        await xmppService.pauseAutomaticReconnect();
        reconnectTriggers.clear();

        await xmppService.setClientState();

        expect(xmppService.connectionState, ConnectionState.connected);
        expect(reconnectTriggers, isEmpty);
        expect(await reconnectionPolicy.getShouldReconnect(), isTrue);
      },
    );

    test('inactive client state does not clear reconnect pause.', () async {
      eventStreamController.add(
        mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.connected,
          mox.XmppConnectionState.notConnected,
        ),
      );
      await pumpEventQueue();
      await xmppService.pauseAutomaticReconnect();
      reconnectTriggers.clear();

      await xmppService.setClientState(false);

      expect(reconnectTriggers, isEmpty);
      expect(await reconnectionPolicy.getShouldReconnect(), isFalse);
      expect(
        await xmppService.requestReconnect(ReconnectTrigger.networkAvailable),
        isFalse,
      );
    });

    test(
      'syncSessionState returns false when reconnect setup fails before dispatch.',
      () async {
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.notConnected,
            mox.XmppConnectionState.connected,
          ),
        );
        await pumpEventQueue();

        await mockConnection.reconnectionPolicy.setShouldReconnect(false);
        when(
          () => mockConnection.setShouldReconnect(true),
        ).thenAnswer((_) async => throw Exception('enable failed'));

        expect(await xmppService.syncSessionState(), isFalse);
        expect(xmppService.connectionState, ConnectionState.notConnected);
        verifyNever(() => mockConnection.requestReconnect(any()));
      },
    );

    test(
      'ensureConnected throws promptly when reconnect dispatch fails locally.',
      () async {
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.notConnected,
            mox.XmppConnectionState.connected,
          ),
        );
        await pumpEventQueue();

        when(
          () => mockConnection.requestReconnect(any()),
        ).thenAnswer((_) async => throw Exception('dispatch failed'));

        await expectLater(
          xmppService.ensureConnected(
            trigger: ReconnectTrigger.networkAvailable,
          ),
          throwsA(isA<XmppDisconnectedException>()),
        );
        expect(xmppService.connectionState, ConnectionState.notConnected);
      },
    );
  });

  group('reconnect recovery', () {
    late XmppReconnectionPolicy reconnectionPolicy;
    late List<ReconnectTrigger> reconnectTriggers;

    setUp(() async {
      reconnectionPolicy = XmppReconnectionPolicy.exponential();
      reconnectTriggers = <ReconnectTrigger>[];
      when(
        () => mockConnection.reconnectionPolicy,
      ).thenReturn(reconnectionPolicy);
      when(
        () => mockConnection.isReconnecting(),
      ).thenAnswer((_) => reconnectionPolicy.getIsReconnecting());
      when(() => mockConnection.setShouldReconnect(any())).thenAnswer((
        invocation,
      ) async {
        await reconnectionPolicy.setShouldReconnect(
          invocation.positionalArguments.first as bool,
        );
      });
      when(() => mockConnection.requestReconnect(any())).thenAnswer((
        invocation,
      ) async {
        reconnectTriggers.add(
          invocation.positionalArguments.first as ReconnectTrigger,
        );
        return ReconnectRequestOutcome.dispatched;
      });

      xmppService = XmppService(
        buildConnection: () => mockConnection,
        buildStateStore: (_, _) => mockStateStore,
        buildDatabase: (_, _) => database,
        notificationService: mockNotificationService,
      );
      await connectSuccessfully(xmppService);
    });

    tearDown(() async {
      withForeground = false;
      foregroundServiceActive.value = false;
      await xmppService.close();
      await pumpEventQueue();
    });

    test(
      'Stream undefined condition recovery uses the lower auto-failure path.',
      () async {
        eventStreamController.add(
          mox.NonRecoverableErrorEvent(mox.StreamUndefinedConditionError()),
        );
        await pumpEventQueue();

        expect(reconnectTriggers, isEmpty);
        expect(await reconnectionPolicy.getIsReconnecting(), isTrue);
      },
    );

    test('Stream conflict outside reconnect remains fatal.', () async {
      eventStreamController.add(
        mox.NonRecoverableErrorEvent(mox.StreamConflictError()),
      );
      await pumpEventQueue();

      expect(await reconnectionPolicy.getShouldReconnect(), isFalse);
      expect(
        await xmppService.requestReconnect(ReconnectTrigger.networkAvailable),
        isFalse,
      );
    });

    test(
      'Stream conflict from replaced old stream does not disable active reconnect.',
      () async {
        await reconnectionPolicy.setShouldReconnect(true);
        await reconnectionPolicy.requestReconnect(
          ReconnectTrigger.immediateRetry,
        );

        eventStreamController.add(
          mox.NonRecoverableErrorEvent(mox.StreamConflictError()),
        );
        await pumpEventQueue();

        expect(await reconnectionPolicy.getShouldReconnect(), isTrue);
        expect(await reconnectionPolicy.getIsReconnecting(), isTrue);
        expect(xmppService.connectionState, ConnectionState.notConnected);
        expect(
          await xmppService.requestReconnect(ReconnectTrigger.networkAvailable),
          isTrue,
        );
      },
    );

    test(
      'Stream conflict from replaced old stream does not demote connected replacement.',
      () async {
        await reconnectionPolicy.setShouldReconnect(true);
        await reconnectionPolicy.requestReconnect(
          ReconnectTrigger.immediateRetry,
        );
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.notConnected,
          ),
        );
        await pumpEventQueue();

        eventStreamController.add(
          mox.NonRecoverableErrorEvent(mox.StreamConflictError()),
        );
        await pumpEventQueue();

        expect(await reconnectionPolicy.getShouldReconnect(), isTrue);
        expect(xmppService.connectionState, ConnectionState.connected);
      },
    );

    test(
      'Bootstrap pass stops scheduling operations after disconnect.',
      () async {
        final operationStarted = Completer<void>();
        final allowOperationToFinish = Completer<void>();
        var secondOperationRan = false;

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.notConnected,
          ),
        );
        await pumpEventQueue();

        xmppService
          ..registerBootstrapOperation(
            XmppBootstrapOperation(
              key: Object(),
              priority: -2,
              triggers: const <XmppBootstrapTrigger>{
                XmppBootstrapTrigger.manualRefresh,
              },
              operationName: 'blocking bootstrap test',
              run: () async {
                operationStarted.complete();
                await allowOperationToFinish.future;
              },
            ),
          )
          ..registerBootstrapOperation(
            XmppBootstrapOperation(
              key: Object(),
              priority: -1,
              triggers: const <XmppBootstrapTrigger>{
                XmppBootstrapTrigger.manualRefresh,
              },
              operationName: 'second bootstrap test',
              run: () async {
                secondOperationRan = true;
              },
            ),
          );

        final runFuture = xmppService.runBootstrapOperations(
          XmppBootstrapTrigger.manualRefresh,
        );
        await operationStarted.future;

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.notConnected,
            mox.XmppConnectionState.connected,
          ),
        );
        await pumpEventQueue();

        allowOperationToFinish.complete();
        await runFuture;

        expect(secondOperationRan, isFalse);
      },
    );

    test('Bootstrap pass stops scheduling operations after reset.', () async {
      final operationStarted = Completer<void>();
      final allowOperationToFinish = Completer<void>();
      var secondOperationRan = false;

      eventStreamController.add(
        mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.connected,
          mox.XmppConnectionState.notConnected,
        ),
      );
      await pumpEventQueue();

      xmppService
        ..registerBootstrapOperation(
          XmppBootstrapOperation(
            key: Object(),
            priority: -2,
            triggers: const <XmppBootstrapTrigger>{
              XmppBootstrapTrigger.manualRefresh,
            },
            operationName: 'blocking bootstrap reset test',
            run: () async {
              operationStarted.complete();
              await allowOperationToFinish.future;
            },
          ),
        )
        ..registerBootstrapOperation(
          XmppBootstrapOperation(
            key: Object(),
            priority: -1,
            triggers: const <XmppBootstrapTrigger>{
              XmppBootstrapTrigger.manualRefresh,
            },
            operationName: 'second bootstrap reset test',
            run: () async {
              secondOperationRan = true;
            },
          ),
        );

      final runFuture = xmppService.runBootstrapOperations(
        XmppBootstrapTrigger.manualRefresh,
      );
      await operationStarted.future;

      xmppService.resetBootstrapOperations();

      allowOperationToFinish.complete();
      await runFuture;

      expect(secondOperationRan, isFalse);
    });

    test(
      'Foreground migration is skipped while lower reconnect is active.',
      () async {
        final originalBridge = foregroundTaskBridge;

        foregroundTaskBridge = _FakeForegroundBridge();
        withForeground = true;
        foregroundServiceActive.value = true;
        when(() => mockConnection.disconnect()).thenAnswer((_) async {});
        addTearDown(() {
          foregroundTaskBridge = originalBridge;
          withForeground = false;
          foregroundServiceActive.value = false;
        });

        await reconnectionPolicy.setShouldReconnect(true);
        await reconnectionPolicy.requestReconnect(
          ReconnectTrigger.immediateRetry,
        );

        TestWidgetsFlutterBinding.ensureInitialized()
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);

        await xmppService.ensureForegroundSocketIfActive();

        verifyNever(() => mockConnection.disconnect());
      },
    );

    test(
      'Foreground migration is skipped while XMPP is disconnected.',
      () async {
        final originalBridge = foregroundTaskBridge;
        final bridge = _FakeForegroundBridge();

        foregroundTaskBridge = bridge;
        withForeground = true;
        foregroundServiceActive.value = true;
        addTearDown(() {
          foregroundTaskBridge = originalBridge;
          withForeground = false;
          foregroundServiceActive.value = false;
        });

        await connectSuccessfully(xmppService);
        clearInteractions(mockConnection);

        TestWidgetsFlutterBinding.ensureInitialized()
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);

        await xmppService.ensureForegroundSocketIfActive();

        expect(bridge.acquiredClients, isEmpty);
        verifyNever(() => mockConnection.disconnect());
        verifyNever(
          () => mockConnection.connect(
            shouldReconnect: false,
            waitForConnection: true,
            waitUntilLogin: true,
          ),
        );
      },
    );

    test(
      'Foreground migration is skipped while stream negotiations are still in progress.',
      () async {
        final originalBridge = foregroundTaskBridge;

        foregroundTaskBridge = _FakeForegroundBridge();
        withForeground = true;
        foregroundServiceActive.value = true;
        when(() => mockConnection.disconnect()).thenAnswer((_) async {});
        addTearDown(() {
          foregroundTaskBridge = originalBridge;
          withForeground = false;
          foregroundServiceActive.value = false;
        });

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.notConnected,
            mox.XmppConnectionState.connected,
          ),
        );
        await pumpEventQueue();
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.notConnected,
          ),
        );
        await pumpEventQueue();

        TestWidgetsFlutterBinding.ensureInitialized()
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);

        await xmppService.ensureForegroundSocketIfActive();

        verifyNever(() => mockConnection.disconnect());
      },
    );

    test(
      'Resume reconnect refreshes the connecting watchdog while joining active cycle.',
      () async {
        await xmppService.close();
        await pumpEventQueue();

        xmppService = XmppService(
          buildConnection: () => mockConnection,
          buildStateStore: (_, _) => mockStateStore,
          buildDatabase: (_, _) => database,
          notificationService: mockNotificationService,
          connectingWatchdogTimeout: const Duration(milliseconds: 120),
        );
        await connectSuccessfully(xmppService);
        await reconnectionPolicy.setShouldReconnect(true);
        await reconnectionPolicy.requestReconnect(
          ReconnectTrigger.immediateRetry,
        );
        await reconnectionPolicy.onSuccess();
        when(
          () => mockConnection.requestReconnect(ReconnectTrigger.resume),
        ).thenAnswer((_) async {
          reconnectTriggers.add(ReconnectTrigger.resume);
          return ReconnectRequestOutcome.joinedActiveCycle;
        });

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connecting,
            mox.XmppConnectionState.notConnected,
          ),
        );
        await pumpEventQueue();

        expect(xmppService.connectionState, ConnectionState.connecting);
        expect(
          reconnectionPolicy.reconnectActivity,
          XmppReconnectActivity.awaitingNegotiation,
        );

        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(
          await xmppService.requestReconnect(ReconnectTrigger.resume),
          isTrue,
        );

        await Future<void>.delayed(const Duration(milliseconds: 80));
        await pumpEventQueue();

        expect(xmppService.connectionState, ConnectionState.connecting);
        expect(reconnectTriggers, [ReconnectTrigger.resume]);

        await Future<void>.delayed(const Duration(milliseconds: 70));
        await pumpEventQueue();

        expect(xmppService.connectionState, ConnectionState.notConnected);
        expect(
          reconnectionPolicy.reconnectActivity,
          XmppReconnectActivity.scheduledBackoff,
        );
      },
    );

    test(
      'Connecting watchdog moves stale awaiting negotiation to backoff.',
      () async {
        await xmppService.close();
        await pumpEventQueue();

        xmppService = XmppService(
          buildConnection: () => mockConnection,
          buildStateStore: (_, _) => mockStateStore,
          buildDatabase: (_, _) => database,
          notificationService: mockNotificationService,
          connectingWatchdogTimeout: const Duration(milliseconds: 50),
        );
        await connectSuccessfully(xmppService);
        await reconnectionPolicy.setShouldReconnect(true);
        await reconnectionPolicy.requestReconnect(
          ReconnectTrigger.immediateRetry,
        );
        await reconnectionPolicy.onSuccess();
        final states = <ConnectionState>[];
        final stateSubscription = xmppService.connectivityStream.listen(
          states.add,
        );
        addTearDown(stateSubscription.cancel);

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connecting,
            mox.XmppConnectionState.notConnected,
          ),
        );
        expect(
          reconnectionPolicy.reconnectActivity,
          XmppReconnectActivity.awaitingNegotiation,
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await pumpEventQueue();

        expect(
          states,
          containsAllInOrder([
            ConnectionState.connecting,
            ConnectionState.notConnected,
          ]),
        );
        expect(xmppService.connectionState, ConnectionState.notConnected);
        expect(
          reconnectionPolicy.reconnectActivity,
          XmppReconnectActivity.scheduledBackoff,
        );
      },
    );

    test(
      'Service-level pre-socket connecting state does not start the watchdog.',
      () async {
        await xmppService.close();
        await pumpEventQueue();

        xmppService = XmppService(
          buildConnection: () => mockConnection,
          buildStateStore: (_, _) => mockStateStore,
          buildDatabase: (_, _) => database,
          notificationService: mockNotificationService,
          connectingWatchdogTimeout: const Duration(milliseconds: 50),
        );
        await connectSuccessfully(xmppService);
        await reconnectionPolicy.setShouldReconnect(true);
        when(
          () => mockConnection.requestReconnect(ReconnectTrigger.resume),
        ).thenAnswer((_) async {
          reconnectTriggers.add(ReconnectTrigger.resume);
          return reconnectionPolicy.requestReconnect(ReconnectTrigger.resume);
        });

        expect(
          await xmppService.requestReconnect(ReconnectTrigger.resume),
          isTrue,
        );
        await pumpEventQueue();

        expect(xmppService.connectionState, ConnectionState.connecting);
        expect(
          reconnectionPolicy.reconnectActivity,
          XmppReconnectActivity.awaitingSocket,
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await pumpEventQueue();

        expect(xmppService.connectionState, ConnectionState.connecting);
        expect(reconnectTriggers, [ReconnectTrigger.resume]);
        expect(
          reconnectionPolicy.reconnectActivity,
          XmppReconnectActivity.awaitingSocket,
        );
      },
    );

    test(
      'Current final socket failure clears connecting and schedules backoff.',
      () async {
        await reconnectionPolicy.setShouldReconnect(true);
        await reconnectionPolicy.requestReconnect(
          ReconnectTrigger.immediateRetry,
        );

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connecting,
            mox.XmppConnectionState.notConnected,
          ),
        );
        await pumpEventQueue();

        expect(xmppService.connectionState, ConnectionState.connecting);
        expect(
          reconnectionPolicy.reconnectActivity,
          XmppReconnectActivity.awaitingSocket,
        );

        expect(
          await mockConnection.socketWrapper.connect('example.invalid'),
          isFalse,
        );

        expect(xmppService.connectionState, ConnectionState.notConnected);
        expect(
          reconnectionPolicy.reconnectActivity,
          XmppReconnectActivity.scheduledBackoff,
        );
      },
    );

    test(
      'Current late socket failure does not move negotiating reconnect.',
      () async {
        await reconnectionPolicy.setShouldReconnect(true);
        await reconnectionPolicy.requestReconnect(
          ReconnectTrigger.immediateRetry,
        );
        await reconnectionPolicy.onSuccess();

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connecting,
            mox.XmppConnectionState.notConnected,
          ),
        );
        await pumpEventQueue();

        expect(xmppService.connectionState, ConnectionState.connecting);
        expect(
          reconnectionPolicy.reconnectActivity,
          XmppReconnectActivity.awaitingNegotiation,
        );

        expect(
          await mockConnection.socketWrapper.connect('example.invalid'),
          isFalse,
        );

        expect(xmppService.connectionState, ConnectionState.connecting);
        expect(
          reconnectionPolicy.reconnectActivity,
          XmppReconnectActivity.awaitingNegotiation,
        );
      },
    );

    test('Stale socket failure callbacks do not move current policy', () async {
      await xmppService.close();
      await pumpEventQueue();

      final staleConnection = MockXmppConnection();
      final resetConnection = MockXmppConnection();
      final currentConnection = MockXmppConnection();
      final staleSocketWrapper = XmppSocketWrapper();
      final resetSocketWrapper = XmppSocketWrapper();
      final currentSocketWrapper = XmppSocketWrapper();
      final stalePolicy = XmppReconnectionPolicy.exponential();
      final resetPolicy = XmppReconnectionPolicy.exponential();
      final currentPolicy = XmppReconnectionPolicy.exponential();
      var connectionBuilds = 0;
      when(() => mockStateStore.read(key: any(named: 'key'))).thenReturn(null);
      when(
        () => mockStateStore.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async => true);
      when(() => mockStateStore.close()).thenAnswer((_) async {});
      when(() => mockDatabase.close()).thenAnswer((_) async {});

      void prepareOfflineConnection(
        MockXmppConnection connection, {
        required XmppSocketWrapper socketWrapper,
        required XmppReconnectionPolicy policy,
      }) {
        when(() => connection.hasConnectionSettings).thenReturn(false);
        when(() => connection.socketWrapper).thenReturn(socketWrapper);
        when(() => connection.reconnectionPolicy).thenReturn(policy);
        when(() => connection.setShouldReconnect(any())).thenAnswer((
          invocation,
        ) async {
          await policy.setShouldReconnect(
            invocation.positionalArguments.first as bool,
          );
        });
      }

      prepareOfflineConnection(
        staleConnection,
        socketWrapper: staleSocketWrapper,
        policy: stalePolicy,
      );
      prepareOfflineConnection(
        resetConnection,
        socketWrapper: resetSocketWrapper,
        policy: resetPolicy,
      );
      prepareOfflineConnection(
        currentConnection,
        socketWrapper: currentSocketWrapper,
        policy: currentPolicy,
      );

      xmppService = XmppService(
        buildConnection: () {
          connectionBuilds++;
          return switch (connectionBuilds) {
            1 => staleConnection,
            2 => resetConnection,
            3 => currentConnection,
            _ => XmppConnection(),
          };
        },
        buildStateStore: (_, _) => mockStateStore,
        buildDatabase: (_, _) => mockDatabase,
        notificationService: mockNotificationService,
      );

      await xmppService.resumeOfflineSession(
        jid: 'stale@axi.im',
        databasePrefix: '',
        databasePassphrase: '',
      );
      await xmppService.resumeOfflineSession(
        jid: 'current@axi.im',
        databasePrefix: '',
        databasePassphrase: '',
      );

      await currentPolicy.setShouldReconnect(true);
      await currentPolicy.requestReconnect(ReconnectTrigger.immediateRetry);

      expect(
        currentPolicy.reconnectActivity,
        XmppReconnectActivity.awaitingSocket,
      );

      expect(await staleSocketWrapper.connect('example.invalid'), isFalse);

      expect(
        currentPolicy.reconnectActivity,
        XmppReconnectActivity.awaitingSocket,
      );
    });

    test('Offline resume with credentials keeps reconnect context', () async {
      await xmppService.close();
      await pumpEventQueue();

      final settings = XmppConnectionSettings(
        jid: mox.JID.fromString('offline@axi.im'),
        password: password,
      );
      when(() => mockConnection.connectionSettings).thenReturn(settings);
      when(() => mockConnection.hasConnectionSettings).thenReturn(true);
      when(() => mockStateStore.read(key: any(named: 'key'))).thenReturn(null);
      when(
        () => mockStateStore.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async => true);
      when(() => mockStateStore.close()).thenAnswer((_) async {});
      when(() => mockDatabase.close()).thenAnswer((_) async {});

      xmppService = XmppService(
        buildConnection: () => mockConnection,
        buildStateStore: (_, _) => mockStateStore,
        buildDatabase: (_, _) => database,
        notificationService: mockNotificationService,
      );

      await xmppService.resumeOfflineSession(
        jid: 'offline@axi.im',
        databasePrefix: '',
        databasePassphrase: '',
        password: password,
        preHashed: true,
      );

      expect(xmppService.hasInMemoryReconnectContext, isTrue);
      expect(
        await xmppService.requestReconnect(ReconnectTrigger.resume),
        isTrue,
      );
      verify(
        () => mockConnection.requestReconnect(ReconnectTrigger.resume),
      ).called(1);
    });

    test(
      'Connecting watchdog does not clear a completed stream negotiation.',
      () async {
        await xmppService.close();
        await pumpEventQueue();

        xmppService = XmppService(
          buildConnection: () => mockConnection,
          buildStateStore: (_, _) => mockStateStore,
          buildDatabase: (_, _) => database,
          notificationService: mockNotificationService,
          connectingWatchdogTimeout: const Duration(milliseconds: 50),
        );
        await connectSuccessfully(xmppService);

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connecting,
            mox.XmppConnectionState.notConnected,
          ),
        );
        await pumpEventQueue();
        eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
        await pumpEventQueue();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await pumpEventQueue();

        expect(xmppService.connectionState, ConnectionState.connected);
      },
    );
  });

  group('XmppConnection', () {});

  group('XmppSocketWrapper', () {
    late ServerSocket serverSocket;
    late Future<Socket> acceptedSocketFuture;

    setUp(() async {
      serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      acceptedSocketFuture = serverSocket.first;
    });

    tearDown(() async {
      await serverSocket.close();
    });

    test(
      'closeStreams detaches the active socket before the controllers close',
      () async {
        final wrapper = XmppSocketWrapper();
        Socket? peerSocket;
        Object? uncaughtError;
        StackTrace? uncaughtStackTrace;

        await runZonedGuarded(
          () async {
            final connected = await wrapper.connect(
              'axi.im',
              host: InternetAddress.loopbackIPv4.address,
              port: serverSocket.port,
            );

            expect(connected, isTrue);

            peerSocket = await acceptedSocketFuture;

            await wrapper.closeStreams();

            try {
              peerSocket!.add('<message />'.codeUnits);
              await peerSocket!.flush();
            } on SocketException {
              // The client may already be detached; either outcome is valid.
            }

            peerSocket!.destroy();
            await pumpEventQueue();
          },
          (Object error, StackTrace stackTrace) {
            uncaughtError = error;
            uncaughtStackTrace = stackTrace;
          },
        );

        try {
          await peerSocket?.close();
        } on SocketException {
          // The peer socket may already be destroyed.
        }

        expect(
          uncaughtError,
          isNull,
          reason: '$uncaughtError\n$uncaughtStackTrace',
        );
      },
    );

    test(
      'connect failure callback fires when no endpoint is available',
      () async {
        final wrapper = XmppSocketWrapper();
        var failures = 0;
        wrapper.registerConnectionCallbacks(onConnectFailure: () => failures++);

        expect(await wrapper.connect('example.invalid'), isFalse);
        expect(failures, 1);

        final clientSocket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          serverSocket.port,
        );
        final acceptedSocket = await acceptedSocketFuture;
        clientSocket.destroy();
        acceptedSocket.destroy();
      },
    );
  });

  test(
    'Failed foreground migration releases the abandoned foreground connection',
    () async {
      final originalBridge = foregroundTaskBridge;
      final bridge = _FakeForegroundBridge();
      final foregroundConnection = MockXmppConnection();
      final fallbackConnection = MockXmppConnection();
      final settings = XmppConnectionSettings(
        jid: mox.JID.fromString(jid),
        password: password,
      );

      foregroundTaskBridge = bridge;
      withForeground = true;
      foregroundServiceActive.value = false;
      addTearDown(() {
        foregroundTaskBridge = originalBridge;
        withForeground = false;
        foregroundServiceActive.value = false;
      });

      void prepareAdditionalConnection(
        MockXmppConnection connection, {
        required XmppSocketWrapper socketWrapper,
      }) {
        when(() => connection.hasConnectionSettings).thenReturn(true);
        when(() => connection.connectionSettings).thenReturn(settings);
        when(() => connection.socketWrapper).thenReturn(socketWrapper);
        when(
          () => connection.registerFeatureNegotiators(any()),
        ).thenAnswer((_) async {});
        when(() => connection.registerManagers(any())).thenAnswer((_) async {});
        when(() => connection.loadStreamState()).thenAnswer((_) async {});
        when(
          () => connection.setShouldReconnect(any()),
        ).thenAnswer((_) async {});
        when(() => connection.setUserAgent(any())).thenAnswer((_) {});
        when(() => connection.setFastToken(any())).thenAnswer((_) {});
        when(
          () => connection.asBroadcastStream(),
        ).thenAnswer((_) => const Stream<mox.XmppEvent>.empty());
        when(
          () => connection.omemoActivityStream,
        ).thenAnswer((_) => const Stream<mox.OmemoActivityEvent>.empty());
        when(() => connection.enableCarbons()).thenAnswer((_) async => true);
        when(() => connection.requestRoster()).thenAnswer(
          (_) =>
              Future<
                moxlib.Result<mox.RosterRequestResult, mox.RosterError>?
              >.value(null),
        );
        when(
          () => connection.requestBlocklist(),
        ).thenAnswer((_) => Future<List<String>?>.value(null));
        when(() => connection.discoInfoQuery(any())).thenAnswer((_) async {
          final discoInfo = mox.DiscoInfo(
            const [mox.mamXmlns],
            const [],
            const [],
            null,
            mox.JID.fromString(jid),
          );
          return moxlib.Result<mox.StanzaError, mox.DiscoInfo>(discoInfo);
        });
        when(() => connection.saltedPassword).thenReturn('');
        when(() => connection.disconnect()).thenAnswer((_) async {});
      }

      prepareMockConnection();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => eventStreamController.stream);
      when(() => mockConnection.hasConnectionSettings).thenReturn(true);
      when(() => mockConnection.connectionSettings).thenReturn(settings);
      when(
        () => mockConnection.isReconnecting(),
      ).thenAnswer((_) async => false);
      when(() => mockConnection.disconnect()).thenAnswer((_) async {});

      final foregroundSocket = ForegroundSocketWrapper(bridge: bridge);
      prepareAdditionalConnection(
        foregroundConnection,
        socketWrapper: foregroundSocket,
      );
      when(
        () => foregroundConnection.connect(
          shouldReconnect: false,
          waitForConnection: true,
          waitUntilLogin: true,
        ),
      ).thenAnswer((_) async {
        await bridge.acquire(clientId: foregroundClientXmpp);
        return const moxlib.Result<bool, mox.XmppError>(false);
      });
      when(() => foregroundConnection.reset()).thenAnswer((_) async {
        await bridge.release(foregroundClientXmpp);
      });

      prepareAdditionalConnection(
        fallbackConnection,
        socketWrapper: XmppSocketWrapper(),
      );
      when(
        () => fallbackConnection.connect(
          shouldReconnect: false,
          waitForConnection: true,
          waitUntilLogin: true,
        ),
      ).thenAnswer((_) async => const moxlib.Result<bool, mox.XmppError>(true));
      when(() => fallbackConnection.reset()).thenAnswer((_) async {});

      var connectionBuilds = 0;
      xmppService = XmppService(
        buildConnection: () {
          connectionBuilds++;
          if (connectionBuilds == 1) {
            return mockConnection;
          }
          if (connectionBuilds == 2) {
            return foregroundConnection;
          }
          return fallbackConnection;
        },
        buildStateStore: (_, _) => mockStateStore,
        buildDatabase: (_, _) => database,
        notificationService: mockNotificationService,
      );

      await connectSuccessfully(xmppService);
      eventStreamController.add(
        mox.ConnectionStateChangedEvent(
          ConnectionState.connected,
          ConnectionState.connecting,
        ),
      );
      await pumpEventQueue();
      eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
      await pumpEventQueue();
      TestWidgetsFlutterBinding.ensureInitialized()
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      foregroundServiceActive.value = true;

      await xmppService.ensureForegroundSocketIfActive();

      expect(bridge.acquiredClients, isEmpty);
      verify(
        () => foregroundConnection.connect(
          shouldReconnect: false,
          waitForConnection: true,
          waitUntilLogin: true,
        ),
      ).called(1);
      verify(() => foregroundConnection.reset()).called(1);

      await xmppService.close();
    },
  );

  group('Settings sync', () {
    late Map<String, Object?> storeData;
    late RecordingSettingsPubSubTransport pubSubTransport;
    late SettingsPubSubManager settingsManager;

    setUp(() async {
      storeData = <String, Object?>{};
      stubSettingsSyncStateStore(storeData);

      xmppService = XmppService(
        buildConnection: () => mockConnection,
        buildStateStore: (_, _) => mockStateStore,
        buildDatabase: (_, _) => database,
        notificationService: mockNotificationService,
      );
      await connectSuccessfully(xmppService);
      stubSettingsSyncStateStore(storeData);

      pubSubTransport = RecordingSettingsPubSubTransport();
      settingsManager = await registerSettingsPubSubManager(
        connection: mockConnection,
        pubSubManager: pubSubTransport,
      );
      when(
        () => mockConnection.getManager<SettingsPubSubManager>(),
      ).thenReturn(settingsManager);
    });

    tearDown(() async {
      await xmppService.close();
      await pumpEventQueue();
    });

    test(
      'syncSettingsSnapshot publishes seeded local settings when remote matches stored snapshot',
      () async {
        final storedUpdatedAt = DateTime.utc(2026, 3, 18, 12, 0);
        final storedPayload = SettingsSyncPayload.encodeSettingsData(
          const <String, dynamic>{'language': 'english'},
        )!;
        storeData['settings_sync_snapshot_payload'] = storedPayload;
        storeData['settings_sync_snapshot_updated_at'] = storedUpdatedAt
            .toIso8601String();
        storeData['settings_sync_snapshot_source_id'] = 'device-a';
        storeData['settings_sync_source_id'] = 'device-a';
        pubSubTransport
                .publishedItems['$settingsPubSubNode|${SettingsSyncPayload.currentItemId}'] =
            SettingsSyncPayload(
              settings: const <String, dynamic>{'language': 'english'},
              updatedAt: storedUpdatedAt,
              sourceId: 'device-a',
            ).toXml();

        await xmppService.seedSettingsSyncSnapshot(const <String, dynamic>{
          'language': 'german',
        });

        final synced = await xmppService.syncSettingsSnapshot();

        expect(synced, isTrue);
        expect(pubSubTransport.publishCount, 1);

        final publishedXml = pubSubTransport
            .publishedItems['$settingsPubSubNode|${SettingsSyncPayload.currentItemId}'];
        final publishedPayload = SettingsSyncPayload.fromXml(
          publishedXml!,
          itemId: SettingsSyncPayload.currentItemId,
        );
        expect(publishedPayload, isNotNull);
        expect(publishedPayload!.settings['language'], 'german');
      },
    );

    test(
      'pre-login local updates keep their sync metadata when state store loads later',
      () async {
        await xmppService.close();
        await pumpEventQueue();
        database = XmppDrift(
          file: File(''),
          passphrase: '',
          executor: NativeDatabase.memory(),
        );

        final storedUpdatedAt = DateTime.utc(2026, 3, 18, 12, 0);
        final localUpdateLowerBound = DateTime.timestamp().toUtc();
        storeData['settings_sync_snapshot_payload'] =
            SettingsSyncPayload.encodeSettingsData(const <String, dynamic>{
              'language': 'english',
            })!;
        storeData['settings_sync_snapshot_updated_at'] = storedUpdatedAt
            .toIso8601String();
        storeData['settings_sync_snapshot_source_id'] = 'device-a';
        storeData['settings_sync_source_id'] = 'device-a';

        xmppService = XmppService(
          buildConnection: () => mockConnection,
          buildStateStore: (_, _) => mockStateStore,
          buildDatabase: (_, _) => database,
          notificationService: mockNotificationService,
        );
        await xmppService.updateSettingsSyncSnapshot(const <String, dynamic>{
          'language': 'german',
        });

        await connectSuccessfully(xmppService);
        stubSettingsSyncStateStore(storeData);

        pubSubTransport = RecordingSettingsPubSubTransport();
        settingsManager = await registerSettingsPubSubManager(
          connection: mockConnection,
          pubSubManager: pubSubTransport,
        );
        when(
          () => mockConnection.getManager<SettingsPubSubManager>(),
        ).thenReturn(settingsManager);

        pubSubTransport
                .publishedItems['$settingsPubSubNode|${SettingsSyncPayload.currentItemId}'] =
            SettingsSyncPayload(
              settings: const <String, dynamic>{'language': 'french'},
              updatedAt: localUpdateLowerBound.subtract(
                const Duration(minutes: 1),
              ),
              sourceId: 'remote-device',
            ).toXml();

        final updates = <Map<String, dynamic>>[];
        final subscription = xmppService.settingsSyncUpdateStream.listen(
          updates.add,
        );
        final synced = await xmppService.syncSettingsSnapshot();

        expect(synced, isTrue);
        expect(updates, isEmpty);
        expect(pubSubTransport.publishCount, 1);

        final publishedXml = pubSubTransport
            .publishedItems['$settingsPubSubNode|${SettingsSyncPayload.currentItemId}'];
        final publishedPayload = SettingsSyncPayload.fromXml(
          publishedXml!,
          itemId: SettingsSyncPayload.currentItemId,
        );
        expect(publishedPayload, isNotNull);
        expect(publishedPayload!.settings['language'], 'german');

        await subscription.cancel();
      },
    );

    test(
      'stale settings sync events do not overwrite newer local settings',
      () async {
        await xmppService.updateSettingsSyncSnapshot(const <String, dynamic>{
          'language': 'german',
        });
        final localUpdatedAt = DateTime.parse(
          storeData['settings_sync_snapshot_updated_at']! as String,
        ).toUtc();
        final updates = <Map<String, dynamic>>[];
        final subscription = xmppService.settingsSyncUpdateStream.listen(
          updates.add,
        );

        eventStreamController.add(
          SettingsSyncUpdatedEvent(
            SettingsSyncPayload(
              settings: const <String, dynamic>{'language': 'english'},
              updatedAt: localUpdatedAt.subtract(const Duration(minutes: 1)),
              sourceId: 'remote-device',
            ),
          ),
        );
        await pumpEventQueue();

        expect(updates, isEmpty);
        expect(pubSubTransport.publishCount, 2);
        expect(
          SettingsSyncPayload.decodeSettingsData(
            storeData['settings_sync_snapshot_payload']! as String,
          )!['language'],
          'german',
        );

        await subscription.cancel();
      },
    );
  });
}
