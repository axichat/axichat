import 'package:axichat/src/common/html_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart' as html_widget;
import 'package:flutter_test/flutter_test.dart';

const String _rawHtml = '<script>alert(1)</script><p>ok</p>';
const String _expectedMarkup = '<p>ok</p>';
const String _blockedTag = '<script';

void main() {
  testWidgets('Html widget uses sanitized markup', (tester) async {
    final sanitized = HtmlContentCodec.sanitizeHtml(_rawHtml);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: html_widget.Html(data: sanitized),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final widget = tester.widget<html_widget.Html>(
      find.byType(html_widget.Html),
    );
    expect(widget.data?.contains(_blockedTag), isFalse);
    expect(widget.data?.contains(_expectedMarkup), isTrue);
  });
}
