import 'dart:async';
import 'dart:io';

import 'package:axichat/src/calendar/view/shell/calendar_task_off_grid_drag_controller.dart';
import 'package:axichat/src/chat/view/timeline/message/email_html_web_view.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/draft_form.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
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

  testWidgets('autosave switch persists for an existing draft', (tester) async {
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

    expect(tester.widget<ShadSwitch>(find.byType(ShadSwitch)).value, isTrue);
    tester.widget<ShadSwitch>(find.byType(ShadSwitch)).onChanged?.call(false);
    await tester.pump();

    verify(
      () =>
          harness.draftCubit.updateDraftAutosaveEnabled(id: 7, enabled: false),
    ).called(1);
    expect(tester.widget<ShadSwitch>(find.byType(ShadSwitch)).value, isFalse);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('autosave switch off prevents scheduled autosave', (
    tester,
  ) async {
    final harness = _DraftFormHarness();

    await tester.pumpWidget(
      harness.wrap(
        DraftForm(
          id: 7,
          locate: harness.locate,
          jids: const ['peer@example.com'],
          body: 'hello',
          autosaveEnabled: false,
          recipientCountAdjustment: 1,
        ),
      ),
    );
    await tester.pump();

    await _enterBodyText(tester, 'hello updated');
    await tester.pump(const Duration(seconds: 3));

    verifyNever(
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
        autosaveEnabled: any(named: 'autosaveEnabled'),
      ),
    );
  });

  testWidgets('seeds recipients before the first post-build pump', (
    tester,
  ) async {
    final harness = _DraftFormHarness();
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
        autosaveEnabled: any(named: 'autosaveEnabled'),
      ),
    ).thenAnswer((_) async => _draft(id: 7));

    await tester.pumpWidget(
      harness.wrap(
        DraftForm(
          id: 7,
          locate: harness.locate,
          jids: const ['peer@example.com'],
          body: 'hello',
        ),
      ),
    );

    await tester.tap(find.text('Save draft'));
    await tester.pump();

    verify(
      () => harness.draftCubit.saveDraft(
        id: 7,
        jids: const ['peer@example.com'],
        body: 'hello',
        subject: any(named: 'subject'),
        quoteTarget: any(named: 'quoteTarget'),
        attachments: any(named: 'attachments'),
        calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
        forwardedBlocks: any(named: 'forwardedBlocks'),
        autoSave: false,
        autosaveEnabled: true,
      ),
    ).called(1);
  });

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
          autosaveEnabled: any(named: 'autosaveEnabled'),
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
          autosaveEnabled: true,
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
        autosaveEnabled: any(named: 'autosaveEnabled'),
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
        autosaveEnabled: true,
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
        autosaveEnabled: any(named: 'autosaveEnabled'),
      ),
    ).thenAnswer((_) async {
      await saveCompleter.future;
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
        autosaveEnabled: true,
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
          autosaveEnabled: any(named: 'autosaveEnabled'),
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
        autosaveEnabled: any(named: 'autosaveEnabled'),
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
          autosaveEnabled: any(named: 'autosaveEnabled'),
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
          autosaveEnabled: true,
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
        autosaveEnabled: any(named: 'autosaveEnabled'),
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
        autosaveEnabled: true,
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

  testWidgets('basic HTML forwarded blocks open as normal body text', (
    tester,
  ) async {
    final harness = _DraftFormHarness();

    await tester.pumpWidget(
      harness.wrap(
        DraftForm(
          locate: harness.locate,
          jids: const ['peer@example.com'],
          body: 'Intro note',
          forwardedBlocks: [_forwardedBasicHtmlBlock()],
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
    expect(find.byType(EmailHtmlWebView), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('forwarded original HTML unblock requires confirmation', (
    tester,
  ) async {
    final harness = _DraftFormHarness();

    await tester.pumpWidget(
      harness.wrap(
        DraftForm(
          locate: harness.locate,
          jids: const ['peer@example.com'],
          body: 'Intro note',
          forwardedBlocks: [_forwardedBlockedHtmlBlock()],
          recipientCountAdjustment: 1,
        ),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<EmailHtmlWebView>(find.byType(EmailHtmlWebView))
          .contentMode,
      EmailHtmlContentMode.safe,
    );

    await tester.tap(find.text('Unblock'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('View original email?'), findsOneWidget);
    expect(
      tester
          .widget<EmailHtmlWebView>(find.byType(EmailHtmlWebView))
          .contentMode,
      EmailHtmlContentMode.safe,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('View original email?'), findsNothing);
    expect(find.text('Unblock'), findsOneWidget);
  });

  testWidgets('send does not start before forwarded attachment hydration', (
    tester,
  ) async {
    final harness = _DraftFormHarness();
    final cloneCompleter = Completer<List<String>>();
    final attachmentFile = File(
      '${Directory.systemTemp.path}/axichat-forwarded-hydration-test.txt',
    )..writeAsStringSync('forwarded attachment');
    final sentAttachments = <List<Attachment>>[];
    addTearDown(() {
      if (attachmentFile.existsSync()) {
        attachmentFile.deleteSync();
      }
    });
    final chat = Chat(
      jid: 'peer@example.com',
      title: 'Peer',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2026),
    );
    when(() => harness.chatsCubit.state).thenReturn(
      ChatsState(
        openCalendar: false,
        items: [chat],
        visibleItems: [chat],
        creationStatus: RequestStatus.none,
      ),
    );
    when(
      () => harness.draftCubit.cloneDraftAttachmentMetadata(any()),
    ).thenAnswer((_) => cloneCompleter.future);
    when(
      () => harness.draftCubit.loadDraftAttachments(any<List<String>>()),
    ).thenAnswer((invocation) async {
      final ids = invocation.positionalArguments.single as List<String>;
      if (!ids.contains('cloned-meta')) {
        return const [];
      }
      return [
        Attachment(
          metadataId: 'cloned-meta',
          path: attachmentFile.path,
          fileName: 'forwarded.txt',
          mimeType: 'text/plain',
          sizeBytes: attachmentFile.lengthSync(),
        ),
      ];
    });
    when(
      () => harness.draftCubit.sendDraft(
        id: any(named: 'id'),
        xmppTargets: any(named: 'xmppTargets'),
        emailTargets: any(named: 'emailTargets'),
        body: any(named: 'body'),
        shareTokenSignatureEnabled: any(named: 'shareTokenSignatureEnabled'),
        subject: any(named: 'subject'),
        quoteTarget: any(named: 'quoteTarget'),
        attachments: any(named: 'attachments'),
        calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
        forwardedBlocks: any(named: 'forwardedBlocks'),
      ),
    ).thenAnswer((invocation) async {
      sentAttachments.add(
        List<Attachment>.from(
          invocation.namedArguments[#attachments] as List<Attachment>,
        ),
      );
      return DraftSendOutcome.success();
    });

    await tester.pumpWidget(
      harness.wrap(
        DraftForm(
          locate: harness.locate,
          jids: const ['peer@example.com'],
          body: 'Intro note',
          forwardedSourceAttachmentMetadataIds: const ['source-meta'],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Send draft'), warnIfMissed: false);
    await tester.pump();

    expect(sentAttachments, isEmpty);

    await tester.runAsync(() async {
      cloneCompleter.complete(const ['cloned-meta']);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 400));

    verify(
      () => harness.draftCubit.cloneDraftAttachmentMetadata(any()),
    ).called(1);
    verify(
      () => harness.draftCubit.loadDraftAttachments(any<List<String>>()),
    ).called(1);

    expect(sentAttachments, isEmpty);
  });

  testWidgets('disposing during forwarded attachment hydration cleans clones', (
    tester,
  ) async {
    final harness = _DraftFormHarness();
    final cloneCompleter = Completer<List<String>>();
    when(
      () => harness.draftCubit.cloneDraftAttachmentMetadata(any()),
    ).thenAnswer((_) => cloneCompleter.future);

    await tester.pumpWidget(
      harness.wrap(
        DraftForm(
          locate: harness.locate,
          body: 'Intro note',
          forwardedSourceAttachmentMetadataIds: const ['source-meta'],
        ),
      ),
    );
    await tester.pumpWidget(harness.wrap(const SizedBox.shrink()));

    await tester.runAsync(() async {
      cloneCompleter.complete(const ['cloned-meta']);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();

    verify(
      () => harness.draftCubit.deleteDraftAttachmentMetadata('cloned-meta'),
    ).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('send preparation disables repeated taps until send finishes', (
    tester,
  ) async {
    final harness = _DraftFormHarness();
    final sendCompleter = Completer<DraftSendOutcome>();
    final chat = Chat(
      jid: 'peer@example.com',
      title: 'Peer',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2026),
    );
    when(
      () => harness.settingsCubit.state,
    ).thenReturn(const SettingsState(emailSendConfirmationEnabled: false));
    when(() => harness.chatsCubit.state).thenReturn(
      ChatsState(
        openCalendar: false,
        items: [chat],
        visibleItems: [chat],
        creationStatus: RequestStatus.none,
      ),
    );
    when(
      () => harness.draftCubit.sendDraft(
        id: any(named: 'id'),
        xmppTargets: any(named: 'xmppTargets'),
        emailTargets: any(named: 'emailTargets'),
        body: any(named: 'body'),
        shareTokenSignatureEnabled: any(named: 'shareTokenSignatureEnabled'),
        subject: any(named: 'subject'),
        quoteTarget: any(named: 'quoteTarget'),
        attachments: any(named: 'attachments'),
        calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
        forwardedBlocks: any(named: 'forwardedBlocks'),
      ),
    ).thenAnswer((_) => sendCompleter.future);

    await tester.pumpWidget(
      harness.wrap(
        DraftForm(
          locate: harness.locate,
          jids: const ['peer@example.com'],
          body: 'hello',
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Send draft').last);
    await tester.pump();
    await tester.tap(find.byTooltip('Send draft'), warnIfMissed: false);
    await tester.pump();

    verify(
      () => harness.draftCubit.sendDraft(
        id: any(named: 'id'),
        xmppTargets: any(named: 'xmppTargets'),
        emailTargets: any(named: 'emailTargets'),
        body: any(named: 'body'),
        shareTokenSignatureEnabled: any(named: 'shareTokenSignatureEnabled'),
        subject: any(named: 'subject'),
        quoteTarget: any(named: 'quoteTarget'),
        attachments: any(named: 'attachments'),
        calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
        forwardedBlocks: any(named: 'forwardedBlocks'),
      ),
    ).called(1);

    sendCompleter.complete(DraftSendOutcome.success());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets(
    'seeded email transport override sends XMPP-looking recipient as email',
    (tester) async {
      final harness = _DraftFormHarness();
      final sentXmppTargetCounts = <int>[];
      final sentEmailTargets = <List<Contact>>[];
      final chat = Chat(
        jid: 'peer@axi.im',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2026),
        transport: MessageTransport.xmpp,
      );
      when(() => harness.settingsCubit.state).thenReturn(
        const SettingsState(
          endpointConfig: EndpointConfig(smtpEnabled: true),
          emailSendConfirmationEnabled: false,
        ),
      );
      when(() => harness.chatsCubit.state).thenReturn(
        ChatsState(
          openCalendar: false,
          items: [chat],
          visibleItems: [chat],
          creationStatus: RequestStatus.none,
        ),
      );
      when(
        () => harness.draftCubit.sendDraft(
          id: any(named: 'id'),
          xmppTargets: any(named: 'xmppTargets'),
          emailTargets: any(named: 'emailTargets'),
          body: any(named: 'body'),
          shareTokenSignatureEnabled: any(named: 'shareTokenSignatureEnabled'),
          subject: any(named: 'subject'),
          quoteTarget: any(named: 'quoteTarget'),
          attachments: any(named: 'attachments'),
          calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
          forwardedBlocks: any(named: 'forwardedBlocks'),
        ),
      ).thenAnswer((invocation) async {
        sentXmppTargetCounts.add(
          (invocation.namedArguments[#xmppTargets] as List<DraftXmppTarget>)
              .length,
        );
        sentEmailTargets.add(
          List<Contact>.from(invocation.namedArguments[#emailTargets] as List),
        );
        return DraftSendOutcome.success();
      });

      await tester.pumpWidget(
        harness.wrap(
          DraftForm(
            locate: harness.locate,
            jids: const ['peer@axi.im'],
            recipientTransportOverrides: const {
              'peer@axi.im': MessageTransport.email,
            },
            body: 'hello',
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Send draft').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(sentXmppTargetCounts, const [0]);
      expect(sentEmailTargets.single, hasLength(1));
      expect(sentEmailTargets.single.single.address, 'peer@axi.im');
      expect(
        sentEmailTargets.single.single.configuredTransport,
        MessageTransport.email,
      );
    },
  );

  testWidgets('mixed draft retry keeps only recipients for failed transport', (
    tester,
  ) async {
    final harness = _DraftFormHarness();
    var sendAttempts = 0;
    final sentXmppTargetCounts = <int>[];
    final sentEmailTargetCounts = <int>[];
    final xmppChat = Chat(
      jid: 'xmpp@example.com',
      title: 'Xmpp',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2026),
      transport: MessageTransport.xmpp,
    );
    final emailChat = Chat(
      jid: 'mail@example.com',
      title: 'Mail',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2026),
      transport: MessageTransport.email,
      emailAddress: 'mail@example.com',
    );
    when(
      () => harness.settingsCubit.state,
    ).thenReturn(const SettingsState(emailSendConfirmationEnabled: false));
    when(() => harness.chatsCubit.state).thenReturn(
      ChatsState(
        openCalendar: false,
        items: [xmppChat, emailChat],
        visibleItems: [xmppChat, emailChat],
        creationStatus: RequestStatus.none,
      ),
    );
    when(
      () => harness.draftCubit.sendDraft(
        id: any(named: 'id'),
        xmppTargets: any(named: 'xmppTargets'),
        emailTargets: any(named: 'emailTargets'),
        body: any(named: 'body'),
        shareTokenSignatureEnabled: any(named: 'shareTokenSignatureEnabled'),
        subject: any(named: 'subject'),
        quoteTarget: any(named: 'quoteTarget'),
        attachments: any(named: 'attachments'),
        calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
        forwardedBlocks: any(named: 'forwardedBlocks'),
      ),
    ).thenAnswer((invocation) async {
      sendAttempts += 1;
      sentXmppTargetCounts.add(
        (invocation.namedArguments[#xmppTargets] as List<DraftXmppTarget>)
            .length,
      );
      sentEmailTargetCounts.add(
        (invocation.namedArguments[#emailTargets] as List<Contact>).length,
      );
      if (sendAttempts == 1) {
        return DraftSendOutcome.failure(
          failureType: DraftSendFailureType.sendFailed,
          completedTransports: {DraftSendTransport.xmpp},
        );
      }
      return DraftSendOutcome.success();
    });

    await tester.pumpWidget(
      harness.wrap(
        DraftForm(
          locate: harness.locate,
          jids: const ['xmpp@example.com', 'mail@example.com'],
          body: 'hello',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Send draft'));
    await tester.pump();
    await tester.tap(find.byTooltip('Send draft'));
    await tester.pump();

    expect(sentXmppTargetCounts, [1, 0]);
    expect(sentEmailTargetCounts, [1, 1]);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('email partial retry keeps only failed email recipients', (
    tester,
  ) async {
    final harness = _DraftFormHarness();
    var sendAttempts = 0;
    final sentEmailTargetAddresses = <List<String>>[];
    final firstChat = Chat(
      jid: 'chat-a@example.com',
      title: 'Mail A',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2026),
      transport: MessageTransport.email,
      emailAddress: 'a@example.com',
    );
    final secondChat = Chat(
      jid: 'chat-b@example.com',
      title: 'Mail B',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2026),
      transport: MessageTransport.email,
      emailAddress: 'b@example.com',
    );
    when(
      () => harness.settingsCubit.state,
    ).thenReturn(const SettingsState(emailSendConfirmationEnabled: false));
    when(() => harness.chatsCubit.state).thenReturn(
      ChatsState(
        openCalendar: false,
        items: [firstChat, secondChat],
        visibleItems: [firstChat, secondChat],
        creationStatus: RequestStatus.none,
      ),
    );
    when(
      () => harness.draftCubit.sendDraft(
        id: any(named: 'id'),
        xmppTargets: any(named: 'xmppTargets'),
        emailTargets: any(named: 'emailTargets'),
        body: any(named: 'body'),
        shareTokenSignatureEnabled: any(named: 'shareTokenSignatureEnabled'),
        subject: any(named: 'subject'),
        quoteTarget: any(named: 'quoteTarget'),
        attachments: any(named: 'attachments'),
        calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
        forwardedBlocks: any(named: 'forwardedBlocks'),
      ),
    ).thenAnswer((invocation) async {
      sendAttempts += 1;
      sentEmailTargetAddresses.add(
        (invocation.namedArguments[#emailTargets] as List<Contact>)
            .map((target) => target.preferredEmailAddress ?? target.key)
            .toList(growable: false),
      );
      if (sendAttempts == 1) {
        return DraftSendOutcome.failure(
          failureType: DraftSendFailureType.sendFailed,
          completedEmailRecipientKeys: const {'a@example.com'},
          latestEmailRecipientStatuses: const {
            'a@example.com': FanOutRecipientState.sent,
            'b@example.com': FanOutRecipientState.failed,
          },
        );
      }
      return DraftSendOutcome.success(
        completedTransports: {DraftSendTransport.email},
        completedEmailRecipientKeys: const {'b@example.com'},
      );
    });

    await tester.pumpWidget(
      harness.wrap(
        DraftForm(
          locate: harness.locate,
          jids: const ['chat-a@example.com', 'chat-b@example.com'],
          body: 'hello',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Send draft'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(sentEmailTargetAddresses, hasLength(1));
    expect(
      find.text(
        'Some recipients were not sent. Sent recipients were removed; retry the remaining recipients.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.priority_high_rounded), findsAtLeastNWidgets(2));
    expect(find.byType(AxiProgressIndicator), findsNothing);

    await tester.tap(find.byTooltip('Send draft'));
    await tester.pump();

    expect(sentEmailTargetAddresses, [
      ['a@example.com', 'b@example.com'],
      ['b@example.com'],
    ]);
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
      () => draftCubit.deleteDraftAttachmentMetadata(any()),
    ).thenAnswer((_) async {});
    when(
      () => draftCubit.deleteDraft(id: any(named: 'id')),
    ).thenAnswer((_) async {});
    when(
      () => draftCubit.updateDraftAutosaveEnabled(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
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
    originalHtml: '<table><tr><td>Forwarded rich body</td></tr></table>',
  );
}

DraftForwardedBlock _forwardedBasicHtmlBlock() {
  return _forwardedBlock().copyWith(
    originalHtml: '<p><strong>Forwarded body</strong></p>',
  );
}

DraftForwardedBlock _forwardedBlockedHtmlBlock() {
  return _forwardedBlock().copyWith(
    originalHtml:
        '<script>alert("blocked")</script>'
        '<table><tr><td>Forwarded rich body</td></tr></table>',
  );
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockProfileCubit extends Mock implements ProfileCubit {}

class _MockRosterCubit extends Mock implements RosterCubit {}

class _MockChatsCubit extends Mock implements ChatsCubit {}

class _MockDraftCubit extends Mock implements DraftCubit {}
