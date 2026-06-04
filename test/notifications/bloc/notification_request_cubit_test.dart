import 'package:axichat/main.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/foreground_runtime_controller.dart';
import 'package:axichat/src/notifications/bloc/notification_request_cubit.dart';
import 'package:axichat/src/xmpp/connection/foreground_socket.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNotificationService notificationService;
  late MockEmailService emailService;
  late MockXmppService xmppService;
  late ForegroundTaskBridge originalForegroundTaskBridge;

  setUp(() {
    notificationService = MockNotificationService();
    emailService = MockEmailService();
    xmppService = MockXmppService();
    originalForegroundTaskBridge = foregroundTaskBridge;
    foregroundTaskBridge = _StoppedForegroundTaskBridge();
    when(
      () => emailService.setForegroundKeepalive(false),
    ).thenAnswer((_) async {});
    when(
      () => emailService.setForegroundKeepalive(true),
    ).thenAnswer((_) async {});
    when(
      () => xmppService.disableForegroundSocketIfActive(),
    ).thenAnswer((_) async => true);
    when(
      () => xmppService.ensureForegroundSocketIfActive(),
    ).thenAnswer((_) async {});
    when(() => xmppService.connected).thenReturn(true);
    when(() => xmppService.hasConnectionSettings).thenReturn(true);
    when(() => xmppService.usingForegroundSocket).thenReturn(false);
    when(
      () => notificationService.hasAllNotificationPermissions(),
    ).thenAnswer((_) async => true);
    withForeground = true;
    resetForegroundNotifier(value: true);
  });

  tearDown(() {
    foregroundTaskBridge = originalForegroundTaskBridge;
    withForeground = false;
    resetForegroundNotifier(value: false);
  });

  test(
    'enableForegroundService rolls back transport leases when the bridge does not start',
    () async {
      resetForegroundNotifier(value: false);
      final cubit = _buildCubit(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final enabled = await cubit.enableForegroundService(
        allowCurrentSessionMigration: true,
      );

      expect(enabled, ForegroundActivationResult.failed);
      expect(foregroundServiceActive.value, isFalse);
      expect(withForeground, isFalse);
      expect(cubit.state.foregroundServiceActive, isFalse);
      verify(() => xmppService.ensureForegroundSocketIfActive()).called(1);
      verify(() => emailService.setForegroundKeepalive(true)).called(1);
      verify(() => emailService.setForegroundKeepalive(false)).called(1);
      verify(() => xmppService.disableForegroundSocketIfActive()).called(1);

      await cubit.close();
    },
  );

  test(
    'enableForegroundService retries when the active flag is stale',
    () async {
      final cubit = _buildCubit(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final enabled = await cubit.enableForegroundService(
        allowCurrentSessionMigration: true,
      );

      expect(enabled, ForegroundActivationResult.failed);
      expect(foregroundServiceActive.value, isFalse);
      expect(withForeground, isFalse);
      verify(() => xmppService.ensureForegroundSocketIfActive()).called(1);

      await cubit.close();
    },
  );

  test(
    'enableForegroundService refreshes transports when bridge is already running',
    () async {
      foregroundTaskBridge = _RunningForegroundTaskBridge();
      when(() => xmppService.usingForegroundSocket).thenReturn(true);
      final cubit = _buildCubit(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final enabled = await cubit.enableForegroundService(
        allowCurrentSessionMigration: true,
      );

      expect(enabled, ForegroundActivationResult.active);
      expect(foregroundServiceActive.value, isTrue);
      expect(withForeground, isTrue);
      verify(() => xmppService.ensureForegroundSocketIfActive()).called(1);
      verify(() => emailService.setForegroundKeepalive(true)).called(1);

      await cubit.close();
    },
  );

  test(
    'enableForegroundService fails when XMPP remains on a direct socket',
    () async {
      foregroundTaskBridge = _RunningForegroundTaskBridge();
      final cubit = _buildCubit(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final enabled = await cubit.enableForegroundService(
        allowCurrentSessionMigration: true,
      );

      expect(enabled, ForegroundActivationResult.failed);
      expect(foregroundServiceActive.value, isTrue);
      expect(withForeground, isFalse);
      verify(() => xmppService.ensureForegroundSocketIfActive()).called(1);
      verify(() => emailService.setForegroundKeepalive(true)).called(1);
      verify(() => emailService.setForegroundKeepalive(false)).called(1);
      verify(() => xmppService.disableForegroundSocketIfActive()).called(1);

      await cubit.close();
    },
  );

  test(
    'enableForegroundService prepares foreground mode for the next reconnect',
    () async {
      resetForegroundNotifier(value: false);
      when(() => xmppService.connected).thenReturn(false);
      final cubit = _buildCubit(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final enabled = await cubit.enableForegroundService();

      expect(enabled, ForegroundActivationResult.active);
      expect(foregroundServiceActive.value, isFalse);
      expect(withForeground, isTrue);
      expect(cubit.state.foregroundServiceActive, isFalse);
      verifyNever(() => xmppService.ensureForegroundSocketIfActive());
      verify(() => emailService.setForegroundKeepalive(true)).called(1);

      await cubit.close();
    },
  );

  test(
    'enableForegroundService defers connected direct sessions until restart',
    () async {
      resetForegroundNotifier(value: false);
      final cubit = _buildCubit(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final enabled = await cubit.enableForegroundService();

      expect(enabled, ForegroundActivationResult.deferredUntilRestart);
      expect(foregroundServiceActive.value, isFalse);
      expect(withForeground, isFalse);
      verifyNever(() => xmppService.ensureForegroundSocketIfActive());
      verifyNever(() => emailService.setForegroundKeepalive(true));

      await cubit.close();
    },
  );

  test(
    'disableForegroundService cleans transports when bridge is already stopped',
    () async {
      resetForegroundNotifier(value: false);
      final cubit = _buildCubit(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final disabled = await cubit.disableForegroundService();

      expect(disabled, isTrue);
      expect(foregroundServiceActive.value, isFalse);
      expect(withForeground, isFalse);
      verify(() => emailService.setForegroundKeepalive(false)).called(1);
      verify(() => xmppService.disableForegroundSocketIfActive()).called(1);

      await cubit.close();
    },
  );

  test(
    'disableForegroundService preserves preference when stopped email keepalive fails',
    () async {
      resetForegroundNotifier(value: false);
      when(
        () => emailService.setForegroundKeepalive(false),
      ).thenThrow(Exception('stop failed'));
      final cubit = _buildCubit(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final disabled = await cubit.disableForegroundService();

      expect(disabled, isFalse);
      expect(foregroundServiceActive.value, isFalse);
      expect(withForeground, isTrue);
      verify(() => xmppService.disableForegroundSocketIfActive()).called(1);

      await cubit.close();
    },
  );

  test(
    'disableForegroundService clears the runtime foreground flag after service stops',
    () async {
      final cubit = _buildCubit(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final disabled = await cubit.disableForegroundService();

      expect(disabled, isTrue);
      expect(foregroundServiceActive.value, isFalse);
      expect(withForeground, isFalse);
      expect(cubit.state.foregroundServiceActive, isFalse);

      await cubit.close();
    },
  );

  test(
    'disableForegroundService clears the runtime flag after XMPP releases the foreground lease',
    () async {
      foregroundTaskBridge = _RunningForegroundTaskBridge();
      when(() => xmppService.disableForegroundSocketIfActive()).thenAnswer((
        _,
      ) async {
        foregroundTaskBridge = _StoppedForegroundTaskBridge();
        return true;
      });
      final cubit = _buildCubit(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final disabled = await cubit.disableForegroundService();

      expect(disabled, isTrue);
      expect(foregroundServiceActive.value, isFalse);
      expect(withForeground, isFalse);
      expect(cubit.state.foregroundServiceActive, isFalse);

      await cubit.close();
    },
  );

  test(
    'disableForegroundService force-stops stale service after transport cleanup',
    () async {
      foregroundTaskBridge = _RunningForegroundTaskBridge();
      final cubit = _buildCubit(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final disabled = await cubit.disableForegroundService();

      expect(disabled, isTrue);
      expect(foregroundServiceActive.value, isFalse);
      expect(withForeground, isFalse);
      expect(cubit.state.foregroundServiceActive, isFalse);
      verify(() => emailService.setForegroundKeepalive(false)).called(1);
      verify(() => xmppService.disableForegroundSocketIfActive()).called(1);

      await cubit.close();
    },
  );

  test(
    'disableForegroundService preserves the runtime flag if XMPP cannot leave foreground',
    () async {
      foregroundTaskBridge = _RunningForegroundTaskBridge();
      when(
        () => xmppService.disableForegroundSocketIfActive(),
      ).thenAnswer((_) async => false);
      final cubit = _buildCubit(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final disabled = await cubit.disableForegroundService();

      expect(disabled, isFalse);
      expect(foregroundServiceActive.value, isTrue);
      expect(withForeground, isTrue);
      expect(cubit.state.foregroundServiceActive, isTrue);

      await cubit.close();
    },
  );

  test(
    'disableForegroundService reconciles a running bridge when runtime flag is stale',
    () async {
      resetForegroundNotifier(value: false);
      foregroundTaskBridge = _RunningForegroundTaskBridge();
      when(() => xmppService.disableForegroundSocketIfActive()).thenAnswer((
        _,
      ) async {
        foregroundTaskBridge = _StoppedForegroundTaskBridge();
        return true;
      });
      final cubit = _buildCubit(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final disabled = await cubit.disableForegroundService();

      expect(disabled, isTrue);
      expect(foregroundServiceActive.value, isFalse);
      expect(withForeground, isFalse);

      await cubit.close();
    },
  );

  test(
    'refreshAfterSessionEnd clears foreground intent after the bridge stops',
    () async {
      resetForegroundNotifier(value: true);
      final controller = _buildController(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final running = await controller.refreshAfterSessionEnd();

      expect(running, isFalse);
      expect(foregroundServiceActive.value, isFalse);
      expect(withForeground, isFalse);
    },
  );

  test(
    'refreshAfterSessionEnd preserves foreground intent while the bridge runs',
    () async {
      foregroundTaskBridge = _RunningForegroundTaskBridge();
      final controller = _buildController(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final running = await controller.refreshAfterSessionEnd();

      expect(running, isTrue);
      expect(foregroundServiceActive.value, isTrue);
      expect(withForeground, isTrue);
    },
  );

  test(
    'prepareForNextXmppConnection clears intent without active XMPP migration',
    () async {
      final controller = _buildController(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      await controller.prepareForNextXmppConnection(desired: false);

      expect(withForeground, isFalse);
      verify(() => emailService.setForegroundKeepalive(false)).called(1);
      verifyNever(() => xmppService.disableForegroundSocketIfActive());
      verifyNever(() => xmppService.ensureForegroundSocketIfActive());
    },
  );

  test(
    'prepareForNextXmppConnection sets intent without active XMPP migration',
    () async {
      resetForegroundNotifier(value: false);
      final controller = _buildController(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      await controller.prepareForNextXmppConnection(desired: true);

      expect(withForeground, isTrue);
      verifyNever(() => emailService.setForegroundKeepalive(true));
      verifyNever(() => xmppService.disableForegroundSocketIfActive());
      verifyNever(() => xmppService.ensureForegroundSocketIfActive());
    },
  );

  test(
    'restoreIfPreferred clears stale foreground intent without permissions',
    () async {
      when(
        () => notificationService.hasAllNotificationPermissions(),
      ).thenAnswer((_) async => false);
      final controller = _buildController(
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final restored = await controller.restoreIfPreferred(desired: true);

      expect(restored, isFalse);
      expect(foregroundServiceActive.value, isFalse);
      expect(withForeground, isFalse);
      verify(() => xmppService.disableForegroundSocketIfActive()).called(1);
      verify(() => emailService.setForegroundKeepalive(false)).called(1);
    },
  );

  test(
    'restoreIfPreferred clears stale foreground intent without platform support',
    () async {
      final controller = _buildController(
        capability: const _NoForegroundCapability(),
        notificationService: notificationService,
        emailService: emailService,
        xmppService: xmppService,
      );

      final restored = await controller.restoreIfPreferred(desired: true);

      expect(restored, isFalse);
      expect(foregroundServiceActive.value, isFalse);
      expect(withForeground, isFalse);
      verify(() => xmppService.disableForegroundSocketIfActive()).called(1);
      verify(() => emailService.setForegroundKeepalive(false)).called(1);
    },
  );
}

NotificationRequestCubit _buildCubit({
  required MockNotificationService notificationService,
  required MockEmailService emailService,
  required MockXmppService xmppService,
}) {
  return NotificationRequestCubit(
    notificationService: notificationService,
    foregroundRuntimeController: _buildController(
      notificationService: notificationService,
      emailService: emailService,
      xmppService: xmppService,
    ),
  );
}

ForegroundRuntimeController _buildController({
  Capability capability = const _ForegroundCapability(),
  required MockNotificationService notificationService,
  required MockEmailService emailService,
  required MockXmppService xmppService,
}) {
  return ForegroundRuntimeController(
    capability: capability,
    notificationService: notificationService,
    xmppService: xmppService,
    emailService: emailService,
  );
}

class _ForegroundCapability extends Capability {
  const _ForegroundCapability();

  @override
  bool get canForegroundService => true;
}

class _NoForegroundCapability extends Capability {
  const _NoForegroundCapability();

  @override
  bool get canForegroundService => false;
}

class _StoppedForegroundTaskBridge implements ForegroundTaskBridge {
  @override
  Future<void> acquire({
    required String clientId,
    ForegroundServiceConfig? config,
  }) async {}

  @override
  Future<bool> isRunning() async => false;

  @override
  Future<bool> stopIfRunning() async => false;

  @override
  Future<void> release(String clientId) async {}

  @override
  void registerListener(
    String clientId,
    ForegroundTaskMessageHandler handler,
  ) {}

  @override
  Future<void> send(List<Object> parts) async {}

  @override
  void unregisterListener(String clientId) {}
}

class _RunningForegroundTaskBridge implements ForegroundTaskBridge {
  var _running = true;

  @override
  Future<void> acquire({
    required String clientId,
    ForegroundServiceConfig? config,
  }) async {}

  @override
  Future<bool> isRunning() async => _running;

  @override
  Future<bool> stopIfRunning() async {
    final wasRunning = _running;
    _running = false;
    return wasRunning;
  }

  @override
  Future<void> release(String clientId) async {}

  @override
  void registerListener(
    String clientId,
    ForegroundTaskMessageHandler handler,
  ) {}

  @override
  Future<void> send(List<Object> parts) async {}

  @override
  void unregisterListener(String clientId) {}
}
