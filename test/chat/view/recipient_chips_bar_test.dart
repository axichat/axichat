import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/ui/recipient_chips_bar.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('submitting email adds recipient', (tester) async {
    Contact? added;
    await tester.pumpWidget(
      _wrapWithTheme(
        RecipientChipsBar(
          recipients: const [],
          availableChats: const [],
          latestStatuses: const {},
          selfIdentity: const SelfAvatar(),
          onRecipientAdded: (target) => added = target,
          onRecipientRemoved: (_) {},
          onRecipientToggled: (_) {},
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'new@example.com');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(added?.address, 'new@example.com');
  });

  testWidgets('tapping chip toggles recipient', (tester) async {
    String? toggledKey;
    final chat = Chat(
      jid: 'dc-1@delta.chat',
      title: 'Bob',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
    );
    final recipient = ComposerRecipient(
      target: Contact.chat(chat: chat, shareSignatureEnabled: true),
    );

    await tester.pumpWidget(
      _wrapWithTheme(
        RecipientChipsBar(
          recipients: [recipient],
          availableChats: const [],
          latestStatuses: const {},
          selfIdentity: const SelfAvatar(),
          onRecipientAdded: (_) {},
          onRecipientRemoved: (_) {},
          onRecipientToggled: (key) => toggledKey = key,
        ),
      ),
    );

    await tester.tap(find.text('Bob'));
    expect(toggledKey, recipient.key);
  });

  testWidgets('backspace removes last non pinned recipient', (tester) async {
    String? removedKey;
    final recipients = [
      ComposerRecipient(
        target: Contact.chat(
          chat: Chat(
            jid: 'dc-1@delta.chat',
            title: 'Pinned',
            type: ChatType.chat,
            lastChangeTimestamp: DateTime.now(),
          ),
          shareSignatureEnabled: true,
        ),
        pinned: true,
      ),
      ComposerRecipient(
        target: Contact.chat(
          chat: Chat(
            jid: 'dc-2@delta.chat',
            title: 'Removable',
            type: ChatType.chat,
            lastChangeTimestamp: DateTime.now(),
          ),
          shareSignatureEnabled: true,
        ),
      ),
    ];

    await tester.pumpWidget(
      _wrapWithTheme(
        RecipientChipsBar(
          recipients: recipients,
          availableChats: const [],
          latestStatuses: const {},
          selfIdentity: const SelfAvatar(),
          onRecipientAdded: (_) {},
          onRecipientRemoved: (key) => removedKey = key,
          onRecipientToggled: (_) {},
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    expect(removedKey, recipients.last.key);
  });

  testWidgets('tapping delete icon removes recipient without toggling', (
    tester,
  ) async {
    String? removedKey;
    String? toggledKey;
    final chat = Chat(
      jid: 'dc-1@delta.chat',
      title: 'Bob',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
    );
    final recipient = ComposerRecipient(
      target: Contact.chat(chat: chat, shareSignatureEnabled: true),
    );

    await tester.pumpWidget(
      _wrapWithTheme(
        RecipientChipsBar(
          recipients: [recipient],
          availableChats: const [],
          latestStatuses: const {},
          selfIdentity: const SelfAvatar(),
          onRecipientAdded: (_) {},
          onRecipientRemoved: (key) => removedKey = key,
          onRecipientToggled: (key) => toggledKey = key,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.close));

    expect(removedKey, recipient.key);
    expect(toggledKey, isNull);
  });

  testWidgets('shows latest status for typed recipient via email key', (
    tester,
  ) async {
    final recipient = ComposerRecipient(
      target: Contact.address(
        address: 'CaseSensitive@Example.com',
        shareSignatureEnabled: true,
      ),
    );
    await tester.pumpWidget(
      _wrapWithTheme(
        RecipientChipsBar(
          recipients: [recipient],
          availableChats: const [],
          latestStatuses: const {
            'casesensitive@example.com': FanOutRecipientState.failed,
          },
          selfIdentity: const SelfAvatar(),
          onRecipientAdded: (_) {},
          onRecipientRemoved: (_) {},
          onRecipientToggled: (_) {},
        ),
      ),
    );

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('autocomplete suggests chats by prefix', (tester) async {
    await tester.pumpWidget(
      _wrapWithTheme(
        RecipientChipsBar(
          recipients: const [],
          availableChats: [
            Chat(
              jid: 'opus@axi.im',
              title: 'Opus',
              type: ChatType.chat,
              lastChangeTimestamp: DateTime(2024, 1, 1),
              emailAddress: 'opus@axi.im',
            ),
            Chat(
              jid: 'codex@axi.im',
              title: 'Codex',
              type: ChatType.chat,
              lastChangeTimestamp: DateTime(2024, 1, 2),
              emailAddress: 'codex@axi.im',
            ),
          ],
          latestStatuses: const {},
          selfIdentity: const SelfAvatar(),
          onRecipientAdded: (_) {},
          onRecipientRemoved: (_) {},
          onRecipientToggled: (_) {},
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'c');
    await tester.pumpAndSettle();

    expect(find.text('Codex'), findsOneWidget);
    expect(find.text('Opus'), findsNothing);
  });

  testWidgets('autocomplete suggests known domains after @', (tester) async {
    await tester.pumpWidget(
      _wrapWithTheme(
        RecipientChipsBar(
          recipients: const [],
          availableChats: [
            Chat(
              jid: 'opus@axi.im',
              title: 'Opus',
              type: ChatType.chat,
              lastChangeTimestamp: DateTime(2024, 1, 1),
              emailAddress: 'opus@axi.im',
            ),
          ],
          latestStatuses: const {},
          selfIdentity: const SelfAvatar(),
          onRecipientAdded: (_) {},
          onRecipientRemoved: (_) {},
          onRecipientToggled: (_) {},
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'ca@');
    await tester.pumpAndSettle();

    expect(find.text('ca@axi.im'), findsOneWidget);
  });
}

Widget _wrapWithTheme(Widget child) {
  final settingsCubit = _MockSettingsCubit();
  when(() => settingsCubit.state).thenReturn(const SettingsState());
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  return MaterialApp(
    home: BlocProvider<SettingsCubit>.value(
      value: settingsCubit,
      child: ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadSlateColorScheme.light(),
          brightness: Brightness.light,
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
