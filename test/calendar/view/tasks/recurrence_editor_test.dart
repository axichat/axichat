// ignore_for_file: prefer_const_declarations, prefer_const_constructors

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_date_time_field.dart';
import 'package:axichat/src/calendar/view/tasks/recurrence_editor.dart';
import 'package:axichat/src/calendar/view/tasks/task_draft_controller.dart';
import 'package:axichat/src/common/ui/ui.dart' hide EditableText;
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  group('RecurrenceFormValue normalizeLimitFields', () {
    test('keeps count mode isolated from derived until', () {
      final value = const RecurrenceFormValue(
        frequency: RecurrenceFrequency.daily,
        interval: 1,
        count: 3,
        limitMode: RecurrenceLimitMode.count,
      );

      final resolved = value.normalizeLimitFields();
      expect(resolved.count, 3);
      expect(resolved.until, isNull);
      expect(resolved.resolvedLimitMode, RecurrenceLimitMode.count);
    });

    test('keeps until mode isolated from derived count', () {
      final until = DateTime(2024, 5, 13, 10); // Next Monday
      final value = RecurrenceFormValue(
        frequency: RecurrenceFrequency.weekly,
        interval: 1,
        weekdays: {DateTime.monday, DateTime.wednesday},
        until: until,
        limitMode: RecurrenceLimitMode.until,
      );

      final resolved = value.normalizeLimitFields();
      expect(resolved.count, isNull);
      expect(resolved.until, until);
      expect(resolved.resolvedLimitMode, RecurrenceLimitMode.until);
    });

    test('clears inactive until when count mode normalizes', () {
      final value = RecurrenceFormValue(
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        count: 2,
        until: DateTime(2024, 2, 29, 8),
        limitMode: RecurrenceLimitMode.count,
      );

      final resolved = value.normalizeLimitFields();
      expect(resolved.count, 2);
      expect(resolved.until, isNull);
      expect(resolved.resolvedLimitMode, RecurrenceLimitMode.count);
    });

    test('preserves count mode with an empty count field', () {
      final value = const RecurrenceFormValue(
        frequency: RecurrenceFrequency.daily,
        limitMode: RecurrenceLimitMode.count,
      );

      final resolved = value.normalizeLimitFields();
      expect(resolved.count, isNull);
      expect(resolved.until, isNull);
      expect(resolved.resolvedLimitMode, RecurrenceLimitMode.count);
    });

    test('preserves selected limit mode when building rules', () {
      final start = DateTime(2024, 5, 1, 9);
      final untilRule = RecurrenceFormValue(
        frequency: RecurrenceFrequency.daily,
        until: DateTime(2024, 5, 3),
        limitMode: RecurrenceLimitMode.until,
      ).toRule(start: start);
      final countRule = const RecurrenceFormValue(
        frequency: RecurrenceFrequency.daily,
        count: 3,
        limitMode: RecurrenceLimitMode.count,
      ).toRule(start: start);

      expect(untilRule?.until, DateTime(2024, 5, 3));
      expect(untilRule?.untilIsDate, isTrue);
      expect(untilRule?.count, isNull);
      expect(countRule?.count, 3);
      expect(countRule?.until, isNull);
    });
  });

  group('TaskDraftController recurrence normalization', () {
    test('keeps count recurrence without a derived until field', () {
      final controller = TaskDraftController();
      final start = DateTime(2024, 5, 1, 9);

      controller.updateStart(start);
      controller.setRecurrence(
        const RecurrenceFormValue(
          frequency: RecurrenceFrequency.daily,
          count: 4,
          limitMode: RecurrenceLimitMode.count,
        ),
      );

      expect(controller.recurrence.count, 4);
      expect(controller.recurrence.until, isNull);
      expect(controller.buildRecurrence(start: start)?.count, 4);
      expect(controller.buildRecurrence(start: start)?.until, isNull);
    });
  });

  group('RecurrenceEditor', () {
    testWidgets('end mode chips select until and count modes', (tester) async {
      final settingsCubit = _settingsCubit();
      RecurrenceFormValue latest = const RecurrenceFormValue(
        frequency: RecurrenceFrequency.daily,
      );

      await tester.pumpWidget(
        _RecurrenceHarness(
          settingsCubit: settingsCubit,
          value: latest,
          referenceStart: DateTime(2024, 5, 1, 9),
          onChanged: (value) => latest = value,
        ),
      );

      await tester.tap(find.text('On date'));
      await tester.pump();

      expect(latest.until, DateTime(2024, 5, 1));
      expect(latest.count, isNull);
      expect(find.byType(CalendarDateTimeField), findsOneWidget);

      await tester.tap(find.text('After'));
      await tester.pump();

      expect(latest.count, 1);
      expect(latest.until, isNull);
      expect(find.byType(AxiTextInput), findsOneWidget);
    });

    testWidgets('empty count text stays in count mode', (tester) async {
      final settingsCubit = _settingsCubit();
      RecurrenceFormValue latest = const RecurrenceFormValue(
        frequency: RecurrenceFrequency.daily,
      );

      await tester.pumpWidget(
        _RecurrenceHarness(
          settingsCubit: settingsCubit,
          value: latest,
          referenceStart: DateTime(2024, 5, 1, 9),
          onChanged: (value) => latest = value,
        ),
      );

      await tester.tap(find.text('After'));
      await tester.pump();
      tester
          .widget<AxiTextInput>(find.byType(AxiTextInput))
          .onChanged
          ?.call('12');
      await tester.pump();

      expect(latest.count, 12);
      expect(latest.until, isNull);
      expect(latest.resolvedLimitMode, RecurrenceLimitMode.count);

      tester
          .widget<AxiTextInput>(find.byType(AxiTextInput))
          .onChanged
          ?.call('');
      await tester.pump();

      expect(latest.count, isNull);
      expect(latest.until, isNull);
      expect(latest.resolvedLimitMode, RecurrenceLimitMode.count);
      expect(find.byType(AxiTextInput), findsOneWidget);
      expect(find.byType(CalendarDateTimeField), findsNothing);
    });

    testWidgets('switching to on date does not retain a hidden count', (
      tester,
    ) async {
      final settingsCubit = _settingsCubit();
      RecurrenceFormValue latest = const RecurrenceFormValue(
        frequency: RecurrenceFrequency.daily,
      );

      await tester.pumpWidget(
        _RecurrenceHarness(
          settingsCubit: settingsCubit,
          value: latest,
          referenceStart: DateTime(2024, 5, 1, 9),
          onChanged: (value) => latest = value,
        ),
      );

      await tester.tap(find.text('After'));
      await tester.pump();
      tester
          .widget<AxiTextInput>(find.byType(AxiTextInput))
          .onChanged
          ?.call('5');
      await tester.pump();

      expect(latest.count, 5);
      expect(latest.until, isNull);

      await tester.tap(find.text('On date'));
      await tester.pump();

      expect(latest.count, isNull);
      expect(latest.until, DateTime(2024, 5, 5));
      expect(latest.resolvedLimitMode, RecurrenceLimitMode.until);
      expect(find.byType(CalendarDateTimeField), findsOneWidget);
    });

    testWidgets('advanced rules open in a dedicated sheet', (tester) async {
      final settingsCubit = _settingsCubit();
      RecurrenceFormValue latest = const RecurrenceFormValue(
        frequency: RecurrenceFrequency.daily,
      );

      await tester.pumpWidget(
        _RecurrenceHarness(
          settingsCubit: settingsCubit,
          value: latest,
          referenceStart: DateTime(2024, 5, 1, 9),
          onChanged: (value) => latest = value,
        ),
      );

      expect(find.text('ADDITIONAL DATES'), findsNothing);

      await tester.tap(find.text('ADVANCED RULES'));
      await tester.pumpAndSettle();

      expect(find.text('Advanced rules'), findsOneWidget);
      expect(find.text('ADDITIONAL DATES'), findsOneWidget);
      expect(find.text('EXCLUDED DATES'), findsOneWidget);
    });
  });
}

class _RecurrenceHarness extends StatefulWidget {
  const _RecurrenceHarness({
    required this.settingsCubit,
    required this.value,
    required this.referenceStart,
    required this.onChanged,
  });

  final SettingsCubit settingsCubit;
  final RecurrenceFormValue value;
  final DateTime referenceStart;
  final ValueChanged<RecurrenceFormValue> onChanged;

  @override
  State<_RecurrenceHarness> createState() => _RecurrenceHarnessState();
}

class _RecurrenceHarnessState extends State<_RecurrenceHarness> {
  late RecurrenceFormValue _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.build(
      shadColor: ShadColor.blue,
      brightness: Brightness.light,
      platform: defaultTargetPlatform,
    );
    return BlocProvider<SettingsCubit>.value(
      value: widget.settingsCubit,
      child: ShadApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: RecurrenceEditor(
              value: _value,
              referenceStart: widget.referenceStart,
              onChanged: (value) {
                setState(() => _value = value);
                widget.onChanged(value);
              },
            ),
          ),
        ),
      ),
    );
  }
}

SettingsCubit _settingsCubit() {
  final cubit = _MockSettingsCubit();
  when(() => cubit.state).thenReturn(const SettingsState());
  when(
    () => cubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => cubit.animationDuration).thenReturn(Duration.zero);
  return cubit;
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
