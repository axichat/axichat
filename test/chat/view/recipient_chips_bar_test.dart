import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/view/recipient_chips_bar.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('submitting email adds recipient', (tester) async {
    FanOutTarget? added;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipientChipsBar(
            recipients: const [],
            availableChats: const [],
            latestStatuses: const {},
            onRecipientAdded: (target) => added = target,
            onRecipientRemoved: (_) {},
            onRecipientToggled: (_) {},
          ),
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
    final recipient = ComposerRecipient(target: FanOutTarget.chat(chat));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipientChipsBar(
            recipients: [recipient],
            availableChats: const [],
            latestStatuses: const {},
            onRecipientAdded: (_) {},
            onRecipientRemoved: (_) {},
            onRecipientToggled: (key) => toggledKey = key,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(InputChip));
    expect(toggledKey, recipient.key);
  });

  testWidgets('backspace removes last non pinned recipient', (tester) async {
    String? removedKey;
    final recipients = [
      ComposerRecipient(
        target: FanOutTarget.chat(
          Chat(
            jid: 'dc-1@delta.chat',
            title: 'Pinned',
            type: ChatType.chat,
            lastChangeTimestamp: DateTime.now(),
          ),
        ),
        pinned: true,
      ),
      ComposerRecipient(
        target: FanOutTarget.chat(
          Chat(
            jid: 'dc-2@delta.chat',
            title: 'Removable',
            type: ChatType.chat,
            lastChangeTimestamp: DateTime.now(),
          ),
        ),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipientChipsBar(
            recipients: recipients,
            availableChats: const [],
            latestStatuses: const {},
            onRecipientAdded: (_) {},
            onRecipientRemoved: (key) => removedKey = key,
            onRecipientToggled: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    expect(removedKey, recipients.last.key);
  });
}
