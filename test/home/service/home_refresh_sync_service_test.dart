import 'package:axichat/src/email/service/email_sync_state.dart';
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

  test(
    'syncOnLogin runs a full restore once and unread-only afterward',
    () async {
      when(() => mockEmailService.hasActiveSession).thenReturn(true);
      when(
        () => mockEmailService.canReconnectConfiguredSession(),
      ).thenAnswer((_) async => false);

      final service = HomeRefreshSyncService(
        xmppService: mockXmppService,
        emailService: mockEmailService,
      );

      await service.syncOnLogin();
      await service.syncOnLogin();

      verify(() => mockEmailService.syncContactsFromCore()).called(1);
      verify(
        () => mockEmailService.performBackgroundFetch(
          timeout: any(named: 'timeout'),
        ),
      ).called(2);
      verify(() => mockEmailService.refreshChatlistFromCore()).called(2);
    },
  );

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
}
