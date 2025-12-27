import 'dart:io';

import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/view/calendar_grid.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_render_surface.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'calendar_test_utils.dart';

class _MockCalendarBloc extends Mock implements CalendarBloc {}

class _GridHarness extends StatelessWidget {
  const _GridHarness({
    required this.child,
    required this.state,
  });

  final Widget child;
  final CalendarState state;

  @override
  Widget build(BuildContext context) {
    final bloc = _MockCalendarBloc();
    when(() => bloc.state).thenReturn(state);
    when(() => bloc.stream)
        .thenAnswer((_) => const Stream<CalendarState>.empty());
    when(() => bloc.add(any())).thenReturn(null);

    return MultiBlocProvider(
      providers: [
        BlocProvider<CalendarBloc>.value(value: bloc),
        BlocProvider<SettingsCubit>(
          create: (_) => SettingsCubit(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(1280, 900),
            ),
            child: Scaffold(
              body: child,
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory:
          Directory.systemTemp.createTempSync('calendar_grid_render_tests'),
    );
    registerCalendarFallbackValues();
  });

  testWidgets('CalendarGrid renders time column labels', (tester) async {
    final state = CalendarTestData.weekView();
    await tester.pumpWidget(
      _GridHarness(
        state: state,
        child: CalendarGrid<CalendarBloc>(
          state: state,
          onDateSelected: (_) {},
          onViewChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CalendarRenderSurface), findsOneWidget);
  });

  testWidgets('CalendarGrid preserves explicit day view on desktop',
      (tester) async {
    final state = CalendarTestData.dayView();
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final List<CalendarView> requestedViews = [];
    await tester.pumpWidget(
      _GridHarness(
        state: state,
        child: CalendarGrid<CalendarBloc>(
          state: state,
          onDateSelected: (_) {},
          onViewChanged: (view) => requestedViews.add(view),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(requestedViews, isEmpty);
  });
}
