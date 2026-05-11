// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  late MockXmppService xmppService;
  late StreamController<List<BlocklistData>> xmppBlocklistController;
  late StreamController<List<EmailBlocklistEntry>> emailBlocklistController;

  setUp(() {
    xmppService = MockXmppService();
    xmppBlocklistController = StreamController<List<BlocklistData>>.broadcast(
      sync: true,
    );
    emailBlocklistController =
        StreamController<List<EmailBlocklistEntry>>.broadcast(sync: true);

    when(
      () => xmppService.blocklistStream(),
    ).thenAnswer((_) => xmppBlocklistController.stream);
    when(
      () => xmppService.addressBlocklistStream(),
    ).thenAnswer((_) => emailBlocklistController.stream);
  });

  tearDown(() async {
    await xmppBlocklistController.close();
    await emailBlocklistController.close();
  });

  test('cache keeps the latest stream-backed blocklist items', () async {
    final cubit = BlocklistCubit(xmppService: xmppService);
    addTearDown(cubit.close);

    final olderEntry = BlocklistData(
      jid: 'older@axi.im',
      blockedAt: DateTime.utc(2025, 1, 1),
    );
    final newerEntry = BlocklistData(
      jid: 'newer@axi.im',
      blockedAt: DateTime.utc(2025, 1, 2),
    );

    xmppBlocklistController.add([olderEntry]);
    await pumpEventQueue();

    xmppBlocklistController.add([newerEntry, olderEntry]);
    await pumpEventQueue();

    final cachedItems =
        cubit[BlocklistCubit.blocklistItemsCacheKey] as List<BlocklistEntry>?;
    final cachedVisibleItems =
        cubit[BlocklistCubit.blocklistVisibleItemsCacheKey]
            as List<BlocklistEntry>?;

    expect(cubit.state, isA<BlocklistAvailable>());
    expect(
      cubit.state.items?.map((entry) => entry.address).toList(),
      equals(['newer@axi.im', 'older@axi.im']),
    );
    expect(
      cachedItems?.map((entry) => entry.address).toList(),
      equals(['newer@axi.im', 'older@axi.im']),
    );
    expect(
      cachedVisibleItems?.map((entry) => entry.address).toList(),
      equals(['newer@axi.im', 'older@axi.im']),
    );
  });

  test('blockContact blocks both transports for merged contacts', () async {
    final cubit = BlocklistCubit(xmppService: xmppService);
    addTearDown(cubit.close);
    when(
      () => xmppService.setAddressBlockStatus(
        address: 'merged@example.com',
        blocked: true,
      ),
    ).thenAnswer((_) async {});
    when(
      () => xmppService.block(jid: 'merged@example.com'),
    ).thenAnswer((_) async {});

    await cubit.blockContact(
      address: 'merged@example.com',
      includeEmail: true,
      includeXmpp: true,
    );

    verify(
      () => xmppService.setAddressBlockStatus(
        address: 'merged@example.com',
        blocked: true,
      ),
    ).called(1);
    verify(() => xmppService.block(jid: 'merged@example.com')).called(1);
    expect(
      cubit.state,
      const BlocklistSuccess(
        BlocklistNotice(
          BlocklistNoticeType.blocked,
          address: 'merged@example.com',
        ),
      ),
    );
  });

  test(
    'blockContact blocks email-only contacts through address blocklist',
    () async {
      final cubit = BlocklistCubit(xmppService: xmppService);
      addTearDown(cubit.close);
      when(
        () => xmppService.setAddressBlockStatus(
          address: 'email@example.com',
          blocked: true,
        ),
      ).thenAnswer((_) async {});

      await cubit.blockContact(
        address: 'email@example.com',
        includeEmail: true,
        includeXmpp: false,
      );

      verify(
        () => xmppService.setAddressBlockStatus(
          address: 'email@example.com',
          blocked: true,
        ),
      ).called(1);
      verifyNever(() => xmppService.block(jid: 'email@example.com'));
      expect(
        cubit.state,
        const BlocklistSuccess(
          BlocklistNotice(
            BlocklistNoticeType.blocked,
            address: 'email@example.com',
          ),
        ),
      );
    },
  );

  test(
    'blockContact blocks XMPP-only contacts through XMPP blocklist',
    () async {
      final cubit = BlocklistCubit(xmppService: xmppService);
      addTearDown(cubit.close);
      when(
        () => xmppService.block(jid: 'xmpp@example.com'),
      ).thenAnswer((_) async {});

      await cubit.blockContact(
        address: 'xmpp@example.com',
        includeEmail: false,
        includeXmpp: true,
      );

      verifyNever(
        () => xmppService.setAddressBlockStatus(
          address: 'xmpp@example.com',
          blocked: true,
        ),
      );
      verify(() => xmppService.block(jid: 'xmpp@example.com')).called(1);
      expect(
        cubit.state,
        const BlocklistSuccess(
          BlocklistNotice(
            BlocklistNoticeType.blocked,
            address: 'xmpp@example.com',
          ),
        ),
      );
    },
  );
}
