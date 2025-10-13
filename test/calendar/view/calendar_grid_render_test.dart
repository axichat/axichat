import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/view/calendar_grid.dart';
import 'package:axichat/src/calendar/view/calendar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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
    when(() => bloc.stream).thenAnswer((_) => Stream<CalendarState>.empty());
    when(() => bloc.add(any())).thenReturn(null);

    return MultiBlocProvider(
      providers: [
        BlocProvider<CalendarBloc>.value(value: bloc),
      ],
      child: MaterialApp(
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: Scaffold(
            body: child,
          ),
        ),
      ),
    );
  }
}

class _WidgetHarness extends StatelessWidget {
  const _WidgetHarness({
    required this.state,
  });

  final CalendarState state;

  @override
  Widget build(BuildContext context) {
    final bloc = _MockCalendarBloc();
    when(() => bloc.state).thenReturn(state);
    when(() => bloc.stream).thenAnswer((_) => Stream<CalendarState>.empty());
    when(() => bloc.add(any())).thenReturn(null);

    return MultiBlocProvider(
      providers: [
        BlocProvider<CalendarBloc>.value(value: bloc),
      ],
      child: MaterialApp(
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(1920, 1080),
            ),
            child: const CalendarWidget(),
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerCalendarFallbackValues);

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

    expect(find.text('12 AM'), findsWidgets);
  });

  testWidgets('CalendarWidget desktop layout shows grid', (tester) async {
    final state = CalendarTestData.weekView();
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_WidgetHarness(state: state));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarGrid<CalendarBloc>), findsOneWidget);
    expect(find.text('12 AM'), findsWidgets);
  });
}
