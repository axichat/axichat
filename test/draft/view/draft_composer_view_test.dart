import 'dart:async';

import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/view/draft_composer_view.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('async recipient add finishing after unmount is ignored', (
    tester,
  ) async {
    final harness = _DraftComposerViewHarness();
    final completer = Completer<bool>();
    final subjectController = TextEditingController();
    final subjectFocusNode = FocusNode();
    final bodyController = TextEditingController();
    final bodyFocusNode = FocusNode();
    Contact? addedRecipient;
    addTearDown(subjectController.dispose);
    addTearDown(subjectFocusNode.dispose);
    addTearDown(bodyController.dispose);
    addTearDown(bodyFocusNode.dispose);

    await tester.pumpWidget(
      harness.wrap(
        _TestDraftComposerView(
          subjectController: subjectController,
          subjectFocusNode: subjectFocusNode,
          bodyController: bodyController,
          bodyFocusNode: bodyFocusNode,
          onRecipientAdded: (target) {
            addedRecipient = target;
            return completer.future;
          },
        ),
      ),
    );

    await _submitRecipientText(tester, 'new@example.com');
    expect(addedRecipient?.address, 'new@example.com');
    await tester.pumpWidget(harness.wrap(const SizedBox.shrink()));

    completer.complete(true);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('autosave saving state disables the switch and shows progress', (
    tester,
  ) async {
    final harness = _DraftComposerViewHarness();
    final subjectController = TextEditingController();
    final subjectFocusNode = FocusNode();
    final bodyController = TextEditingController();
    final bodyFocusNode = FocusNode();
    addTearDown(subjectController.dispose);
    addTearDown(subjectFocusNode.dispose);
    addTearDown(bodyController.dispose);
    addTearDown(bodyFocusNode.dispose);

    await tester.pumpWidget(
      harness.wrap(
        _TestDraftComposerView(
          subjectController: subjectController,
          subjectFocusNode: subjectFocusNode,
          bodyController: bodyController,
          bodyFocusNode: bodyFocusNode,
          onRecipientAdded: (_) async => true,
          autosaveEnabled: true,
          autosaveSaving: true,
          onAutosaveChanged: (_) {},
        ),
      ),
    );

    expect(find.byType(AxiProgressIndicator), findsOneWidget);
    expect(
      tester.widget<ShadSwitch>(find.byType(ShadSwitch)).onChanged,
      isNull,
    );
  });

  testWidgets('autosave saved state uses the compact check indicator', (
    tester,
  ) async {
    final harness = _DraftComposerViewHarness();
    final subjectController = TextEditingController();
    final subjectFocusNode = FocusNode();
    final bodyController = TextEditingController();
    final bodyFocusNode = FocusNode();
    addTearDown(subjectController.dispose);
    addTearDown(subjectFocusNode.dispose);
    addTearDown(bodyController.dispose);
    addTearDown(bodyFocusNode.dispose);

    await tester.pumpWidget(
      harness.wrap(
        _TestDraftComposerView(
          subjectController: subjectController,
          subjectFocusNode: subjectFocusNode,
          bodyController: bodyController,
          bodyFocusNode: bodyFocusNode,
          onRecipientAdded: (_) async => true,
          showAutosaveHint: true,
          autosaveEnabled: true,
          onAutosaveChanged: (_) {},
        ),
      ),
    );

    expect(find.byIcon(LucideIcons.check), findsOneWidget);
  });
}

class _TestDraftComposerView extends StatelessWidget {
  const _TestDraftComposerView({
    required this.subjectController,
    required this.subjectFocusNode,
    required this.bodyController,
    required this.bodyFocusNode,
    required this.onRecipientAdded,
    this.showAutosaveHint = false,
    this.autosaveEnabled = false,
    this.autosaveSaving = false,
    this.onAutosaveChanged,
  });

  final TextEditingController subjectController;
  final FocusNode subjectFocusNode;
  final TextEditingController bodyController;
  final FocusNode bodyFocusNode;
  final FutureOr<bool> Function(Contact target) onRecipientAdded;
  final bool showAutosaveHint;
  final bool autosaveEnabled;
  final bool autosaveSaving;
  final ValueChanged<bool>? onAutosaveChanged;

  @override
  Widget build(BuildContext context) {
    return DraftComposerView(
      enabled: true,
      showValidationMessages: false,
      recipients: const [],
      availableChats: const [],
      rosterItems: const [],
      databaseSuggestionAddresses: const [],
      selfJid: 'self@example.com',
      selfIdentity: const SelfAvatar(),
      latestStatuses: const {},
      collapsedRecipientsByDefault: false,
      suggestionAddresses: const {},
      suggestionDomains: const {'example.com'},
      recipientAddError: (_) => null,
      onRecipientAdded: onRecipientAdded,
      onRecipientRemoved: (_) {},
      subjectController: subjectController,
      subjectFocusNode: subjectFocusNode,
      bodyController: bodyController,
      bodyFocusNode: bodyFocusNode,
      onSubjectSubmitted: () {},
      loadingAttachments: false,
      attachments: const [],
      addingAttachment: false,
      onAddAttachment: null,
      onAttachmentRetry: (_) {},
      onAttachmentRemove: (_) {},
      onAttachmentPressed: (_) {},
      onAttachmentPreview: (_) async {},
      readyToSend: false,
      sending: false,
      onSendPressed: null,
      showSendBlockerMessage: false,
      sendBlockerMessage: null,
      sendErrorMessage: null,
      showSendingStatus: false,
      showAutosaveHint: showAutosaveHint,
      autosaveEnabled: autosaveEnabled,
      autosaveSaving: autosaveSaving,
      onAutosaveChanged: onAutosaveChanged,
      canDiscard: false,
      canSave: false,
      onDiscardPressed: null,
      onSavePressed: null,
    );
  }
}

class _DraftComposerViewHarness {
  _DraftComposerViewHarness() {
    when(() => settingsCubit.state).thenReturn(const SettingsState());
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    when(
      () => settingsCubit.animationDuration,
    ).thenReturn(const Duration(milliseconds: 200));
  }

  final settingsCubit = _MockSettingsCubit();

  Widget wrap(Widget child) {
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
              child: SizedBox(width: 800, height: 900, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _submitRecipientText(WidgetTester tester, String text) async {
  final field = tester.widget<AxiTextField>(find.byType(AxiTextField));
  expect(field.controller, isNotNull);
  expect(field.onSubmitted, isNotNull);
  field.controller!.text = text;
  field.onSubmitted!(text);
  await tester.pump();
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
