import 'dart:async';

import 'package:axichat/src/home/bloc/home_bloc.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const Duration(seconds: 1));
  });

  late MockXmppService xmppService;
  late MockEmailService emailService;
  late StreamController<EmailSyncState> emailSyncStateController;
  late StreamController<void> emailReadyTransitionController;

  setUp(() {
    xmppService = MockXmppService();
    emailService = MockEmailService();
    emailSyncStateController = StreamController<EmailSyncState>.broadcast();
    emailReadyTransitionController = StreamController<void>.broadcast();

    when(() => xmppService.syncSessionState()).thenAnswer((_) async => true);

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
  });

  test(
    'refresh emits loading then success for the full sync sequence',
    () async {
      final bloc = HomeBloc(
        xmppService: xmppService,
        emailService: emailService,
        tabs: const [HomeTab.chats, HomeTab.spam],
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
}
