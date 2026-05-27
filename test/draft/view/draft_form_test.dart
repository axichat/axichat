import 'dart:async';

import 'package:axichat/src/calendar/view/shell/calendar_task_off_grid_drag_controller.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/draft_form.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<DraftForwardedBlock>[]);
  });

  testWidgets(
    'does not delete tracked draft when autosaved form becomes empty',
    (tester) async {
      final harness = _DraftFormHarness();

      await tester.pumpWidget(
        harness.wrap(
          DraftForm(
            id: 7,
            locate: harness.locate,
            jids: const ['peer@example.com'],
            body: 'hello',
            recipientCountAdjustment: 1,
          ),
        ),
      );
      await tester.pump();

      await _enterBodyText(tester, '');
      await tester.pump(const Duration(seconds: 3));

      verifyNever(() => harness.draftCubit.deleteDraft(id: 7));
    },
  );

  testWidgets(
    'does not delete tracked draft after emptying during in-flight autosave',
    (tester) async {
      final harness = _DraftFormHarness();
      final saveCompleter = Completer<Draft>();
      when(
        () => harness.draftCubit.saveDraft(
          id: any(named: 'id'),
          jids: any(named: 'jids'),
          body: any(named: 'body'),
          subject: any(named: 'subject'),
          quoteTarget: any(named: 'quoteTarget'),
          attachments: any(named: 'attachments'),
          calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
          forwardedBlocks: any(named: 'forwardedBlocks'),
          autoSave: any(named: 'autoSave'),
          shouldCommit: any(named: 'shouldCommit'),
        ),
      ).thenAnswer((_) => saveCompleter.future);

      await tester.pumpWidget(
        harness.wrap(
          DraftForm(
            id: 7,
            locate: harness.locate,
            jids: const ['peer@example.com'],
            body: 'hello',
            recipientCountAdjustment: 1,
          ),
        ),
      );
      await tester.pump();

      await _enterBodyText(tester, 'hello updated');
      await tester.pump(const Duration(seconds: 3));
      verify(
        () => harness.draftCubit.saveDraft(
          id: 7,
          jids: any(named: 'jids'),
          body: 'hello updated',
          subject: any(named: 'subject'),
          quoteTarget: any(named: 'quoteTarget'),
          attachments: any(named: 'attachments'),
          calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
          forwardedBlocks: any(named: 'forwardedBlocks'),
          autoSave: true,
          shouldCommit: any(named: 'shouldCommit'),
        ),
      ).called(1);

      await _enterBodyText(tester, '');
      await tester.pump(const Duration(seconds: 3));
      verifyNever(() => harness.draftCubit.deleteDraft(id: 7));

      saveCompleter.complete(_draft(id: 7));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      verifyNever(() => harness.draftCubit.deleteDraft(id: 7));
    },
  );

  testWidgets('closes unchanged empty tracked draft without deleting', (
    tester,
  ) async {
    final harness = _DraftFormHarness();
    final formKey = GlobalKey<DraftFormState>();
    var closed = false;

    await tester.pumpWidget(
      harness.wrap(
        DraftForm(
          key: formKey,
          id: 7,
          locate: harness.locate,
          jids: const ['peer@example.com'],
          recipientCountAdjustment: 1,
          onClosed: () => closed = true,
        ),
      ),
    );
    await tester.pump();

    final closeResult = await formKey.currentState!.handleCloseRequest();
    await tester.pumpAndSettle();

    expect(closeResult, isTrue);
    verifyNever(() => harness.draftCubit.deleteDraft(id: 7));
    expect(closed, isTrue);
  });

  testWidgets('discarding close prompt changes preserves the saved draft', (
    tester,
  ) async {
    final harness = _DraftFormHarness();
    final formKey = GlobalKey<DraftFormState>();
    var discarded = false;

    await tester.pumpWidget(
      harness.wrap(
        DraftForm(
          key: formKey,
          id: 7,
          locate: harness.locate,
          jids: const ['peer@example.com'],
          body: 'hello',
          recipientCountAdjustment: 1,
          onDiscarded: () => discarded = true,
        ),
      ),
    );
    await tester.pump();

    await _enterBodyText(tester, '');
    final closeResult = formKey.currentState!.handleCloseRequest();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Discard').last);
    await tester.pumpAndSettle();

    expect(await closeResult, isTrue);
    verifyNever(() => harness.draftCubit.deleteDraft(id: 7));
    expect(discarded, isTrue);
  });

  testWidgets('close prompt does not wait for in-flight autosave', (
    tester,
  ) async {
    final harness = _DraftFormHarness();
    final formKey = GlobalKey<DraftFormState>();
    final saveCompleter = Completer<Draft>();
    when(
      () => harness.draftCubit.saveDraft(
        id: any(named: 'id'),
        jids: any(named: 'jids'),
        body: any(named: 'body'),
        subject: any(named: 'subject'),
        quoteTarget: any(named: 'quoteTarget'),
        attachments: any(named: 'attachments'),
        calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
        forwardedBlocks: any(named: 'forwardedBlocks'),
        autoSave: any(named: 'autoSave'),
        shouldCommit: any(named: 'shouldCommit'),
      ),
    ).thenAnswer((_) => saveCompleter.future);

    await tester.pumpWidget(
      harness.wrap(
        DraftForm(
          key: formKey,
          id: 7,
          locate: harness.locate,
          jids: const ['peer@example.com'],
          body: 'hello',
          recipientCountAdjustment: 1,
        ),
      ),
    );
    await tester.pump();

    await _enterBodyText(tester, 'hello updated');
    await tester.pump(const Duration(seconds: 3));
    verify(
      () => harness.draftCubit.saveDraft(
        id: 7,
        jids: any(named: 'jids'),
        body: 'hello updated',
        subject: any(named: 'subject'),
        quoteTarget: any(named: 'quoteTarget'),
        attachments: any(named: 'attachments'),
        calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
        forwardedBlocks: any(named: 'forwardedBlocks'),
        autoSave: true,
        shouldCommit: any(named: 'shouldCommit'),
      ),
    ).called(1);

    final closeResult = formKey.currentState!.handleCloseRequest();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(await closeResult, isFalse);

    saveCompleter.complete(_draft(id: 7));
    await tester.pump();
  });

  testWidgets('discarding during in-flight autosave ignores its completion', (
    tester,
  ) async {
    final harness = _DraftFormHarness();
    final formKey = GlobalKey<DraftFormState>();
    final saveCompleter = Completer<Draft>();
    final savedDraftIds = <int>[];
    bool Function()? shouldCommit;
    var discarded = false;
    when(
      () => harness.draftCubit.saveDraft(
        id: any(named: 'id'),
        jids: any(named: 'jids'),
        body: any(named: 'body'),
        subject: any(named: 'subject'),
        quoteTarget: any(named: 'quoteTarget'),
        attachments: any(named: 'attachments'),
        calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
        forwardedBlocks: any(named: 'forwardedBlocks'),
        autoSave: any(named: 'autoSave'),
        shouldCommit: any(named: 'shouldCommit'),
      ),
    ).thenAnswer((invocation) async {
      shouldCommit =
          invocation.namedArguments[#shouldCommit] as bool Function()?;
      await saveCompleter.future;
      if (shouldCommit?.call() == false) {
        throw const DraftSaveAbortedException();
      }
      return _draft(id: 7);
    });

    await tester.pumpWidget(
      harness.wrap(
        DraftForm(
          key: formKey,
          id: 7,
          locate: harness.locate,
          jids: const ['peer@example.com'],
          body: 'hello',
          recipientCountAdjustment: 1,
          onDraftSaved: savedDraftIds.add,
          onDiscarded: () => discarded = true,
        ),
      ),
    );
    await tester.pump();

    await _enterBodyText(tester, 'hello updated');
    await tester.pump(const Duration(seconds: 3));
    verify(
      () => harness.draftCubit.saveDraft(
        id: 7,
        jids: any(named: 'jids'),
        body: 'hello updated',
        subject: any(named: 'subject'),
        quoteTarget: any(named: 'quoteTarget'),
        attachments: any(named: 'attachments'),
        calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
        forwardedBlocks: any(named: 'forwardedBlocks'),
        autoSave: true,
        shouldCommit: any(named: 'shouldCommit'),
      ),
    ).called(1);

    final closeResult = formKey.currentState!.handleCloseRequest();
    var closeCompleted = false;
    unawaited(closeResult.then((value) => closeCompleted = value));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Discard').last);
    await tester.pumpAndSettle();

    expect(closeCompleted, isTrue);
    expect(await closeResult, isTrue);
    expect(discarded, isTrue);
    expect(shouldCommit?.call(), isFalse);
    verifyNever(() => harness.draftCubit.deleteDraft(id: 7));

    saveCompleter.complete(_draft(id: 7));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(savedDraftIds, isEmpty);
  });

  testWidgets(
    'discarding during changed in-flight autosave does not reschedule',
    (tester) async {
      final harness = _DraftFormHarness();
      final formKey = GlobalKey<DraftFormState>();
      final saveCompleter = Completer<Draft>();
      var saveCalls = 0;
      when(
        () => harness.draftCubit.saveDraft(
          id: any(named: 'id'),
          jids: any(named: 'jids'),
          body: any(named: 'body'),
          subject: any(named: 'subject'),
          quoteTarget: any(named: 'quoteTarget'),
          attachments: any(named: 'attachments'),
          calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
          forwardedBlocks: any(named: 'forwardedBlocks'),
          autoSave: any(named: 'autoSave'),
          shouldCommit: any(named: 'shouldCommit'),
        ),
      ).thenAnswer((_) {
        saveCalls += 1;
        return saveCompleter.future;
      });

      await tester.pumpWidget(
        harness.wrap(
          DraftForm(
            key: formKey,
            id: 7,
            locate: harness.locate,
            jids: const ['peer@example.com'],
            body: 'hello',
            recipientCountAdjustment: 1,
          ),
        ),
      );
      await tester.pump();

      await _enterBodyText(tester, 'hello updated');
      await tester.pump(const Duration(seconds: 3));
      expect(saveCalls, 1);

      await _enterBodyText(tester, 'hello changed again');
      final closeResult = formKey.currentState!.handleCloseRequest();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(find.text('Discard').last);
      await tester.pumpAndSettle();
      expect(await closeResult, isTrue);

      saveCompleter.complete(_draft(id: 7));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(saveCalls, 1);
    },
  );

  testWidgets('no-prompt close ignores stale in-flight autosave completion', (
    tester,
  ) async {
    final harness = _DraftFormHarness();
    final formKey = GlobalKey<DraftFormState>();
    final saveCompleter = Completer<Draft>();
    final savedDraftIds = <int>[];
    var closed = false;
    when(
      () => harness.draftCubit.saveDraft(
        id: any(named: 'id'),
        jids: any(named: 'jids'),
        body: any(named: 'body'),
        subject: any(named: 'subject'),
        quoteTarget: any(named: 'quoteTarget'),
        attachments: any(named: 'attachments'),
        calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
        forwardedBlocks: any(named: 'forwardedBlocks'),
        autoSave: any(named: 'autoSave'),
        shouldCommit: any(named: 'shouldCommit'),
      ),
    ).thenAnswer((_) => saveCompleter.future);

    await tester.pumpWidget(
      harness.wrap(
        DraftForm(
          key: formKey,
          id: 7,
          locate: harness.locate,
          jids: const ['peer@example.com'],
          body: 'hello',
          recipientCountAdjustment: 1,
          onClosed: () => closed = true,
          onDraftSaved: savedDraftIds.add,
        ),
      ),
    );
    await tester.pump();

    await _enterBodyText(tester, 'hello updated');
    await tester.pump(const Duration(seconds: 3));
    await _enterBodyText(tester, 'hello');

    final closeResult = await formKey.currentState!.handleCloseRequest();
    await tester.pump();

    expect(closeResult, isTrue);
    expect(closed, isTrue);
    expect(find.text('Unsaved changes'), findsNothing);

    saveCompleter.complete(_draft(id: 7));
    await tester.pump();

    expect(savedDraftIds, isEmpty);
  });

  testWidgets(
    'discarding close prompt changes preserves a newly autosaved draft',
    (tester) async {
      final harness = _DraftFormHarness();
      final formKey = GlobalKey<DraftFormState>();
      var discarded = false;
      when(
        () => harness.draftCubit.saveDraft(
          id: any(named: 'id'),
          jids: any(named: 'jids'),
          body: any(named: 'body'),
          subject: any(named: 'subject'),
          quoteTarget: any(named: 'quoteTarget'),
          attachments: any(named: 'attachments'),
          calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
          forwardedBlocks: any(named: 'forwardedBlocks'),
          autoSave: any(named: 'autoSave'),
          shouldCommit: any(named: 'shouldCommit'),
        ),
      ).thenAnswer((_) async => _draft(id: 8));

      await tester.pumpWidget(
        harness.wrap(
          DraftForm(
            key: formKey,
            locate: harness.locate,
            jids: const ['peer@example.com'],
            recipientCountAdjustment: 1,
            onDiscarded: () => discarded = true,
          ),
        ),
      );
      await tester.pump();

      await _enterBodyText(tester, 'hello saved');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await _enterBodyText(tester, 'hello unsaved');
      final closeResult = formKey.currentState!.handleCloseRequest();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(find.text('Discard').last);
      await tester.pumpAndSettle();

      expect(await closeResult, isTrue);
      verify(
        () => harness.draftCubit.saveDraft(
          id: null,
          jids: any(named: 'jids'),
          body: 'hello saved',
          subject: any(named: 'subject'),
          quoteTarget: any(named: 'quoteTarget'),
          attachments: any(named: 'attachments'),
          calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
          forwardedBlocks: any(named: 'forwardedBlocks'),
          autoSave: true,
          shouldCommit: any(named: 'shouldCommit'),
        ),
      ).called(1);
      verifyNever(() => harness.draftCubit.deleteDraft(id: 8));
      expect(discarded, isTrue);
    },
  );

  testWidgets('converting a forwarded block autosaves editable text', (
    tester,
  ) async {
    final harness = _DraftFormHarness();
    final savedBlocks = <List<DraftForwardedBlock>>[];
    when(
      () => harness.draftCubit.saveDraft(
        id: any(named: 'id'),
        jids: any(named: 'jids'),
        body: any(named: 'body'),
        subject: any(named: 'subject'),
        quoteTarget: any(named: 'quoteTarget'),
        attachments: any(named: 'attachments'),
        calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
        forwardedBlocks: any(named: 'forwardedBlocks'),
        autoSave: any(named: 'autoSave'),
        shouldCommit: any(named: 'shouldCommit'),
      ),
    ).thenAnswer((invocation) async {
      savedBlocks.add(
        List<DraftForwardedBlock>.from(
          invocation.namedArguments[#forwardedBlocks]
              as List<DraftForwardedBlock>,
        ),
      );
      return _draft(id: 8);
    });

    await tester.pumpWidget(
      harness.wrap(
        DraftForm(
          locate: harness.locate,
          jids: const ['peer@example.com'],
          body: 'Intro note',
          forwardedBlocks: [_forwardedHtmlBlock()],
          recipientCountAdjustment: 1,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Convert to editable text'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    verify(
      () => harness.draftCubit.saveDraft(
        id: null,
        jids: any(named: 'jids'),
        body: 'Intro note',
        subject: any(named: 'subject'),
        quoteTarget: any(named: 'quoteTarget'),
        attachments: any(named: 'attachments'),
        calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
        forwardedBlocks: any(named: 'forwardedBlocks'),
        autoSave: true,
        shouldCommit: any(named: 'shouldCommit'),
      ),
    ).called(1);
    expect(savedBlocks.single.single.isConverted, isTrue);
    expect(
      savedBlocks.single.single.convertedText,
      contains('-------- Forwarded message --------'),
    );
    expect(savedBlocks.single.single.convertedText, contains('Forwarded body'));
  });

  testWidgets('text-only forwarded blocks open as normal body text', (
    tester,
  ) async {
    final harness = _DraftFormHarness();

    await tester.pumpWidget(
      harness.wrap(
        DraftForm(
          locate: harness.locate,
          jids: const ['peer@example.com'],
          body: 'Intro note',
          forwardedBlocks: [_forwardedBlock()],
          recipientCountAdjustment: 1,
        ),
      ),
    );
    await tester.pump();

    final field = tester.widget<AxiTextFormField>(_bodyField());
    expect(
      field.controller?.text,
      allOf(
        contains('Intro note'),
        contains('-------- Forwarded message --------'),
        contains('Forwarded body'),
      ),
    );
    expect(find.text('Convert to editable text'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
  });
}

class _DraftFormHarness {
  _DraftFormHarness() {
    when(() => settingsCubit.state).thenReturn(const SettingsState());
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    when(
      () => settingsCubit.animationDuration,
    ).thenReturn(const Duration(milliseconds: 200));
    when(
      () => profileCubit.state,
    ).thenReturn(const ProfileState(jid: '', resource: '', username: ''));
    when(
      () => profileCubit.stream,
    ).thenAnswer((_) => const Stream<ProfileState>.empty());
    when(() => rosterCubit.state).thenReturn(const RosterState());
    when(
      () => rosterCubit.stream,
    ).thenAnswer((_) => const Stream<RosterState>.empty());
    when(() => rosterCubit[RosterCubit.itemsCacheKey]).thenReturn(null);
    when(() => chatsCubit.state).thenReturn(
      const ChatsState(
        openCalendar: false,
        items: [],
        creationStatus: RequestStatus.none,
      ),
    );
    when(
      () => chatsCubit.stream,
    ).thenAnswer((_) => const Stream<ChatsState>.empty());
    when(
      () => draftCubit.state,
    ).thenReturn(const DraftsAvailable(items: [], visibleItems: []));
    when(
      () => draftCubit.stream,
    ).thenAnswer((_) => const Stream<DraftState>.empty());
    when(
      () => draftCubit.loadDraftAttachments(any<List<String>>()),
    ).thenAnswer((_) async => const []);
    when(
      () => draftCubit.deleteDraft(id: any(named: 'id')),
    ).thenAnswer((_) async {});
  }

  final settingsCubit = _MockSettingsCubit();
  final profileCubit = _MockProfileCubit();
  final rosterCubit = _MockRosterCubit();
  final chatsCubit = _MockChatsCubit();
  final draftCubit = _MockDraftCubit();

  T locate<T>() => switch (T) {
    const (SettingsCubit) => settingsCubit as T,
    const (ProfileCubit) => profileCubit as T,
    const (RosterCubit) => rosterCubit as T,
    const (ChatsCubit) => chatsCubit as T,
    const (DraftCubit) => draftCubit as T,
    _ => throw StateError('No test dependency for $T'),
  };

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ChangeNotifierProvider<CalendarTaskOffGridDragController>(
        create: (context) => CalendarTaskOffGridDragController(),
        child: MultiBlocProvider(
          providers: [
            BlocProvider<SettingsCubit>.value(value: settingsCubit),
            BlocProvider<ProfileCubit>.value(value: profileCubit),
            BlocProvider<RosterCubit>.value(value: rosterCubit),
            BlocProvider<ChatsCubit>.value(value: chatsCubit),
            BlocProvider<DraftCubit>.value(value: draftCubit),
          ],
          child: ShadTheme(
            data: ShadThemeData(
              colorScheme: const ShadSlateColorScheme.light(),
              brightness: Brightness.light,
            ),
            child: Scaffold(
              body: SizedBox(width: 800, height: 900, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

Finder _bodyField() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is AxiTextFormField &&
        widget.minLines == 7 &&
        widget.maxLines == null,
  );
}

Future<void> _enterBodyText(WidgetTester tester, String text) async {
  final field = _bodyField();
  expect(field, findsOneWidget);
  await tester.tap(field, warnIfMissed: false);
  tester.testTextInput.enterText(text);
  await tester.pump();
}

Draft _draft({required int id, List<String> attachmentMetadataIds = const []}) {
  return Draft(
    id: id,
    jids: const ['peer@example.com'],
    body: 'hello',
    draftSyncId: 'draft-sync',
    draftUpdatedAt: DateTime.utc(2026),
    draftSourceId: 'source',
    attachmentMetadataIds: attachmentMetadataIds,
  );
}

DraftForwardedBlock _forwardedBlock() {
  return const DraftForwardedBlock(
    blockId: 'forward-block',
    sourceMessageId: 'source-message',
    senderJid: 'sender@example.com',
    senderLabel: 'Sender',
    originalSubject: 'Original subject',
    originalPlainText: 'Forwarded body',
  );
}

DraftForwardedBlock _forwardedHtmlBlock() {
  return _forwardedBlock().copyWith(
    originalHtml: '<p><strong>Forwarded body</strong></p>',
  );
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockProfileCubit extends Mock implements ProfileCubit {}

class _MockRosterCubit extends Mock implements RosterCubit {}

class _MockChatsCubit extends Mock implements ChatsCubit {}

class _MockDraftCubit extends Mock implements DraftCubit {}
