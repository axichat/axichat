import 'dart:async';

import 'package:axichat/main.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;

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
const String _mucOwnerXmlns = 'http://jabber.org/protocol/muc#owner';
const String _mucAdminXmlns = 'http://jabber.org/protocol/muc#admin';
const String _dataFormXmlns = 'jabber:x:data';
const String _dataFormTag = 'x';
const String _queryTag = 'query';
const String _itemTag = 'item';
const String _jidAttr = 'jid';
const String _nickAttr = 'nick';
const String _roleAttr = 'role';
const String _affiliationAttr = 'affiliation';
const String _reasonTag = 'reason';
const String _subjectTag = 'subject';
const String _bodyTag = 'body';
const String _messageTag = 'message';
const String _xmlnsAttr = 'xmlns';
const String _typeAttr = 'type';
const String _toAttr = 'to';
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

class MockDiscoManager extends Mock implements mox.DiscoManager {}

class MockDiscoItem extends Mock implements mox.DiscoItem {}

class MockDiscoInfo extends Mock implements mox.DiscoInfo {}

class MockRoomInformation extends Mock implements mox.RoomInformation {}

class FakeStanzaError extends Fake implements mox.StanzaError {}

class FakeMucError extends Fake implements mox.MUCError {}

class FakeJid extends Fake implements mox.JID {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeUserAgent());
    registerFallbackValue(FakeStanzaDetails());
    registerFallbackValue(FakeMessageEvent());
    registerFallbackValue(FakeMessage());
    registerFallbackValue(FakeChat());
    registerFallbackValue(FakeJid());
    registerFallbackValue(_fallbackChatType);
    registerFallbackValue(_emptyXmlNodeList);
    registerOmemoFallbacks();
    resetForegroundNotifier(value: false);
  });

  late XmppService xmppService;
  late StreamController<mox.XmppEvent> eventStreamController;
  late MockMucManager mucManager;
  late MockDiscoManager discoManager;
  late MucJoinBootstrapManager joinBootstrapManager;

  setUp(() async {
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockDatabase = MockXmppDatabase();
    mockNotificationService = MockNotificationService();
    eventStreamController = StreamController<mox.XmppEvent>.broadcast();
    mucManager = MockMucManager();
    discoManager = MockDiscoManager();
    joinBootstrapManager = MucJoinBootstrapManager();

    prepareMockConnection();

    when(() => mockConnection.asBroadcastStream())
        .thenAnswer((_) => eventStreamController.stream);
    when(() => mockConnection.getManager<MUCManager>()).thenReturn(mucManager);
    when(() => mockConnection.getManager<mox.DiscoManager>())
        .thenReturn(discoManager);
    when(() => mockConnection.getManager<MucJoinBootstrapManager>())
        .thenReturn(joinBootstrapManager);
    when(() => mockConnection.sendStanza(any())).thenAnswer((_) async => null);
    when(() => mockDatabase.getChat(any())).thenAnswer((_) async => null);

    xmppService = XmppService(
      buildConnection: () => mockConnection,
      buildStateStore: (_, __) => mockStateStore,
      buildDatabase: (_, __) => mockDatabase,
      notificationService: mockNotificationService,
    );

    await connectSuccessfully(xmppService);
    eventStreamController.add(
      mox.ConnectionStateChangedEvent(
        _connectedState,
        _disconnectedState,
      ),
    );
    await pumpEventQueue();
  });

  tearDown(() async {
    await eventStreamController.close();
    await xmppService.close();
    resetMocktailState();
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
          (_) async => moxlib.Result<mox.StanzaError, List<mox.DiscoItem>>(
            [item],
          ),
        );
        when(() => discoManager.discoInfoQuery(any())).thenAnswer(
          (_) async => moxlib.Result<mox.StanzaError, mox.DiscoInfo>(info),
        );

        await xmppService.discoverMucServiceHost();

        expect(xmppService.mucServiceHost, equals(_serviceJid));
      },
    );

    test(
      'DISC-013 [UP] disco item errors fall back to domain info',
      () async {
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
      },
    );

    test(
      'DISC-011 [HP] discoverRooms returns room items',
      () async {
        final roomItem = MockDiscoItem();
        when(() => roomItem.jid).thenReturn(mox.JID.fromString(_roomJid));

        when(() => discoManager.discoItemsQuery(any())).thenAnswer(
          (_) async => moxlib.Result<mox.StanzaError, List<mox.DiscoItem>>(
            [roomItem],
          ),
        );

        final rooms = await xmppService.discoverRooms(serviceJid: _serviceJid);

        expect(rooms, hasLength(_singleItemCount));
        expect(rooms.single, equals(roomItem));
      },
    );

    test(
      'DISC-013 [UP] discoverRooms returns empty list on error',
      () async {
        when(() => discoManager.discoItemsQuery(any())).thenAnswer(
          (_) async => moxlib.Result<mox.StanzaError, List<mox.DiscoItem>>(
            FakeStanzaError(),
          ),
        );

        final rooms = await xmppService.discoverRooms(serviceJid: _serviceJid);

        expect(rooms, isEmpty);
      },
    );

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
    test(
      'OWN-010 [HP] fetchRoomConfigurationForm returns data form',
      () async {
        final form = mox.XMLNode.xmlns(
          tag: _dataFormTag,
          xmlns: _dataFormXmlns,
        );
        final query = mox.XMLNode.xmlns(
          tag: _queryTag,
          xmlns: _mucOwnerXmlns,
          children: [form],
        );
        final response = mox.Stanza.iq(
          type: _iqTypeResult,
          children: [query],
        );

        when(() => mockConnection.sendStanza(any()))
            .thenAnswer((_) async => response);

        final result = await xmppService.fetchRoomConfigurationForm(_roomJid);

        expect(result, isNotNull);
        expect(result?.tag, equals(_dataFormTag));
        expect(result?.attributes[_xmlnsAttr], equals(_dataFormXmlns));
      },
    );

    test(
      'OWN-011 [HP] submitRoomConfiguration returns true on result',
      () async {
        final form = mox.XMLNode.xmlns(
          tag: _dataFormTag,
          xmlns: _dataFormXmlns,
        );
        final response = mox.Stanza.iq(type: _iqTypeResult);

        when(() => mockConnection.sendStanza(any()))
            .thenAnswer((_) async => response);

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

        when(() => mockConnection.sendStanza(any()))
            .thenAnswer((_) async => response);

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
        when(() => mockConnection.sendStanza(any())).thenAnswer(
          (invocation) async {
            captured =
                invocation.positionalArguments.first as mox.StanzaDetails;
            return null;
          },
        );

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

    test(
      'SUBJ-003 [HP] subject events update room subject streams',
      () async {
        final stream = xmppService.roomSubjectStream(_roomJid);
        expectLater(
          stream,
          emitsInOrder([_subjectTrimmed]),
        );

        eventStreamController.add(
          MucSubjectChangedEvent(
            roomJid: _roomJid,
            subject: _subjectRaw,
          ),
        );

        await pumpEventQueue();
      },
    );

    test(
      'SUBJ-006 [EC] empty subject events clear the stored subject',
      () async {
        final stream = xmppService.roomSubjectStream(_roomJid);
        expectLater(
          stream,
          emitsInOrder([null]),
        );

        eventStreamController.add(
          MucSubjectChangedEvent(
            roomJid: _roomJid,
            subject: _subjectEmpty,
          ),
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
          (_) async => const moxlib.Result<bool, mox.MUCError>(
            _presenceAvailable,
          ),
        );

        await xmppService.joinRoom(
          roomJid: _roomJid,
          nickname: _roomNick,
        );

        verify(
          () => mucManager.joinRoom(
            mox.JID.fromString(_roomJidBare),
            _roomNick,
            maxHistoryStanzas: _defaultHistoryStanzas,
          ),
        ).called(1);
      },
    );

    test(
      'HIST-010 [HP] joinRoom forwards custom history maxstanzas',
      () async {
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer(
          (_) async => const moxlib.Result<bool, mox.MUCError>(
            _presenceAvailable,
          ),
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
      },
    );

    test(
      'JOIN-015 [EC] ensureJoined skips rejoin when already present',
      () async {
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer(
          (_) async => const moxlib.Result<bool, mox.MUCError>(
            _presenceAvailable,
          ),
        );

        xmppService.updateOccupantFromPresence(
          roomJid: _roomJid,
          occupantId: _roomJidWithSelfNick,
          nick: _roomNick,
          realJid: _accountBareJid,
          isPresent: _presenceAvailable,
        );

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

        when(() => mockDatabase.getChat(_roomJid))
            .thenAnswer((_) async => chat);
        when(() => mockDatabase.updateChat(any())).thenAnswer((_) async {});
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer(
          (_) async => const moxlib.Result<bool, mox.MUCError>(
            _presenceAvailable,
          ),
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
          ),
        ).thenAnswer((_) async {});
        when(() => mockConnection.sendMessage(any()))
            .thenAnswer((_) async => true);

        await xmppService.inviteUserToRoom(
          roomJid: _roomJid,
          inviteeJid: _inviteeJid,
          reason: _inviteReasonRaw,
          password: _invitePasswordRaw,
        );

        final captured = verify(() => mockConnection.sendMessage(captureAny()))
            .captured
            .single as mox.MessageEvent;
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
            room?.occupants[_roomJidWithNick]?.nick, equals(_roomNickTrimmed));
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
      'PRES-002 [HP] removeOccupant deletes a roster entry',
      () async {
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
      },
    );

    test(
      'PRES-003 [EC] removing unknown occupants is safe',
      () async {
        xmppService.removeOccupant(
          roomJid: _roomJid,
          occupantId: _roomJidWithNick,
        );

        final room = xmppService.roomStateFor(_roomJid);
        expect(room, isNull);
      },
    );
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
          children: [
            mox.XMLNode(tag: _reasonTag, text: _inviteReasonTrimmed),
          ],
        );
        final query = mox.XMLNode.xmlns(
          tag: _queryTag,
          xmlns: _mucAdminXmlns,
          children: [item],
        );
        final response = mox.Stanza.iq(
          type: _iqTypeResult,
          children: [query],
        );

        when(() => mockConnection.sendStanza(any()))
            .thenAnswer((_) async => response);

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
  });

  group('Moderation actions', () {
    test(
      'MOD-001 [HP] kickOccupant sends role=none admin IQ',
      () async {
        when(() => mucManager.sendAdminIq(
              roomJid: any(named: 'roomJid'),
              items: any(named: 'items'),
            )).thenAnswer((_) async {});

        await xmppService.kickOccupant(
          roomJid: _roomJid,
          nick: _roomNick,
          reason: _inviteReasonRaw,
        );

        final captured = verify(
          () => mucManager.sendAdminIq(
            roomJid: _roomJid,
            items: captureAny(named: 'items'),
          ),
        ).captured.single as List<mox.XMLNode>;

        final item = captured.single;
        expect(item.attributes[_nickAttr], equals(_roomNickTrimmed));
        expect(
          item.attributes[_roleAttr],
          equals(OccupantRole.none.xmlValue),
        );
        expect(
          item.firstTag(_reasonTag)?.innerText(),
          equals(_inviteReasonRaw),
        );
      },
    );

    test(
      'ADM-001 [HP] banOccupant sends affiliation=outcast admin IQ',
      () async {
        when(() => mucManager.sendAdminIq(
              roomJid: any(named: 'roomJid'),
              items: any(named: 'items'),
            )).thenAnswer((_) async {});

        await xmppService.banOccupant(
          roomJid: _roomJid,
          jid: _inviteeJid,
          reason: _inviteReasonRaw,
        );

        final captured = verify(
          () => mucManager.sendAdminIq(
            roomJid: _roomJid,
            items: captureAny(named: 'items'),
          ),
        ).captured.single as List<mox.XMLNode>;

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

    test(
      'MOD-010 [HP] changeRole sends role updates via admin IQ',
      () async {
        when(() => mucManager.sendAdminIq(
              roomJid: any(named: 'roomJid'),
              items: any(named: 'items'),
            )).thenAnswer((_) async {});

        await xmppService.changeRole(
          roomJid: _roomJid,
          nick: _roomNick,
          role: OccupantRole.moderator,
        );

        final captured = verify(
          () => mucManager.sendAdminIq(
            roomJid: _roomJid,
            items: captureAny(named: 'items'),
          ),
        ).captured.single as List<mox.XMLNode>;

        final item = captured.single;
        expect(item.attributes[_nickAttr], equals(_roomNickTrimmed));
        expect(
          item.attributes[_roleAttr],
          equals(OccupantRole.moderator.xmlValue),
        );
      },
    );

    test(
      'ADM-010 [HP] changeAffiliation sends affiliation updates via admin IQ',
      () async {
        when(() => mucManager.sendAdminIq(
              roomJid: any(named: 'roomJid'),
              items: any(named: 'items'),
            )).thenAnswer((_) async {});

        await xmppService.changeAffiliation(
          roomJid: _roomJid,
          jid: _inviteeJid,
          affiliation: OccupantAffiliation.member,
        );

        final captured = verify(
          () => mucManager.sendAdminIq(
            roomJid: _roomJid,
            items: captureAny(named: 'items'),
          ),
        ).captured.single as List<mox.XMLNode>;

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
        expect(room?.myOccupantId, isNull);
      },
    );
  });

  group('Room status codes', () {
    test(
      'STAT-002 [HP] roomCreated reflects status 201',
      () {
        final state = RoomState(
          roomJid: _roomJid,
          occupants: const {},
          selfPresenceStatusCodes: {mucStatusRoomCreated},
        );
        expect(state.roomCreated, isTrue);
      },
    );

    test(
      'STAT-003 [HP] nickAssigned reflects status 210',
      () {
        final state = RoomState(
          roomJid: _roomJid,
          occupants: const {},
          selfPresenceStatusCodes: {mucStatusNickAssigned},
        );
        expect(state.nickAssigned, isTrue);
      },
    );

    test(
      'STAT-009 [HP] wasBanned reflects status 301',
      () {
        final state = RoomState(
          roomJid: _roomJid,
          occupants: const {},
          selfPresenceStatusCodes: {mucStatusBanned},
        );
        expect(state.wasBanned, isTrue);
      },
    );

    test(
      'STAT-010 [HP] wasKicked reflects status 307',
      () {
        final state = RoomState(
          roomJid: _roomJid,
          occupants: const {},
          selfPresenceStatusCodes: {mucStatusKicked},
        );
        expect(state.wasKicked, isTrue);
      },
    );

    test(
      'STAT-013 [HP] roomShutdown reflects status 332',
      () {
        final state = RoomState(
          roomJid: _roomJid,
          occupants: const {},
          selfPresenceStatusCodes: {mucStatusRoomShutdown},
        );
        expect(state.roomShutdown, isTrue);
      },
    );
  });
}
