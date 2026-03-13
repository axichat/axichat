import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:axichat/main.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:fake_async/fake_async.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks.dart';

const String _accountBareJid = 'jid@axi.im';
const String _accountDomain = 'axi.im';
const String _serviceJid = 'muc.axi.im';
const String _roomJid = 'room@muc.axi.im';
const String _roomJidBare = _roomJid;
const String _roomJidWithNick = 'room@muc.axi.im/nick';
const String _roomJidWithSelfNick = 'room@muc.axi.im/me';
const String _roomName = 'Planning Room';
const String _roomNick = 'Nick';
const String _roomNickTrimmed = 'Nick';
const String _roomNickUpdatedTrimmed = 'New Nick';
const String _inviteeJid = 'friend@axi.im';
const String _inviteReasonRaw = '  Let us sync  ';
const String _inviteReasonTrimmed = 'Let us sync';
const String _invitePasswordRaw = '  roompass  ';
const String _invitePasswordTrimmed = 'roompass';
const String _stanzaId = 'stanza-123';
const int _defaultHistoryStanzas = 50;
const int _customHistoryStanzas = 5;
const int _noHistoryStanzas = 0;
const String _subjectRaw = '  Roadmap  ';
const String _subjectTrimmed = 'Roadmap';
const String _subjectEmpty = '   ';
const String _mucDiscoFeature = 'http://jabber.org/protocol/muc';
const String _mucMembersOnlyFeature = 'muc_membersonly';
const String _mucOwnerXmlns = 'http://jabber.org/protocol/muc#owner';
const String _mucAdminXmlns = 'http://jabber.org/protocol/muc#admin';
const String _mucRoomInfoFormType = 'http://jabber.org/protocol/muc#roominfo';
const String _mucRoomConfigFormType =
    'http://jabber.org/protocol/muc#roomconfig';
const String _bookmarksCompatFeature = 'urn:xmpp:bookmarks:1#compat';
const String _bookmarksCompatPepFeature = 'urn:xmpp:bookmarks:1#compat-pep';
const String _bookmarksConversionFeature = 'urn:xmpp:bookmarks-conversion:0';
const String _discoInfoXmlns = 'http://jabber.org/protocol/disco#info';
const String _dataFormXmlns = 'jabber:x:data';
const String _dataFormTag = 'x';
const String _queryTag = 'query';
const String _fieldTag = 'field';
const String _itemTag = 'item';
const String _destroyTag = 'destroy';
const String _jidAttr = 'jid';
const String _nickAttr = 'nick';
const String _roleAttr = 'role';
const String _affiliationAttr = 'affiliation';
const String _varAttr = 'var';
const String _errorTag = 'error';
const String _reasonTag = 'reason';
const String _subjectTag = 'subject';
const String _bodyTag = 'body';
const String _messageTag = 'message';
const String _xmlnsAttr = 'xmlns';
const String _typeAttr = 'type';
const String _toAttr = 'to';
const String _iqTypeGet = 'get';
const String _iqTypeSet = 'set';
const String _iqTypeResult = 'result';
const String _iqTypeError = 'error';
const String _messageTypeGroupchat = 'groupchat';
const bool _presenceAvailable = true;
const String _roomNickUpdatedRaw = '  New Nick  ';
const int _singleItemCount = 1;
const mox.XmppConnectionState _connectedState =
    mox.XmppConnectionState.connected;
const mox.XmppConnectionState _disconnectedState =
    mox.XmppConnectionState.notConnected;
const ChatType _fallbackChatType = ChatType.groupChat;
const List<mox.XMLNode> _emptyXmlNodeList = <mox.XMLNode>[];

final DateTime _fixedTimestamp = DateTime(2024, 1, 1);

class MockMucManager extends Mock implements MUCManager {}

class MockMamManager extends Mock implements mox.MAMManager {}

class MockDiscoManager extends Mock implements mox.DiscoManager {}

class MockDiscoItem extends Mock implements mox.DiscoItem {}

class MockDiscoInfo extends Mock implements mox.DiscoInfo {}

class MockRoomInformation extends Mock implements mox.RoomInformation {}

class FakeStanzaError extends Fake implements mox.StanzaError {}

class FakeMucError extends Fake implements mox.MUCError {}

class FakeJid extends Fake implements mox.JID {}

class FakeMamQueryOptions extends Fake implements mox.MAMQueryOptions {}

class FakeResultSetManagement extends Fake implements mox.ResultSetManagement {}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

const List<int> _pngLikeBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
];

mox.XMLNode _formTypeField(String formType) => mox.XMLNode(
  tag: _fieldTag,
  attributes: {_varAttr: 'FORM_TYPE', 'type': 'hidden'},
  children: [mox.XMLNode(tag: 'value', text: formType)],
);

mox.XMLNode _singleValueField(String name, String value) => mox.XMLNode(
  tag: _fieldTag,
  attributes: {_varAttr: name},
  children: [mox.XMLNode(tag: 'value', text: value)],
);

mox.Stanza _memberAffiliationQueryResult(String jid) {
  final query = mox.XMLNode.xmlns(
    tag: _queryTag,
    xmlns: _mucAdminXmlns,
    children: [
      mox.XMLNode(
        tag: _itemTag,
        attributes: {
          _jidAttr: jid,
          _affiliationAttr: OccupantAffiliation.member.xmlValue,
        },
      ),
    ],
  );
  return mox.Stanza.iq(type: _iqTypeResult, children: [query]);
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
    registerFallbackValue(fallbackMessage);
    registerFallbackValue(fallbackChat);
    registerFallbackValue(FakeJid());
    registerFallbackValue(FakeMamQueryOptions());
    registerFallbackValue(FakeResultSetManagement());
    registerFallbackValue(_fallbackChatType);
    registerFallbackValue(_emptyXmlNodeList);
    registerFallbackValue(MessageTimelineFilter.directOnly);
    registerFallbackValue(MessageNotificationChannel.chat);
    registerOmemoFallbacks();
    resetForegroundNotifier(value: false);
  });

  late XmppService xmppService;
  late StreamController<mox.XmppEvent> eventStreamController;
  late MockMucManager mucManager;
  late MockMamManager mamManager;
  late MockDiscoManager discoManager;
  late MucJoinBootstrapManager joinBootstrapManager;
  late PathProviderPlatform originalPathProvider;
  late Directory tempDir;

  setUp(() async {
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockDatabase = MockXmppDatabase();
    mockNotificationService = MockNotificationService();
    eventStreamController = StreamController<mox.XmppEvent>.broadcast();
    mucManager = MockMucManager();
    mamManager = MockMamManager();
    discoManager = MockDiscoManager();
    joinBootstrapManager = MucJoinBootstrapManager();
    originalPathProvider = PathProviderPlatform.instance;
    tempDir = await Directory.systemTemp.createTemp('axichat-muc-avatar-');
    final supportDir = Directory(p.join(tempDir.path, 'support'));
    await supportDir.create(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir.path);

    prepareMockConnection();
    when(() => mockConnection.discoInfoQuery(any())).thenAnswer((
      invocation,
    ) async {
      final target = invocation.positionalArguments.first;
      final jid = target is mox.JID
          ? target.toBare().toString()
          : target.toString();
      final features = jid == _serviceJid || jid == 'muc.axi.im'
          ? <String>[_mucDiscoFeature]
          : <String>[mox.mamXmlns];
      final discoInfo = mox.DiscoInfo(
        features,
        const [],
        const [],
        null,
        mox.JID.fromString(_accountBareJid),
      );
      return moxlib.Result<mox.StanzaError, mox.DiscoInfo>(discoInfo);
    });

    when(
      () => mockConnection.asBroadcastStream(),
    ).thenAnswer((_) => eventStreamController.stream);
    when(() => mockConnection.getManager<MUCManager>()).thenReturn(mucManager);
    when(
      () => mockConnection.getManager<mox.DiscoManager>(),
    ).thenReturn(discoManager);
    when(
      () => mockConnection.getManager<MucJoinBootstrapManager>(),
    ).thenReturn(joinBootstrapManager);
    when(() => mockConnection.sendStanza(any())).thenAnswer((_) async => null);
    when(() => mockDatabase.getChat(any())).thenAnswer((_) async => null);
    when(() => mockDatabase.createChat(any())).thenAnswer((_) async {});
    when(() => mockDatabase.updateChat(any())).thenAnswer((_) async {});
    when(() => mockDatabase.getRosterItem(any())).thenAnswer((_) async => null);
    when(
      () => mockDatabase.countChatMessages(
        any(),
        filter: any(named: 'filter'),
        includePseudoMessages: any(named: 'includePseudoMessages'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => mockDatabase.watchBlocklist(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) => const Stream<List<BlocklistData>>.empty());
    when(
      () => mockDatabase.getBlocklist(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => <BlocklistData>[]);
    when(() => mucManager.getRoomState(any())).thenAnswer((_) async => null);
    final defaultRoomInfo = MockRoomInformation();
    when(
      () => defaultRoomInfo.features,
    ).thenReturn(const <String>[_mucDiscoFeature]);
    when(() => mucManager.queryRoomInformation(any())).thenAnswer(
      (_) async =>
          moxlib.Result<mox.RoomInformation, mox.MUCError>(defaultRoomInfo),
    );

    xmppService = XmppService(
      buildConnection: () => mockConnection,
      buildStateStore: (_, _) => mockStateStore,
      buildDatabase: (_, _) => mockDatabase,
      notificationService: mockNotificationService,
    );

    await connectSuccessfully(xmppService);
    eventStreamController.add(
      mox.ConnectionStateChangedEvent(_connectedState, _disconnectedState),
    );
    await pumpEventQueue();
  });

  Future<List<XmppOperationEvent>> captureXmppOperations(
    Future<void> Function() action,
  ) async {
    final events = <XmppOperationEvent>[];
    final subscription = xmppService.xmppOperationStream.listen(events.add);
    try {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await pumpEventQueue();
      return List<XmppOperationEvent>.from(events);
    } finally {
      await subscription.cancel();
    }
  }

  tearDown(() async {
    await eventStreamController.close();
    await xmppService.close();
    PathProviderPlatform.instance = originalPathProvider;
    await tempDir.delete(recursive: true);
    resetMocktailState();
  });

  group('RoomState bootstrap', () {
    test(
      'BOOT-001 [HP] room bootstrap stays pending while post-join refresh is in flight',
      () {
        final room = RoomState(
          roomJid: _roomJid,
          occupants: <String, Occupant>{
            _roomJidWithSelfNick: Occupant(
              occupantId: _roomJidWithSelfNick,
              nick: 'me',
              affiliation: OccupantAffiliation.owner,
              role: OccupantRole.moderator,
              isPresent: true,
            ),
          },
          myOccupantJid: _roomJidWithSelfNick,
          selfPresenceStatusCodes: {MucStatusCode.selfPresence.code},
          postJoinRefreshPending: true,
        );

        expect(room.isReadyForMessaging, isTrue);
        expect(room.isBootstrapPending, isTrue);
      },
    );
  });

  group('Discovery and room info', () {
    test(
      'DISC-010 [HP] discoverMucServiceHost uses MUC feature from disco items',
      () async {
        final item = MockDiscoItem();
        when(() => item.jid).thenReturn(mox.JID.fromString(_serviceJid));
        final info = MockDiscoInfo();
        when(() => info.features).thenReturn([_mucDiscoFeature]);

        when(() => discoManager.discoItemsQuery(any())).thenAnswer(
          (_) async =>
              moxlib.Result<mox.StanzaError, List<mox.DiscoItem>>([item]),
        );
        when(() => discoManager.discoInfoQuery(any())).thenAnswer(
          (_) async => moxlib.Result<mox.StanzaError, mox.DiscoInfo>(info),
        );

        await xmppService.discoverMucServiceHost();

        expect(xmppService.mucServiceHost, equals(_serviceJid));
      },
    );

    test('DISC-013 [UP] disco item errors fall back to domain info', () async {
      final info = MockDiscoInfo();
      when(() => info.features).thenReturn([_mucDiscoFeature]);

      when(() => discoManager.discoItemsQuery(any())).thenAnswer(
        (_) async => moxlib.Result<mox.StanzaError, List<mox.DiscoItem>>(
          FakeStanzaError(),
        ),
      );
      when(() => discoManager.discoInfoQuery(any())).thenAnswer(
        (_) async => moxlib.Result<mox.StanzaError, mox.DiscoInfo>(info),
      );

      await xmppService.discoverMucServiceHost();

      expect(xmppService.mucServiceHost, equals(_accountDomain));
    });

    test(
      'DISC-014 [HP] refreshPubSubSupport treats bookmarks compatibility features as bookmarks support',
      () async {
        final selfInfo = MockDiscoInfo();
        when(() => selfInfo.features).thenReturn([
          mox.pubsubXmlns,
          _bookmarksCompatFeature,
          _bookmarksCompatPepFeature,
          _bookmarksConversionFeature,
        ]);
        final hostInfo = MockDiscoInfo();
        when(() => hostInfo.features).thenReturn([mox.pubsubXmlns]);

        when(() => discoManager.discoInfoQuery(any())).thenAnswer((
          invocation,
        ) async {
          final target = invocation.positionalArguments.first as mox.JID;
          final bare = target.toBare().toString();
          final info = bare == _accountBareJid ? selfInfo : hostInfo;
          return moxlib.Result<mox.StanzaError, mox.DiscoInfo>(info);
        });

        final support = await xmppService.refreshPubSubSupport(force: true);

        expect(support.canUseBookmarks2, isTrue);
        expect(support.bookmarks2Supported, isTrue);
      },
    );

    test('DISC-011 [HP] discoverRooms returns room items', () async {
      final roomItem = MockDiscoItem();
      when(() => roomItem.jid).thenReturn(mox.JID.fromString(_roomJid));

      when(() => discoManager.discoItemsQuery(any())).thenAnswer(
        (_) async =>
            moxlib.Result<mox.StanzaError, List<mox.DiscoItem>>([roomItem]),
      );

      final rooms = await xmppService.discoverRooms(serviceJid: _serviceJid);

      expect(rooms, hasLength(_singleItemCount));
      expect(rooms.single, equals(roomItem));
    });

    test('DISC-013 [UP] discoverRooms returns empty list on error', () async {
      when(() => discoManager.discoItemsQuery(any())).thenAnswer(
        (_) async => moxlib.Result<mox.StanzaError, List<mox.DiscoItem>>(
          FakeStanzaError(),
        ),
      );

      final rooms = await xmppService.discoverRooms(serviceJid: _serviceJid);

      expect(rooms, isEmpty);
    });

    test(
      'DISC-020 [HP] fetchRoomInformation returns information on success',
      () async {
        final info = MockRoomInformation();
        when(() => info.name).thenReturn(_roomName);

        when(() => mucManager.queryRoomInformation(any())).thenAnswer(
          (_) async => moxlib.Result<mox.RoomInformation, mox.MUCError>(info),
        );

        final result = await xmppService.fetchRoomInformation(_roomJid);

        expect(result, equals(info));
      },
    );

    test(
      'DISC-023 [UP] fetchRoomInformation returns null on MUC errors',
      () async {
        when(() => mucManager.queryRoomInformation(any())).thenAnswer(
          (_) async =>
              moxlib.Result<mox.RoomInformation, mox.MUCError>(FakeMucError()),
        );

        final result = await xmppService.fetchRoomInformation(_roomJid);

        expect(result, isNull);
      },
    );
  });

  group('Room configuration', () {
    test('OWN-010 [HP] fetchRoomConfigurationForm returns data form', () async {
      final form = mox.XMLNode.xmlns(tag: _dataFormTag, xmlns: _dataFormXmlns);
      final query = mox.XMLNode.xmlns(
        tag: _queryTag,
        xmlns: _mucOwnerXmlns,
        children: [form],
      );
      final response = mox.Stanza.iq(type: _iqTypeResult, children: [query]);

      when(
        () => mockConnection.sendStanza(any()),
      ).thenAnswer((_) async => response);

      final result = await xmppService.fetchRoomConfigurationForm(_roomJid);

      expect(result, isNotNull);
      expect(result?.tag, equals(_dataFormTag));
      expect(result?.attributes[_xmlnsAttr], equals(_dataFormXmlns));
    });

    test(
      'OWN-011 [HP] submitRoomConfiguration returns true on result',
      () async {
        final form = mox.XMLNode.xmlns(
          tag: _dataFormTag,
          xmlns: _dataFormXmlns,
        );
        final response = mox.Stanza.iq(type: _iqTypeResult);

        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => response);

        final result = await xmppService.submitRoomConfiguration(
          roomJid: _roomJid,
          form: form,
        );

        expect(result, isTrue);
      },
    );

    test(
      'OWN-011 [UP] submitRoomConfiguration returns false on errors',
      () async {
        final form = mox.XMLNode.xmlns(
          tag: _dataFormTag,
          xmlns: _dataFormXmlns,
        );
        final response = mox.Stanza.iq(type: _iqTypeError);

        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => response);

        final result = await xmppService.submitRoomConfiguration(
          roomJid: _roomJid,
          form: form,
        );

        expect(result, isFalse);
      },
    );
  });

  group('Subjects', () {
    test(
      'SUBJ-001 [HP] setRoomSubject sends subject-only groupchat messages',
      () async {
        mox.StanzaDetails? captured;
        when(() => mockConnection.sendStanza(any())).thenAnswer((
          invocation,
        ) async {
          captured = invocation.positionalArguments.first as mox.StanzaDetails;
          return null;
        });

        await xmppService.setRoomSubject(
          roomJid: _roomJid,
          subject: _subjectRaw,
        );

        final stanza = captured?.stanza;
        expect(stanza?.tag, equals(_messageTag));
        expect(stanza?.attributes[_typeAttr], equals(_messageTypeGroupchat));
        expect(stanza?.attributes[_toAttr], equals(_roomJid));
        expect(
          stanza?.firstTag(_subjectTag)?.innerText(),
          equals(_subjectTrimmed),
        );
        expect(stanza?.firstTag(_bodyTag), isNull);
      },
    );

    test('SUBJ-003 [HP] subject events update room subject streams', () async {
      final stream = xmppService.roomSubjectStream(_roomJid);
      expectLater(stream, emitsInOrder([_subjectTrimmed]));

      eventStreamController.add(
        MucSubjectChangedEvent(roomJid: _roomJid, subject: _subjectRaw),
      );

      await pumpEventQueue();
    });

    test(
      'SUBJ-006 [EC] empty subject events clear the stored subject',
      () async {
        final stream = xmppService.roomSubjectStream(_roomJid);
        expectLater(stream, emitsInOrder([null]));

        eventStreamController.add(
          MucSubjectChangedEvent(roomJid: _roomJid, subject: _subjectEmpty),
        );

        await pumpEventQueue();
      },
    );
  });

  group('Join and rejoin behavior', () {
    test(
      'JOIN-001 [HP] joinRoom forwards maxHistoryStanzas defaults',
      () async {
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer(
          (_) async =>
              const moxlib.Result<bool, mox.MUCError>(_presenceAvailable),
        );

        await xmppService.joinRoom(roomJid: _roomJid, nickname: _roomNick);

        verify(
          () => mucManager.joinRoom(
            mox.JID.fromString(_roomJidBare),
            _roomNick,
            maxHistoryStanzas: _defaultHistoryStanzas,
          ),
        ).called(1);
      },
    );

    test('HIST-010 [HP] joinRoom forwards custom history maxstanzas', () async {
      when(
        () => mucManager.joinRoom(
          any(),
          any(),
          maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
        ),
      ).thenAnswer(
        (_) async =>
            const moxlib.Result<bool, mox.MUCError>(_presenceAvailable),
      );

      await xmppService.joinRoom(
        roomJid: _roomJid,
        nickname: _roomNick,
        maxHistoryStanzas: _customHistoryStanzas,
      );

      verify(
        () => mucManager.joinRoom(
          mox.JID.fromString(_roomJidBare),
          _roomNick,
          maxHistoryStanzas: _customHistoryStanzas,
        ),
      ).called(1);
    });

    test(
      'JOIN-015 [EC] ensureJoined skips rejoin when already present',
      () async {
        final managerRoomState = mox.RoomState(
          roomJid: mox.JID.fromString(_roomJidBare),
          joined: true,
          nick: _roomNick,
        );
        when(
          () => mucManager.getRoomState(mox.JID.fromString(_roomJidBare)),
        ).thenAnswer((_) async => managerRoomState);
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer(
          (_) async =>
              const moxlib.Result<bool, mox.MUCError>(_presenceAvailable),
        );

        eventStreamController.add(
          MucSelfPresenceEvent(
            roomJid: _roomJid,
            occupantJid: _roomJidWithSelfNick,
            nick: _roomNick,
            affiliation: OccupantAffiliation.owner.xmlValue,
            role: OccupantRole.moderator.xmlValue,
            isAvailable: true,
            isError: false,
            isNickChange: false,
            statusCodes: {MucStatusCode.selfPresence.code},
          ),
        );
        await pumpEventQueue();

        await xmppService.ensureJoined(roomJid: _roomJid);

        verifyNever(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        );
      },
    );

    test(
      'JOIN-015B [HP] ensureJoined rejoins when manager state is stale',
      () async {
        final managerRoomState = mox.RoomState(
          roomJid: mox.JID.fromString(_roomJidBare),
          joined: false,
          nick: _roomNick,
        );
        when(
          () => mucManager.getRoomState(mox.JID.fromString(_roomJidBare)),
        ).thenAnswer((_) async => managerRoomState);
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer((_) async {
          eventStreamController.add(
            MucSelfPresenceEvent(
              roomJid: _roomJid,
              occupantJid: _roomJidWithSelfNick,
              nick: _roomNick,
              affiliation: OccupantAffiliation.owner.xmlValue,
              role: OccupantRole.moderator.xmlValue,
              isAvailable: true,
              isError: false,
              isNickChange: false,
              statusCodes: {MucStatusCode.selfPresence.code},
            ),
          );
          return const moxlib.Result<bool, mox.MUCError>(_presenceAvailable);
        });

        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: _roomJidWithSelfNick,
          nick: _roomNick,
          realJid: _accountBareJid,
          affiliation: OccupantAffiliation.owner,
          role: OccupantRole.moderator,
          isPresent: true,
          fromPresence: true,
        );

        await xmppService.ensureJoined(roomJid: _roomJid);

        verify(
          () => mucManager.joinRoom(
            mox.JID.fromString(_roomJidBare),
            _roomNick,
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).called(1);
        expect(managerRoomState.joined, isTrue);
      },
    );

    test(
      'JOIN-015C [HP] joinRoom clears stale local self presence before waiting for fresh self presence',
      () async {
        final managerRoomState = mox.RoomState(
          roomJid: mox.JID.fromString(_roomJidBare),
          joined: true,
          nick: _roomNick,
        );
        when(
          () => mucManager.getRoomState(mox.JID.fromString(_roomJidBare)),
        ).thenAnswer((_) async => managerRoomState);
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer((_) async {
          final roomBeforePresence = xmppService.roomStateFor(_roomJid);
          expect(roomBeforePresence?.hasSelfPresence, isFalse);
          expect(roomBeforePresence?.hasPresentSelfOccupant, isFalse);
          expect(managerRoomState.joined, isFalse);
          eventStreamController.add(
            MucSelfPresenceEvent(
              roomJid: _roomJid,
              occupantJid: _roomJidWithSelfNick,
              nick: _roomNick,
              affiliation: OccupantAffiliation.owner.xmlValue,
              role: OccupantRole.moderator.xmlValue,
              isAvailable: true,
              isError: false,
              isNickChange: false,
              statusCodes: {MucStatusCode.selfPresence.code},
            ),
          );
          return const moxlib.Result<bool, mox.MUCError>(_presenceAvailable);
        });

        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: _roomJidWithSelfNick,
          nick: _roomNick,
          realJid: _accountBareJid,
          affiliation: OccupantAffiliation.owner,
          role: OccupantRole.moderator,
          isPresent: true,
          fromPresence: true,
        );

        await xmppService.joinRoom(roomJid: _roomJid, nickname: _roomNick);

        final room = xmppService.roomStateFor(_roomJid);
        expect(room?.hasSelfPresence, isTrue);
        expect(room?.hasPresentSelfOccupant, isTrue);
      },
    );

    test(
      'JOIN-016 [HP] ensureJoined clears roomCreated after instant room configuration succeeds',
      () async {
        final managerRoomState = mox.RoomState(
          roomJid: mox.JID.fromString(_roomJidBare),
          joined: true,
          nick: _roomNick,
        );
        when(
          () => mucManager.getRoomState(mox.JID.fromString(_roomJidBare)),
        ).thenAnswer((_) async => managerRoomState);
        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => mox.Stanza.iq(type: _iqTypeResult));
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer((_) async {
          eventStreamController.add(
            MucSelfPresenceEvent(
              roomJid: _roomJid,
              occupantJid: _roomJidWithSelfNick,
              nick: _roomNick,
              affiliation: OccupantAffiliation.owner.xmlValue,
              role: OccupantRole.moderator.xmlValue,
              isAvailable: true,
              isError: false,
              isNickChange: false,
              statusCodes: {MucStatusCode.selfPresence.code},
            ),
          );
          return const moxlib.Result<bool, mox.MUCError>(_presenceAvailable);
        });

        eventStreamController.add(
          MucSelfPresenceEvent(
            roomJid: _roomJid,
            occupantJid: _roomJidWithSelfNick,
            nick: _roomNick,
            affiliation: OccupantAffiliation.owner.xmlValue,
            role: OccupantRole.moderator.xmlValue,
            isAvailable: true,
            isError: false,
            isNickChange: false,
            statusCodes: {
              MucStatusCode.selfPresence.code,
              MucStatusCode.roomCreated.code,
            },
          ),
        );
        await pumpEventQueue();

        await xmppService.ensureJoined(roomJid: _roomJid);

        final room = xmppService.roomStateFor(_roomJid);
        expect(room?.roomCreated, isFalse);
        verifyNever(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        );
      },
    );

    test(
      'JOIN-017 [HP] ensureJoined configures a newly created room only once',
      () async {
        final managerRoomState = mox.RoomState(
          roomJid: mox.JID.fromString(_roomJidBare),
          joined: true,
          nick: _roomNick,
        );
        when(
          () => mucManager.getRoomState(mox.JID.fromString(_roomJidBare)),
        ).thenAnswer((_) async => managerRoomState);
        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => mox.Stanza.iq(type: _iqTypeResult));
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer(
          (_) async =>
              const moxlib.Result<bool, mox.MUCError>(_presenceAvailable),
        );

        eventStreamController.add(
          MucSelfPresenceEvent(
            roomJid: _roomJid,
            occupantJid: _roomJidWithSelfNick,
            nick: _roomNick,
            affiliation: OccupantAffiliation.owner.xmlValue,
            role: OccupantRole.moderator.xmlValue,
            isAvailable: true,
            isError: false,
            isNickChange: false,
            statusCodes: {
              MucStatusCode.selfPresence.code,
              MucStatusCode.roomCreated.code,
            },
          ),
        );
        await pumpEventQueue();

        await xmppService.ensureJoined(roomJid: _roomJid);
        await xmppService.ensureJoined(roomJid: _roomJid);

        final capturedStanzas = verify(
          () => mockConnection.sendStanza(captureAny()),
        ).captured.cast<mox.StanzaDetails>();
        final configSubmitCount = capturedStanzas
            .map((details) => details.stanza)
            .where(
              (stanza) =>
                  stanza.attributes[_typeAttr] == _iqTypeSet &&
                  stanza
                          .firstTag(_queryTag, xmlns: _mucOwnerXmlns)
                          ?.firstTag(_dataFormTag, xmlns: _dataFormXmlns)
                          ?.attributes[_typeAttr] ==
                      'submit',
            )
            .length;
        expect(configSubmitCount, 1);
        verifyNever(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        );
      },
    );

    test(
      'JOIN-018 [HP] self presence auth errors stop bootstrap and preserve join failure details',
      () async {
        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: _roomJidWithSelfNick,
          nick: 'me',
          realJid: _accountBareJid,
          affiliation: OccupantAffiliation.owner,
          role: OccupantRole.moderator,
        );

        eventStreamController.add(
          MucSelfPresenceEvent(
            roomJid: _roomJid,
            occupantJid: _roomJidWithSelfNick,
            nick: 'me',
            affiliation: OccupantAffiliation.none.xmlValue,
            role: OccupantRole.none.xmlValue,
            isAvailable: false,
            isError: true,
            isNickChange: false,
            statusCodes: const <String>{},
            errorCondition: MucJoinErrorCondition.registrationRequired.xmlValue,
            errorText: 'Membership is required to enter this room',
          ),
        );
        await pumpEventQueue();

        final room = xmppService.roomStateFor(_roomJid);
        expect(room, isNotNull);
        expect(room?.hasJoinError, isTrue);
        expect(
          room?.joinErrorCondition,
          equals(MucJoinErrorCondition.registrationRequired),
        );
        expect(
          room?.joinErrorText,
          equals('Membership is required to enter this room'),
        );
        expect(room?.isBootstrapPending, isFalse);
      },
    );

    test(
      'JOIN-020 [HP] own data arriving before self presence is applied once self presence lands',
      () async {
        eventStreamController.add(
          mox.OwnDataChangedEvent(
            mox.JID.fromString(_roomJid),
            'me',
            mox.Affiliation.owner,
            mox.Role.moderator,
          ),
        );

        eventStreamController.add(
          MucSelfPresenceEvent(
            roomJid: _roomJid,
            occupantJid: _roomJidWithSelfNick,
            nick: 'me',
            affiliation: OccupantAffiliation.none.xmlValue,
            role: OccupantRole.participant.xmlValue,
            isAvailable: true,
            isError: false,
            isNickChange: false,
            statusCodes: {MucStatusCode.selfPresence.code},
          ),
        );

        await pumpEventQueue();

        final room = xmppService.roomStateFor(_roomJid);
        expect(room?.hasSelfPresence, isTrue);
        expect(room?.myOccupantJid, equals(_roomJidWithSelfNick));
        expect(room?.myAffiliation, equals(OccupantAffiliation.owner));
        expect(room?.myRole, equals(OccupantRole.moderator));
        expect(
          room?.occupants[_roomJidWithSelfNick]?.realJid,
          equals(_accountBareJid),
        );
      },
    );

    test(
      'JOIN-021 [HP] joinRoom requests affiliations as soon as self presence arrives',
      () async {
        final requestedAffiliations = <String>[];
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer((_) async {
          eventStreamController.add(
            MucSelfPresenceEvent(
              roomJid: _roomJid,
              occupantJid: _roomJidWithSelfNick,
              nick: 'me',
              affiliation: OccupantAffiliation.owner.xmlValue,
              role: OccupantRole.moderator.xmlValue,
              isAvailable: true,
              isError: false,
              isNickChange: false,
              statusCodes: {MucStatusCode.selfPresence.code},
            ),
          );
          return const moxlib.Result<bool, mox.MUCError>(_presenceAvailable);
        });
        when(() => mockConnection.sendStanza(any())).thenAnswer((
          invocation,
        ) async {
          final details =
              invocation.positionalArguments.first as mox.StanzaDetails;
          final stanza = details.stanza;
          final adminQuery = stanza.firstTag(_queryTag, xmlns: _mucAdminXmlns);
          if (adminQuery != null) {
            final affiliation = adminQuery
                .firstTag(_itemTag)
                ?.attributes[_affiliationAttr]
                ?.toString();
            if (affiliation != null) {
              requestedAffiliations.add(affiliation);
            }
            return mox.Stanza.iq(
              type: _iqTypeResult,
              children: [
                mox.XMLNode.xmlns(tag: _queryTag, xmlns: _mucAdminXmlns),
              ],
            );
          }
          final ownerQuery = stanza.firstTag(_queryTag, xmlns: _mucOwnerXmlns);
          if (ownerQuery != null) {
            final affiliation = ownerQuery
                .firstTag(_itemTag)
                ?.attributes[_affiliationAttr]
                ?.toString();
            if (affiliation != null) {
              requestedAffiliations.add(affiliation);
            }
            return mox.Stanza.iq(
              type: _iqTypeResult,
              children: [
                mox.XMLNode.xmlns(tag: _queryTag, xmlns: _mucOwnerXmlns),
              ],
            );
          }
          return null;
        });

        await xmppService.joinRoom(roomJid: _roomJid, nickname: 'me');

        expect(
          requestedAffiliations,
          containsAll(<String>[
            OccupantAffiliation.member.xmlValue,
            OccupantAffiliation.owner.xmlValue,
            OccupantAffiliation.admin.xmlValue,
          ]),
        );
      },
    );

    test(
      'JOIN-022 [HP] joinRoom completes before post-join metadata refresh replies',
      () async {
        final pendingMetadataReplies = Completer<mox.XMLNode?>();
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer((_) async {
          eventStreamController.add(
            MucSelfPresenceEvent(
              roomJid: _roomJid,
              occupantJid: _roomJidWithSelfNick,
              nick: 'me',
              affiliation: OccupantAffiliation.owner.xmlValue,
              role: OccupantRole.moderator.xmlValue,
              isAvailable: true,
              isError: false,
              isNickChange: false,
              statusCodes: {
                MucStatusCode.selfPresence.code,
                MucStatusCode.roomCreated.code,
              },
            ),
          );
          return const moxlib.Result<bool, mox.MUCError>(_presenceAvailable);
        });
        when(() => mucManager.leaveRoom(any())).thenAnswer(
          (_) async => const moxlib.Result<bool, mox.MUCError>(true),
        );
        when(() => mockConnection.sendStanza(any())).thenAnswer((invocation) {
          final details =
              invocation.positionalArguments.first as mox.StanzaDetails;
          final stanza = details.stanza;
          final isAffiliationQuery =
              stanza.firstTag(_queryTag, xmlns: _mucAdminXmlns) != null ||
              stanza.firstTag(_queryTag, xmlns: _mucOwnerXmlns) != null;
          if (!isAffiliationQuery) {
            return Future<mox.XMLNode?>.value(null);
          }
          return pendingMetadataReplies.future;
        });

        await xmppService
            .joinRoom(roomJid: _roomJid, nickname: 'me')
            .timeout(const Duration(seconds: 1));

        expect(xmppService.roomStateFor(_roomJid)?.hasSelfPresence, isTrue);

        pendingMetadataReplies.complete(null);
        await pumpEventQueue();
      },
    );

    test(
      'JOIN-023 [HP] resumed streams invalidate stale joined room state before any next send',
      () async {
        final managerRoomState = mox.RoomState(
          roomJid: mox.JID.fromString(_roomJidBare),
          nick: 'me',
          joined: true,
        );
        when(
          () => mucManager.getRoomState(mox.JID.fromString(_roomJidBare)),
        ).thenAnswer((_) async => managerRoomState);

        eventStreamController.add(
          MucSelfPresenceEvent(
            roomJid: _roomJid,
            occupantJid: _roomJidWithSelfNick,
            nick: 'me',
            affiliation: OccupantAffiliation.owner.xmlValue,
            role: OccupantRole.moderator.xmlValue,
            isAvailable: true,
            isError: false,
            isNickChange: false,
            statusCodes: {MucStatusCode.selfPresence.code},
          ),
        );
        await pumpEventQueue();

        expect(xmppService.roomStateFor(_roomJid)?.hasSelfPresence, isTrue);
        expect(
          xmppService
              .roomStateFor(_roomJid)
              ?.occupants[_roomJidWithSelfNick]
              ?.isPresent,
          isTrue,
        );
        expect(managerRoomState.joined, isTrue);

        eventStreamController.add(mox.StreamNegotiationsDoneEvent(true));
        await pumpEventQueue();

        final room = xmppService.roomStateFor(_roomJid);
        expect(room?.hasSelfPresence, isFalse);
        expect(room?.occupants[_roomJidWithSelfNick]?.isPresent, isFalse);
        expect(managerRoomState.joined, isFalse);
      },
    );

    test('JOIN-024 [HP] joinRoom emits room join operation events', () async {
      when(
        () => mucManager.joinRoom(
          any(),
          any(),
          maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
        ),
      ).thenAnswer((_) async {
        eventStreamController.add(
          MucSelfPresenceEvent(
            roomJid: _roomJid,
            occupantJid: _roomJidWithSelfNick,
            nick: 'me',
            affiliation: OccupantAffiliation.owner.xmlValue,
            role: OccupantRole.moderator.xmlValue,
            isAvailable: true,
            isError: false,
            isNickChange: false,
            statusCodes: {MucStatusCode.selfPresence.code},
          ),
        );
        return const moxlib.Result<bool, mox.MUCError>(_presenceAvailable);
      });

      final events = await captureXmppOperations(
        () => xmppService.joinRoom(roomJid: _roomJid, nickname: 'me'),
      );
      final joinEvents = events
          .where((event) => event.kind == XmppOperationKind.mucJoin)
          .toList(growable: false);

      expect(joinEvents, hasLength(2));
      expect(joinEvents.first.stage, XmppOperationStage.start);
      expect(joinEvents.last.stage, XmppOperationStage.end);
      expect(joinEvents.last.isSuccess, isTrue);
    });

    test(
      'CREATE-001 [HP] createRoom emits create events without nested join events',
      () async {
        await xmppService.setMucServiceHost(_serviceJid);
        when(() => mockDatabase.createChat(any())).thenAnswer((_) async {});
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer((_) async {
          eventStreamController.add(
            MucSelfPresenceEvent(
              roomJid: 'planning-room@$_serviceJid',
              occupantJid: 'planning-room@$_serviceJid/me',
              nick: 'me',
              affiliation: OccupantAffiliation.owner.xmlValue,
              role: OccupantRole.moderator.xmlValue,
              isAvailable: true,
              isError: false,
              isNickChange: false,
              statusCodes: {
                MucStatusCode.selfPresence.code,
                MucStatusCode.roomCreated.code,
              },
            ),
          );
          return const moxlib.Result<bool, mox.MUCError>(_presenceAvailable);
        });

        final events = await captureXmppOperations(
          () => xmppService.createRoom(name: _roomName, nickname: 'me'),
        );
        final createEvents = events
            .where((event) => event.kind == XmppOperationKind.mucCreate)
            .toList(growable: false);
        final joinEvents = events
            .where((event) => event.kind == XmppOperationKind.mucJoin)
            .toList(growable: false);

        expect(createEvents, hasLength(2));
        expect(createEvents.first.stage, XmppOperationStage.start);
        expect(createEvents.last.stage, XmppOperationStage.end);
        expect(createEvents.last.isSuccess, isTrue);
        expect(joinEvents, isEmpty);
      },
    );

    test(
      'CREATE-002 [HP] createRoom fails closed when the room already exists',
      () async {
        await xmppService.setMucServiceHost(_serviceJid);
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer((_) async {
          eventStreamController.add(
            MucSelfPresenceEvent(
              roomJid: 'planning-room@$_serviceJid',
              occupantJid: 'planning-room@$_serviceJid/me',
              nick: 'me',
              affiliation: OccupantAffiliation.member.xmlValue,
              role: OccupantRole.participant.xmlValue,
              isAvailable: true,
              isError: false,
              isNickChange: false,
              statusCodes: {MucStatusCode.selfPresence.code},
            ),
          );
          return const moxlib.Result<bool, mox.MUCError>(_presenceAvailable);
        });
        when(() => mucManager.leaveRoom(any())).thenAnswer(
          (_) async => const moxlib.Result<bool, mox.MUCError>(true),
        );

        final events = await captureXmppOperations(() async {
          await expectLater(
            xmppService.createRoom(name: _roomName, nickname: 'me'),
            throwsA(isA<XmppMucCreateConflictException>()),
          );
        });
        final createEvents = events
            .where((event) => event.kind == XmppOperationKind.mucCreate)
            .toList(growable: false);

        expect(createEvents, hasLength(2));
        expect(createEvents.first.stage, XmppOperationStage.start);
        expect(createEvents.last.stage, XmppOperationStage.end);
        expect(createEvents.last.isSuccess, isFalse);
        expect(xmppService.roomStateFor('planning-room@$_serviceJid'), isNull);
        verify(() => mucManager.leaveRoom(any())).called(1);
        verifyNever(() => mockDatabase.createChat(any()));
      },
    );

    test(
      'CREATE-003 [HP] createRoom seeds a local room avatar before the remote update completes',
      () async {
        const roomJid = 'planning-room@$_serviceJid';
        final payload = AvatarUploadPayload(
          bytes: Uint8List.fromList(_pngLikeBytes),
          mimeType: 'image/png',
          width: 1,
          height: 1,
          hash: 'created-room-avatar-hash',
        );
        await xmppService.setMucServiceHost(_serviceJid);
        when(() => mockDatabase.createChat(any())).thenAnswer((_) async {});
        when(() => mockDatabase.getChat(roomJid)).thenAnswer(
          (_) async => Chat(
            jid: roomJid,
            title: _roomName,
            type: ChatType.groupChat,
            myNickname: 'me',
            lastChangeTimestamp: DateTime.timestamp(),
            contactJid: roomJid,
          ),
        );
        when(
          () => mockDatabase.updateChatAvatar(
            jid: any(named: 'jid'),
            avatarPath: any(named: 'avatarPath'),
            avatarHash: any(named: 'avatarHash'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer((_) async {
          eventStreamController.add(
            MucSelfPresenceEvent(
              roomJid: roomJid,
              occupantJid: '$roomJid/me',
              nick: 'me',
              affiliation: OccupantAffiliation.owner.xmlValue,
              role: OccupantRole.moderator.xmlValue,
              isAvailable: true,
              isError: false,
              isNickChange: false,
              statusCodes: {
                MucStatusCode.selfPresence.code,
                MucStatusCode.roomCreated.code,
              },
            ),
          );
          return const moxlib.Result<bool, mox.MUCError>(_presenceAvailable);
        });
        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => null);

        await xmppService.createRoom(
          name: _roomName,
          nickname: 'me',
          avatar: payload,
        );
        await pumpEventQueue();

        verify(
          () => mockDatabase.updateChatAvatar(
            jid: roomJid,
            avatarPath: any(named: 'avatarPath'),
            avatarHash: any(named: 'avatarHash'),
          ),
        ).called(1);
      },
    );

    test(
      'CREATE-004 [HP] createRoom waits for instant room configuration before publishing the room avatar',
      () async {
        const roomJid = 'planning-room@$_serviceJid';
        const expectedHash = 'created-room-avatar-hash';
        final payload = AvatarUploadPayload(
          bytes: Uint8List.fromList(_pngLikeBytes),
          mimeType: 'image/png',
          width: 1,
          height: 1,
          hash: expectedHash,
        );
        final requests = <String>[];

        await xmppService.setMucServiceHost(_serviceJid);
        when(() => mockDatabase.createChat(any())).thenAnswer((_) async {});
        when(() => mockDatabase.getChat(roomJid)).thenAnswer(
          (_) async => Chat(
            jid: roomJid,
            title: _roomName,
            type: ChatType.groupChat,
            myNickname: 'me',
            lastChangeTimestamp: DateTime.timestamp(),
            contactJid: roomJid,
          ),
        );
        when(
          () => mockDatabase.updateChatAvatar(
            jid: any(named: 'jid'),
            avatarPath: any(named: 'avatarPath'),
            avatarHash: any(named: 'avatarHash'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer((_) async {
          eventStreamController.add(
            MucSelfPresenceEvent(
              roomJid: roomJid,
              occupantJid: '$roomJid/me',
              nick: 'me',
              affiliation: OccupantAffiliation.owner.xmlValue,
              role: OccupantRole.moderator.xmlValue,
              isAvailable: true,
              isError: false,
              isNickChange: false,
              statusCodes: {
                MucStatusCode.selfPresence.code,
                MucStatusCode.roomCreated.code,
              },
            ),
          );
          return const moxlib.Result<bool, mox.MUCError>(_presenceAvailable);
        });
        when(() => mockConnection.sendStanza(any())).thenAnswer((invocation) {
          final details =
              invocation.positionalArguments.first as mox.StanzaDetails;
          final stanza = details.stanza;
          final type = stanza.attributes[_typeAttr]?.toString();
          final ownerQuery = stanza.firstTag(_queryTag, xmlns: _mucOwnerXmlns);

          if (ownerQuery != null && type == _iqTypeSet) {
            final form = ownerQuery.firstTag(
              _dataFormTag,
              xmlns: _dataFormXmlns,
            );
            final fieldNames = form
                ?.findTags(_fieldTag)
                .map((field) => field.attributes['var']?.toString() ?? '')
                .toList(growable: false);
            final isInstantConfig =
                fieldNames != null &&
                fieldNames.length == 1 &&
                fieldNames.single == 'FORM_TYPE';
            requests.add(
              isInstantConfig ? 'instant-config-set' : 'avatar-config-set',
            );
            return Future<mox.XMLNode?>.value(
              mox.Stanza.iq(type: _iqTypeResult),
            );
          }

          if (ownerQuery != null && type == _iqTypeGet) {
            requests.add('avatar-config-get');
            return Future<mox.XMLNode?>.value(
              mox.Stanza.iq(
                type: _iqTypeResult,
                children: [
                  mox.XMLNode.xmlns(
                    tag: _queryTag,
                    xmlns: _mucOwnerXmlns,
                    children: [
                      mox.XMLNode.xmlns(
                        tag: _dataFormTag,
                        xmlns: _dataFormXmlns,
                        attributes: {'type': 'form'},
                        children: [
                          _formTypeField(_mucRoomConfigFormType),
                          _singleValueField('muc#roomconfig_avatar', ''),
                          _singleValueField('muc#roomconfig_avatar_hash', ''),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          if (stanza.firstTag('vCard', xmlns: 'vcard-temp') != null &&
              type == _iqTypeSet) {
            requests.add('avatar-vcard-set');
            return Future<mox.XMLNode?>.value(
              mox.Stanza.iq(type: _iqTypeResult),
            );
          }

          if (stanza.firstTag(_queryTag, xmlns: _discoInfoXmlns) != null) {
            requests.add('room-info-get');
            return Future<mox.XMLNode?>.value(
              mox.Stanza.iq(
                type: _iqTypeResult,
                children: [
                  mox.XMLNode.xmlns(
                    tag: _queryTag,
                    xmlns: _discoInfoXmlns,
                    children: [
                      mox.XMLNode.xmlns(
                        tag: _dataFormTag,
                        xmlns: _dataFormXmlns,
                        attributes: {'type': 'result'},
                        children: [
                          _formTypeField(_mucRoomInfoFormType),
                          _singleValueField(
                            'muc#roominfo_avatar_hash',
                            expectedHash,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return Future<mox.XMLNode?>.value(null);
        });

        await xmppService.createRoom(
          name: _roomName,
          nickname: 'me',
          avatar: payload,
        );
        await pumpEventQueue();
        await pumpEventQueue();

        expect(
          requests,
          containsAllInOrder(<String>[
            'instant-config-set',
            'avatar-config-get',
            'avatar-config-set',
          ]),
        );
        verifyNever(() => mucManager.leaveRoom(any()));
      },
    );

    test(
      'JOIN-025 [HP] joining a room triggers room history sync operation events',
      () async {
        await xmppService.setMucServiceHost(_serviceJid);
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer((_) async {
          eventStreamController.add(
            MucSelfPresenceEvent(
              roomJid: _roomJid,
              occupantJid: _roomJidWithSelfNick,
              nick: 'me',
              affiliation: OccupantAffiliation.owner.xmlValue,
              role: OccupantRole.moderator.xmlValue,
              isAvailable: true,
              isError: false,
              isNickChange: false,
              statusCodes: {MucStatusCode.selfPresence.code},
            ),
          );
          return const moxlib.Result<bool, mox.MUCError>(_presenceAvailable);
        });
        when(() => mockConnection.sendStanza(any())).thenAnswer((invocation) {
          final details =
              invocation.positionalArguments.first as mox.StanzaDetails;
          final stanza = details.stanza;
          if (stanza.firstTag(_queryTag, xmlns: _mucAdminXmlns) != null) {
            return Future<mox.XMLNode?>.value(
              mox.Stanza.iq(
                type: _iqTypeResult,
                children: [
                  mox.XMLNode.xmlns(tag: _queryTag, xmlns: _mucAdminXmlns),
                ],
              ),
            );
          }
          if (stanza.firstTag(_queryTag, xmlns: _mucOwnerXmlns) != null) {
            return Future<mox.XMLNode?>.value(
              mox.Stanza.iq(
                type: _iqTypeResult,
                children: [
                  mox.XMLNode.xmlns(tag: _queryTag, xmlns: _mucOwnerXmlns),
                ],
              ),
            );
          }
          if (stanza.firstTag(_queryTag, xmlns: mox.mamXmlns) != null) {
            return Future<mox.XMLNode?>.value(
              mox.Stanza.iq(
                type: _iqTypeError,
                children: [mox.XMLNode(tag: _errorTag)],
              ),
            );
          }
          return Future<mox.XMLNode?>.value(null);
        });

        final events = await captureXmppOperations(
          () => xmppService.joinRoom(roomJid: _roomJid, nickname: 'me'),
        );
        await pumpEventQueue();

        final roomHistoryEvents = events
            .where((event) => event.kind == XmppOperationKind.mamMucSync)
            .toList(growable: false);

        expect(roomHistoryEvents, hasLength(2));
        expect(roomHistoryEvents.first.stage, XmppOperationStage.start);
        expect(roomHistoryEvents.last.stage, XmppOperationStage.end);
        expect(roomHistoryEvents.last.isSuccess, isFalse);
      },
    );

    test(
      'JOIN-026 [HP] deferred room history sync waits for join completion after login sync',
      () async {
        await xmppService.setMucServiceHost(_serviceJid);
        await xmppService.setMamSupportOverride(true);
        final loginSyncGate = Completer<List<Chat>>();
        when(
          () => mockDatabase.getChats(
            start: any(named: 'start'),
            end: any(named: 'end'),
          ),
        ).thenAnswer((_) => loginSyncGate.future);
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer((_) async {
          eventStreamController.add(
            MucSelfPresenceEvent(
              roomJid: _roomJid,
              occupantJid: _roomJidWithSelfNick,
              nick: 'me',
              affiliation: OccupantAffiliation.owner.xmlValue,
              role: OccupantRole.moderator.xmlValue,
              isAvailable: true,
              isError: false,
              isNickChange: false,
              statusCodes: {MucStatusCode.selfPresence.code},
            ),
          );
          return const moxlib.Result<bool, mox.MUCError>(_presenceAvailable);
        });
        when(() => mockConnection.sendStanza(any())).thenAnswer((invocation) {
          final details =
              invocation.positionalArguments.first as mox.StanzaDetails;
          final stanza = details.stanza;
          if (stanza.firstTag(_queryTag, xmlns: _mucAdminXmlns) != null) {
            return Future<mox.XMLNode?>.value(
              mox.Stanza.iq(
                type: _iqTypeResult,
                children: [
                  mox.XMLNode.xmlns(tag: _queryTag, xmlns: _mucAdminXmlns),
                ],
              ),
            );
          }
          if (stanza.firstTag(_queryTag, xmlns: _mucOwnerXmlns) != null) {
            return Future<mox.XMLNode?>.value(
              mox.Stanza.iq(
                type: _iqTypeResult,
                children: [
                  mox.XMLNode.xmlns(tag: _queryTag, xmlns: _mucOwnerXmlns),
                ],
              ),
            );
          }
          if (stanza.firstTag(_queryTag, xmlns: mox.mamXmlns) != null) {
            return Future<mox.XMLNode?>.value(
              mox.Stanza.iq(
                type: _iqTypeError,
                children: [mox.XMLNode(tag: _errorTag)],
              ),
            );
          }
          return Future<mox.XMLNode?>.value(null);
        });

        final events = <XmppOperationEvent>[];
        final subscription = xmppService.xmppOperationStream.listen(events.add);
        addTearDown(subscription.cancel);

        final loginSyncFuture = xmppService.syncMessageArchiveSnapshot();
        await pumpEventQueue();

        final joinFuture = xmppService.joinRoom(
          roomJid: _roomJid,
          nickname: 'me',
        );
        await pumpEventQueue();

        loginSyncGate.complete(const <Chat>[]);
        await loginSyncFuture;
        await joinFuture;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await pumpEventQueue();

        final roomHistoryEvents = events
            .where((event) => event.kind == XmppOperationKind.mamMucSync)
            .toList(growable: false);

        expect(roomHistoryEvents, hasLength(2));
        expect(roomHistoryEvents.first.stage, XmppOperationStage.start);
        expect(roomHistoryEvents.last.stage, XmppOperationStage.end);
        expect(roomHistoryEvents.last.isSuccess, isFalse);
      },
    );

    test(
      'MAM-001 [HP] hanging archive queries fail via the hard timeout fallback',
      () {
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);
        when(
          () => mamManager.queryArchive(
            to: any(named: 'to'),
            options: any(named: 'options'),
            rsm: any(named: 'rsm'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) => Completer<mox.MAMQueryResult?>().future);

        fakeAsync((async) {
          final events = <XmppOperationEvent>[];
          final subscription = xmppService.xmppOperationStream.listen(
            events.add,
          );
          addTearDown(subscription.cancel);

          Object? capturedError;
          xmppService
              .fetchLatestFromArchive(jid: _inviteeJid)
              .then<void>(
                (_) {},
                onError: (Object error, StackTrace _) {
                  capturedError = error;
                },
              );

          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 96));
          async.flushMicrotasks();

          final mamEvents = events
              .where((event) => event.kind == XmppOperationKind.mamFetch)
              .toList(growable: false);

          expect(mamEvents, hasLength(2));
          expect(mamEvents.first.stage, XmppOperationStage.start);
          expect(mamEvents.last.stage, XmppOperationStage.end);
          expect(mamEvents.last.isSuccess, isFalse);
          expect(capturedError, isA<TimeoutException>());
        });
      },
    );

    test(
      'ROOM-AVATAR-001 [HP] updateRoomAvatar does not emit xmpp operation events',
      () async {
        const expectedHash = 'expected-room-avatar-hash';
        final payload = AvatarUploadPayload(
          bytes: Uint8List.fromList(_pngLikeBytes),
          mimeType: 'image/png',
          width: 1,
          height: 1,
          hash: expectedHash,
        );
        when(() => mockConnection.sendStanza(any())).thenAnswer((invocation) {
          final details =
              invocation.positionalArguments.first as mox.StanzaDetails;
          final stanza = details.stanza;
          final type = stanza.attributes[_typeAttr]?.toString();
          if (stanza.firstTag(_queryTag, xmlns: _mucOwnerXmlns)
              case final query? when type == _iqTypeGet) {
            final item = query.firstTag(_itemTag);
            if (item != null) {
              return Future<mox.XMLNode?>.value(
                mox.Stanza.iq(
                  type: _iqTypeResult,
                  children: [
                    mox.XMLNode.xmlns(tag: _queryTag, xmlns: _mucOwnerXmlns),
                  ],
                ),
              );
            }
            return Future<mox.XMLNode?>.value(
              mox.Stanza.iq(
                type: _iqTypeResult,
                children: [
                  mox.XMLNode.xmlns(
                    tag: _queryTag,
                    xmlns: _mucOwnerXmlns,
                    children: [
                      mox.XMLNode.xmlns(
                        tag: _dataFormTag,
                        xmlns: _dataFormXmlns,
                        attributes: {'type': 'form'},
                        children: [
                          _formTypeField(_mucRoomConfigFormType),
                          _singleValueField('muc#roomconfig_avatar', ''),
                          _singleValueField('muc#roomconfig_avatar_hash', ''),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
          if (stanza.firstTag(_queryTag, xmlns: _mucOwnerXmlns) != null &&
              type == _iqTypeSet) {
            return Future<mox.XMLNode?>.value(
              mox.Stanza.iq(type: _iqTypeResult),
            );
          }
          if (stanza.firstTag(_queryTag, xmlns: _discoInfoXmlns) != null) {
            return Future<mox.XMLNode?>.value(
              mox.Stanza.iq(
                type: _iqTypeResult,
                children: [
                  mox.XMLNode.xmlns(
                    tag: _queryTag,
                    xmlns: _discoInfoXmlns,
                    children: [
                      mox.XMLNode.xmlns(
                        tag: _dataFormTag,
                        xmlns: _dataFormXmlns,
                        attributes: {'type': 'result'},
                        children: [
                          _formTypeField(_mucRoomInfoFormType),
                          _singleValueField(
                            'muc#roominfo_avatar_hash',
                            expectedHash,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
          return Future<mox.XMLNode?>.value(null);
        });

        final events = await captureXmppOperations(
          () =>
              xmppService.updateRoomAvatar(roomJid: _roomJid, avatar: payload),
        );

        expect(events, isEmpty);
      },
    );

    test(
      'ROOM-AVATAR-002 [HP] MUC vCard avatar updates refresh room avatars',
      () async {
        const roomAvatarHash = 'room-avatar-hash';
        final encodedAvatar = base64Encode(_pngLikeBytes);
        await xmppService.setMucServiceHost(_serviceJid);
        when(() => mockDatabase.getChat(_roomJid)).thenAnswer(
          (_) async => Chat(
            jid: _roomJid,
            title: _roomName,
            type: ChatType.groupChat,
            myNickname: _roomNick,
            lastChangeTimestamp: DateTime.timestamp(),
            contactJid: _roomJid,
          ),
        );
        when(
          () => mockDatabase.updateChatAvatar(
            jid: any(named: 'jid'),
            avatarPath: any(named: 'avatarPath'),
            avatarHash: any(named: 'avatarHash'),
          ),
        ).thenAnswer((_) async {});
        when(() => mockConnection.sendStanza(any())).thenAnswer((invocation) {
          final details =
              invocation.positionalArguments.first as mox.StanzaDetails;
          final stanza = details.stanza;
          final type = stanza.attributes[_typeAttr]?.toString();
          if (stanza.firstTag('vCard', xmlns: 'vcard-temp') != null &&
              type == _iqTypeGet) {
            return Future<mox.XMLNode?>.value(
              mox.Stanza.iq(
                type: _iqTypeResult,
                children: [
                  mox.XMLNode.xmlns(
                    tag: 'vCard',
                    xmlns: 'vcard-temp',
                    children: [
                      mox.XMLNode(
                        tag: 'PHOTO',
                        children: [
                          mox.XMLNode(tag: 'BINVAL', text: encodedAvatar),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
          return Future<mox.XMLNode?>.value(null);
        });

        eventStreamController.add(
          mox.VCardAvatarUpdatedEvent(
            mox.JID.fromString(_roomJid),
            roomAvatarHash,
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        verify(
          () => mockDatabase.updateChatAvatar(
            jid: _roomJid,
            avatarPath: any(named: 'avatarPath'),
            avatarHash: any(named: 'avatarHash'),
          ),
        ).called(1);
      },
    );
  });

  group('Nickname changes', () {
    test(
      'RN-001 [HP] changeNickname rejoins with trimmed nick and no history',
      () async {
        final chat = Chat(
          jid: _roomJid,
          title: _roomName,
          type: ChatType.groupChat,
          myNickname: _roomNick,
          lastChangeTimestamp: _fixedTimestamp,
          contactJid: _roomJid,
        );

        when(
          () => mockDatabase.getChat(_roomJid),
        ).thenAnswer((_) async => chat);
        when(() => mockDatabase.updateChat(any())).thenAnswer((_) async {});
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer(
          (_) async =>
              const moxlib.Result<bool, mox.MUCError>(_presenceAvailable),
        );

        await xmppService.changeNickname(
          roomJid: _roomJid,
          nickname: _roomNickUpdatedRaw,
        );

        verify(
          () => mucManager.joinRoom(
            mox.JID.fromString(_roomJidBare),
            _roomNickUpdatedTrimmed,
            maxHistoryStanzas: _noHistoryStanzas,
          ),
        ).called(1);

        verify(
          () => mockDatabase.updateChat(
            chat.copyWith(myNickname: _roomNickUpdatedTrimmed),
          ),
        ).called(1);
      },
    );
  });

  group('Invites', () {
    test(
      'DINV-010 [HP] inviteUserToRoom sends direct invite extensions',
      () async {
        when(() => mockConnection.generateId()).thenReturn(_stanzaId);
        when(
          () => mockDatabase.saveMessage(
            any(),
            chatType: any(named: 'chatType'),
            selfJid: any(named: 'selfJid'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => true);

        await xmppService.inviteUserToRoom(
          roomJid: _roomJid,
          inviteeJid: _inviteeJid,
          reason: _inviteReasonRaw,
          password: _invitePasswordRaw,
        );

        final captured =
            verify(
                  () => mockConnection.sendMessage(captureAny()),
                ).captured.single
                as mox.MessageEvent;
        final directInvite = captured.get<DirectMucInviteData>();
        final axiInvite = captured.get<AxiMucInvitePayload>();

        expect(directInvite, isNotNull);
        expect(directInvite?.roomJid, equals(_roomJid));
        expect(directInvite?.reason, equals(_inviteReasonRaw));
        expect(directInvite?.password, equals(_invitePasswordTrimmed));
        expect(axiInvite, isNotNull);
        expect(axiInvite?.roomJid, equals(_roomJid));
        expect(axiInvite?.inviter, equals(_accountBareJid));
        expect(axiInvite?.invitee, equals(_inviteeJid));
      },
    );

    test(
      'DINV-011 [HP] inviteUserToRoom grants membership before inviting to members-only rooms',
      () async {
        final info = MockRoomInformation();
        when(
          () => info.features,
        ).thenReturn(const <String>[_mucDiscoFeature, _mucMembersOnlyFeature]);
        when(() => mucManager.queryRoomInformation(any())).thenAnswer(
          (_) async => moxlib.Result<mox.RoomInformation, mox.MUCError>(info),
        );
        when(
          () => mucManager.sendAdminIq(
            roomJid: any(named: 'roomJid'),
            items: any(named: 'items'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => _memberAffiliationQueryResult(_inviteeJid));
        when(() => mockConnection.generateId()).thenReturn(_stanzaId);
        when(
          () => mockDatabase.saveMessage(
            any(),
            chatType: any(named: 'chatType'),
            selfJid: any(named: 'selfJid'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => true);

        await xmppService.inviteUserToRoom(
          roomJid: _roomJid,
          inviteeJid: _inviteeJid,
          reason: _inviteReasonRaw,
          password: _invitePasswordRaw,
        );

        final captured =
            verify(
                  () => mucManager.sendAdminIq(
                    roomJid: _roomJid,
                    items: captureAny(named: 'items'),
                  ),
                ).captured.single
                as List<mox.XMLNode>;

        final item = captured.single;
        expect(item.attributes[_jidAttr], equals(_inviteeJid));
        expect(
          item.attributes[_affiliationAttr],
          equals(OccupantAffiliation.member.xmlValue),
        );
        verify(() => mockConnection.sendMessage(any())).called(1);
      },
    );

    test(
      'DINV-012 [HP] inviteUserToRoom normalizes invitee JIDs to bare form',
      () async {
        const inviteeFullJid = 'friend@axi.im/phone';
        final info = MockRoomInformation();
        when(
          () => info.features,
        ).thenReturn(const <String>[_mucDiscoFeature, _mucMembersOnlyFeature]);
        when(() => mucManager.queryRoomInformation(any())).thenAnswer(
          (_) async => moxlib.Result<mox.RoomInformation, mox.MUCError>(info),
        );
        when(
          () => mucManager.sendAdminIq(
            roomJid: any(named: 'roomJid'),
            items: any(named: 'items'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => _memberAffiliationQueryResult(_inviteeJid));
        when(() => mockConnection.generateId()).thenReturn(_stanzaId);
        when(
          () => mockDatabase.saveMessage(
            any(),
            chatType: any(named: 'chatType'),
            selfJid: any(named: 'selfJid'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => true);

        await xmppService.inviteUserToRoom(
          roomJid: _roomJid,
          inviteeJid: inviteeFullJid,
          reason: _inviteReasonRaw,
        );

        final capturedAdminItems =
            verify(
                  () => mucManager.sendAdminIq(
                    roomJid: _roomJid,
                    items: captureAny(named: 'items'),
                  ),
                ).captured.single
                as List<mox.XMLNode>;
        final capturedMessage =
            verify(
                  () => mockConnection.sendMessage(captureAny()),
                ).captured.single
                as mox.MessageEvent;
        final axiInvite = capturedMessage.get<AxiMucInvitePayload>();

        expect(capturedAdminItems.single.attributes[_jidAttr], _inviteeJid);
        expect(capturedMessage.to.toBare().toString(), _inviteeJid);
        expect(axiInvite?.invitee, _inviteeJid);
      },
    );

    test(
      'DINV-013 [HP] acceptRoomInvite retries when only a cached self occupant exists',
      () async {
        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: _roomJidWithSelfNick,
          nick: 'me',
          realJid: _accountBareJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: false,
        );
        when(() => mockDatabase.createChat(any())).thenAnswer((_) async {});
        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => mox.Stanza.iq(type: _iqTypeResult));
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer((_) async {
          eventStreamController.add(
            MucSelfPresenceEvent(
              roomJid: _roomJid,
              occupantJid: _roomJidWithSelfNick,
              nick: 'me',
              affiliation: OccupantAffiliation.member.xmlValue,
              role: OccupantRole.participant.xmlValue,
              isAvailable: true,
              isError: false,
              isNickChange: false,
              statusCodes: {MucStatusCode.selfPresence.code},
            ),
          );
          return const moxlib.Result<bool, mox.MUCError>(_presenceAvailable);
        });

        await xmppService.acceptRoomInvite(
          roomJid: _roomJid,
          roomName: _roomName,
          nickname: 'me',
        );

        verify(
          () => mucManager.joinRoom(
            mox.JID.fromString(_roomJidBare),
            'me',
            maxHistoryStanzas: _defaultHistoryStanzas,
          ),
        ).called(1);
      },
    );

    test(
      'DINV-014 [HP] inviteUserToRoom grants membership when local owner state is known even without disco members-only support',
      () async {
        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: _roomJidWithSelfNick,
          nick: 'me',
          realJid: _accountBareJid,
          affiliation: OccupantAffiliation.owner,
          role: OccupantRole.moderator,
        );
        when(() => mucManager.queryRoomInformation(any())).thenAnswer(
          (_) async =>
              moxlib.Result<mox.RoomInformation, mox.MUCError>(FakeMucError()),
        );
        when(
          () => mucManager.sendAdminIq(
            roomJid: any(named: 'roomJid'),
            items: any(named: 'items'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => _memberAffiliationQueryResult(_inviteeJid));
        when(() => mockConnection.generateId()).thenReturn(_stanzaId);
        when(
          () => mockDatabase.saveMessage(
            any(),
            chatType: any(named: 'chatType'),
            selfJid: any(named: 'selfJid'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => true);

        await xmppService.inviteUserToRoom(
          roomJid: _roomJid,
          inviteeJid: _inviteeJid,
          reason: _inviteReasonRaw,
        );

        verify(
          () => mucManager.sendAdminIq(
            roomJid: _roomJid,
            items: any(named: 'items'),
          ),
        ).called(1);
      },
    );

    test(
      'DINV-015 [HP] inviteUserToRoom fails before inviting when membership is not visible on the server',
      () async {
        final info = MockRoomInformation();
        when(
          () => info.features,
        ).thenReturn(const <String>[_mucDiscoFeature, _mucMembersOnlyFeature]);
        when(() => mucManager.queryRoomInformation(any())).thenAnswer(
          (_) async => moxlib.Result<mox.RoomInformation, mox.MUCError>(info),
        );
        when(
          () => mucManager.sendAdminIq(
            roomJid: any(named: 'roomJid'),
            items: any(named: 'items'),
          ),
        ).thenAnswer((_) async {});
        when(() => mockConnection.sendStanza(any())).thenAnswer((_) async {
          final query = mox.XMLNode.xmlns(
            tag: _queryTag,
            xmlns: _mucAdminXmlns,
            children: const <mox.XMLNode>[],
          );
          return mox.Stanza.iq(type: _iqTypeResult, children: [query]);
        });

        await expectLater(
          () => xmppService.inviteUserToRoom(
            roomJid: _roomJid,
            inviteeJid: _inviteeJid,
            reason: _inviteReasonRaw,
          ),
          throwsA(isA<XmppMessageException>()),
        );

        verifyNever(() => mockConnection.sendMessage(any()));
      },
    );
  });

  group('Roster updates', () {
    test(
      'PRES-001 [HP] updateOccupantFromPresence inserts a roster entry',
      () async {
        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: _roomJidWithNick,
          nick: _roomNick,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: _presenceAvailable,
        );

        final room = xmppService.roomStateFor(_roomJid);
        expect(room, isNotNull);
        expect(
          room?.occupants[_roomJidWithNick]?.nick,
          equals(_roomNickTrimmed),
        );
        expect(
          room?.occupants[_roomJidWithNick]?.affiliation,
          equals(OccupantAffiliation.member),
        );
        expect(
          room?.occupants[_roomJidWithNick]?.role,
          equals(OccupantRole.participant),
        );
      },
    );

    test(
      'PRES-001A [HP] jid-less updates do not reuse stale real jids from offline rows',
      () async {
        const occupantId = '$_roomJidBare/Coffee';
        const staleRealJid = 'alice@axi.im';

        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: occupantId,
          nick: 'Coffee',
          realJid: staleRealJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: false,
        );

        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: occupantId,
          nick: 'Coffee',
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
        );

        final room = xmppService.roomStateFor(_roomJid);
        expect(room?.occupants[occupantId]?.realJid, isNull);

        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: occupantId,
          nick: 'Coffee',
          realJid: _inviteeJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
        );

        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: occupantId,
          nick: 'Coffee',
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.moderator,
          isPresent: true,
        );

        final updatedRoom = xmppService.roomStateFor(_roomJid);
        expect(updatedRoom?.occupants[occupantId]?.realJid, _inviteeJid);
        expect(
          updatedRoom?.occupants[occupantId]?.role,
          OccupantRole.moderator,
        );
      },
    );

    test('PRES-002 [HP] removeOccupant deletes a roster entry', () async {
      xmppService.updateOccupantFromPresence(
        roomJid: _roomJid,
        occupantId: _roomJidWithNick,
        nick: _roomNick,
        realJid: _accountBareJid,
      );

      xmppService.removeOccupant(
        roomJid: _roomJid,
        occupantId: _roomJidWithNick,
      );

      final room = xmppService.roomStateFor(_roomJid);
      expect(room?.occupants.containsKey(_roomJidWithNick), isFalse);
    });

    test(
      'PRES-002A [HP] removeOccupant clears myOccupantJid for self rows',
      () async {
        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: _roomJidWithSelfNick,
          nick: _roomNick,
          realJid: _accountBareJid,
        );

        xmppService.removeOccupant(
          roomJid: _roomJid,
          occupantId: _roomJidWithSelfNick,
        );

        final room = xmppService.roomStateFor(_roomJid);
        expect(room?.myOccupantJid, isNull);
        expect(room?.occupants.containsKey(_roomJidWithSelfNick), isFalse);
      },
    );

    test('PRES-003 [EC] removing unknown occupants is safe', () async {
      xmppService.removeOccupant(
        roomJid: _roomJid,
        occupantId: _roomJidWithNick,
      );

      final room = xmppService.roomStateFor(_roomJid);
      expect(room, isNull);
    });
  });

  group('Affiliations', () {
    test(
      'REG-007 [HP] fetchRoomAffiliations updates matching occupants',
      () async {
        const occupantId = '$_roomJidBare/$_roomNickTrimmed';
        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: occupantId,
          nick: _roomNick,
          realJid: _accountBareJid,
        );

        final item = mox.XMLNode(
          tag: _itemTag,
          attributes: {
            _affiliationAttr: OccupantAffiliation.member.xmlValue,
            _roleAttr: OccupantRole.moderator.xmlValue,
            _jidAttr: _accountBareJid,
            _nickAttr: _roomNick,
          },
          children: [mox.XMLNode(tag: _reasonTag, text: _inviteReasonTrimmed)],
        );
        final query = mox.XMLNode.xmlns(
          tag: _queryTag,
          xmlns: _mucAdminXmlns,
          children: [item],
        );
        final response = mox.Stanza.iq(type: _iqTypeResult, children: [query]);

        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => response);

        final entries = await xmppService.fetchRoomAffiliations(
          roomJid: _roomJid,
          affiliation: OccupantAffiliation.member,
        );

        expect(entries, hasLength(_singleItemCount));
        expect(entries.single.affiliation, equals(OccupantAffiliation.member));
        expect(entries.single.role, equals(OccupantRole.moderator));

        final room = xmppService.roomStateFor(_roomJid);
        expect(
          room?.occupants[occupantId]?.affiliation,
          equals(OccupantAffiliation.member),
        );
        expect(
          room?.occupants[occupantId]?.role,
          equals(OccupantRole.moderator),
        );
      },
    );

    test(
      'REG-008 [HP] owner affiliation queries use the admin namespace',
      () async {
        mox.StanzaDetails? capturedDetails;
        final query = mox.XMLNode.xmlns(
          tag: _queryTag,
          xmlns: _mucAdminXmlns,
          children: const [],
        );
        final response = mox.Stanza.iq(type: _iqTypeResult, children: [query]);

        when(() => mockConnection.sendStanza(any())).thenAnswer((
          invocation,
        ) async {
          capturedDetails =
              invocation.positionalArguments.first as mox.StanzaDetails;
          return response;
        });

        await xmppService.fetchRoomOwners(roomJid: _roomJid);

        final stanza = capturedDetails?.stanza;
        expect(stanza, isNotNull);
        expect(stanza!.firstTag(_queryTag, xmlns: _mucAdminXmlns), isNotNull);
        expect(stanza.firstTag(_queryTag, xmlns: _mucOwnerXmlns), isNull);
      },
    );

    test(
      'REG-009 [HP] fetchRoomAffiliations keeps jid-only offline members',
      () async {
        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: _roomJidWithSelfNick,
          nick: 'me',
          realJid: _accountBareJid,
          affiliation: OccupantAffiliation.owner,
          role: OccupantRole.moderator,
        );

        final query = mox.XMLNode.xmlns(
          tag: _queryTag,
          xmlns: _mucAdminXmlns,
          children: [
            mox.XMLNode(
              tag: _itemTag,
              attributes: {
                _jidAttr: _inviteeJid,
                _affiliationAttr: OccupantAffiliation.member.xmlValue,
              },
            ),
          ],
        );
        final response = mox.Stanza.iq(type: _iqTypeResult, children: [query]);

        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => response);

        await xmppService.fetchRoomAffiliations(
          roomJid: _roomJid,
          affiliation: OccupantAffiliation.member,
        );

        final room = xmppService.roomStateFor(_roomJid);
        final offlineMember = room?.occupants.values.singleWhere(
          (occupant) => occupant.realJid == _inviteeJid,
        );

        expect(offlineMember, isNotNull);
        expect(offlineMember?.nick, equals(_inviteeJid));
        expect(offlineMember?.affiliation, OccupantAffiliation.member);
        expect(offlineMember?.isPresent, isFalse);
      },
    );

    test(
      'REG-009A [HP] fetchRoomAffiliations keeps jid-only entries separate from live occupants',
      () async {
        const occupantId = '$_roomJidBare/friend';
        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: occupantId,
          nick: 'friend',
          affiliation: OccupantAffiliation.none,
          role: OccupantRole.participant,
          isPresent: _presenceAvailable,
        );

        final query = mox.XMLNode.xmlns(
          tag: _queryTag,
          xmlns: _mucAdminXmlns,
          children: [
            mox.XMLNode(
              tag: _itemTag,
              attributes: {
                _jidAttr: _inviteeJid,
                _affiliationAttr: OccupantAffiliation.member.xmlValue,
              },
            ),
          ],
        );
        final response = mox.Stanza.iq(type: _iqTypeResult, children: [query]);

        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => response);

        await xmppService.fetchRoomAffiliations(
          roomJid: _roomJid,
          affiliation: OccupantAffiliation.member,
        );

        final room = xmppService.roomStateFor(_roomJid);
        final liveOccupant = room?.occupants[occupantId];
        final offlineMember = room?.occupants.values.singleWhere(
          (occupant) => occupant.realJid == _inviteeJid,
        );

        expect(liveOccupant, isNotNull);
        expect(liveOccupant?.realJid, isNull);
        expect(liveOccupant?.affiliation, OccupantAffiliation.none);
        expect(offlineMember, isNotNull);
        expect(offlineMember?.occupantId, isNot(occupantId));
        expect(offlineMember?.affiliation, OccupantAffiliation.member);
        expect(offlineMember?.isPresent, isFalse);
      },
    );

    test(
      'REG-009B [HP] presence hydrates live occupants and absorbs matching synthetic affiliation rows',
      () async {
        const occupantId = '$_roomJidBare/Coffee';
        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: occupantId,
          nick: 'Coffee',
          affiliation: OccupantAffiliation.none,
          role: OccupantRole.participant,
          isPresent: _presenceAvailable,
        );

        final query = mox.XMLNode.xmlns(
          tag: _queryTag,
          xmlns: _mucAdminXmlns,
          children: [
            mox.XMLNode(
              tag: _itemTag,
              attributes: {
                _jidAttr: _inviteeJid,
                _affiliationAttr: OccupantAffiliation.member.xmlValue,
              },
            ),
          ],
        );
        final response = mox.Stanza.iq(type: _iqTypeResult, children: [query]);

        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => response);

        await xmppService.fetchRoomAffiliations(
          roomJid: _roomJid,
          affiliation: OccupantAffiliation.member,
        );

        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: occupantId,
          nick: 'Coffee',
          realJid: _inviteeJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: _presenceAvailable,
        );

        final room = xmppService.roomStateFor(_roomJid);
        final matchingOccupants =
            room?.occupants.values
                .where((occupant) => occupant.realJid == _inviteeJid)
                .toList(growable: false) ??
            const <Occupant>[];

        expect(matchingOccupants, hasLength(1));
        expect(matchingOccupants.single.occupantId, occupantId);
        expect(
          matchingOccupants.single.affiliation,
          OccupantAffiliation.member,
        );
        expect(matchingOccupants.single.isPresent, isTrue);
      },
    );

    test(
      'REG-010 [HP] fetchRoomAffiliations merges jid-and-nick entries into matching live occupants',
      () async {
        const customRoomNick = 'Coffee';
        const occupantId = '$_roomJidBare/Coffee';
        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: occupantId,
          nick: customRoomNick,
          affiliation: OccupantAffiliation.none,
          role: OccupantRole.participant,
          isPresent: _presenceAvailable,
        );

        final query = mox.XMLNode.xmlns(
          tag: _queryTag,
          xmlns: _mucAdminXmlns,
          children: [
            mox.XMLNode(
              tag: _itemTag,
              attributes: {
                _jidAttr: _inviteeJid,
                _nickAttr: customRoomNick,
                _affiliationAttr: OccupantAffiliation.member.xmlValue,
              },
            ),
          ],
        );
        final response = mox.Stanza.iq(type: _iqTypeResult, children: [query]);

        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => response);

        await xmppService.fetchRoomAffiliations(
          roomJid: _roomJid,
          affiliation: OccupantAffiliation.member,
        );

        final room = xmppService.roomStateFor(_roomJid);
        final liveOccupant = room?.occupants[occupantId];
        final memberMatches =
            room?.occupants.values
                .where((occupant) => occupant.realJid == _inviteeJid)
                .toList(growable: false) ??
            const <Occupant>[];

        expect(liveOccupant, isNotNull);
        expect(liveOccupant?.affiliation, OccupantAffiliation.member);
        expect(liveOccupant?.realJid, _inviteeJid);
        expect(memberMatches, hasLength(1));
        expect(memberMatches.single.occupantId, occupantId);
      },
    );

    test(
      'REG-010A [HP] fetchRoomAffiliations does not reuse synthetic same-nick rows for a different jid',
      () async {
        const customRoomNick = 'Coffee';
        const liveOccupantId = '$_roomJidBare/Coffee';
        const staleRealJid = 'alice@axi.im';
        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: '$_roomJidBare/bootstrap',
          nick: 'bootstrap',
          isPresent: _presenceAvailable,
        );
        final staleQuery = mox.XMLNode.xmlns(
          tag: _queryTag,
          xmlns: _mucAdminXmlns,
          children: [
            mox.XMLNode(
              tag: _itemTag,
              attributes: {
                _jidAttr: staleRealJid,
                _nickAttr: customRoomNick,
                _affiliationAttr: OccupantAffiliation.member.xmlValue,
              },
            ),
          ],
        );
        when(() => mockConnection.sendStanza(any())).thenAnswer(
          (_) async =>
              mox.Stanza.iq(type: _iqTypeResult, children: [staleQuery]),
        );

        await xmppService.fetchRoomAffiliations(
          roomJid: _roomJid,
          affiliation: OccupantAffiliation.member,
        );

        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: liveOccupantId,
          nick: customRoomNick,
          affiliation: OccupantAffiliation.none,
          role: OccupantRole.participant,
          isPresent: _presenceAvailable,
        );

        final query = mox.XMLNode.xmlns(
          tag: _queryTag,
          xmlns: _mucAdminXmlns,
          children: [
            mox.XMLNode(
              tag: _itemTag,
              attributes: {
                _jidAttr: _inviteeJid,
                _nickAttr: customRoomNick,
                _affiliationAttr: OccupantAffiliation.member.xmlValue,
              },
            ),
          ],
        );
        final response = mox.Stanza.iq(type: _iqTypeResult, children: [query]);

        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => response);

        await xmppService.fetchRoomAffiliations(
          roomJid: _roomJid,
          affiliation: OccupantAffiliation.member,
        );

        final room = xmppService.roomStateFor(_roomJid);
        final liveOccupant = room?.occupants[liveOccupantId];
        final staleOccupant = room?.occupants.values.where(
          (occupant) => occupant.realJid == staleRealJid,
        );
        final inviteeMatches =
            room?.occupants.values
                .where((occupant) => occupant.realJid == _inviteeJid)
                .toList(growable: false) ??
            const <Occupant>[];

        expect(liveOccupant, isNotNull);
        expect(liveOccupant?.realJid, _inviteeJid);
        expect(staleOccupant, isEmpty);
        expect(inviteeMatches, hasLength(1));
        expect(inviteeMatches.single.occupantId, liveOccupantId);
      },
    );

    test(
      'REG-011 [HP] warmRoomFromHistory restores persisted offline owners for later member list use',
      () async {
        final stateEntries = <String, Object?>{};
        when(() => mockStateStore.read(key: any(named: 'key'))).thenAnswer((
          invocation,
        ) {
          final key = invocation.namedArguments[#key] as RegisteredStateKey;
          return stateEntries[key.value];
        });
        when(
          () => mockStateStore.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((invocation) async {
          final key = invocation.namedArguments[#key] as RegisteredStateKey;
          stateEntries[key.value] = invocation.namedArguments[#value];
          return true;
        });
        when(() => mockStateStore.delete(key: any(named: 'key'))).thenAnswer((
          invocation,
        ) async {
          final key = invocation.namedArguments[#key] as RegisteredStateKey;
          stateEntries.remove(key.value);
          return true;
        });

        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: 'opaque-owner-id',
          nick: 'OwnerNick',
          realJid: 'owner@axi.im',
          affiliation: OccupantAffiliation.owner,
          role: OccupantRole.moderator,
          isPresent: _presenceAvailable,
          fromPresence: true,
        );
        await pumpEventQueue();
        await pumpEventQueue();

        await xmppService.close();

        xmppService = XmppService(
          buildConnection: () => mockConnection,
          buildStateStore: (_, _) => mockStateStore,
          buildDatabase: (_, _) => mockDatabase,
          notificationService: mockNotificationService,
        );
        await connectSuccessfully(xmppService);
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(_connectedState, _disconnectedState),
        );
        await pumpEventQueue();

        when(
          () => mockDatabase.getChatMessages(
            _roomJid,
            start: any(named: 'start'),
            end: any(named: 'end'),
            filter: any(named: 'filter'),
          ),
        ).thenAnswer(
          (_) async => <Message>[
            Message(
              stanzaID: 'owner-history-message',
              senderJid: '$_roomJid/OwnerNick',
              chatJid: _roomJid,
              timestamp: DateTime.timestamp(),
              body: 'hello from the owner',
            ),
          ],
        );

        final room = await xmppService.warmRoomFromHistory(roomJid: _roomJid);
        final owner = room.owners.single;

        expect(owner.nick, 'OwnerNick');
        expect(owner.realJid, 'owner@axi.im');
        expect(owner.affiliation, OccupantAffiliation.owner);
        expect(owner.isPresent, isFalse);
      },
    );

    test(
      'REG-012 [HP] warmRoomFromHistory restores opaque occupant ids for bare-room history senders',
      () async {
        final stateEntries = <String, Object?>{};
        when(() => mockStateStore.read(key: any(named: 'key'))).thenAnswer((
          invocation,
        ) {
          final key = invocation.namedArguments[#key] as RegisteredStateKey;
          return stateEntries[key.value];
        });
        when(
          () => mockStateStore.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((invocation) async {
          final key = invocation.namedArguments[#key] as RegisteredStateKey;
          stateEntries[key.value] = invocation.namedArguments[#value];
          return true;
        });
        when(() => mockStateStore.delete(key: any(named: 'key'))).thenAnswer((
          invocation,
        ) async {
          final key = invocation.namedArguments[#key] as RegisteredStateKey;
          stateEntries.remove(key.value);
          return true;
        });

        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: 'opaque-owner-id',
          nick: 'OwnerNick',
          realJid: 'owner@axi.im',
          affiliation: OccupantAffiliation.owner,
          role: OccupantRole.moderator,
          isPresent: _presenceAvailable,
          fromPresence: true,
        );
        await pumpEventQueue();
        await pumpEventQueue();

        await xmppService.close();

        xmppService = XmppService(
          buildConnection: () => mockConnection,
          buildStateStore: (_, _) => mockStateStore,
          buildDatabase: (_, _) => mockDatabase,
          notificationService: mockNotificationService,
        );
        await connectSuccessfully(xmppService);
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(_connectedState, _disconnectedState),
        );
        await pumpEventQueue();

        when(
          () => mockDatabase.getChatMessages(
            _roomJid,
            start: any(named: 'start'),
            end: any(named: 'end'),
            filter: any(named: 'filter'),
          ),
        ).thenAnswer(
          (_) async => <Message>[
            Message(
              stanzaID: 'owner-history-message',
              senderJid: _roomJid,
              occupantID: 'opaque-owner-id',
              chatJid: _roomJid,
              timestamp: DateTime.timestamp(),
              body: 'hello from the owner',
            ),
          ],
        );

        final room = await xmppService.warmRoomFromHistory(roomJid: _roomJid);
        final owner = room.occupants['opaque-owner-id'];

        expect(owner, isNotNull);
        expect(owner?.nick, 'OwnerNick');
        expect(owner?.realJid, 'owner@axi.im');
        expect(owner?.affiliation, OccupantAffiliation.owner);
        expect(room.occupants.containsKey('$_roomJid/OwnerNick'), isFalse);
      },
    );
  });

  group('Moderation actions', () {
    test('MOD-001 [HP] kickOccupant sends role=none admin IQ', () async {
      when(
        () => mucManager.sendAdminIq(
          roomJid: any(named: 'roomJid'),
          items: any(named: 'items'),
        ),
      ).thenAnswer((_) async {});

      await xmppService.kickOccupant(
        roomJid: _roomJid,
        nick: _roomNick,
        reason: _inviteReasonRaw,
      );

      final captured =
          verify(
                () => mucManager.sendAdminIq(
                  roomJid: _roomJid,
                  items: captureAny(named: 'items'),
                ),
              ).captured.single
              as List<mox.XMLNode>;

      final item = captured.single;
      expect(item.attributes[_nickAttr], equals(_roomNickTrimmed));
      expect(item.attributes[_roleAttr], equals(OccupantRole.none.xmlValue));
      expect(item.firstTag(_reasonTag)?.innerText(), equals(_inviteReasonRaw));
    });

    test(
      'ADM-001 [HP] banOccupant sends affiliation=outcast admin IQ',
      () async {
        when(
          () => mucManager.sendAdminIq(
            roomJid: any(named: 'roomJid'),
            items: any(named: 'items'),
          ),
        ).thenAnswer((_) async {});

        await xmppService.banOccupant(
          roomJid: _roomJid,
          jid: _inviteeJid,
          reason: _inviteReasonRaw,
        );

        final captured =
            verify(
                  () => mucManager.sendAdminIq(
                    roomJid: _roomJid,
                    items: captureAny(named: 'items'),
                  ),
                ).captured.single
                as List<mox.XMLNode>;

        final item = captured.single;
        expect(item.attributes[_jidAttr], equals(_inviteeJid));
        expect(
          item.attributes[_affiliationAttr],
          equals(OccupantAffiliation.outcast.xmlValue),
        );
        expect(
          item.firstTag(_reasonTag)?.innerText(),
          equals(_inviteReasonRaw),
        );
      },
    );

    test('MOD-010 [HP] changeRole sends role updates via admin IQ', () async {
      when(
        () => mucManager.sendAdminIq(
          roomJid: any(named: 'roomJid'),
          items: any(named: 'items'),
        ),
      ).thenAnswer((_) async {});

      await xmppService.changeRole(
        roomJid: _roomJid,
        nick: _roomNick,
        role: OccupantRole.moderator,
      );

      final captured =
          verify(
                () => mucManager.sendAdminIq(
                  roomJid: _roomJid,
                  items: captureAny(named: 'items'),
                ),
              ).captured.single
              as List<mox.XMLNode>;

      final item = captured.single;
      expect(item.attributes[_nickAttr], equals(_roomNickTrimmed));
      expect(
        item.attributes[_roleAttr],
        equals(OccupantRole.moderator.xmlValue),
      );
    });

    test(
      'ADM-010 [HP] changeAffiliation sends affiliation updates via admin IQ',
      () async {
        when(
          () => mucManager.sendAdminIq(
            roomJid: any(named: 'roomJid'),
            items: any(named: 'items'),
          ),
        ).thenAnswer((_) async {});

        await xmppService.changeAffiliation(
          roomJid: _roomJid,
          jid: _inviteeJid,
          affiliation: OccupantAffiliation.member,
        );

        final captured =
            verify(
                  () => mucManager.sendAdminIq(
                    roomJid: _roomJid,
                    items: captureAny(named: 'items'),
                  ),
                ).captured.single
                as List<mox.XMLNode>;

        final item = captured.single;
        expect(item.attributes[_jidAttr], equals(_inviteeJid));
        expect(
          item.attributes[_affiliationAttr],
          equals(OccupantAffiliation.member.xmlValue),
        );
      },
    );
  });

  group('Leave and cleanup', () {
    test(
      'PRES-010 [HP] leaveRoom clears state and forgets passwords',
      () async {
        when(() => mucManager.leaveRoom(any())).thenAnswer(
          (_) async => const moxlib.Result<bool, mox.MUCError>(true),
        );
        joinBootstrapManager.rememberPassword(
          roomJid: _roomJid,
          password: _invitePasswordRaw,
        );

        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: _roomJidWithSelfNick,
          nick: _roomNick,
          realJid: _accountBareJid,
        );

        await xmppService.leaveRoom(_roomJid);

        expect(joinBootstrapManager.passwordForRoom(_roomJid), isNull);
        final room = xmppService.roomStateFor(_roomJid);
        expect(room?.occupants, isEmpty);
        expect(room?.myOccupantJid, isNull);
      },
    );

    test(
      'PRES-011 [HP] acceptRoomInvite rejects stale invites that create a new room',
      () async {
        when(
          () => mucManager.sendOwnerIq(
            roomJid: any(named: 'roomJid'),
            children: any(named: 'children'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer((_) async {
          eventStreamController.add(
            MucSelfPresenceEvent(
              roomJid: _roomJid,
              occupantJid: _roomJidWithSelfNick,
              nick: 'me',
              affiliation: OccupantAffiliation.owner.xmlValue,
              role: OccupantRole.moderator.xmlValue,
              isAvailable: true,
              isError: false,
              isNickChange: false,
              statusCodes: {
                MucStatusCode.selfPresence.code,
                MucStatusCode.roomCreated.code,
              },
            ),
          );
          return const moxlib.Result<bool, mox.MUCError>(_presenceAvailable);
        });

        await expectLater(
          () => xmppService.acceptRoomInvite(
            roomJid: _roomJid,
            roomName: _roomName,
            nickname: 'me',
          ),
          throwsA(isA<XmppMessageException>()),
        );

        verify(
          () => mucManager.sendOwnerIq(
            roomJid: _roomJid,
            children: any(named: 'children'),
          ),
        ).called(1);
        verifyNever(() => mockDatabase.createChat(any()));
      },
    );

    test(
      'PRES-012 [HP] destroyRoom sends an owner destroy IQ and archives the room locally',
      () async {
        final existingChat = Chat(
          jid: _roomJid,
          title: _roomName,
          type: ChatType.groupChat,
          myNickname: 'me',
          lastChangeTimestamp: _fixedTimestamp,
          contactJid: _roomJid,
          open: true,
        );
        when(
          () => mockDatabase.getChat(_roomJid),
        ).thenAnswer((_) async => existingChat);
        when(
          () => mucManager.sendOwnerIq(
            roomJid: any(named: 'roomJid'),
            children: any(named: 'children'),
          ),
        ).thenAnswer((_) async {});

        await xmppService.destroyRoom(
          roomJid: _roomJid,
          reason: _inviteReasonRaw,
        );

        final captured =
            verify(
                  () => mucManager.sendOwnerIq(
                    roomJid: _roomJid,
                    children: captureAny(named: 'children'),
                  ),
                ).captured.single
                as List<mox.XMLNode>;
        final updatedChat =
            verify(() => mockDatabase.updateChat(captureAny())).captured.single
                as Chat;

        expect(captured.single.tag, _destroyTag);
        expect(
          captured.single.firstTag(_reasonTag)?.innerText(),
          equals(_inviteReasonTrimmed),
        );
        expect(updatedChat.archived, isTrue);
        expect(updatedChat.open, isFalse);
        expect(xmppService.roomStateFor(_roomJid)?.roomDestroyed, isTrue);
      },
    );

    test(
      'PRES-012B [HP] destroyed self presence marks the room destroyed and archives it',
      () async {
        final existingChat = Chat(
          jid: _roomJid,
          title: _roomName,
          type: ChatType.groupChat,
          myNickname: 'me',
          lastChangeTimestamp: _fixedTimestamp,
          contactJid: _roomJid,
          open: true,
        );
        when(
          () => mockDatabase.getChat(_roomJid),
        ).thenAnswer((_) async => existingChat);

        eventStreamController.add(
          MucSelfPresenceEvent(
            roomJid: _roomJid,
            occupantJid: _roomJidWithSelfNick,
            nick: 'me',
            affiliation: OccupantAffiliation.owner.xmlValue,
            role: OccupantRole.moderator.xmlValue,
            isAvailable: false,
            isError: false,
            isNickChange: false,
            statusCodes: const <String>{},
            reason: _inviteReasonRaw,
            isRoomDestroyed: true,
            destroyAlternateRoomJid: 'other@conference.example',
          ),
        );
        await pumpEventQueue();

        final updatedChat =
            verify(() => mockDatabase.updateChat(captureAny())).captured.single
                as Chat;
        final room = xmppService.roomStateFor(_roomJid);

        expect(updatedChat.archived, isTrue);
        expect(updatedChat.open, isFalse);
        expect(room?.roomDestroyed, isTrue);
        expect(
          room?.destroyedAlternateRoomJid,
          equals('other@conference.example'),
        );
        expect(room?.selfPresenceReason, equals(_inviteReasonTrimmed));
      },
    );

    test('PRES-013 [HP] leaveRoom fails via the hard action timeout', () {
      when(() => mucManager.leaveRoom(any())).thenAnswer(
        (_) => Completer<moxlib.Result<bool, mox.MUCError>>().future,
      );

      fakeAsync((async) {
        Object? capturedError;
        xmppService
            .leaveRoom(_roomJid)
            .then<void>(
              (_) {},
              onError: (Object error, StackTrace _) {
                capturedError = error;
              },
            );

        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        expect(capturedError, isA<TimeoutException>());
      });
    });

    test('PRES-014 [HP] destroyRoom fails via the hard action timeout', () {
      when(
        () => mucManager.sendOwnerIq(
          roomJid: any(named: 'roomJid'),
          children: any(named: 'children'),
        ),
      ).thenAnswer((_) => Completer<void>().future);

      fakeAsync((async) {
        Object? capturedError;
        xmppService
            .destroyRoom(roomJid: _roomJid)
            .then<void>(
              (_) {},
              onError: (Object error, StackTrace _) {
                capturedError = error;
              },
            );

        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        expect(capturedError, isA<TimeoutException>());
      });
    });
  });

  group('Room status codes', () {
    test('STAT-002 [HP] roomCreated reflects status 201', () {
      final state = RoomState(
        roomJid: _roomJid,
        occupants: const {},
        selfPresenceStatusCodes: {MucStatusCode.roomCreated.code},
      );
      expect(state.roomCreated, isTrue);
    });

    test('STAT-003 [HP] nickAssigned reflects status 210', () {
      final state = RoomState(
        roomJid: _roomJid,
        occupants: const {},
        selfPresenceStatusCodes: {MucStatusCode.nickAssigned.code},
      );
      expect(state.nickAssigned, isTrue);
    });

    test('STAT-009 [HP] wasBanned reflects status 301', () {
      final state = RoomState(
        roomJid: _roomJid,
        occupants: const {},
        selfPresenceStatusCodes: {MucStatusCode.banned.code},
      );
      expect(state.wasBanned, isTrue);
    });

    test('STAT-010 [HP] wasKicked reflects status 307', () {
      final state = RoomState(
        roomJid: _roomJid,
        occupants: const {},
        selfPresenceStatusCodes: {MucStatusCode.kicked.code},
      );
      expect(state.wasKicked, isTrue);
    });

    test('STAT-013 [HP] roomShutdown reflects status 332', () {
      final state = RoomState(
        roomJid: _roomJid,
        occupants: const {},
        selfPresenceStatusCodes: {MucStatusCode.roomShutdown.code},
      );
      expect(state.roomShutdown, isTrue);
    });

    test('STAT-014 [HP] removedByAffiliationChange reflects status 321', () {
      final state = RoomState(
        roomJid: _roomJid,
        occupants: const {},
        selfPresenceStatusCodes: {
          MucStatusCode.removedByAffiliationChange.code,
        },
      );
      expect(state.removedByAffiliationChange, isTrue);
    });

    test('STAT-015 [HP] removedByMembersOnlyChange reflects status 322', () {
      final state = RoomState(
        roomJid: _roomJid,
        occupants: const {},
        selfPresenceStatusCodes: {
          MucStatusCode.removedByMembersOnlyChange.code,
        },
      );
      expect(state.removedByMembersOnlyChange, isTrue);
    });

    test('STAT-016 [HP] roomDestroyed reflects explicit destroy state', () {
      final state = RoomState(
        roomJid: _roomJid,
        occupants: const {},
        isDestroyed: true,
        destroyedAlternateRoomJid: 'other@conference.example',
      );
      expect(state.roomDestroyed, isTrue);
      expect(
        state.destroyedAlternateRoomJid,
        equals('other@conference.example'),
      );
    });

    test('STAT-014 [HP] terminal room states are not bootstrap pending', () {
      final shutdownState = RoomState(
        roomJid: _roomJid,
        occupants: const {},
        selfPresenceStatusCodes: {MucStatusCode.roomShutdown.code},
      );
      final destroyedState = RoomState(
        roomJid: _roomJid,
        occupants: const {},
        isDestroyed: true,
      );
      final affiliationRemovedState = RoomState(
        roomJid: _roomJid,
        occupants: const {},
        selfPresenceStatusCodes: {
          MucStatusCode.removedByAffiliationChange.code,
        },
      );
      final membersOnlyRemovedState = RoomState(
        roomJid: _roomJid,
        occupants: const {},
        selfPresenceStatusCodes: {
          MucStatusCode.removedByMembersOnlyChange.code,
        },
      );
      final kickedState = RoomState(
        roomJid: _roomJid,
        occupants: const {},
        selfPresenceStatusCodes: {MucStatusCode.kicked.code},
      );
      final bannedState = RoomState(
        roomJid: _roomJid,
        occupants: const {},
        selfPresenceStatusCodes: {MucStatusCode.banned.code},
      );

      expect(shutdownState.isBootstrapPending, isFalse);
      expect(destroyedState.isBootstrapPending, isFalse);
      expect(affiliationRemovedState.isBootstrapPending, isFalse);
      expect(membersOnlyRemovedState.isBootstrapPending, isFalse);
      expect(kickedState.isBootstrapPending, isFalse);
      expect(bannedState.isBootstrapPending, isFalse);
    });
  });
}
