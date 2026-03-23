// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/axi_editable_text.dart' as axi;
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('AxiTextField uses the settings typing animation duration', (
    tester,
  ) async {
    const typingAnimationDuration = Duration(milliseconds: 240);
    final controller = TextEditingController();

    await tester.pumpWidget(
      _ComposerInputTestApp(
        settingsCubit: _mockSettingsCubit(
          animationDuration: typingAnimationDuration,
        ),
        child: AxiTextField(controller: controller),
      ),
    );

    final editableText = tester.widget<axi.EditableText>(
      find.byType(axi.EditableText),
    );

    expect(editableText.typingAnimationDuration, typingAnimationDuration);
  });

  testWidgets('leading cutout children receive taps on their left half', (
    tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      _ComposerInputTestApp(
        settingsCubit: _mockSettingsCubit(),
        child: Center(
          child: SizedBox(
            width: 240,
            child: CutoutSurface(
              backgroundColor: Colors.white,
              borderColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.black),
              ),
              cutouts: [
                CutoutSpec(
                  edge: CutoutEdge.left,
                  alignment: Alignment.centerLeft,
                  depth: 20,
                  thickness: 48,
                  cornerRadius: 16,
                  child: SizedBox(
                    key: const Key('leading-cutout-button'),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        tapCount += 1;
                      },
                      child: const ColoredBox(color: Colors.red),
                    ),
                  ),
                ),
              ],
              child: const SizedBox(
                height: 80,
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );

    final buttonRect = tester.getRect(
      find.byKey(const Key('leading-cutout-button')),
    );
    await tester.tapAt(Offset(buttonRect.left + 5, buttonRect.center.dy));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets(
    'typing caret advances when inserts retarget before the next frame',
    (tester) async {
      final controller = TypingTextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _ComposerInputTestApp(
          settingsCubit: _mockSettingsCubit(),
          child: Center(
            child: SizedBox(
              width: 320,
              child: axi.EditableText(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(fontSize: 18, color: Colors.black),
                cursorColor: Colors.blue,
                backgroundCursorColor: Colors.grey,
                typingAnimationDuration: const Duration(milliseconds: 300),
              ),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      final TypingCaretPainter painter = _typingCaretPainter(tester);
      final double initialDx = painter.caretOffset.dx;

      controller.value = const TextEditingValue(
        text: 'a',
        selection: TextSelection.collapsed(offset: 1),
      );
      final double afterFirstInsertDx = painter.caretOffset.dx;

      controller.value = const TextEditingValue(
        text: 'ab',
        selection: TextSelection.collapsed(offset: 2),
      );
      final double afterRetargetDx = painter.caretOffset.dx;

      await tester.pump(const Duration(milliseconds: 120));
      final double settledDx = painter.caretOffset.dx;

      expect(afterFirstInsertDx, initialDx);
      expect(afterRetargetDx, greaterThan(initialDx));
      expect(afterRetargetDx, lessThanOrEqualTo(settledDx));

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focusNode.dispose();
    },
  );

  testWidgets(
    'typing caret has advanced before the glyph animation completes',
    (tester) async {
      final controller = TypingTextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _ComposerInputTestApp(
          settingsCubit: _mockSettingsCubit(),
          child: Center(
            child: SizedBox(
              width: 320,
              child: axi.EditableText(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(fontSize: 18, color: Colors.black),
                cursorColor: Colors.blue,
                backgroundCursorColor: Colors.grey,
                typingAnimationDuration: const Duration(milliseconds: 300),
              ),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      final TypingCaretPainter painter = _typingCaretPainter(tester);
      final double initialDx = painter.caretOffset.dx;

      controller.value = const TextEditingValue(
        text: 'a',
        selection: TextSelection.collapsed(offset: 1),
      );

      await tester.pump(const Duration(milliseconds: 16));
      final double midAnimationDx = painter.caretOffset.dx;

      await tester.pump(const Duration(milliseconds: 80));
      final double finalDx = painter.caretOffset.dx;

      expect(midAnimationDx, greaterThan(initialDx));
      expect(finalDx, greaterThanOrEqualTo(midAnimationDx));

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focusNode.dispose();
    },
  );

  testWidgets('typing caret does not use predictive motion for RTL', (
    tester,
  ) async {
    final controller = TypingTextEditingController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      _ComposerInputTestApp(
        settingsCubit: _mockSettingsCubit(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              width: 320,
              child: axi.EditableText(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(fontSize: 18, color: Colors.black),
                cursorColor: Colors.blue,
                backgroundCursorColor: Colors.grey,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.start,
                typingAnimationDuration: const Duration(milliseconds: 300),
              ),
            ),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();

    final TypingCaretPainter painter = _typingCaretPainter(tester);
    final double initialDx = painter.caretOffset.dx;

    controller.value = const TextEditingValue(
      text: 'a',
      selection: TextSelection.collapsed(offset: 1),
    );
    final double immediateDx = painter.caretOffset.dx;

    expect(immediateDx, initialDx);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    focusNode.dispose();
  });
}

class _ComposerInputTestApp extends StatelessWidget {
  const _ComposerInputTestApp({
    required this.settingsCubit,
    required this.child,
  });

  final SettingsCubit settingsCubit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SettingsCubit>.value(
      value: settingsCubit,
      child: MaterialApp(
        theme: ThemeData(
          extensions: const <ThemeExtension<dynamic>>[
            axiBorders,
            axiRadii,
            axiSpacing,
            axiSizing,
            axiMotion,
          ],
        ),
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: Scaffold(body: child),
        ),
      ),
    );
  }
}

SettingsCubit _mockSettingsCubit({Duration animationDuration = Duration.zero}) {
  final settingsCubit = _MockSettingsCubit();
  when(() => settingsCubit.state).thenReturn(const SettingsState());
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => settingsCubit.animationDuration).thenReturn(animationDuration);
  return settingsCubit;
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

TypingCaretPainter _typingCaretPainter(WidgetTester tester) {
  final editableState = tester.state<axi.EditableTextState>(
    find.byType(axi.EditableText),
  );
  final RenderEditable renderEditable = editableState.renderEditable;
  return renderEditable.foregroundPainter! as TypingCaretPainter;
}
