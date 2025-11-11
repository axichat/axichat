import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:axichat/src/calendar/view/widgets/calendar_keyboard_scope.dart';

void main() {
  Future<void> sendShortcut(
    WidgetTester tester,
    List<LogicalKeyboardKey> modifiers,
    LogicalKeyboardKey key,
  ) async {
    for (final modifier in modifiers) {
      await tester.sendKeyDownEvent(modifier);
    }
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
    for (final modifier in modifiers.reversed) {
      await tester.sendKeyUpEvent(modifier);
    }
    await tester.pump();
  }

  testWidgets('triggers undo and redo shortcuts', (tester) async {
    int undoCount = 0;
    int redoCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CalendarKeyboardScope(
          autofocus: true,
          canUndo: true,
          canRedo: true,
          onUndo: () => undoCount++,
          onRedo: () => redoCount++,
          child: const SizedBox.shrink(),
        ),
      ),
    );

    await sendShortcut(
      tester,
      const [LogicalKeyboardKey.controlLeft],
      LogicalKeyboardKey.keyZ,
    );
    await sendShortcut(
      tester,
      const [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.shiftLeft],
      LogicalKeyboardKey.keyZ,
    );
    await sendShortcut(
      tester,
      const [LogicalKeyboardKey.controlLeft],
      LogicalKeyboardKey.keyY,
    );

    expect(undoCount, 1);
    expect(redoCount, 2);
  });

  testWidgets('ignores shortcuts when text input focused', (tester) async {
    int undoCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CalendarKeyboardScope(
          autofocus: true,
          canUndo: true,
          canRedo: true,
          onUndo: () => undoCount++,
          onRedo: () {},
          child: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(12),
              child: TextField(),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await sendShortcut(
      tester,
      const [LogicalKeyboardKey.controlLeft],
      LogicalKeyboardKey.keyZ,
    );

    expect(undoCount, 0);
  });
}
