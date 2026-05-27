import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Finder recipientChipsInputFinder({Finder? root}) {
  final input = find.descendant(
    of: find.byKey(const ValueKey<String>('autocomplete-field')),
    matching: find.byType(AxiTextField),
  );
  if (root == null) {
    return input;
  }
  return find.descendant(of: root, matching: input);
}

Future<void> submitRecipientChip(
  WidgetTester tester,
  String text, {
  Finder? root,
}) async {
  final field = tester.widget<AxiTextField>(
    recipientChipsInputFinder(root: root),
  );
  field.controller!.text = text;
  field.onSubmitted?.call(text);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> typePendingRecipientChip(
  WidgetTester tester,
  String text, {
  Finder? root,
}) async {
  final field = tester.widget<AxiTextField>(
    recipientChipsInputFinder(root: root),
  );
  field.focusNode!.requestFocus();
  await tester.pump();
  field.controller!.text = text;
  await tester.pump();
}

Future<void> tapFirstRecipientDelete(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Delete').first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder sendIconButtonFinder() {
  return find.byWidgetPredicate(
    (widget) => widget is AxiIconButton && widget.iconData == LucideIcons.send,
  );
}

Future<void> assertPendingRecipientTapIsConsumed({
  required WidgetTester tester,
  required String pendingText,
  required Finder sendFinder,
  required bool Function() hasSent,
}) async {
  await typePendingRecipientChip(tester, pendingText);
  await tester.tap(sendFinder, warnIfMissed: false);
  await tester.pump();

  expect(hasSent(), isFalse);

  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(sendFinder, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
