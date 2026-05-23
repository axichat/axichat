import 'dart:async';

import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
import 'package:axichat/src/localization/app_localizations.dart';
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
          onRecipientAdded: (target) {
            added = target;
            return true;
          },
          onRecipientRemoved: (_) {},
        ),
      ),
    );
    await _submitRecipientText(tester, 'new@example.com');
    expect(added?.address, 'new@example.com');
  });

  testWidgets('manual recipient entry rejects invalid email addresses', (
    tester,
  ) async {
    final added = <Contact>[];
    await tester.pumpWidget(
      _wrapWithTheme(
        RecipientChipsBar(
          recipients: const [],
          availableChats: const [],
          latestStatuses: const {},
          selfIdentity: const SelfAvatar(),
          onRecipientAdded: (target) {
            added.add(target);
            return true;
          },
          onRecipientRemoved: (_) {},
        ),
      ),
    );

    for (final value in const ['alice', 'alice@', 'alice@server']) {
      await _submitRecipientText(tester, value);
    }

    expect(added, isEmpty);
  });

  testWidgets('manual recipient entry submits exact display name', (
    tester,
  ) async {
    final added = <Contact>[];
    await tester.pumpWidget(
      _wrapWithTheme(
        RecipientChipsBar(
          recipients: const [],
          availableChats: [_chat(jid: 'alice@example.com', title: 'Alice')],
          latestStatuses: const {},
          selfIdentity: const SelfAvatar(),
          onRecipientAdded: (target) {
            added.add(target);
            return true;
          },
          onRecipientRemoved: (_) {},
        ),
      ),
    );

    await _submitRecipientText(tester, 'Alice');

    expect(added.single.chat?.jid, 'alice@example.com');
  });

  testWidgets('manual recipient entry preserves spaces in display names', (
    tester,
  ) async {
    final added = <Contact>[];
    await tester.pumpWidget(
      _wrapWithTheme(
        RecipientChipsBar(
          recipients: const [],
          availableChats: [
            _chat(
              jid: 'alice.smith@example.com',
              title: 'alice.smith@example.com',
              contactDisplayName: 'Alice Smith',
            ),
          ],
          latestStatuses: const {},
          selfIdentity: const SelfAvatar(),
          onRecipientAdded: (target) {
            added.add(target);
            return true;
          },
          onRecipientRemoved: (_) {},
        ),
      ),
    );

    expect(_inputField(tester).inputFormatters, isNull);
    await _submitRecipientText(tester, 'Alice Smith');

    expect(added.single.chat?.jid, 'alice.smith@example.com');
  });

  testWidgets(
    'manual recipient entry submits exact title when contact name differs',
    (tester) async {
      final added = <Contact>[];
      await tester.pumpWidget(
        _wrapWithTheme(
          RecipientChipsBar(
            recipients: const [],
            availableChats: [
              _chat(
                jid: 'alice@example.com',
                title: 'Alice Inbox',
                contactDisplayName: 'Alice Smith',
              ),
            ],
            latestStatuses: const {},
            selfIdentity: const SelfAvatar(),
            onRecipientAdded: (target) {
              added.add(target);
              return true;
            },
            onRecipientRemoved: (_) {},
          ),
        ),
      );

      await _submitRecipientText(tester, 'Alice Inbox');

      expect(added.single.chat?.jid, 'alice@example.com');
    },
  );

  testWidgets(
    'manual recipient entry scans exact display names past suggestion cap',
    (tester) async {
      final added = <Contact>[];
      await tester.pumpWidget(
        _wrapWithTheme(
          RecipientChipsBar(
            recipients: const [],
            availableChats: [
              for (var i = 0; i < 8; i++)
                _chat(jid: 'alexandra$i@example.com', title: 'Alexandra $i'),
              _chat(jid: 'alex@example.com', title: 'Alex'),
            ],
            latestStatuses: const {},
            selfIdentity: const SelfAvatar(),
            onRecipientAdded: (target) {
              added.add(target);
              return true;
            },
            onRecipientRemoved: (_) {},
          ),
        ),
      );

      await _submitRecipientText(tester, 'Alex');

      expect(added.single.chat?.jid, 'alex@example.com');
    },
  );

  testWidgets(
    'manual recipient entry keeps capped duplicate exact names unresolved',
    (tester) async {
      final added = <Contact>[];
      await tester.pumpWidget(
        _wrapWithTheme(
          RecipientChipsBar(
            recipients: const [],
            availableChats: [
              for (var i = 0; i < 8; i++)
                _chat(jid: 'alexandra$i@example.com', title: 'Alexandra $i'),
              _chat(jid: 'alex.one@example.com', title: 'Alex'),
              _chat(jid: 'alex.two@example.com', title: 'Alex'),
            ],
            latestStatuses: const {},
            selfIdentity: const SelfAvatar(),
            onRecipientAdded: (target) {
              added.add(target);
              return true;
            },
            onRecipientRemoved: (_) {},
          ),
        ),
      );

      await _submitRecipientText(tester, 'Alex');

      expect(added, isEmpty);
      expect(_inputField(tester).controller!.text, 'Alex');
    },
  );

  testWidgets(
    'manual recipient entry resolves display names without addresses',
    (tester) async {
      final added = <Contact>[];
      await tester.pumpWidget(
        _wrapWithTheme(
          RecipientChipsBar(
            recipients: const [],
            availableChats: [_chat(jid: 'bob@example.com', title: 'Bob')],
            latestStatuses: const {},
            selfIdentity: const SelfAvatar(),
            allowAddressTargets: false,
            onRecipientAdded: (target) {
              added.add(target);
              return true;
            },
            onRecipientRemoved: (_) {},
          ),
        ),
      );

      await _submitRecipientText(tester, 'Bob');

      expect(added.single.chat?.jid, 'bob@example.com');
    },
  );

  testWidgets(
    'manual recipient entry keeps duplicate display names unresolved',
    (tester) async {
      final added = <Contact>[];
      await tester.pumpWidget(
        _wrapWithTheme(
          RecipientChipsBar(
            recipients: const [],
            availableChats: [
              _chat(jid: 'alex.one@example.com', title: 'Alex'),
              _chat(jid: 'alex.two@example.com', title: 'Alex'),
            ],
            latestStatuses: const {},
            selfIdentity: const SelfAvatar(),
            onRecipientAdded: (target) {
              added.add(target);
              return true;
            },
            onRecipientRemoved: (_) {},
          ),
        ),
      );

      await _submitRecipientText(tester, 'Alex');

      expect(added, isEmpty);
      expect(_inputField(tester).controller!.text, 'Alex');
    },
  );

  testWidgets(
    'manual recipient entry keeps duplicate display aliases unresolved',
    (tester) async {
      final added = <Contact>[];
      await tester.pumpWidget(
        _wrapWithTheme(
          RecipientChipsBar(
            recipients: const [],
            availableChats: [
              _chat(
                jid: 'alex.title@example.com',
                title: 'Alex',
                contactDisplayName: 'Alex Title',
              ),
              _chat(
                jid: 'alex.name@example.com',
                title: 'Alex Name',
                contactDisplayName: 'Alex',
              ),
            ],
            latestStatuses: const {},
            selfIdentity: const SelfAvatar(),
            onRecipientAdded: (target) {
              added.add(target);
              return true;
            },
            onRecipientRemoved: (_) {},
          ),
        ),
      );

      await _submitRecipientText(tester, 'Alex');

      expect(added, isEmpty);
      expect(_inputField(tester).controller!.text, 'Alex');
    },
  );

  testWidgets(
    'manual recipient entry prefers valid addresses over email display names',
    (tester) async {
      final added = <Contact>[];
      await tester.pumpWidget(
        _wrapWithTheme(
          RecipientChipsBar(
            recipients: const [],
            availableChats: [
              _chat(
                jid: 'first@example.com',
                title: 'First',
                contactDisplayName: 'team@example.com',
              ),
              _chat(
                jid: 'second@example.com',
                title: 'Second',
                contactDisplayName: 'team@example.com',
              ),
            ],
            latestStatuses: const {},
            selfIdentity: const SelfAvatar(),
            onRecipientAdded: (target) {
              added.add(target);
              return true;
            },
            onRecipientRemoved: (_) {},
          ),
        ),
      );

      await _submitRecipientText(tester, 'team@example.com');

      expect(added.single.address, 'team@example.com');
      expect(added.single.chat, isNull);
    },
  );

  testWidgets(
    'manual recipient entry resolves email display names without addresses',
    (tester) async {
      final added = <Contact>[];
      await tester.pumpWidget(
        _wrapWithTheme(
          RecipientChipsBar(
            recipients: const [],
            availableChats: [
              _chat(
                jid: 'team-chat@example.com',
                title: 'Team',
                contactDisplayName: 'team@example.com',
              ),
            ],
            latestStatuses: const {},
            selfIdentity: const SelfAvatar(),
            allowAddressTargets: false,
            onRecipientAdded: (target) {
              added.add(target);
              return true;
            },
            onRecipientRemoved: (_) {},
          ),
        ),
      );

      await _submitRecipientText(tester, 'team@example.com');

      expect(added.single.chat?.jid, 'team-chat@example.com');
    },
  );

  testWidgets('failed async add keeps typed address', (tester) async {
    final completer = Completer<bool>();
    await tester.pumpWidget(
      _wrapWithTheme(
        RecipientChipsBar(
          recipients: const [],
          availableChats: const [],
          latestStatuses: const {},
          selfIdentity: const SelfAvatar(),
          onRecipientAdded: (_) => completer.future,
          onRecipientRemoved: (_) {},
        ),
      ),
    );

    await _submitRecipientText(tester, 'new@example.com');
    expect(_inputField(tester).controller!.text, 'new@example.com');

    completer.complete(false);
    await tester.pump();

    expect(_inputField(tester).controller!.text, 'new@example.com');
  });

  testWidgets('tapping chip toggles between display name and address', (
    tester,
  ) async {
    final chat = Chat(
      jid: 'dc-1@delta.chat',
      title: 'Bob',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
      emailAddress: 'bob@example.com',
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
          onRecipientAdded: (_) => true,
          onRecipientRemoved: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();

    expect(find.text('bob@example.com'), findsOneWidget);

    await tester.tap(find.text('bob@example.com'));
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('backspace confirms then removes last non pinned recipient', (
    tester,
  ) async {
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
          onRecipientAdded: (_) => true,
          onRecipientRemoved: (key) => removedKey = key,
        ),
      ),
    );

    await _pressBackspace(tester);
    expect(removedKey, isNull);

    await _pressBackspace(tester);
    expect(removedKey, recipients.last.key);
  });

  testWidgets('tapping delete icon removes recipient without toggling', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithTheme(const _RecipientChipsBarRemovalHarness()),
    );

    expect(find.text('Bob'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsNothing);
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
          onRecipientAdded: (_) => true,
          onRecipientRemoved: (_) {},
        ),
      ),
    );

    expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);
  });

  testWidgets('does not show sent status checkmarks on recipient chips', (
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
            'casesensitive@example.com': FanOutRecipientState.sent,
          },
          selfIdentity: const SelfAvatar(),
          onRecipientAdded: (_) => true,
          onRecipientRemoved: (_) {},
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsNothing);
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
          onRecipientAdded: (_) => true,
          onRecipientRemoved: (_) {},
        ),
      ),
    );

    final options = _autocompleteOptionsFor(tester, 'c');
    expect(
      options.map((option) => option.chat?.title ?? option.displayName),
      contains('Codex'),
    );
    expect(
      options.map((option) => option.chat?.title ?? option.displayName),
      isNot(contains('Opus')),
    );
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
          onRecipientAdded: (_) => true,
          onRecipientRemoved: (_) {},
        ),
      ),
    );

    final options = _autocompleteOptionsFor(tester, 'ca@');
    expect(
      options.map(
        (option) =>
            option.address ??
            option.chat?.emailAddress ??
            option.chat?.jid ??
            option.displayName,
      ),
      contains('ca@axi.im'),
    );
  });

  testWidgets(
    'empty recipient input stays on chip row when compact space fits',
    (tester) async {
      final recipient = _chatRecipient(title: 'Bob');
      await tester.pumpWidget(
        _wrapWithTheme(
          SizedBox(
            width: 320,
            child: RecipientChipsBar(
              recipients: [recipient],
              availableChats: const [],
              latestStatuses: const {},
              selfIdentity: const SelfAvatar(),
              onRecipientAdded: (_) => true,
              onRecipientRemoved: (_) {},
            ),
          ),
        ),
      );

      final chipCenter = tester.getCenter(find.text('Bob'));
      final inputCenter = tester.getCenter(_recipientInputFieldFinder());

      expect((inputCenter.dy - chipCenter.dy).abs(), lessThan(8));
    },
  );

  testWidgets('empty recipient input wraps when compact space does not fit', (
    tester,
  ) async {
    final recipient = _chatRecipient(title: 'Bob');
    await tester.pumpWidget(
      _wrapWithTheme(
        SizedBox(
          width: 140,
          child: RecipientChipsBar(
            recipients: [recipient],
            availableChats: const [],
            latestStatuses: const {},
            selfIdentity: const SelfAvatar(),
            onRecipientAdded: (_) => true,
            onRecipientRemoved: (_) {},
          ),
        ),
      ),
    );

    final chipCenter = tester.getCenter(find.text('Bob'));
    final inputCenter = tester.getCenter(_recipientInputFieldFinder());

    expect(inputCenter.dy - chipCenter.dy, greaterThan(24));
  });

  testWidgets('recipient input expands for long typed text', (tester) async {
    await tester.pumpWidget(
      _wrapWithTheme(
        SizedBox(
          width: 400,
          child: RecipientChipsBar(
            recipients: const [],
            availableChats: const [],
            latestStatuses: const {},
            selfIdentity: const SelfAvatar(),
            onRecipientAdded: (_) => true,
            onRecipientRemoved: (_) {},
          ),
        ),
      ),
    );

    final inputFinder = _recipientInputFieldFinder();
    final initialWidth = tester.getSize(inputFinder).width;
    final field = tester.widget<AxiTextField>(inputFinder);
    field.controller!.text = 'averylongrecipientaddress@example.com';
    await tester.pump();

    final expandedWidth = tester.getSize(inputFinder).width;

    expect(expandedWidth, greaterThan(initialWidth));
    expect(expandedWidth, lessThanOrEqualTo(260));
  });

  testWidgets('grouped text field receives focus after recipient submission', (
    tester,
  ) async {
    final added = <Contact>[];
    final targetFocusNode = FocusNode();
    addTearDown(targetFocusNode.dispose);
    await tester.pumpWidget(
      _wrapWithTheme(
        _RecipientFocusTransferHarness(
          targetFocusNode: targetFocusNode,
          onRecipientAdded: (target) {
            added.add(target);
            return true;
          },
        ),
      ),
    );

    final recipientFieldFinder = _recipientInputFieldFinder();
    final field = tester.widget<AxiTextField>(recipientFieldFinder);
    field.focusNode!.requestFocus();
    field.controller!.text = 'new@example.com';
    await tester.pump();

    await tester.tap(_targetFieldFinder);
    await tester.pump();

    expect(added.single.address, 'new@example.com');
    expect(targetFocusNode.hasFocus, isTrue);
  });

  testWidgets('grouped text field closes open autocomplete on focus transfer', (
    tester,
  ) async {
    final added = <Contact>[];
    final targetFocusNode = FocusNode();
    addTearDown(targetFocusNode.dispose);
    await tester.pumpWidget(
      _wrapWithTheme(
        _RecipientFocusTransferHarness(
          targetFocusNode: targetFocusNode,
          suggestionAddresses: const {'new@example.com'},
          onRecipientAdded: (target) {
            added.add(target);
            return true;
          },
        ),
      ),
    );

    final recipientFieldFinder = _recipientInputFieldFinder();
    final field = tester.widget<AxiTextField>(recipientFieldFinder);
    field.focusNode!.requestFocus();
    field.controller!.text = 'new@example.com';
    await tester.pump();
    await tester.pump();

    expect(_autocompleteOptionsListFinder, findsOneWidget);

    await tester.tap(_targetFieldFinder);
    await tester.pump();
    await tester.pump();

    expect(added.single.address, 'new@example.com');
    expect(targetFocusNode.hasFocus, isTrue);
    expect(_autocompleteOptionsListFinder, findsNothing);
  });

  testWidgets('outside tap closes autocomplete and submits pending recipient', (
    tester,
  ) async {
    final added = <Contact>[];
    final targetFocusNode = FocusNode();
    var outsideTapped = false;
    addTearDown(targetFocusNode.dispose);
    await tester.pumpWidget(
      _wrapWithTheme(
        _RecipientFocusTransferHarness(
          targetFocusNode: targetFocusNode,
          suggestionAddresses: const {'new@example.com'},
          onOutsideTapped: () => outsideTapped = true,
          onRecipientAdded: (target) {
            added.add(target);
            return true;
          },
        ),
      ),
    );

    final recipientFieldFinder = _recipientInputFieldFinder();
    final field = tester.widget<AxiTextField>(recipientFieldFinder);
    field.focusNode!.requestFocus();
    field.controller!.text = 'new@example.com';
    await tester.pump();
    await tester.pump();

    expect(_autocompleteOptionsListFinder, findsOneWidget);

    await tester.tap(_outsideTapTargetFinder);
    await tester.pump();
    await tester.pump();

    expect(outsideTapped, isFalse);
    expect(added.single.address, 'new@example.com');
    expect(field.focusNode!.hasFocus, isFalse);
    expect(_autocompleteOptionsListFinder, findsNothing);
  });

  testWidgets('outside tap with pending recipient consumes tapped target', (
    tester,
  ) async {
    final completer = Completer<bool>();
    Contact? submitted;
    final targetFocusNode = FocusNode();
    var outsideTapped = false;
    addTearDown(targetFocusNode.dispose);
    await tester.pumpWidget(
      _wrapWithTheme(
        _RecipientFocusTransferHarness(
          targetFocusNode: targetFocusNode,
          onOutsideTapped: () => outsideTapped = true,
          onRecipientAdded: (target) {
            submitted = target;
            return completer.future;
          },
        ),
      ),
    );

    final recipientFieldFinder = _recipientInputFieldFinder();
    final field = tester.widget<AxiTextField>(recipientFieldFinder);
    field.focusNode!.requestFocus();
    field.controller!.text = 'new@example.com';
    await tester.pump();

    await tester.tap(_outsideTapTargetFinder);
    await tester.pump();

    expect(outsideTapped, isFalse);
    expect(submitted?.address, 'new@example.com');
    expect(field.controller!.text, 'new@example.com');

    completer.complete(true);
    await tester.pump();

    expect(field.controller!.text, isEmpty);
  });

  testWidgets('outside tap with empty recipient reaches tapped target', (
    tester,
  ) async {
    final targetFocusNode = FocusNode();
    var outsideTapped = false;
    addTearDown(targetFocusNode.dispose);
    await tester.pumpWidget(
      _wrapWithTheme(
        _RecipientFocusTransferHarness(
          targetFocusNode: targetFocusNode,
          suggestionAddresses: const {'new@example.com'},
          onOutsideTapped: () => outsideTapped = true,
          onRecipientAdded: (_) => true,
        ),
      ),
    );

    final field = tester.widget<AxiTextField>(_recipientInputFieldFinder());
    field.focusNode!.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(_autocompleteOptionsListFinder, findsOneWidget);

    await tester.tap(_outsideTapTargetFinder);
    await tester.pump();

    expect(outsideTapped, isTrue);
    expect(_autocompleteOptionsListFinder, findsNothing);
  });
}

final Finder _inputFieldFinder = find.byType(AxiTextField);
final Finder _autocompleteOverlayFinder = find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == '_RecipientAutocompleteOverlay',
);
final Finder _autocompleteOptionsListFinder = find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == '_AutocompleteOptionsList',
);
const Key _targetFieldKey = ValueKey<String>('target-field');
final Finder _targetFieldFinder = find.byKey(_targetFieldKey);
const Key _outsideTapTargetKey = ValueKey<String>('outside-tap-target');
final Finder _outsideTapTargetFinder = find.byKey(_outsideTapTargetKey);

AxiTextField _inputField(WidgetTester tester) {
  return tester.widget<AxiTextField>(_inputFieldFinder);
}

Finder _recipientInputFieldFinder() {
  return find.descendant(
    of: find.byKey(const ValueKey<String>('autocomplete-field')),
    matching: find.byType(AxiTextField),
  );
}

Future<void> _submitRecipientText(WidgetTester tester, String text) async {
  final field = _inputField(tester);
  field.controller!.text = text;
  field.onSubmitted?.call(text);
  await tester.pump();
}

Future<void> _pressBackspace(WidgetTester tester) async {
  final field = _inputField(tester);
  field.focusNode?.onKeyEvent?.call(
    field.focusNode!,
    const KeyDownEvent(
      timeStamp: Duration.zero,
      physicalKey: PhysicalKeyboardKey.backspace,
      logicalKey: LogicalKeyboardKey.backspace,
    ),
  );
  await tester.pump();
}

List<Contact> _autocompleteOptionsFor(WidgetTester tester, String raw) {
  final dynamic overlay = tester.widget(_autocompleteOverlayFinder);
  final optionsBuilder =
      overlay.optionsBuilder as Iterable<Contact> Function(String);
  return optionsBuilder(raw).toList(growable: false);
}

Widget _wrapWithTheme(Widget child) {
  final settingsCubit = _MockSettingsCubit();
  when(() => settingsCubit.state).thenReturn(const SettingsState());
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(
    () => settingsCubit.animationDuration,
  ).thenReturn(const Duration(milliseconds: 200));
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<SettingsCubit>.value(
      value: settingsCubit,
      child: ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadSlateColorScheme.light(),
          brightness: Brightness.light,
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 640,
              height: 320,
              child: Align(alignment: Alignment.topLeft, child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

Chat _chat({
  required String jid,
  required String title,
  String? contactDisplayName,
}) {
  return Chat(
    jid: jid,
    title: title,
    type: ChatType.chat,
    lastChangeTimestamp: DateTime(2024, 1, 1),
    contactDisplayName: contactDisplayName,
  );
}

ComposerRecipient _chatRecipient({required String title}) {
  return ComposerRecipient(
    target: Contact.chat(
      chat: _chat(jid: '${title.toLowerCase()}@example.com', title: title),
      shareSignatureEnabled: true,
    ),
  );
}

class _RecipientChipsBarRemovalHarness extends StatefulWidget {
  const _RecipientChipsBarRemovalHarness();

  @override
  State<_RecipientChipsBarRemovalHarness> createState() =>
      _RecipientChipsBarRemovalHarnessState();
}

class _RecipientChipsBarRemovalHarnessState
    extends State<_RecipientChipsBarRemovalHarness> {
  late List<ComposerRecipient> _recipients;

  @override
  void initState() {
    super.initState();
    _recipients = <ComposerRecipient>[
      ComposerRecipient(
        target: Contact.chat(
          chat: Chat(
            jid: 'dc-1@delta.chat',
            title: 'Bob',
            type: ChatType.chat,
            lastChangeTimestamp: DateTime(2024, 1, 1),
          ),
          shareSignatureEnabled: true,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return RecipientChipsBar(
      recipients: _recipients,
      availableChats: const [],
      latestStatuses: const {},
      selfIdentity: const SelfAvatar(),
      onRecipientAdded: (_) => true,
      onRecipientRemoved: (key) {
        setState(() {
          _recipients = _recipients
              .where((recipient) => recipient.key != key)
              .toList(growable: false);
        });
      },
    );
  }
}

class _RecipientFocusTransferHarness extends StatefulWidget {
  const _RecipientFocusTransferHarness({
    required this.targetFocusNode,
    required this.onRecipientAdded,
    this.suggestionAddresses = const <String>{},
    this.onOutsideTapped,
  });

  final FocusNode targetFocusNode;
  final FutureOr<bool> Function(Contact) onRecipientAdded;
  final Set<String> suggestionAddresses;
  final VoidCallback? onOutsideTapped;

  @override
  State<_RecipientFocusTransferHarness> createState() =>
      _RecipientFocusTransferHarnessState();
}

class _RecipientFocusTransferHarnessState
    extends State<_RecipientFocusTransferHarness> {
  final Object _tapRegionGroup = Object();
  final TextEditingController _targetController = TextEditingController();

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 320,
              child: RecipientChipsBar(
                recipients: const [],
                availableChats: const [],
                latestStatuses: const {},
                selfIdentity: const SelfAvatar(),
                suggestionAddresses: widget.suggestionAddresses,
                tapRegionGroup: _tapRegionGroup,
                onRecipientAdded: widget.onRecipientAdded,
                onRecipientRemoved: (_) {},
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 240,
              child: AxiTextField(
                key: _targetFieldKey,
                controller: _targetController,
                focusNode: widget.targetFocusNode,
                groupId: _tapRegionGroup,
                decoration: const InputDecoration(hintText: 'Message'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 160),
        GestureDetector(
          key: _outsideTapTargetKey,
          behavior: HitTestBehavior.opaque,
          onTap: widget.onOutsideTapped,
          child: const SizedBox(width: 120, height: 48),
        ),
      ],
    );
  }
}
