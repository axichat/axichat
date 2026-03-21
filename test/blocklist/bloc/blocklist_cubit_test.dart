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
}
