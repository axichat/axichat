import 'dart:async';

import 'package:axichat/src/calendar/view/shell/calendar_task_off_grid_drag_controller.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/compose_launcher.dart';
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
    'openComposeDraft route survives opener disposal and dispatches through provided cubits',
    (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = _ComposeDraftContextHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.wrap());

      await tester.tap(find.text('Open compose draft'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      harness.showOpener.value = false;
      await tester.pump();
      expect(tester.takeException(), isNull);

      harness.emitSettings(const SettingsState());
      await tester.pump();
      expect(tester.takeException(), isNull);

      await _enterBodyText(tester, 'message from route');
      await tester.tap(find.byTooltip('Send draft'));
      await tester.pump();

      verify(
        () => harness.draftCubit.sendDraft(
          id: null,
          xmppTargets: any(named: 'xmppTargets'),
          emailTargets: any(named: 'emailTargets'),
          body: 'message from route',
          shareTokenSignatureEnabled: any(named: 'shareTokenSignatureEnabled'),
          subject: any(named: 'subject'),
          quoteTarget: any(named: 'quoteTarget'),
          attachments: any(named: 'attachments'),
          calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
          forwardedBlocks: any(named: 'forwardedBlocks'),
        ),
      ).called(1);
    },
  );

  testWidgets('compose route keeps actions above keyboard at bottom scroll', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(bottom: 24);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });

    final harness = _ComposeDraftContextHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.wrap());

    await tester.tap(find.text('Open compose draft'));
    await tester.pumpAndSettle();

    final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
    final recipientsRect = tester.getRect(find.byType(RecipientChipsBar));
    expect(recipientsRect.top, moreOrLessEquals(appBarBottom, epsilon: 1));
    expect(recipientsRect.left, moreOrLessEquals(0, epsilon: 1));
    expect(
      recipientsRect.right,
      moreOrLessEquals(
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
        epsilon: 1,
      ),
    );

    await _enterBodyText(tester, List.filled(32, 'message line').join('\n'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pump();
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();

    final visibleBottom =
        tester.view.physicalSize.height / tester.view.devicePixelRatio - 320;
    expect(
      tester.getRect(find.widgetWithText(AxiButton, 'Discard')).bottom,
      lessThanOrEqualTo(visibleBottom),
    );
    expect(
      tester.getRect(find.widgetWithText(AxiButton, 'Save draft')).bottom,
      lessThanOrEqualTo(visibleBottom),
    );
  });
}

class _ComposeDraftContextHarness {
  _ComposeDraftContextHarness() {
    when(() => settingsCubit.state).thenAnswer((_) => _settingsState);
    when(() => settingsCubit.stream).thenAnswer((_) => _settings.stream);
    when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
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
    final chat = Chat(
      jid: 'peer@example.com',
      title: 'Peer',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2026),
    );
    when(() => chatsCubit.state).thenReturn(
      ChatsState(
        openCalendar: false,
        items: [chat],
        visibleItems: [chat],
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
    when(
      () => draftCubit.saveDraft(
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
    ).thenAnswer((_) async => _draft(id: 1));
    when(
      () => draftCubit.sendDraft(
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
    ).thenAnswer(
      (_) async => DraftSendOutcome.success(
        completedTransports: {DraftSendTransport.xmpp},
      ),
    );
  }

  final showOpener = ValueNotifier<bool>(true);
  final settingsCubit = _MockSettingsCubit();
  final profileCubit = _MockProfileCubit();
  final rosterCubit = _MockRosterCubit();
  final chatsCubit = _MockChatsCubit();
  final draftCubit = _MockDraftCubit();
  final composeWindowCubit = _MockComposeWindowCubit();
  final _settings = StreamController<SettingsState>.broadcast();
  SettingsState _settingsState = const SettingsState();

  void emitSettings(SettingsState state) {
    _settingsState = state;
    _settings.add(state);
  }

  void dispose() {
    showOpener.dispose();
    unawaited(_settings.close());
  }

  Widget wrap() {
    return ShadTheme(
      data: ShadThemeData(
        colorScheme: const ShadSlateColorScheme.light(),
        brightness: Brightness.light,
      ),
      child: MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
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
              BlocProvider<ComposeWindowCubit>.value(value: composeWindowCubit),
            ],
            child: Scaffold(
              body: Builder(
                builder: (openerContext) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: showOpener,
                    builder: (context, showOpener, child) {
                      if (!showOpener) {
                        return const SizedBox.shrink();
                      }
                      return Center(
                        child: TextButton(
                          onPressed: () {
                            openComposeDraft(
                              openerContext,
                              jids: const ['peer@example.com'],
                              body: 'hello',
                            );
                          },
                          child: const Text('Open compose draft'),
                        ),
                      );
                    },
                  );
                },
              ),
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

Draft _draft({required int id}) {
  return Draft(
    id: id,
    jids: const ['peer@example.com'],
    body: 'message from route',
    draftSyncId: 'draft-sync',
    draftUpdatedAt: DateTime.utc(2026),
    draftSourceId: 'source',
  );
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockProfileCubit extends Mock implements ProfileCubit {}

class _MockRosterCubit extends Mock implements RosterCubit {}

class _MockChatsCubit extends Mock implements ChatsCubit {}

class _MockDraftCubit extends Mock implements DraftCubit {}

class _MockComposeWindowCubit extends Mock implements ComposeWindowCubit {}
