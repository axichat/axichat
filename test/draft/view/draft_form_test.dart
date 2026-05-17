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
  testWidgets('deletes tracked draft when autosaved form becomes empty', (
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
          recipientCountAdjustment: 1,
        ),
      ),
    );
    await tester.pump();

    await _enterBodyText(tester, '');
    await tester.pump(const Duration(seconds: 3));

    verify(() => harness.draftCubit.deleteDraft(id: 7)).called(1);
  });

  testWidgets(
    'deletes tracked draft after emptying during in-flight autosave',
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
          autoSave: any(named: 'autoSave'),
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
          autoSave: true,
        ),
      ).called(1);

      await _enterBodyText(tester, '');
      await tester.pump(const Duration(seconds: 3));
      verifyNever(() => harness.draftCubit.deleteDraft(id: 7));

      saveCompleter.complete(_draft(id: 7));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      verify(() => harness.draftCubit.deleteDraft(id: 7)).called(1);
    },
  );

  testWidgets('deletes empty tracked draft before closing without prompt', (
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
    verify(() => harness.draftCubit.deleteDraft(id: 7)).called(1);
    expect(closed, isTrue);
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

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockProfileCubit extends Mock implements ProfileCubit {}

class _MockRosterCubit extends Mock implements RosterCubit {}

class _MockChatsCubit extends Mock implements ChatsCubit {}

class _MockDraftCubit extends Mock implements DraftCubit {}
