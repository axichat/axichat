import 'package:axichat/main.dart';
import 'package:axichat/src/notifications/bloc/notification_request_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNotificationService notificationService;
  late MockXmppService xmppService;

  setUp(() {
    notificationService = MockNotificationService();
    xmppService = MockXmppService();
    withForeground = true;
    resetForegroundNotifier(value: true);
  });

  tearDown(() {
    withForeground = false;
    resetForegroundNotifier(value: false);
  });

  test(
    'disableForegroundService clears the runtime foreground flag without clearing support',
    () async {
      final cubit = NotificationRequestCubit(
        notificationService: notificationService,
        xmppService: xmppService,
      );

      cubit.disableForegroundService();
      await pumpEventQueue();

      expect(foregroundServiceActive.value, isFalse);
      expect(withForeground, isTrue);
      expect(cubit.state.foregroundServiceActive, isFalse);

      await cubit.close();
    },
  );
}
