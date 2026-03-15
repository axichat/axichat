import 'dart:async';

import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/home/service/home_refresh_sync_service.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  late MockXmppService mockXmppService;
  late MockEmailService mockEmailService;

  setUpAll(() {
    registerFallbackValue(const Duration(seconds: 1));
  });

  setUp(() {
    mockXmppService = MockXmppService();
    mockEmailService = MockEmailService();

    when(() => mockXmppService.hasConnectionSettings).thenReturn(false);
    when(
      () => mockXmppService.connectionState,
    ).thenReturn(ConnectionState.notConnected);
    when(
      () => mockEmailService.syncState,
    ).thenReturn(const EmailSyncState.offline('offline'));
    when(
      () => mockEmailService.canReconnectConfiguredSession(),
    ).thenAnswer((_) async => false);
    when(
      () => mockEmailService.ensureEventChannelActive(),
    ).thenAnswer((_) async {});
    when(
      () => mockEmailService.handleNetworkAvailable(),
    ).thenAnswer((_) async {});
    when(
      () => mockEmailService.performBackgroundFetch(
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => mockEmailService.refreshChatlistFromCore(),
    ).thenAnswer((_) async {});
    when(
      () => mockEmailService.syncContactsFromCore(),
    ).thenAnswer((_) async {});
  });

  test(
    'refreshUnreadOnly skips email healing without reconnect context',
    () async {
      when(() => mockEmailService.hasActiveSession).thenReturn(false);
      when(
        () => mockEmailService.hasInMemoryReconnectContext,
      ).thenReturn(false);
      when(
        () => mockEmailService.canReconnectConfiguredSession(),
      ).thenAnswer((_) async => false);

      final service = HomeRefreshSyncService(
        xmppService: mockXmppService,
        emailService: mockEmailService,
      );

      await service.refreshUnreadOnly();

      verifyNever(() => mockEmailService.ensureEventChannelActive());
      verifyNever(() => mockEmailService.handleNetworkAvailable());
    },
  );

  test('refreshUnreadOnly heals email with reconnect context', () async {
    when(() => mockEmailService.hasActiveSession).thenReturn(true);
    when(() => mockEmailService.hasInMemoryReconnectContext).thenReturn(true);
    when(
      () => mockEmailService.canReconnectConfiguredSession(),
    ).thenAnswer((_) async => true);

    final service = HomeRefreshSyncService(
      xmppService: mockXmppService,
      emailService: mockEmailService,
    );

    await service.refreshUnreadOnly();

    verify(() => mockEmailService.ensureEventChannelActive()).called(1);
    verify(() => mockEmailService.handleNetworkAvailable()).called(1);
  });

  test('refresh does a full restore and unread-only stays scoped', () async {
    when(() => mockEmailService.hasActiveSession).thenReturn(true);
    when(
      () => mockEmailService.canReconnectConfiguredSession(),
    ).thenAnswer((_) async => false);

    final service = HomeRefreshSyncService(
      xmppService: mockXmppService,
      emailService: mockEmailService,
    );

    await service.refresh();
    await service.refreshUnreadOnly();

    verify(() => mockEmailService.syncContactsFromCore()).called(1);
    verify(
      () => mockEmailService.performBackgroundFetch(
        timeout: any(named: 'timeout'),
      ),
    ).called(3);
    verify(() => mockEmailService.refreshChatlistFromCore()).called(3);
  });

  test(
    'refresh fetches email history even while email sync is offline',
    () async {
      when(() => mockEmailService.hasActiveSession).thenReturn(true);
      when(
        () => mockEmailService.canReconnectConfiguredSession(),
      ).thenAnswer((_) async => false);

      final service = HomeRefreshSyncService(
        xmppService: mockXmppService,
        emailService: mockEmailService,
      );

      await service.refresh();

      verify(() => mockEmailService.syncContactsFromCore()).called(1);
      verify(
        () => mockEmailService.performBackgroundFetch(
          timeout: any(named: 'timeout'),
        ),
      ).called(1);
      verify(() => mockEmailService.refreshChatlistFromCore()).called(1);
    },
  );

  test('close waits for unread refresh progression during shutdown', () async {
    when(() => mockEmailService.hasActiveSession).thenReturn(true);
    when(
      () => mockEmailService.canReconnectConfiguredSession(),
    ).thenAnswer((_) async => false);
    final fetchCompleter = Completer<bool>();
    when(
      () => mockEmailService.performBackgroundFetch(
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((_) => fetchCompleter.future);

    final service = HomeRefreshSyncService(
      xmppService: mockXmppService,
      emailService: mockEmailService,
    );
    final updates = <HomeRefreshSyncUpdate>[];
    final updatesSubscription = service.syncUpdates.listen(updates.add);
    addTearDown(updatesSubscription.cancel);

    final refreshFuture = service.refreshUnreadOnly();
    await untilCalled(
      () => mockEmailService.performBackgroundFetch(
        timeout: any(named: 'timeout'),
      ),
    );

    var closeCompleted = false;
    final closeFuture = service.close().then((_) {
      closeCompleted = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(closeCompleted, isFalse);
    fetchCompleter.complete(true);
    await refreshFuture;
    await closeFuture;
    await Future<void>.delayed(Duration.zero);

    verify(() => mockEmailService.refreshChatlistFromCore()).called(1);
    expect(updates.map((update) => update.phase), [
      HomeRefreshSyncPhase.running,
      HomeRefreshSyncPhase.success,
    ]);
  });

  test('close can abort unread refresh progression during logout', () async {
    when(() => mockEmailService.hasActiveSession).thenReturn(true);
    when(
      () => mockEmailService.canReconnectConfiguredSession(),
    ).thenAnswer((_) async => false);
    final fetchCompleter = Completer<bool>();
    when(
      () => mockEmailService.performBackgroundFetch(
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((_) => fetchCompleter.future);

    final service = HomeRefreshSyncService(
      xmppService: mockXmppService,
      emailService: mockEmailService,
    );
    final updates = <HomeRefreshSyncUpdate>[];
    final updatesSubscription = service.syncUpdates.listen(updates.add);
    addTearDown(updatesSubscription.cancel);

    final refreshFuture = service.refreshUnreadOnly();
    await untilCalled(
      () => mockEmailService.performBackgroundFetch(
        timeout: any(named: 'timeout'),
      ),
    );

    var closeCompleted = false;
    final closeFuture = service.close(abortPendingSync: true).then((_) {
      closeCompleted = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(closeCompleted, isTrue);

    fetchCompleter.complete(true);
    await refreshFuture;
    await closeFuture;

    verifyNever(() => mockEmailService.refreshChatlistFromCore());
    expect(updates.map((update) => update.phase), [
      HomeRefreshSyncPhase.running,
    ]);
  });
}
