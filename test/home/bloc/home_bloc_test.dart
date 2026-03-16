import 'dart:async';

import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/home/bloc/home_bloc.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const Duration(seconds: 1));
    registerFallbackValue(ReconnectTrigger.userAction);
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

    when(
      () => xmppService.ensureConnected(
        trigger: any(named: 'trigger'),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => xmppService.syncGlobalMamCatchUpForRefresh(
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => MamGlobalSyncOutcome.failed);
    when(() => xmppService.syncSpamSnapshot()).thenAnswer((_) async {});
    when(() => xmppService.syncAddressBlockSnapshot()).thenAnswer((_) async {});
    when(
      () => xmppService.syncConversationIndexSnapshot(),
    ).thenAnswer((_) async => const []);
    when(
      () => xmppService.syncMucBookmarksSnapshot(),
    ).thenAnswer((_) async => const []);
    when(
      () => xmppService.rehydrateCalendarFromMam(),
    ).thenAnswer((_) async => true);
    when(
      () => xmppService.refreshAvatarsForConversationIndex(),
    ).thenAnswer((_) async {});
    when(() => xmppService.syncDraftsSnapshot()).thenAnswer((_) async {});

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
    when(() => emailService.recoverForHomeRefresh()).thenAnswer((_) async {});
    when(
      () => emailService.refreshUnreadForHomeRefresh(),
    ).thenAnswer((_) async {});
    when(
      () => emailService.refreshHistoryForHomeRefresh(),
    ).thenAnswer((_) async {});
    when(
      () => emailService.syncContactsForHomeRefresh(),
    ).thenAnswer((_) async {});
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
      verify(
        () => xmppService.syncGlobalMamCatchUpForRefresh(pageSize: 50),
      ).called(1);
      verify(() => emailService.syncContactsForHomeRefresh()).called(1);
      verify(() => emailService.refreshHistoryForHomeRefresh()).called(1);
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
    verifyNever(() => emailService.syncContactsForHomeRefresh());
    verifyNever(() => xmppService.syncConversationIndexSnapshot());
  });

  test(
    'close cancels subscriptions and tolerates in-flight refresh work',
    () async {
      final fetchCompleter = Completer<void>();
      when(
        () => emailService.refreshHistoryForHomeRefresh(),
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
      await untilCalled(() => emailService.refreshHistoryForHomeRefresh());

      final closeFuture = bloc.close();
      fetchCompleter.complete();
      await closeFuture;

      expect(emittedStates.first.refreshStatus, RequestStatus.loading);
      verify(() => emailService.refreshHistoryForHomeRefresh()).called(1);
    },
  );
}
