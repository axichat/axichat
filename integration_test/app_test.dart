import 'dart:async';

import 'package:axichat/main.dart' as app;
import 'package:axichat/src/authentication/view/login_form.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/profile/view/profile_card.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

extension on WidgetTester {
  Future<void> waitUntil(Finder finder) async {
    final timer = Timer(
      const Duration(seconds: 10),
      () => throw TimeoutException('Timed out waiting for $finder'),
    );

    while (finder.evaluate().isEmpty) {
      await pumpAndSettle();
    }

    timer.cancel();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late final String username;
  late final String password;

  setUpAll(() async {
    await const FlutterSecureStorage().deleteAll();

    username = const String.fromEnvironment('USERNAME');
    if (username.isEmpty) {
      throw StateError('Undefined USERNAME environment variable.');
    }

    password = const String.fromEnvironment('PASSWORD');
    if (password.isEmpty) {
      throw StateError('Undefined PASSWORD environment variable.');
    }

    // final envRaw = await rootBundle.loadString('.env');
    // for (final definition in envRaw.split('\n')) {
    //   if (definition.startsWith('#')) continue;
    //
    //   final terms = definition.split('=');
    //   env[terms[0]] = terms[1];
    // }
  });

  group('End-to-end', () {
    testWidgets('Log in', (tester) async {
      app.main();

      await tester.waitUntil(find.text(LoginForm.title));

      await tester.enterText(
        find.byKey(loginUsernameKey),
        username,
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(loginPasswordKey),
        password,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ShadCheckboxFormField));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(loginSubmitKey));

      await tester.waitUntil(find.byType(ProfileCard));
    });
  });
}
