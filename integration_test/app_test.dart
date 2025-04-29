import 'dart:async';

import 'package:axichat/main.dart' as app;
import 'package:axichat/src/authentication/view/login_form.dart';
import 'package:axichat/src/authentication/view/logout_button.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/profile/view/profile_card.dart';
import 'package:axichat/src/roster/view/roster_add_button.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

extension on WidgetTester {
  Future<void> pumpUntil(Finder finder) async {
    final timer = Timer(
      const Duration(seconds: 45),
      () => throw TimeoutException('Timed out waiting for $finder'),
    );

    while (finder.evaluate().isEmpty) {
      await pumpAndSettle();
    }

    timer.cancel();
  }

  Future<void> pumpUntilGone(Finder finder) async {
    final timer = Timer(
      const Duration(seconds: 15),
      () => throw TimeoutException('Timed out waiting for $finder'),
    );

    while (finder.evaluate().isNotEmpty) {
      await pumpAndSettle();
    }

    timer.cancel();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late final String username;
  late final String password;
  late final String contactJid;

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

    contactJid = const String.fromEnvironment('CONTACT_JID');
    if (contactJid.isEmpty) {
      throw StateError('Undefined CONTACT_JID environment variable.');
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
    testWidgets(
      'Critical path: log in, add contact, send message, '
      'remove contact, log out.',
      (tester) async {
        await app.main();

        await tester.pumpAndSettle(const Duration(seconds: 3));

        await tester.pumpUntil(find.text(LoginForm.title));

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

        final findProfileCard = find.byType(ProfileCard);
        await tester.pumpUntil(findProfileCard);

        final findContactsTab = find.widgetWithText(Tab, 'Contacts');
        await tester.tap(findContactsTab);

        final findRosterAddButton = find.byType(RosterAddButton);
        await tester.pumpUntil(findRosterAddButton);
        await tester.tap(findRosterAddButton);

        final findJidInput = find.byType(JidInput);
        await tester.pumpUntil(findJidInput);
        await tester.enterText(findJidInput, contactJid);

        await pumpEventQueue();
        await tester.pumpAndSettle();

        final findContinueButton = find.widgetWithText(ShadButton, 'Continue');
        await tester.tap(findContinueButton);

        final findRosterTile = find.widgetWithText(AxiListTile, contactJid);
        await tester.pumpUntil(findRosterTile);

        final findChatsTab = find.widgetWithText(Tab, 'Chats');
        await tester.pumpUntil(findChatsTab);
        await tester.pumpUntilGone(find.byType(ShadToast));
        await tester.tap(findChatsTab);

        await tester.pumpAndSettle();

        await tester.tap(find.byKey(Key(contactJid)).first);

        await tester.pumpUntil(find.byType(DashChat));

        const message = 'Hello';
        await tester.enterText(find.byType(TextField), message);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithIcon(ShadButton, Icons.send));
        await tester.pumpUntil(find.byWidgetPredicate((widget) =>
            widget is DynamicInlineText && widget.text.text == message));

        await tester.tap(
          find.widgetWithIcon(ShadButton, LucideIcons.arrowLeft),
        );

        await tester.pumpUntil(findContactsTab);
        await tester.tap(findContactsTab);

        await tester.pumpUntil(findRosterTile);

        await tester.drag(findRosterTile, const Offset(300, 0));

        await tester.pumpUntil(find.widgetWithText(ShadDialog, 'Confirm'));

        await tester.tap(findContinueButton);

        await pumpEventQueue();
        await tester.pumpAndSettle();

        expect(findRosterTile, findsNothing);

        await tester.pumpUntil(findProfileCard);
        await tester.pumpUntilGone(find.byType(ShadToast));
        await tester.tap(findProfileCard);

        final findLogoutButton = find.byType(LogoutButton);
        await tester.pumpUntil(findLogoutButton);
        await tester.tap(findLogoutButton);

        await tester.pumpUntil(find.text(LogoutButton.title));
        await tester.tap(find.widgetWithText(ListTile, 'Burn'));

        await tester.pumpAndSettle();

        await tester.tap(findContinueButton);

        await tester.pumpUntil(find.text(LoginForm.title));
      },
    );
  });
}
