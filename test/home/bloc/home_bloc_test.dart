import 'dart:async';

import 'package:axichat/src/home/bloc/home_bloc.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const Duration(seconds: 1));
    registerFallbackValue(HomeBadgeBucket.drafts);
    registerFallbackValue(DateTime.utc(2026, 1, 1));
  });

  late MockXmppService xmppService;
  late MockEmailService emailService;
  late StreamController<EmailSyncState> emailSyncStateController;
  late StreamController<void> emailReadyTransitionController;
  late StreamController<Map<HomeBadgeBucket, DateTime>>
  homeBadgeSeenMarkersController;
  late Map<HomeBadgeBucket, DateTime> homeBadgeSeenMarkers;

  setUp(() {
    xmppService = MockXmppService();
    emailService = MockEmailService();
    emailSyncStateController = StreamController<EmailSyncState>.broadcast();
    emailReadyTransitionController = StreamController<void>.broadcast();
    homeBadgeSeenMarkersController =
        StreamController<Map<HomeBadgeBucket, DateTime>>.broadcast();
    homeBadgeSeenMarkers = <HomeBadgeBucket, DateTime>{};

    when(() => xmppService.hasConnectionSettings).thenReturn(true);
    when(() => xmppService.syncSessionState()).thenAnswer((_) async => true);
    when(
      () => xmppService.homeBadgeSeenMarkersStream,
    ).thenAnswer((_) => homeBadgeSeenMarkersController.stream);
    when(
      () => xmppService.markHomeBadgeBucketSeen(
        bucket: any(named: 'bucket'),
        seenAt: any(named: 'seenAt'),
      ),
    ).thenAnswer((invocation) async {
      final bucket = invocation.namedArguments[#bucket] as HomeBadgeBucket;
      final seenAt = (invocation.namedArguments[#seenAt] as DateTime).toUtc();
      final current = homeBadgeSeenMarkers[bucket];
      if (current != null && !seenAt.isAfter(current)) {
        return;
      }
      homeBadgeSeenMarkers = <HomeBadgeBucket, DateTime>{
        ...homeBadgeSeenMarkers,
        bucket: seenAt,
      };
      homeBadgeSeenMarkersController.add(
        Map<HomeBadgeBucket, DateTime>.unmodifiable(homeBadgeSeenMarkers),
      );
    });

    when(
      () => emailService.syncState,
    ).thenReturn(const EmailSyncState.offline('offline'));
    when(
      () => emailService.syncStateStream,
    ).thenAnswer((_) => emailSyncStateController.stream);
    when(
      () => emailService.readyTransitionStream,
    ).thenAnswer((_) => emailReadyTransitionController.stream);
    when(
      () => emailService.canReconnectConfiguredSession(),
    ).thenAnswer((_) async => false);
    when(() => emailService.hasActiveSession).thenReturn(true);
    when(
      () => emailService.recoverForHomeRefresh(),
    ).thenAnswer((_) async => true);
    when(
      () => emailService.refreshUnreadForHomeRefresh(),
    ).thenAnswer((_) async => true);
    when(
      () => emailService.refreshHistoryForHomeRefresh(),
    ).thenAnswer((_) async => true);
    when(
      () => emailService.syncContactsForHomeRefresh(),
    ).thenAnswer((_) async => true);
    when(() => emailService.syncSessionState()).thenAnswer((_) async => true);
    when(
      () => emailService.ensureEventChannelActive(),
    ).thenAnswer((_) async {});
    when(() => emailService.handleNetworkAvailable()).thenAnswer((_) async {});
    when(
      () => emailService.performBackgroundFetch(timeout: any(named: 'timeout')),
    ).thenAnswer((_) async => true);
    when(() => emailService.refreshChatlistFromCore()).thenAnswer((_) async {});
    when(() => emailService.syncContactsFromCore()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await emailSyncStateController.close();
    await emailReadyTransitionController.close();
    await homeBadgeSeenMarkersController.close();
  });

  test(
    'refresh emits loading then success for the full sync sequence',
    () async {
      final bloc = HomeBloc(
        xmppService: xmppService,
        emailService: emailService,
        tabs: const [HomeTab.chats, HomeTab.folders],
      );
      final emittedStates = <HomeState>[];
      final subscription = bloc.stream.listen(emittedStates.add);
      addTearDown(() async {
        await subscription.cancel();
        await bloc.close();
      });

      bloc.add(const HomeRefreshRequested());
      await pumpEventQueue();

      expect(emittedStates.map((state) => state.refreshStatus), [
        RequestStatus.loading,
        RequestStatus.success,
      ]);
      verify(() => emailService.syncSessionState()).called(1);
      verify(() => xmppService.syncSessionState()).called(1);
    },
  );

  test('email ready transition triggers unread-only refresh work', () async {
    final bloc = HomeBloc(
      xmppService: xmppService,
      emailService: emailService,
      tabs: const [HomeTab.chats],
    );
    addTearDown(bloc.close);

    await pumpEventQueue();
    emailReadyTransitionController.add(null);
    await pumpEventQueue();

    verify(() => emailService.refreshUnreadForHomeRefresh()).called(1);
    verifyNever(() => emailService.syncSessionState());
    verifyNever(() => xmppService.syncSessionState());
  });

  test(
    'already-ready email service triggers unread refresh on attach',
    () async {
      when(
        () => emailService.syncState,
      ).thenReturn(const EmailSyncState.ready());

      final bloc = HomeBloc(
        xmppService: xmppService,
        emailService: emailService,
        tabs: const [HomeTab.chats],
      );
      addTearDown(bloc.close);

      await pumpEventQueue();

      verify(() => emailService.refreshUnreadForHomeRefresh()).called(1);
      verifyNever(() => emailService.syncSessionState());
      verifyNever(() => xmppService.syncSessionState());
    },
  );

  test('folders important and spam search state stay independent', () async {
    final bloc = HomeBloc(
      xmppService: xmppService,
      emailService: emailService,
      tabs: const [HomeTab.folders],
    );
    addTearDown(bloc.close);

    bloc.add(
      const HomeSearchQueryChanged(
        'spam query',
        slot: HomeSearchSlot.foldersSpam,
      ),
    );
    await pumpEventQueue();
    bloc.add(
      const HomeSearchQueryChanged(
        'important query',
        slot: HomeSearchSlot.foldersImportant,
      ),
    );
    await pumpEventQueue();

    expect(
      bloc.state.stateForSlot(HomeSearchSlot.foldersSpam).query,
      'spam query',
    );
    expect(
      bloc.state.stateForSlot(HomeSearchSlot.foldersImportant).query,
      'important query',
    );
  });

  test('refresh delegates to the two session sync owners only', () async {
    final bloc = HomeBloc(
      xmppService: xmppService,
      emailService: emailService,
      tabs: const [HomeTab.chats],
    );
    final emittedStates = <HomeState>[];
    final subscription = bloc.stream.listen(emittedStates.add);
    addTearDown(() async {
      await subscription.cancel();
      await bloc.close();
    });

    bloc.add(const HomeRefreshRequested());
    await pumpEventQueue();

    expect(emittedStates.map((state) => state.refreshStatus), [
      RequestStatus.loading,
      RequestStatus.success,
    ]);
    verify(() => emailService.syncSessionState()).called(1);
    verify(() => xmppService.syncSessionState()).called(1);
  });

  test(
    'email sync failure still runs XMPP sync and reports success when XMPP is configured',
    () async {
      when(
        () => emailService.syncSessionState(),
      ).thenAnswer((_) async => false);

      final bloc = HomeBloc(
        xmppService: xmppService,
        emailService: emailService,
        tabs: const [HomeTab.chats],
      );
      final emittedStates = <HomeState>[];
      final subscription = bloc.stream.listen(emittedStates.add);
      addTearDown(() async {
        await subscription.cancel();
        await bloc.close();
      });

      bloc.add(const HomeRefreshRequested());
      await pumpEventQueue();

      expect(emittedStates.map((state) => state.refreshStatus), [
        RequestStatus.loading,
        RequestStatus.success,
      ]);
      verify(() => emailService.syncSessionState()).called(1);
      verify(() => xmppService.syncSessionState()).called(1);
    },
  );

  test('email sync failure reports failure for SMTP-only refresh', () async {
    when(() => xmppService.hasConnectionSettings).thenReturn(false);
    when(() => emailService.syncSessionState()).thenAnswer((_) async => false);

    final bloc = HomeBloc(
      xmppService: xmppService,
      emailService: emailService,
      tabs: const [HomeTab.chats],
    );
    final emittedStates = <HomeState>[];
    final subscription = bloc.stream.listen(emittedStates.add);
    addTearDown(() async {
      await subscription.cancel();
      await bloc.close();
    });

    bloc.add(const HomeRefreshRequested());
    await pumpEventQueue();

    expect(emittedStates.map((state) => state.refreshStatus), [
      RequestStatus.loading,
      RequestStatus.failure,
    ]);
    verify(() => emailService.syncSessionState()).called(1);
    verifyNever(() => xmppService.syncSessionState());
  });

  test(
    'close during email subscription reconcile does not leave a later listener active',
    () async {
      final firstCancelStarted = Completer<void>();
      final firstCancelCompleter = Completer<void>();
      final firstReadyTransitionController = StreamController<void>.broadcast(
        onCancel: () async {
          if (!firstCancelStarted.isCompleted) {
            firstCancelStarted.complete();
          }
          await firstCancelCompleter.future;
        },
      );
      final secondReadyTransitionController =
          StreamController<void>.broadcast();
      final firstEmailService = MockEmailService();
      final secondEmailService = MockEmailService();
      addTearDown(() async {
        await firstReadyTransitionController.close();
        await secondReadyTransitionController.close();
      });

      when(
        () => firstEmailService.syncState,
      ).thenReturn(const EmailSyncState.offline('offline'));
      when(
        () => firstEmailService.readyTransitionStream,
      ).thenAnswer((_) => firstReadyTransitionController.stream);
      when(
        () => firstEmailService.refreshUnreadForHomeRefresh(),
      ).thenAnswer((_) async => true);

      when(
        () => secondEmailService.syncState,
      ).thenReturn(const EmailSyncState.offline('offline'));
      when(
        () => secondEmailService.readyTransitionStream,
      ).thenAnswer((_) => secondReadyTransitionController.stream);
      when(
        () => secondEmailService.refreshUnreadForHomeRefresh(),
      ).thenAnswer((_) async => true);

      final bloc = HomeBloc(
        xmppService: xmppService,
        emailService: firstEmailService,
        tabs: const [HomeTab.chats],
      );
      await pumpEventQueue();

      bloc.add(HomeEmailServiceChanged(secondEmailService));
      await firstCancelStarted.future;

      final closeFuture = bloc.close();
      firstCancelCompleter.complete();
      await closeFuture;

      secondReadyTransitionController.add(null);
      await pumpEventQueue();

      verifyNever(() => secondEmailService.refreshUnreadForHomeRefresh());
    },
  );

  test(
    'close cancels subscriptions and tolerates in-flight refresh work',
    () async {
      final fetchCompleter = Completer<bool>();
      when(
        () => emailService.syncSessionState(),
      ).thenAnswer((_) => fetchCompleter.future);

      final bloc = HomeBloc(
        xmppService: xmppService,
        emailService: emailService,
        tabs: const [HomeTab.chats],
      );
      final emittedStates = <HomeState>[];
      final subscription = bloc.stream.listen(emittedStates.add);
      addTearDown(subscription.cancel);

      bloc.add(const HomeRefreshRequested());
      await untilCalled(() => emailService.syncSessionState());

      final closeFuture = bloc.close();
      fetchCompleter.complete(true);
      await closeFuture;

      expect(emittedStates.first.refreshStatus, RequestStatus.loading);
      verify(() => emailService.syncSessionState()).called(1);
    },
  );

  test('home badge marker stream drives loaded state and writes', () async {
    final bloc = HomeBloc(
      xmppService: xmppService,
      tabs: const [HomeTab.chats, HomeTab.drafts],
    );
    addTearDown(bloc.close);

    await pumpEventQueue();
    expect(bloc.state.badgeSeenMarkersLoaded, isFalse);

    homeBadgeSeenMarkersController.add(const <HomeBadgeBucket, DateTime>{});
    await pumpEventQueue();

    expect(bloc.state.badgeSeenMarkersLoaded, isTrue);
    expect(bloc.state.badgeSeenMarkers, isEmpty);

    await bloc.advanceHomeBadgeSeenMarker(
      bucket: HomeBadgeBucket.drafts,
      seenAt: DateTime.utc(2026, 1, 2),
    );
    await pumpEventQueue();

    expect(
      bloc.state.badgeSeenMarkers[HomeBadgeBucket.drafts],
      DateTime.utc(2026, 1, 2),
    );
  });
}
