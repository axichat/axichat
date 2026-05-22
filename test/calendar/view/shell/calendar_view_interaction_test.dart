import 'dart:async';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/month/day_event_editor.dart';
import 'package:axichat/src/calendar/view/sidebar/critical_path_panel.dart';
import 'package:axichat/src/calendar/view/tasks/edit_task_dropdown.dart';
import 'package:axichat/src/calendar/view/tasks/quick_add_modal.dart';
import 'package:axichat/src/calendar/view/tasks/location_autocomplete.dart';
import 'package:axichat/src/calendar/view/tasks/reminder_preferences_field.dart';
import 'package:axichat/src/calendar/view/shell/calendar_task_off_grid_drag_controller.dart';
import 'package:axichat/src/calendar/view/shell/chat_calendar_widget.dart';
import 'package:axichat/src/calendar/view/tasks/task_form_section.dart';
import 'package:axichat/src/calendar/view/tasks/task_text_field.dart';
import 'package:axichat/src/common/ui/axi_adaptive_sheet.dart';
import 'package:axichat/src/common/ui/axi_sheet_scaffold.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/buttons/axi_button.dart';
import 'package:axichat/src/common/ui/axi_text_input.dart';
import 'package:axichat/src/common/ui/focus_extensions.dart';
import 'package:axichat/src/calendar/view/grid/task_interaction_controller.dart';
import 'package:axichat/src/calendar/view/grid/calendar_task_geometry.dart';
import 'package:axichat/src/calendar/view/grid/calendar_task_surface.dart';
import 'package:axichat/src/calendar/view/tasks/resizable_task_widget.dart';
import 'package:axichat/src/calendar/models/recurrence_utils.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models/chat_models.dart' as chat_models;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../calendar_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerCalendarFallbackValues);

  testWidgets('QuickAddModal submits scheduled task with prefilled time', (
    tester,
  ) async {
    final slotTime = DateTime(2024, 1, 15, 10, 30);
    ensureCalendarTestStorage();
    final SettingsCubit settingsCubit = SettingsCubit();
    addTearDown(settingsCubit.close);
    CalendarTask? submitted;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: BlocProvider<SettingsCubit>.value(
            value: settingsCubit,
            child: QuickAddModal(
              prefilledDateTime: slotTime,
              onTaskAdded: (task, _) => submitted = task,
              locationHelper: LocationAutocompleteHelper.fromSeeds(const []),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleField = find.byType(AxiTextInput).first;
    await tester.tap(titleField, warnIfMissed: false);
    tester.testTextInput.enterText('Modal Submit Test');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.title, 'Modal Submit Test');
    expect(submitted!.scheduledTime, slotTime);
  });

  testWidgets('QuickAddModal keeps repeat inside reminders section', (
    tester,
  ) async {
    ensureCalendarTestStorage();
    final SettingsCubit settingsCubit = SettingsCubit();
    addTearDown(settingsCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: BlocProvider<SettingsCubit>.value(
            value: settingsCubit,
            child: QuickAddModal(
              onTaskAdded: (_, _) {},
              locationHelper: LocationAutocompleteHelper.fromSeeds(const []),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _expectReminderRepeatGrouping(tester);
  });

  testWidgets('EditTaskDropdown keeps repeat inside reminders section', (
    tester,
  ) async {
    ensureCalendarTestStorage();
    final SettingsCubit settingsCubit = SettingsCubit();
    addTearDown(settingsCubit.close);

    final bloc = MockCalendarBloc();
    final state = CalendarTestData.baseState();
    when(() => bloc.state).thenReturn(state);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<CalendarState>.empty());
    when(() => bloc.close()).thenAnswer((_) async {});
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: BlocProvider<SettingsCubit>.value(
            value: settingsCubit,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 760,
                  height: 560,
                  child: BlocProvider<CalendarBloc>.value(
                    value: bloc,
                    child: EditTaskDropdown<CalendarBloc>(
                      task: state.model.tasks['task-unscheduled']!,
                      onClose: () {},
                      onTaskUpdated: (_) {},
                      onTaskDeleted: (_) {},
                      locationHelper: LocationAutocompleteHelper.fromSeeds(
                        const [],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _expectReminderRepeatGrouping(tester);
  });

  testWidgets('QuickAddModal keeps text focus when keyboard insets change', (
    tester,
  ) async {
    await _pumpMobileSheetHarness(
      tester,
      Builder(
        builder: (context) {
          return Center(
            child: ElevatedButton(
              onPressed: () {
                showQuickAddModal(
                  context: context,
                  onTaskAdded: (_, _) {},
                  locationHelper: LocationAutocompleteHelper.fromSeeds(
                    const [],
                  ),
                );
              },
              child: const Text('Open quick add'),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('Open quick add'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AxiTextInput).first, warnIfMissed: false);
    await tester.pump();
    expect(FocusManager.instance.isTextInputFocused, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(FocusManager.instance.isTextInputFocused, isTrue);
    expect(find.text('Add Task'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(
      tester.getRect(find.text('Add').last).bottom,
      lessThanOrEqualTo(
        tester.view.physicalSize.height / tester.view.devicePixelRatio - 320,
      ),
    );
  });

  testWidgets('day event editor keeps text focus when keyboard insets change', (
    tester,
  ) async {
    await _pumpMobileSheetHarness(
      tester,
      Builder(
        builder: (context) {
          return Center(
            child: ElevatedButton(
              onPressed: () {
                showDayEventEditor(
                  context: context,
                  initialDate: DateTime(2024, 1, 15),
                );
              },
              child: const Text('Open day event'),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('Open day event'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AxiTextInput).first, warnIfMissed: false);
    await tester.pump();
    expect(FocusManager.instance.isTextInputFocused, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(FocusManager.instance.isTextInputFocused, isTrue);
    expect(find.text('New day event'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(
      tester.getRect(find.text('Add').last).bottom,
      lessThanOrEqualTo(
        tester.view.physicalSize.height / tester.view.devicePixelRatio - 320,
      ),
    );
  });

  testWidgets('edit task sheet keeps footer actions above keyboard', (
    tester,
  ) async {
    final bloc = MockCalendarBloc();
    final state = CalendarTestData.baseState();
    when(() => bloc.state).thenReturn(state);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<CalendarState>.empty());
    when(() => bloc.close()).thenAnswer((_) async {});
    addTearDown(bloc.close);

    await _pumpMobileSheetHarness(
      tester,
      BlocProvider<CalendarBloc>.value(
        value: bloc,
        child: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                onPressed: () {
                  showAdaptiveBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useBottomSafeArea: false,
                    surfacePadding: EdgeInsets.zero,
                    builder: (sheetContext) {
                      final mediaQuery = MediaQuery.of(sheetContext);
                      return BlocProvider<CalendarBloc>.value(
                        value: bloc,
                        child: EditTaskDropdown<CalendarBloc>(
                          task: state.model.tasks['task-unscheduled']!,
                          maxHeight:
                              mediaQuery.size.height -
                              mediaQuery.viewPadding.vertical,
                          isSheet: true,
                          onClose: () => Navigator.of(sheetContext).maybePop(),
                          onTaskUpdated: (_) {},
                          onTaskDeleted: (_) {},
                          locationHelper: LocationAutocompleteHelper.fromSeeds(
                            const [],
                          ),
                        ),
                      );
                    },
                  );
                },
                child: const Text('Open edit task'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open edit task'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AxiTextInput).first, warnIfMissed: false);
    await tester.pump();
    expect(FocusManager.instance.isTextInputFocused, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(FocusManager.instance.isTextInputFocused, isTrue);
    expect(find.text('Save'), findsWidgets);
    expect(
      tester.getRect(find.text('Save').last).bottom,
      lessThanOrEqualTo(
        tester.view.physicalSize.height / tester.view.devicePixelRatio - 320,
      ),
    );
  });

  testWidgets(
    'QuickAddModal submit action reflects disabled and loading state',
    (tester) async {
      ensureCalendarTestStorage();
      final SettingsCubit settingsCubit = SettingsCubit();
      addTearDown(settingsCubit.close);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: ShadTheme(
            data: ShadThemeData(
              colorScheme: const ShadSlateColorScheme.light(),
              brightness: Brightness.light,
            ),
            child: BlocProvider<SettingsCubit>.value(
              value: settingsCubit,
              child: QuickAddModal(
                onTaskAdded: (_, _) {},
                locationHelper: LocationAutocompleteHelper.fromSeeds(const []),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder disabledSubmitFinder = find.ancestor(
        of: find.text('Add'),
        matching: find.byType(AxiButton),
      );
      expect(disabledSubmitFinder, findsOneWidget);
      expect(tester.widget<AxiButton>(disabledSubmitFinder).onPressed, isNull);

      final bloc = MockCalendarBloc();
      final state = CalendarTestData.baseState().copyWith(
        isTaskCreationSubmitting: true,
      );
      when(() => bloc.state).thenReturn(state);
      when(
        () => bloc.stream,
      ).thenAnswer((_) => const Stream<CalendarState>.empty());
      when(() => bloc.close()).thenAnswer((_) async {});
      addTearDown(bloc.close);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: ShadTheme(
            data: ShadThemeData(
              colorScheme: const ShadSlateColorScheme.light(),
              brightness: Brightness.light,
            ),
            child: BlocProvider<SettingsCubit>.value(
              value: settingsCubit,
              child: QuickAddModal(
                prefilledText: 'Busy task',
                onTaskAdded: (_, _) {},
                locationHelper: LocationAutocompleteHelper.fromSeeds(const []),
                locateCalendarBloc: () => bloc,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final Finder loadingSubmitFinder = find.ancestor(
        of: find.text('Add'),
        matching: find.byType(AxiButton),
      );
      expect(loadingSubmitFinder, findsOneWidget);
      final AxiButton loadingSubmit = tester.widget<AxiButton>(
        loadingSubmitFinder,
      );
      expect(loadingSubmit.loading, isTrue);
      expect(loadingSubmit.onPressed, isNull);
    },
  );

  testWidgets('critical path picker shows paths created while open', (
    tester,
  ) async {
    final controller = StreamController<CalendarState>.broadcast();
    addTearDown(controller.close);

    final bloc = MockCalendarBloc();
    var state = CalendarTestData.baseState();
    when(() => bloc.state).thenAnswer((_) => state);
    when(() => bloc.stream).thenAnswer((_) => controller.stream);
    when(() => bloc.close()).thenAnswer((_) async {});
    addTearDown(bloc.close);

    final createdPath = CalendarCriticalPath(
      id: 'created-path',
      name: 'Created path',
      createdAt: DateTime(2024, 1, 15),
      modifiedAt: DateTime(2024, 1, 15),
    );

    await _pumpMobileSheetHarness(
      tester,
      Builder(
        builder: (context) {
          return Center(
            child: ElevatedButton(
              onPressed: () {
                showCriticalPathPicker(
                  context: context,
                  paths: const <CalendarCriticalPath>[],
                  bloc: bloc,
                  stayOpen: true,
                  onCreateNewPath: (_) async {
                    state = state.copyWith(
                      model: state.model.addCriticalPath(createdPath),
                    );
                    controller.add(state);
                    return null;
                  },
                );
              },
              child: const Text('Open critical path picker'),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('Open critical path picker'));
    await tester.pumpAndSettle();

    expect(find.text('Create a critical path to get started'), findsOneWidget);

    await tester.tap(find.text('New critical path'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Created path'), findsOneWidget);
  });

  testWidgets('add-to-critical-path create treats first task as attached', (
    tester,
  ) async {
    final controller = StreamController<CalendarState>.broadcast();
    addTearDown(controller.close);

    final bloc = MockCalendarBloc();
    final events = <CalendarEvent>[];
    var state = CalendarTestData.baseState();
    final task = state.model.tasks['task-weekly-sync']!;
    when(() => bloc.state).thenAnswer((_) => state);
    when(() => bloc.stream).thenAnswer((_) => controller.stream);
    when(() => bloc.add(any())).thenAnswer((invocation) {
      events.add(invocation.positionalArguments.first as CalendarEvent);
    });
    when(() => bloc.close()).thenAnswer((_) async {});
    addTearDown(bloc.close);

    await _pumpMobileSheetHarness(
      tester,
      Builder(
        builder: (context) {
          return Center(
            child: ElevatedButton(
              onPressed: () {
                unawaited(
                  addTaskToCriticalPath(
                    context: context,
                    bloc: bloc,
                    task: task,
                  ),
                );
              },
              child: const Text('Open add to critical path'),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('Open add to critical path'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New critical path'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Critical path name'), findsOneWidget);
    await tester.tap(find.text('Critical path name'), warnIfMissed: false);
    tester.testTextInput.enterText('Created path');
    await tester.pump();
    await tester.tap(find.text('Save').last);
    await tester.pump();
    final saveException = tester.takeException();
    expect(
      saveException,
      isNull,
      reason: saveException is FlutterError
          ? saveException.toStringDeep()
          : '$saveException',
    );

    expect(events.single, isA<CalendarCriticalPathCreated>());
    final createdEvent = events.single as CalendarCriticalPathCreated;
    expect(createdEvent.taskId, task.id);

    final stalePath = CalendarCriticalPath(
      id: 'stale-path',
      name: 'Stale path',
      createdAt: DateTime(2024, 1, 14),
      modifiedAt: DateTime(2024, 1, 14),
    );
    state = state.copyWith(
      model: state.model.addCriticalPath(stalePath),
      isCriticalPathMutating: false,
      criticalPathMutationError: null,
      lastCreatedCriticalPathId: stalePath.id,
    );
    controller.add(state);
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(
      find.text('Created "Created path" and added task.'),
      findsNothing,
      reason: 'A stale last-created path must not complete this request.',
    );

    state = state.copyWith(
      isCriticalPathMutating: true,
      criticalPathMutationError: null,
      lastCreatedCriticalPathId: null,
    );
    controller.add(state);
    await tester.pump();
    expect(tester.takeException(), isNull);

    final createdPath = CalendarCriticalPath(
      id: 'created-path',
      name: 'Created path',
      createdAt: DateTime(2024, 1, 15),
      modifiedAt: DateTime(2024, 1, 15),
    );
    final updatedModel = state.model
        .addCriticalPath(createdPath)
        .addTaskToCriticalPath(pathId: createdPath.id, taskId: task.baseId);
    state = state.copyWith(
      model: updatedModel,
      isCriticalPathMutating: false,
      criticalPathMutationError: null,
      lastCreatedCriticalPathId: createdPath.id,
      lastCriticalPathTaskAddedPathId: null,
      lastCriticalPathTaskAddedTaskId: null,
    );
    controller.add(state);
    await tester.pump();

    expect(find.text('Created "Created path" and added task.'), findsOneWidget);
    expect(
      events.whereType<CalendarCriticalPathTaskAdded>(),
      isEmpty,
      reason: 'The create event already attaches the first task.',
    );
    expect(tester.takeException(), isNull);

    Navigator.of(
      tester.element(find.text('Created "Created path" and added task.')),
    ).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('add-to-critical-path picker re-enables after path selection', (
    tester,
  ) async {
    final controller = StreamController<CalendarState>.broadcast();
    addTearDown(controller.close);

    final bloc = MockCalendarBloc();
    final events = <CalendarEvent>[];
    final firstPath = CalendarCriticalPath(
      id: 'first-path',
      name: 'First path',
      createdAt: DateTime(2024, 1, 15),
      modifiedAt: DateTime(2024, 1, 15),
    );
    final secondPath = CalendarCriticalPath(
      id: 'second-path',
      name: 'Second path',
      createdAt: DateTime(2024, 1, 16),
      modifiedAt: DateTime(2024, 1, 16),
    );
    final baseState = CalendarTestData.baseState();
    var state = baseState.copyWith(
      model: baseState.model
          .addCriticalPath(firstPath)
          .addCriticalPath(secondPath),
    );
    final task = state.model.tasks['task-weekly-sync']!;
    when(() => bloc.state).thenAnswer((_) => state);
    when(() => bloc.stream).thenAnswer((_) => controller.stream);
    when(() => bloc.add(any())).thenAnswer((invocation) {
      events.add(invocation.positionalArguments.first as CalendarEvent);
    });
    when(() => bloc.close()).thenAnswer((_) async {});
    addTearDown(bloc.close);

    await _pumpMobileSheetHarness(
      tester,
      Builder(
        builder: (context) {
          return Center(
            child: ElevatedButton(
              onPressed: () {
                unawaited(
                  addTaskToCriticalPath(
                    context: context,
                    bloc: bloc,
                    task: task,
                  ),
                );
              },
              child: const Text('Open add to critical path'),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('Open add to critical path'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('First path'));
    await tester.pump();
    expect(events.single, isA<CalendarCriticalPathTaskAdded>());

    state = state.copyWith(
      isCriticalPathMutating: true,
      criticalPathMutationError: null,
      lastCriticalPathTaskAddedPathId: null,
      lastCriticalPathTaskAddedTaskId: null,
    );
    controller.add(state);
    await tester.pump();

    state = state.copyWith(
      model: state.model.addTaskToCriticalPath(
        pathId: firstPath.id,
        taskId: task.baseId,
      ),
      isCriticalPathMutating: false,
      criticalPathMutationError: null,
      lastCriticalPathTaskAddedPathId: firstPath.id,
      lastCriticalPathTaskAddedTaskId: task.baseId,
    );
    controller.add(state);
    await tester.pump();

    expect(find.text('Added to "First path".'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Second path'));
    await tester.pump();
    expect(events.whereType<CalendarCriticalPathTaskAdded>(), hasLength(2));

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('focused critical path notice can unfocus calendar', (
    tester,
  ) async {
    final baseState = CalendarTestData.weekView();
    final path = CalendarCriticalPath(
      id: 'focused-path',
      name: 'Focused path',
      taskIds: const <String>['task-weekly-sync'],
      createdAt: DateTime(2024, 1, 15),
      modifiedAt: DateTime(2024, 1, 15),
    );
    final state = baseState.copyWith(
      model: baseState.model.addCriticalPath(path),
      focusedCriticalPathId: path.id,
    );

    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      state: state,
      size: const Size(390, 844),
    );

    expect(find.text('"Focused path" is focused.'), findsOneWidget);

    await tester.tap(find.text('Unfocus'));
    await tester.pump();

    verify(
      () => harness.bloc.add(
        CalendarEvent.criticalPathUnfocused(pathId: path.id),
      ),
    ).called(1);
  });

  testWidgets('focused critical path notice is not duplicated by refresh', (
    tester,
  ) async {
    final baseState = CalendarTestData.weekView();
    final path = CalendarCriticalPath(
      id: 'focused-path',
      name: 'Focused path',
      taskIds: const <String>['task-weekly-sync'],
      createdAt: DateTime(2024, 1, 15),
      modifiedAt: DateTime(2024, 1, 15),
    );
    final state = baseState.copyWith(
      model: baseState.model.addCriticalPath(path),
      focusedCriticalPathId: path.id,
    );

    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      state: state,
      size: const Size(390, 844),
    );

    expect(find.text('"Focused path" is focused.'), findsOneWidget);

    await harness.pumpState(
      state.copyWith(lastSyncTime: DateTime(2024, 1, 16)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('"Focused path" is focused.'), findsOneWidget);
  });

  testWidgets('focused critical path notice waits for active surface', (
    tester,
  ) async {
    final baseState = CalendarTestData.weekView();
    final path = CalendarCriticalPath(
      id: 'focused-path',
      name: 'Focused path',
      taskIds: const <String>['task-weekly-sync'],
      createdAt: DateTime(2024, 1, 15),
      modifiedAt: DateTime(2024, 1, 15),
    );
    final state = baseState.copyWith(
      model: baseState.model.addCriticalPath(path),
      focusedCriticalPathId: path.id,
    );

    await CalendarWidgetHarness.pump(
      tester: tester,
      state: state,
      size: const Size(390, 844),
      active: false,
    );

    expect(find.text('"Focused path" is focused.'), findsNothing);
  });

  testWidgets('chat calendar focus notice waits for active surface', (
    tester,
  ) async {
    final baseState = CalendarTestData.weekView();
    final path = CalendarCriticalPath(
      id: 'focused-path',
      name: 'Focused path',
      taskIds: const <String>['task-weekly-sync'],
      createdAt: DateTime(2024, 1, 15),
      modifiedAt: DateTime(2024, 1, 15),
    );
    final state = baseState.copyWith(
      model: baseState.model.addCriticalPath(path),
      focusedCriticalPathId: path.id,
    );
    final harness = _ChatCalendarWidgetHarness(tester: tester, state: state);

    await harness.pump(surfacePopEnabled: true, active: false);

    expect(find.text('"Focused path" is focused.'), findsNothing);

    await harness.pump(surfacePopEnabled: true);

    expect(find.text('"Focused path" is focused.'), findsOneWidget);
  });

  testWidgets(
    'closing add-to-critical-path picker does not reuse disposed state',
    (tester) async {
      final controller = StreamController<CalendarState>.broadcast();
      addTearDown(controller.close);

      final bloc = MockCalendarBloc();
      final state = CalendarTestData.baseState();
      final task = state.model.tasks['task-weekly-sync']!;
      when(() => bloc.state).thenReturn(state);
      when(() => bloc.stream).thenAnswer((_) => controller.stream);
      when(() => bloc.add(any())).thenAnswer((_) {});
      when(() => bloc.close()).thenAnswer((_) async {});
      addTearDown(bloc.close);

      await _pumpMobileSheetHarness(
        tester,
        Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                onPressed: () {
                  unawaited(
                    addTaskToCriticalPath(
                      context: context,
                      bloc: bloc,
                      task: task,
                    ),
                  );
                },
                child: const Text('Open add to critical path'),
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('Open add to critical path'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('CalendarWidget week view renders day headers', (tester) async {
    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      state: CalendarTestData.weekView(),
      size: const Size(1600, 900),
    );

    expect(
      find.descendant(of: harness.gridFinder, matching: find.text('MON 15')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: harness.gridFinder, matching: find.text('TUE 16')),
      findsOneWidget,
    );
  });

  testWidgets('selection sidebar exit button clears selection', (tester) async {
    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      state: CalendarTestData.selectionMode(),
      size: const Size(1600, 900),
    );

    expect(find.text('Clear Selection'), findsOneWidget);

    final clearedState = CalendarTestData.selectionMode().copyWith(
      isSelectionMode: false,
      selectedTaskIds: <String>{},
    );
    await harness.pumpState(clearedState);

    expect(find.text('Clear Selection'), findsNothing);
  });

  testWidgets('zoom controls update label after zoomIn call', (tester) async {
    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      state: CalendarTestData.weekView(),
      size: const Size(1600, 900),
    );

    final dynamic gridState = tester.state(harness.gridFinder);
    gridState.zoomIn();
    await tester.pump();

    expect(find.text('Expanded'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Expanded'), findsOneWidget);
  });

  testWidgets('selection sidebar summary updates with bloc state', (
    tester,
  ) async {
    final initialState = CalendarTestData.selectionMode();

    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      state: initialState,
      size: const Size(1600, 900),
    );

    expect(find.text('2 tasks selected'), findsOneWidget);

    final nextState = initialState.copyWith(
      selectedTaskIds: {'task-overlap-a'},
    );

    await harness.pumpState(nextState);
    expect(find.text('1 task selected'), findsOneWidget);
  });

  testWidgets('selection batch apply button dispatches title change', (
    tester,
  ) async {
    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      state: CalendarTestData.selectionMode(),
      size: const Size(1600, 900),
    );

    final applyFinder = find.widgetWithText(AxiButton, 'Apply changes');
    expect(applyFinder, findsOneWidget);

    var applyButton = tester.widget<AxiButton>(applyFinder);
    expect(applyButton.onPressed, isNull);

    final titleField = _taskTextFieldByHint('Set title for selected tasks');
    final titleController = _taskTextController(
      tester,
      'Set title for selected tasks',
    );

    await tester.tap(titleField, warnIfMissed: false);
    tester.testTextInput.enterText('Batch Title');
    await tester.pump();

    applyButton = tester.widget<AxiButton>(applyFinder);
    expect(applyButton.onPressed, isNotNull);

    await tester.tap(applyFinder);
    await tester.pump();

    verify(
      () => harness.bloc.add(
        const CalendarEvent.selectionTitleChanged(title: 'Batch Title'),
      ),
    ).called(1);

    final updatedTasks = Map<String, CalendarTask>.from(
      harness.currentState.model.tasks,
    );
    for (final id in harness.currentState.selectedTaskIds) {
      final String baseId = baseTaskIdFrom(id);
      final CalendarTask? baseTask = updatedTasks[baseId];
      if (baseTask == null) {
        continue;
      }

      final String? occurrenceKey = occurrenceKeyFrom(id);
      if (occurrenceKey == null || occurrenceKey.isEmpty) {
        updatedTasks[baseId] = baseTask.copyWith(
          title: 'Batch Title',
          modifiedAt: baseTask.modifiedAt.add(const Duration(minutes: 1)),
        );
        continue;
      }

      final overrides = {...baseTask.occurrenceOverrides};
      final TaskOccurrenceOverride existing =
          overrides[occurrenceKey] ?? const TaskOccurrenceOverride();
      overrides[occurrenceKey] = existing.copyWith(title: 'Batch Title');

      updatedTasks[baseId] = baseTask.copyWith(
        occurrenceOverrides: overrides,
        modifiedAt: baseTask.modifiedAt.add(const Duration(minutes: 1)),
      );
    }

    final updatedState = harness.currentState.copyWith(
      model: harness.currentState.model.copyWith(tasks: updatedTasks),
    );

    await harness.pumpState(updatedState);

    expect(titleController.text, 'Batch Title');

    applyButton = tester.widget<AxiButton>(applyFinder);
    expect(applyButton.onPressed, isNull);
  });

  testWidgets('right-click opens task context menu', (tester) async {
    final taskFinder = await _pumpContextMenuSurface(tester);
    final menuFinder = find.text('Copy Task');
    expect(taskFinder, findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(taskFinder),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await tester.pump();
    expect(menuFinder, findsNothing);
    await gesture.up();
    await _pumpUntilMenuVisible(tester, menuFinder);

    expect(menuFinder, findsOneWidget);

    await _clickOutsideContextMenu(tester);
    expect(menuFinder, findsNothing);
  });

  testWidgets('right-click repeatedly opens task context menu', (tester) async {
    final taskFinder = await _pumpContextMenuSurface(tester);
    final menuFinder = find.text('Copy Task');
    expect(taskFinder, findsOneWidget);

    for (var attempt = 0; attempt < 5; attempt++) {
      final gesture = await tester.startGesture(
        tester.getCenter(taskFinder),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await tester.pump();
      expect(
        menuFinder,
        findsNothing,
        reason: 'menu unexpectedly visible before release on attempt $attempt',
      );
      await gesture.up();
      await _pumpUntilMenuVisible(tester, menuFinder);
      expect(
        menuFinder,
        findsOneWidget,
        reason: 'context menu did not open on attempt $attempt',
      );

      await _clickOutsideContextMenu(tester);
      expect(
        menuFinder,
        findsNothing,
        reason: 'context menu did not close after attempt $attempt',
      );
    }
  });

  testWidgets('task context menu opens across vertical positions', (
    tester,
  ) async {
    final taskFinder = await _pumpContextMenuSurface(tester);
    final menuFinder = find.text('Copy Task');
    final Rect taskRect = tester.getRect(taskFinder);

    Future<void> expectMenuAt(Offset point, String label) async {
      final TestGesture gesture = await tester.startGesture(
        point,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await tester.pump();
      await gesture.up();
      await _pumpUntilMenuVisible(tester, menuFinder);

      expect(
        menuFinder,
        findsOneWidget,
        reason:
            'Context menu should appear after right-clicking the $label region.',
      );

      final Rect menuRect = tester.getRect(menuFinder.first);
      expect(
        (menuRect.center.dy - point.dy).abs(),
        lessThan(180),
        reason:
            'Menu should anchor near the $label click point vertically (dy=${point.dy}).',
      );

      await _clickOutsideContextMenu(tester);
      expect(
        menuFinder,
        findsNothing,
        reason: 'Context menu should close after tapping outside.',
      );
    }

    await expectMenuAt(Offset(taskRect.center.dx, taskRect.top + 6), 'top');
    await expectMenuAt(taskRect.center, 'center');
    await expectMenuAt(
      Offset(taskRect.center.dx, taskRect.bottom - 6),
      'bottom',
    );
  });

  testWidgets(
    'task context menu prefers side placement when horizontal room is available',
    (tester) async {
      final Finder taskFinder = await _pumpWideContextMenuSurface(tester);
      final Finder menuFinder = find.text('Copy Task');

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(taskFinder),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await tester.pump();
      await gesture.up();
      await _pumpUntilMenuVisible(tester, menuFinder);

      expect(menuFinder, findsOneWidget);

      final Rect taskRect = tester.getRect(taskFinder);
      final Rect menuRect = tester.getRect(menuFinder.first);
      final bool opensToRight = menuRect.center.dx >= taskRect.right;
      final bool opensToLeft = menuRect.center.dx <= taskRect.left;
      expect(
        opensToRight || opensToLeft,
        isTrue,
        reason:
            'Menu should open to either side when horizontal room exists. '
            'task=$taskRect menu=$menuRect',
      );
      expect(
        (menuRect.center.dy - taskRect.center.dy).abs(),
        lessThan(120),
        reason: 'Side placement should stay vertically aligned to the task.',
      );
    },
  );

  testWidgets('opening a second task context menu closes the previous menu', (
    tester,
  ) async {
    final finders = await _pumpNestedContextMenuSurfaces(tester);
    final Finder topTaskFinder = finders['top']!;
    final Finder bottomTaskFinder = finders['bottom']!;
    final Finder menuFinder = find.text('Copy Task');

    Future<void> openMenu(Finder taskFinder) async {
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(taskFinder),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await tester.pump();
      await gesture.up();
      await _pumpUntilMenuVisible(tester, menuFinder);
    }

    await openMenu(topTaskFinder);
    expect(menuFinder, findsOneWidget);

    await openMenu(bottomTaskFinder);
    expect(
      menuFinder,
      findsOneWidget,
      reason: 'Opening a new task context menu should close the previous one.',
    );
  });

  testWidgets(
    'context menu opens for top and bottom tasks inside nested navigators',
    (tester) async {
      final finders = await _pumpNestedContextMenuSurfaces(tester);
      final Finder topTaskFinder = finders['top']!;
      final Finder bottomTaskFinder = finders['bottom']!;
      final Finder menuFinder = find.text('Copy Task');

      Future<double> openMenu(Finder finder) async {
        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(finder),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryButton,
        );
        await tester.pump();
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await _pumpUntilMenuVisible(tester, menuFinder);
        final Rect menuRect = tester.getRect(menuFinder.first);
        return menuRect.top;
      }

      final double topMenuOffset = await openMenu(topTaskFinder);
      await _clickOutsideContextMenu(tester);

      final double bottomMenuOffset = await openMenu(bottomTaskFinder);
      expect(
        bottomMenuOffset,
        greaterThan(topMenuOffset),
        reason:
            'Bottom task anchor should appear lower than the top task anchor.',
      );

      await _clickOutsideContextMenu(tester);
    },
  );

  testWidgets('context menu remains open while hovering into menu items', (
    tester,
  ) async {
    final finders = await _pumpNestedContextMenuSurfaces(tester);
    final Finder topTaskFinder = finders['top']!;
    final Finder menuFinder = find.text('Copy Task');

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(topTaskFinder),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await _pumpUntilMenuVisible(tester, menuFinder);

    final Rect menuRect = tester.getRect(menuFinder.first);
    final TestPointer hoverPointer = TestPointer(21, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      hoverPointer.hover(menuRect.topLeft - const Offset(48, 48)),
    );
    await tester.pump();
    await tester.sendEventToBinding(hoverPointer.hover(menuRect.center));
    await tester.pump();

    expect(
      menuFinder,
      findsOneWidget,
      reason: 'Menu should remain visible while hovering over entries.',
    );

    await tester.sendEventToBinding(hoverPointer.removePointer());
    await _clickOutsideContextMenu(tester);
    expect(menuFinder, findsNothing);
  });

  testWidgets('log calendar grid geometry', (tester) async {
    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      size: const Size(1600, 900),
    );

    final double bodyTop = harness.gridBodyTop();
    debugPrint('Calendar grid body top: $bodyTop');

    final Offset morningSlot = harness.slotPosition(
      0,
      const Duration(hours: 9),
    );
    final Offset eveningSlot = harness.slotPosition(
      0,
      const Duration(hours: 15),
    );
    debugPrint('Slot 9am center: $morningSlot');
    debugPrint('Slot 8pm center: $eveningSlot');
  }, skip: true);

  testWidgets('debug find calendar task widgets', (tester) async {
    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      size: const Size(1600, 900),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    final Finder weeklyFinder = find.byKey(
      const ValueKey('calendar-task-task-weekly-sync'),
    );
    final Finder designFinder = find.byKey(
      const ValueKey('calendar-task-task-design-review'),
    );

    debugPrint('Weekly Sync widgets: ${weeklyFinder.evaluate().length}');
    debugPrint('Design Review widgets: ${designFinder.evaluate().length}');

    final taskTitles = find.descendant(
      of: harness.gridFinder,
      matching: find.byType(Text),
    );
    debugPrint('Total text widgets in grid: ${taskTitles.evaluate().length}');
  }, skip: true);

  testWidgets('log hit test stack for calendar slots', (tester) async {
    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      size: const Size(1600, 900),
    );

    final Rect gridRect = tester.getRect(harness.gridFinder);
    final Offset sampleTop = Offset(
      gridRect.left + gridRect.width / 2,
      gridRect.top + 12,
    );
    final Offset sampleBottom = Offset(
      gridRect.left + gridRect.width / 2,
      gridRect.bottom - 12,
    );

    final HitTestResult topResult = HitTestResult();
    final int viewId =
        RendererBinding.instance.renderViews.first.flutterView.viewId;
    tester.binding.hitTestInView(topResult, sampleTop, viewId);
    debugPrint('Hit test entries near grid top:');
    for (final entry in topResult.path) {
      debugPrint('  ${entry.target.runtimeType}');
    }

    final HitTestResult bottomResult = HitTestResult();
    tester.binding.hitTestInView(bottomResult, sampleBottom, viewId);
    debugPrint('Hit test entries near grid bottom:');
    for (final entry in bottomResult.path) {
      debugPrint('  ${entry.target.runtimeType}');
    }
  }, skip: true);

  testWidgets('selection batch editors preload shared field values', (
    tester,
  ) async {
    final base = CalendarTestData.baseState();
    final sourceTask = base.model.tasks['task-design-review']!;
    final updatedTask = sourceTask.copyWith(
      description: 'Review the sprint backlog',
      location: 'Room 12',
    );
    final updatedModel = base.model.copyWith(
      tasks: {...base.model.tasks, updatedTask.id: updatedTask},
    );
    final selectionState = base.copyWith(
      model: updatedModel,
      isSelectionMode: true,
      selectedTaskIds: {updatedTask.id},
    );

    await CalendarWidgetHarness.pump(
      tester: tester,
      state: selectionState,
      size: const Size(1600, 900),
    );

    expect(
      _taskTextController(tester, 'Set title for selected tasks').text,
      updatedTask.title,
    );
    expect(
      _taskTextController(
        tester,
        'Set description (leave blank to clear)',
      ).text,
      'Review the sprint backlog',
    );
    expect(
      _taskTextController(tester, 'Set location (leave blank to clear)').text,
      'Room 12',
    );
  });

  testWidgets('selection list retains recurring occurrences when updated', (
    tester,
  ) async {
    final base = CalendarTestData.baseState();
    final recurring = base.model.tasks['task-recurring-standup']!;
    final rangeStart = base.weekStart;
    final rangeEnd = rangeStart.add(const Duration(days: 7));
    final occurrences = recurring
        .occurrencesWithin(rangeStart, rangeEnd)
        .take(3)
        .toList();
    final Set<String> firstTwoIds = {occurrences[0].id, occurrences[1].id};

    final initialState = base.copyWith(
      isSelectionMode: true,
      selectedTaskIds: firstTwoIds,
    );

    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      state: initialState,
      size: const Size(1600, 900),
    );

    expect(find.byTooltip('Remove from selection'), findsNWidgets(2));

    final Set<String> updatedIds = {...firstTwoIds, occurrences[2].id};
    final updatedState = initialState.copyWith(selectedTaskIds: updatedIds);
    await harness.pumpState(updatedState);

    expect(find.byTooltip('Remove from selection'), findsNWidgets(3));
    expect(harness.currentState.selectedTaskIds, updatedIds);
  });
}

Future<void> _expectReminderRepeatGrouping(WidgetTester tester) async {
  for (var attempt = 0; attempt < 8; attempt++) {
    if (tester.any(find.byType(TaskReminderRepeatSection))) {
      break;
    }
    final Finder scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -600));
    await tester.pump();
  }

  final Finder groupFinder = find.byType(TaskReminderRepeatSection);
  expect(groupFinder, findsOneWidget);
  expect(
    find.descendant(
      of: groupFinder,
      matching: find.byType(ReminderPreferencesField),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: groupFinder,
      matching: find.byType(TaskRecurrenceSection),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: groupFinder,
      matching: find.byType(AxiSheetSectionDivider),
    ),
    findsNothing,
  );
}

Future<Finder> _pumpContextMenuSurface(WidgetTester tester) async {
  final task = CalendarTestData.scheduled(
    'task-context-menu',
    'Context Menu Task',
    DateTime(2024, 1, 15, 10),
  );
  final interactionController = TaskInteractionController();
  final bindings = _buildTestBindings(
    controller: interactionController,
    groupId: const ValueKey('test-task-menu'),
    builderFactory: (controller) =>
        (context, request) => [
          ShadContextMenuItem(
            onPressed: () => controller.hide(),
            child: const Text('Copy Task'),
          ),
        ],
  );

  await tester.pumpWidget(
    _contextMenuTestApp(
      child: Center(
        child: SizedBox(
          width: 300,
          height: 240,
          child: Stack(
            children: [
              Positioned(
                left: 20,
                top: 40,
                width: 240,
                height: 120,
                child: CalendarTaskSurface(
                  key: const ValueKey('surface-task-context-menu'),
                  task: task,
                  isDayView: true,
                  bindings: bindings,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  return find.byKey(const ValueKey('task-context-menu'));
}

Future<Finder> _pumpWideContextMenuSurface(WidgetTester tester) async {
  final task = CalendarTestData.scheduled(
    'task-context-menu-wide',
    'Wide Context Menu Task',
    DateTime(2024, 1, 15, 10),
  );
  final interactionController = TaskInteractionController();
  final bindings = _buildTestBindings(
    controller: interactionController,
    groupId: const ValueKey('test-task-menu'),
    builderFactory: (controller) =>
        (context, request) => [
          ShadContextMenuItem(
            onPressed: () => controller.hide(),
            child: const Text('Copy Task'),
          ),
        ],
  );

  await tester.pumpWidget(
    _contextMenuTestApp(
      child: Center(
        child: SizedBox(
          width: 920,
          height: 360,
          child: Stack(
            children: [
              Positioned(
                left: 340,
                top: 120,
                width: 240,
                height: 120,
                child: CalendarTaskSurface(
                  key: const ValueKey('surface-task-context-menu-wide'),
                  task: task,
                  isDayView: true,
                  bindings: bindings,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  return find.byKey(const ValueKey('task-context-menu-wide'));
}

CalendarTaskTileCallbacks _testTileCallbacks() => CalendarTaskTileCallbacks(
  onResizePreview: (_) {},
  onResizeEnd: (_) {},
  onResizePointerMove: (_) {},
  onDragStarted: () {},
  resolveDragOriginSlot: (task) => task.scheduledTime,
  onDragUpdate: (_) {},
  onDragEnded: (_) {},
  onEnterSelectionMode: () {},
  onToggleSelection: () {},
  onTap: (_, _) {},
);

CalendarTaskEntryBindings _buildTestBindings({
  required TaskInteractionController controller,
  required ValueKey<String> groupId,
  required CalendarTaskContextMenuBuilderFactory builderFactory,
  Rect geometryRect = const Rect.fromLTWH(0, 0, 240, 60),
}) {
  final geometry = CalendarTaskGeometry(
    rect: geometryRect,
    narrowedWidth: geometryRect.width * 0.8,
    splitWidthFactor: geometryRect.width == 0
        ? 0
        : (geometryRect.width * 0.8) / geometryRect.width,
  );
  return CalendarTaskEntryBindings(
    isSelectionMode: false,
    isSelected: false,
    isPopoverOpen: false,
    splitPreviewAnimationDuration: Duration.zero,
    contextMenuGroupId: groupId,
    contextMenuBuilderFactory: builderFactory,
    enableContextMenuLongPress: true,
    resizeHandleExtent: 12,
    interactionController: controller,
    cancelBucketHoverNotifier: const AlwaysStoppedAnimation(false),
    callbacks: _testTileCallbacks(),
    geometryProvider: (_) => geometry,
    globalRectProvider: (_) => geometry.rect,
    stepHeight: 15,
    minutesPerStep: 15,
    hourHeight: 60,
    viewportScrollOffsetProvider: () => 0,
    addGeometryListener: (_) {},
    removeGeometryListener: (_) {},
    requiresLongPressToDrag: false,
    longPressToDragDelay: Duration.zero,
  );
}

Future<Map<String, Finder>> _pumpNestedContextMenuSurfaces(
  WidgetTester tester,
) async {
  const ValueKey<String> groupId = ValueKey('test-task-menu');
  TaskContextMenuBuilder? defaultContextMenuBuilder(
    ShadPopoverController controller,
  ) {
    return (BuildContext context, TaskContextMenuRequest request) => [
      ShadContextMenuItem(
        onPressed: () => controller.hide(),
        child: const Text('Copy Task'),
      ),
    ];
  }

  final CalendarTaskContextMenuBuilderFactory builderFactory =
      defaultContextMenuBuilder;

  final TaskInteractionController topController = TaskInteractionController();
  final TaskInteractionController bottomController =
      TaskInteractionController();

  final CalendarTask topTask = CalendarTestData.scheduled(
    'task-top-context',
    'Top Context Task',
    DateTime(2024, 1, 15, 9),
  );
  final CalendarTask bottomTask = CalendarTestData.scheduled(
    'task-bottom-context',
    'Bottom Context Task',
    DateTime(2024, 1, 15, 20),
  );

  await tester.pumpWidget(
    _contextMenuTestApp(
      child: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => Center(
                child: SizedBox(
                  width: 360,
                  height: 680,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 40,
                        top: 24,
                        width: 240,
                        height: 140,
                        child: CalendarTaskSurface(
                          key: ValueKey('surface-${topTask.id}'),
                          task: topTask,
                          isDayView: true,
                          bindings: _buildTestBindings(
                            controller: topController,
                            groupId: groupId,
                            builderFactory: builderFactory,
                            geometryRect: const Rect.fromLTWH(40, 24, 240, 140),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 40,
                        top: 420,
                        width: 240,
                        height: 140,
                        child: CalendarTaskSurface(
                          key: ValueKey('surface-${bottomTask.id}'),
                          task: bottomTask,
                          isDayView: true,
                          bindings: _buildTestBindings(
                            controller: bottomController,
                            groupId: groupId,
                            builderFactory: builderFactory,
                            geometryRect: const Rect.fromLTWH(
                              40,
                              420,
                              240,
                              140,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  return {
    'top': find.byKey(ValueKey(topTask.id)),
    'bottom': find.byKey(ValueKey(bottomTask.id)),
  };
}

Future<void> _pumpUntilMenuVisible(
  WidgetTester tester,
  Finder menuFinder,
) async {
  for (int i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (tester.any(menuFinder)) {
      return;
    }
  }
  expect(
    menuFinder,
    findsOneWidget,
    reason: 'Context menu should appear after secondary tap.',
  );
}

Future<void> _clickOutsideContextMenu(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    const Offset(5, 5),
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );
  await tester.pump();
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _pumpMobileSheetHarness(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewInsets = FakeViewPadding.zero;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  });

  ensureCalendarTestStorage();
  final SettingsCubit settingsCubit = SettingsCubit();
  addTearDown(settingsCubit.close);

  await tester.pumpWidget(
    BlocProvider<SettingsCubit>.value(
      value: settingsCubit,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          platform: TargetPlatform.android,
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF0F172A),
          brightness: Brightness.light,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: EnvScope(
          child: ShadTheme(
            data: ShadThemeData(
              colorScheme: const ShadSlateColorScheme.light(),
              brightness: Brightness.light,
            ),
            child: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _taskTextFieldByHint(String hint) {
  return find.byWidgetPredicate((widget) {
    return widget is TaskTextField && widget.hintText == hint;
  });
}

TextEditingController _taskTextController(WidgetTester tester, String hint) {
  return tester.widget<TaskTextField>(_taskTextFieldByHint(hint)).controller;
}

Widget _contextMenuTestApp({required Widget child}) {
  final settingsCubit = _MockSettingsCubit();
  when(() => settingsCubit.state).thenReturn(const SettingsState());
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
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
        child: Scaffold(body: child),
      ),
    ),
  );
}

class _ChatCalendarWidgetHarness {
  _ChatCalendarWidgetHarness({required this.tester, required this.state}) {
    ensureCalendarTestStorage();
    settingsCubit = SettingsCubit();
    when(() => bloc.state).thenReturn(state);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<CalendarState>.empty());
    when(() => bloc.add(any<CalendarEvent>())).thenAnswer((_) {});
    when(() => bloc.close()).thenAnswer((_) async {});
    addTearDown(bloc.close);
    addTearDown(settingsCubit.close);
  }

  final WidgetTester tester;
  final CalendarState state;
  final MockChatCalendarBloc bloc = MockChatCalendarBloc();
  late final SettingsCubit settingsCubit;
  bool _viewConfigured = false;

  Future<void> pump({
    required bool surfacePopEnabled,
    bool active = true,
  }) async {
    if (!_viewConfigured) {
      _viewConfigured = true;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF0F172A),
          brightness: Brightness.light,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: MediaQuery(
          data: MediaQueryData(
            size: tester.view.physicalSize,
            devicePixelRatio: 1.0,
            textScaler: const TextScaler.linear(0.7),
          ),
          child: ShadTheme(
            data: ShadThemeData(
              colorScheme: const ShadSlateColorScheme.light(),
              brightness: Brightness.light,
            ),
            child: EnvScope(
              child: SizedBox.expand(
                child: MultiBlocProvider(
                  providers: [
                    ChangeNotifierProvider<CalendarTaskOffGridDragController>(
                      create: (context) => CalendarTaskOffGridDragController(),
                    ),
                    BlocProvider<ChatCalendarBloc>.value(value: bloc),
                    BlocProvider<CalendarBloc>.value(value: bloc),
                    BlocProvider<BaseCalendarBloc>.value(value: bloc),
                    BlocProvider<SettingsCubit>.value(value: settingsCubit),
                  ],
                  child: ChatCalendarWidget(
                    chat: chat_models.Chat(
                      jid: 'team@example.com',
                      title: 'Team',
                      type: chat_models.ChatType.groupChat,
                      lastChangeTimestamp: DateTime(2024, 1, 15),
                    ),
                    surfacePopEnabled: surfacePopEnabled,
                    active: active,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
