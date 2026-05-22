// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  late MockXmppService rosterService;
  late StreamController<List<RosterItem>> rosterController;
  late StreamController<List<Invite>> invitesController;
  late RosterCubit cubit;

  setUp(() {
    rosterService = MockXmppService();
    rosterController = StreamController<List<RosterItem>>();
    invitesController = StreamController<List<Invite>>();
    when(
      () => rosterService.rosterStream(),
    ).thenAnswer((_) => rosterController.stream);
    when(
      () => rosterService.invitesStream(),
    ).thenAnswer((_) => invitesController.stream);
    cubit = RosterCubit(rosterService: rosterService);
  });

  tearDown(() async {
    await cubit.close();
    await rosterController.close();
    await invitesController.close();
    resetMocktailState();
  });

  test('keeps different roster JIDs actionable while one loads', () async {
    final firstAdd = Completer<void>();
    when(
      () => rosterService.addToRoster(jid: 'alpha@example.com', title: null),
    ).thenAnswer((_) => firstAdd.future);
    when(
      () => rosterService.rejectSubscriptionRequest('beta@example.com'),
    ).thenAnswer((_) async {});

    final pending = cubit.addContact(jid: 'alpha@example.com');
    await pumpEventQueue();

    expect(
      cubit.state.loadingActions,
      contains(
        const RosterActionLoading(
          action: RosterActionType.add,
          jid: 'alpha@example.com',
        ),
      ),
    );

    await cubit.rejectContact(jid: 'beta@example.com');

    verify(
      () => rosterService.addToRoster(jid: 'alpha@example.com', title: null),
    ).called(1);
    verify(
      () => rosterService.rejectSubscriptionRequest('beta@example.com'),
    ).called(1);
    expect(
      cubit.state.loadingActions,
      contains(
        const RosterActionLoading(
          action: RosterActionType.add,
          jid: 'alpha@example.com',
        ),
      ),
    );

    firstAdd.complete();
    await pending;

    expect(cubit.state.loadingActions, isEmpty);
  });

  test('ignores duplicate roster actions while the JID loads', () async {
    final add = Completer<void>();
    when(
      () => rosterService.addToRoster(jid: 'alpha@example.com', title: null),
    ).thenAnswer((_) => add.future);

    final pending = cubit.addContact(jid: 'alpha@example.com');
    await pumpEventQueue();

    await cubit.addContact(jid: 'alpha@example.com');

    verify(
      () => rosterService.addToRoster(jid: 'alpha@example.com', title: null),
    ).called(1);

    add.complete();
    await pending;
    expect(cubit.state.loadingActions, isEmpty);
  });

  test('normalizes roster action loading keys before deduping', () async {
    final add = Completer<void>();
    when(
      () => rosterService.addToRoster(
        jid: 'alpha@example.com/resource',
        title: null,
      ),
    ).thenAnswer((_) => add.future);

    final pending = cubit.addContact(jid: 'alpha@example.com/resource');
    await pumpEventQueue();

    expect(
      cubit.state.loadingActions,
      contains(
        const RosterActionLoading(
          action: RosterActionType.add,
          jid: 'alpha@example.com',
        ),
      ),
    );
    expect(cubit.state.isRosterJidLoading('alpha@example.com'), isTrue);
    expect(
      cubit.state.isRosterActionLoading(
        const RosterActionLoading(
          action: RosterActionType.add,
          jid: 'alpha@example.com/resource',
        ),
      ),
      isTrue,
    );

    await cubit.rejectContact(jid: 'alpha@example.com');
    await cubit.addContact(jid: 'alpha@example.com');

    verifyNever(
      () => rosterService.rejectSubscriptionRequest('alpha@example.com'),
    );
    verifyNever(
      () => rosterService.addToRoster(jid: 'alpha@example.com', title: null),
    );

    add.complete();
    await pending;
    expect(cubit.state.loadingActions, isEmpty);
  });
}
