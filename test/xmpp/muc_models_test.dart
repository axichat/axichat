import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';

const String _roomJid = 'room@conference.example.com';
const String _roomNickOccupantId = 'room@conference.example.com/nick';
const String _syntheticOccupantId =
    'room@conference.example.com/~user@example.com';
const String _realJid = 'user@example.com';

void main() {
  group('Occupant merge helpers', () {
    test(
      'nextRealJid prefers incoming, then present current, then fallback',
      () {
        final present = Occupant(
          occupantId: '$_roomJid/present',
          nick: 'present',
          realJid: 'present@example.com',
          isPresent: true,
        );
        final offline = Occupant(
          occupantId: '$_roomJid/offline',
          nick: 'offline',
          realJid: 'offline@example.com',
          isPresent: false,
        );
        final fallback = Occupant(
          occupantId: _syntheticOccupantId,
          nick: 'fallback',
          realJid: _realJid,
          isPresent: false,
        );

        expect(
          present.nextRealJid('incoming@example.com', fallback: fallback),
          'incoming@example.com',
        );
        expect(
          present.nextRealJid(null, fallback: fallback),
          'present@example.com',
        );
        expect(offline.nextRealJid(null, fallback: fallback), _realJid);
      },
    );

    test('nextAffiliation and nextRole preserve resolved membership state', () {
      final unresolved = Occupant(
        occupantId: _roomNickOccupantId,
        nick: 'nick',
        affiliation: OccupantAffiliation.none,
        role: OccupantRole.none,
      );
      final fallback = Occupant(
        occupantId: _syntheticOccupantId,
        nick: 'nick',
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.participant,
      );

      expect(
        unresolved.nextAffiliation(null, fallback: fallback),
        OccupantAffiliation.member,
      );
      expect(
        unresolved.nextAffiliation(
          OccupantAffiliation.admin,
          fallback: fallback,
        ),
        OccupantAffiliation.admin,
      );
      expect(
        unresolved.nextRole(null, fallback: fallback),
        OccupantRole.participant,
      );
      expect(
        unresolved.nextRole(OccupantRole.moderator, fallback: fallback),
        OccupantRole.moderator,
      );
    });

    test('nextPresence prefers incoming presence, then current presence', () {
      final present = Occupant(
        occupantId: _roomNickOccupantId,
        nick: 'nick',
        isPresent: true,
      );
      final offline = Occupant(
        occupantId: _syntheticOccupantId,
        nick: 'nick',
        isPresent: false,
      );

      expect(present.nextPresence(null), isTrue);
      expect(present.nextPresence(false), isFalse);
      expect(offline.nextPresence(null), isFalse);
    });
  });

  group('RoomState occupant identity', () {
    test('occupantForSenderJid keeps exact room occupant by default', () {
      final roomState = RoomState(
        roomJid: _roomJid,
        occupants: {
          _roomNickOccupantId: Occupant(
            occupantId: _roomNickOccupantId,
            nick: 'nick',
            isPresent: true,
          ),
          _syntheticOccupantId: Occupant(
            occupantId: _syntheticOccupantId,
            nick: 'nick',
            realJid: _realJid,
            isPresent: false,
          ),
        },
      );

      expect(
        roomState.occupantForSenderJid(_roomNickOccupantId)?.occupantId,
        _roomNickOccupantId,
      );
    });

    test('occupantForSenderJid can prefer the occupant with a real jid', () {
      final roomState = RoomState(
        roomJid: _roomJid,
        occupants: {
          _roomNickOccupantId: Occupant(
            occupantId: _roomNickOccupantId,
            nick: 'nick',
            isPresent: true,
          ),
          _syntheticOccupantId: Occupant(
            occupantId: _syntheticOccupantId,
            nick: 'nick',
            realJid: _realJid,
            isPresent: false,
          ),
        },
      );

      expect(
        roomState
            .occupantForSenderJid(_roomNickOccupantId, preferRealJid: true)
            ?.occupantId,
        _syntheticOccupantId,
      );
    });

    test(
      'canonicalOccupantId does not collapse room nick ids onto synthetic occupants',
      () {
        final roomState = RoomState(
          roomJid: _roomJid,
          occupants: {
            _syntheticOccupantId: Occupant(
              occupantId: _syntheticOccupantId,
              nick: 'nick',
              realJid: _realJid,
              isPresent: false,
            ),
          },
        );

        expect(roomState.canonicalOccupantId(_roomNickOccupantId), isNull);
      },
    );

    test(
      'occupantIdForAffiliation keeps room nick occupants when ids align',
      () {
        final roomState = RoomState(
          roomJid: _roomJid,
          occupants: {
            _roomNickOccupantId: Occupant(
              occupantId: _roomNickOccupantId,
              nick: 'nick',
              realJid: _realJid,
              isPresent: false,
            ),
          },
        );

        expect(
          roomState.occupantIdForAffiliation(realJid: _realJid, nick: 'nick'),
          _roomNickOccupantId,
        );
        expect(
          roomState.occupantIdForAffiliation(
            realJid: 'other@example.com',
            nick: 'nick',
          ),
          isNull,
        );
      },
    );

    test('matchingOccupant prefers a non-room nick real jid match', () {
      final roomState = RoomState(
        roomJid: _roomJid,
        occupants: {
          _roomNickOccupantId: Occupant(
            occupantId: _roomNickOccupantId,
            nick: 'nick',
            isPresent: true,
          ),
          _syntheticOccupantId: Occupant(
            occupantId: _syntheticOccupantId,
            nick: 'nick',
            realJid: _realJid,
            isPresent: false,
          ),
        },
      );

      expect(
        roomState
            .matchingOccupant(_roomNickOccupantId, realJid: _realJid)
            ?.occupantId,
        _syntheticOccupantId,
      );
    });

    test('shouldPreferMatchedOccupantId prefers an existing room nick id', () {
      final roomState = RoomState(roomJid: _roomJid, occupants: const {});

      expect(
        roomState.shouldPreferMatchedOccupantId(
          _syntheticOccupantId,
          _roomNickOccupantId,
        ),
        isTrue,
      );
      expect(
        roomState.shouldPreferMatchedOccupantId(
          _roomNickOccupantId,
          _syntheticOccupantId,
        ),
        isFalse,
      );
    });

    test('isSelfOccupantId ignores surrounding whitespace', () {
      final roomState = RoomState(
        roomJid: _roomJid,
        myOccupantJid: ' $_roomNickOccupantId ',
      );

      expect(roomState.isSelfOccupantId(_roomNickOccupantId), isTrue);
    });

    test('directChatJidForOccupant normalizes mixed-case real jids', () {
      final roomState = RoomState(
        roomJid: _roomJid,
        occupants: {
          _roomNickOccupantId: Occupant(
            occupantId: _roomNickOccupantId,
            nick: 'nick',
            realJid: 'User@Example.com',
            isPresent: true,
          ),
        },
      );

      expect(
        roomState.directChatJidForOccupant(
          roomState.occupants[_roomNickOccupantId]!,
        ),
        _realJid,
      );
    });

    test('moderation actions still require a normalized real jid', () {
      final roomState = RoomState(
        roomJid: _roomJid,
        myOccupantJid: '$_roomJid/self',
        occupants: {
          '$_roomJid/self': Occupant(
            occupantId: '$_roomJid/self',
            nick: 'self',
            affiliation: OccupantAffiliation.admin,
            role: OccupantRole.moderator,
            isPresent: true,
          ),
          _roomNickOccupantId: Occupant(
            occupantId: _roomNickOccupantId,
            nick: 'nick',
            realJid: '/',
            affiliation: OccupantAffiliation.none,
            role: OccupantRole.participant,
            isPresent: true,
          ),
        },
      );

      expect(
        roomState.moderationActionsFor(
          roomState.occupants[_roomNickOccupantId]!,
        ),
        contains(MucModerationAction.kick),
      );
      expect(
        roomState.moderationActionsFor(
          roomState.occupants[_roomNickOccupantId]!,
        ),
        isNot(contains(MucModerationAction.ban)),
      );
      expect(
        roomState.moderationActionsFor(
          roomState.occupants[_roomNickOccupantId]!,
        ),
        isNot(contains(MucModerationAction.member)),
      );
    });
  });

  group('RoomState transformations', () {
    test('withSelfOccupantId updates and clears the self occupant id', () {
      final state = RoomState(
        roomJid: _roomJid,
        occupants: {
          _roomNickOccupantId: Occupant(
            occupantId: _roomNickOccupantId,
            nick: 'nick',
          ),
        },
      );

      final marked = state.withSelfOccupantId(' $_roomNickOccupantId ');
      final cleared = marked.withSelfOccupantId(null);

      expect(marked.myOccupantJid, _roomNickOccupantId);
      expect(cleared.myOccupantJid, isNull);
      expect(cleared.occupants, state.occupants);
    });

    test('withSelfOccupantUnavailable only affects the self occupant', () {
      final selfOccupantId = '$_roomJid/self';
      final otherOccupantId = '$_roomJid/other';
      final state = RoomState(
        roomJid: _roomJid,
        occupants: {
          selfOccupantId: Occupant(
            occupantId: selfOccupantId,
            nick: 'self',
            isPresent: true,
          ),
          otherOccupantId: Occupant(
            occupantId: otherOccupantId,
            nick: 'other',
            isPresent: true,
          ),
        },
        myOccupantJid: selfOccupantId,
      );

      final updated = state.withSelfOccupantUnavailable();

      expect(updated.occupants[selfOccupantId]?.isPresent, isFalse);
      expect(updated.occupants[otherOccupantId]?.isPresent, isTrue);
      expect(updated.myOccupantJid, selfOccupantId);
    });

    test(
      'withSelfOccupant removes conflicting entries and updates self id',
      () {
        final previousSelfOccupantId = '$_roomJid/self';
        final state = RoomState(
          roomJid: _roomJid,
          occupants: {
            _roomNickOccupantId: Occupant(
              occupantId: _roomNickOccupantId,
              nick: 'nick',
              realJid: _realJid,
              isPresent: true,
            ),
            _syntheticOccupantId: Occupant(
              occupantId: _syntheticOccupantId,
              nick: 'nick',
              realJid: _realJid,
              isPresent: false,
            ),
            previousSelfOccupantId: Occupant(
              occupantId: previousSelfOccupantId,
              nick: 'self',
              realJid: 'self@example.com',
              isPresent: true,
            ),
          },
          myOccupantJid: previousSelfOccupantId,
          selfPresenceStatusCodes: {MucStatusCode.selfPresence.code},
        );

        final updated = state.withSelfOccupant(
          ' $_roomNickOccupantId ',
          realJid: _realJid,
        );

        expect(updated.occupants.keys, {_roomNickOccupantId});
        expect(updated.myOccupantJid, _roomNickOccupantId);
        expect(updated.selfPresenceStatusCodes, state.selfPresenceStatusCodes);
      },
    );

    test('withSelfPresence updates presence and clears join failure', () {
      final state = RoomState(
        roomJid: _roomJid,
        occupants: {
          _roomNickOccupantId: Occupant(
            occupantId: _roomNickOccupantId,
            nick: 'nick',
          ),
        },
        myOccupantJid: _roomNickOccupantId,
        selfPresenceStatusCodes: {MucStatusCode.roomCreated.code},
        selfPresenceReason: 'old',
        joinErrorCondition: MucJoinErrorCondition.forbidden,
        joinErrorText: 'denied',
        postJoinRefreshPending: true,
      );

      final updated = state.withSelfPresence(
        statusCodes: {MucStatusCode.selfPresence.code},
        reason: 'new',
      );

      expect(updated.selfPresenceStatusCodes, {
        MucStatusCode.selfPresence.code,
      });
      expect(updated.selfPresenceReason, 'new');
      expect(updated.joinErrorCondition, isNull);
      expect(updated.joinErrorText, isNull);
      expect(updated.postJoinRefreshPending, isTrue);
      expect(updated.myOccupantJid, _roomNickOccupantId);
    });

    test('withJoinFailure updates join error fields only', () {
      final state = RoomState(
        roomJid: _roomJid,
        occupants: {
          _roomNickOccupantId: Occupant(
            occupantId: _roomNickOccupantId,
            nick: 'nick',
          ),
        },
        myOccupantJid: _roomNickOccupantId,
        selfPresenceStatusCodes: {MucStatusCode.selfPresence.code},
        selfPresenceReason: 'reason',
      );

      final updated = state.withJoinFailure(
        condition: MucJoinErrorCondition.forbidden,
        text: 'denied',
      );

      expect(updated.joinErrorCondition, MucJoinErrorCondition.forbidden);
      expect(updated.joinErrorText, 'denied');
      expect(updated.selfPresenceStatusCodes, state.selfPresenceStatusCodes);
      expect(updated.selfPresenceReason, state.selfPresenceReason);
      expect(updated.myOccupantJid, _roomNickOccupantId);
    });

    test('withDestroyedState updates destroyed fields only', () {
      final state = RoomState(
        roomJid: _roomJid,
        occupants: {
          _roomNickOccupantId: Occupant(
            occupantId: _roomNickOccupantId,
            nick: 'nick',
          ),
        },
        myOccupantJid: _roomNickOccupantId,
        selfPresenceStatusCodes: {MucStatusCode.selfPresence.code},
      );

      final updated = state.withDestroyedState(
        destroyed: true,
        alternateRoomJid: 'alt@conference.example.com',
      );
      final cleared = updated.withDestroyedState(destroyed: false);

      expect(updated.isDestroyed, isTrue);
      expect(updated.destroyedAlternateRoomJid, 'alt@conference.example.com');
      expect(cleared.isDestroyed, isFalse);
      expect(cleared.destroyedAlternateRoomJid, isNull);
    });

    test('withoutSelfPresenceStatusCode removes only the requested code', () {
      final state = RoomState(
        roomJid: _roomJid,
        selfPresenceStatusCodes: {
          MucStatusCode.selfPresence.code,
          MucStatusCode.roomCreated.code,
        },
        selfPresenceReason: 'reason',
      );

      final updated = state.withoutSelfPresenceStatusCode(
        MucStatusCode.roomCreated.code,
      );

      expect(updated.selfPresenceStatusCodes, {
        MucStatusCode.selfPresence.code,
      });
      expect(updated.selfPresenceReason, 'reason');
    });

    test('withPostJoinRefreshPending preserves other room state', () {
      final state = RoomState(
        roomJid: _roomJid,
        occupants: {
          _roomNickOccupantId: Occupant(
            occupantId: _roomNickOccupantId,
            nick: 'nick',
          ),
        },
        myOccupantJid: _roomNickOccupantId,
        selfPresenceStatusCodes: {MucStatusCode.selfPresence.code},
        selfPresenceReason: 'reason',
        joinErrorCondition: MucJoinErrorCondition.forbidden,
        joinErrorText: 'denied',
      );

      final updated = state.withPostJoinRefreshPending(true);

      expect(updated.postJoinRefreshPending, isTrue);
      expect(updated.selfPresenceStatusCodes, state.selfPresenceStatusCodes);
      expect(updated.selfPresenceReason, state.selfPresenceReason);
      expect(updated.joinErrorCondition, state.joinErrorCondition);
      expect(updated.joinErrorText, state.joinErrorText);
      expect(updated.myOccupantJid, _roomNickOccupantId);
    });

    test('withoutOccupants clears occupants and self occupant id only', () {
      final state = RoomState(
        roomJid: _roomJid,
        occupants: {
          _roomNickOccupantId: Occupant(
            occupantId: _roomNickOccupantId,
            nick: 'nick',
          ),
        },
        myOccupantJid: _roomNickOccupantId,
        selfPresenceStatusCodes: {MucStatusCode.selfPresence.code},
        selfPresenceReason: 'reason',
        joinErrorCondition: MucJoinErrorCondition.forbidden,
        joinErrorText: 'denied',
        isDestroyed: true,
        destroyedAlternateRoomJid: 'alt@conference.example.com',
        postJoinRefreshPending: true,
      );

      final updated = state.withoutOccupants();

      expect(updated.occupants, isEmpty);
      expect(updated.myOccupantJid, isNull);
      expect(updated.selfPresenceStatusCodes, state.selfPresenceStatusCodes);
      expect(updated.selfPresenceReason, state.selfPresenceReason);
      expect(updated.joinErrorCondition, state.joinErrorCondition);
      expect(updated.joinErrorText, state.joinErrorText);
      expect(updated.isDestroyed, isTrue);
      expect(updated.destroyedAlternateRoomJid, 'alt@conference.example.com');
      expect(updated.postJoinRefreshPending, isTrue);
    });

    test('withoutExactOccupant ignores canonical matches for missing ids', () {
      final state = RoomState(
        roomJid: _roomJid,
        occupants: {
          _syntheticOccupantId: Occupant(
            occupantId: _syntheticOccupantId,
            nick: 'nick',
            realJid: _realJid,
          ),
        },
        myOccupantJid: _syntheticOccupantId,
      );

      final updated = state.withoutExactOccupant(_roomNickOccupantId);

      expect(updated.occupants.keys, {_syntheticOccupantId});
      expect(updated.myOccupantJid, _syntheticOccupantId);
    });

    test(
      'withoutOtherOccupantsForRealJid keeps the requested occupant only',
      () {
        final state = RoomState(
          roomJid: _roomJid,
          occupants: {
            _roomNickOccupantId: Occupant(
              occupantId: _roomNickOccupantId,
              nick: 'nick',
              realJid: _realJid,
              isPresent: true,
            ),
            _syntheticOccupantId: Occupant(
              occupantId: _syntheticOccupantId,
              nick: 'nick',
              realJid: _realJid,
              isPresent: false,
            ),
          },
          myOccupantJid: _syntheticOccupantId,
          selfPresenceStatusCodes: {MucStatusCode.selfPresence.code},
        );

        final updated = state.withoutOtherOccupantsForRealJid(
          keepOccupantId: _roomNickOccupantId,
          realJid: _realJid,
        );

        expect(updated.occupants.keys, {_roomNickOccupantId});
        expect(updated.myOccupantJid, isNull);
        expect(updated.selfPresenceStatusCodes, state.selfPresenceStatusCodes);
      },
    );

    test(
      'withoutPresenceAndJoinState preserves occupants and self occupant id',
      () {
        final selfOccupantId = '$_roomJid/self';
        final state = RoomState(
          roomJid: _roomJid,
          occupants: {
            selfOccupantId: Occupant(
              occupantId: selfOccupantId,
              nick: 'self',
              isPresent: false,
            ),
          },
          myOccupantJid: selfOccupantId,
          selfPresenceStatusCodes: {MucStatusCode.selfPresence.code},
          selfPresenceReason: 'reason',
          joinErrorCondition: MucJoinErrorCondition.forbidden,
          joinErrorText: 'denied',
          isDestroyed: true,
          destroyedAlternateRoomJid: 'alt@conference.example.com',
          postJoinRefreshPending: true,
        );

        final updated = state.withoutPresenceAndJoinState();

        expect(updated.occupants, state.occupants);
        expect(updated.myOccupantJid, selfOccupantId);
        expect(updated.selfPresenceStatusCodes, isEmpty);
        expect(updated.selfPresenceReason, isNull);
        expect(updated.joinErrorCondition, isNull);
        expect(updated.joinErrorText, isNull);
        expect(updated.isDestroyed, isFalse);
        expect(updated.destroyedAlternateRoomJid, isNull);
        expect(updated.postJoinRefreshPending, isFalse);
      },
    );
  });

  group('RoomState affiliation merge', () {
    test('withAffiliationEntries updates the self occupant', () {
      final state = RoomState(roomJid: _roomJid, occupants: const {});

      final updated = state.withAffiliationEntries(
        queriedAffiliation: OccupantAffiliation.member,
        entries: const [
          MucAffiliationEntry(
            affiliation: OccupantAffiliation.member,
            jid: _realJid,
            nick: 'nick',
          ),
        ],
        selfRealJid: _realJid,
      );

      expect(updated.selfNick, 'nick');
      expect(updated.myOccupantJid, _syntheticOccupantId);
      expect(
        updated.occupants[_syntheticOccupantId]?.affiliation,
        OccupantAffiliation.member,
      );
    });

    test(
      'withAffiliationEntries removes stale offline occupants for queried affiliation',
      () {
        final state = RoomState(
          roomJid: _roomJid,
          occupants: {
            _syntheticOccupantId: Occupant(
              occupantId: _syntheticOccupantId,
              nick: 'nick',
              realJid: _realJid,
              affiliation: OccupantAffiliation.member,
              isPresent: false,
            ),
          },
        );

        final updated = state.withAffiliationEntries(
          queriedAffiliation: OccupantAffiliation.member,
          entries: const [],
        );

        expect(updated.occupants, isEmpty);
      },
    );
  });

  group('MucSelfPresenceEvent', () {
    test('exposes computed membership transition helpers', () {
      final event = MucSelfPresenceEvent(
        roomJid: _roomJid,
        occupantJid: _roomNickOccupantId,
        nick: 'old-nick',
        affiliation: OccupantAffiliation.admin.xmlValue,
        role: OccupantRole.participant.xmlValue,
        isAvailable: false,
        isError: false,
        isNickChange: true,
        statusCodes: {
          MucStatusCode.configurationChanged.code,
          MucStatusCode.removedByMembersOnlyChange.code,
        },
        newNick: 'new-nick',
        errorCondition: MucJoinErrorCondition.registrationRequired.xmlValue,
      );

      expect(event.occupantAffiliation, OccupantAffiliation.admin);
      expect(event.occupantRole, OccupantRole.participant);
      expect(
        event.parsedErrorCondition,
        MucJoinErrorCondition.registrationRequired,
      );
      expect(event.nextNick, 'new-nick');
      expect(event.nextOccupantJid, '$_roomJid/new-nick');
      expect(event.shouldLeaveRoom, isFalse);
      expect(event.shouldArchiveRoom, isTrue);
      expect(event.hasStatus(MucStatusCode.configurationChanged), isTrue);
    });
  });
}
