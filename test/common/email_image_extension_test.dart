import 'package:axichat/src/chat/view/widgets/email_image_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart' as html_widget;
import 'package:flutter_test/flutter_test.dart';

const String _httpsImageHtml = '<img src="https://example.com/p.png" />';
const String _httpImageHtml = '<img src="http://example.com/p.png" />';
const bool _shouldLoadDisabled = false;
const bool _shouldLoadEnabled = true;
const bool _expectError = true;
const bool _expectNoError = false;

class _EmailImageHarness extends StatelessWidget {
  const _EmailImageHarness({
    required this.html,
    required this.shouldLoad,
  });

  final String html;
  final bool shouldLoad;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: html_widget.Html(
          data: html,
          extensions: [
            createEmailImageExtension(
              shouldLoad: shouldLoad,
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('EmailImageExtension', () {
    testWidgets('blocks remote images when loading is disabled',
        (tester) async {
      await tester.pumpWidget(
        const _EmailImageHarness(
          html: _httpsImageHtml,
          shouldLoad: _shouldLoadDisabled,
        ),
      );
      await tester.pump();

      expect(find.byType(EmailImageLoader), findsNothing);
      final placeholder = tester.widget<EmailImagePlaceholder>(
        find.byType(EmailImagePlaceholder),
      );
      expect(placeholder.isError, _expectNoError);
    });

    testWidgets('rejects non-https sources when loading is enabled',
        (tester) async {
      await tester.pumpWidget(
        const _EmailImageHarness(
          html: _httpImageHtml,
          shouldLoad: _shouldLoadEnabled,
        ),
      );
      await tester.pump();

      expect(find.byType(EmailImageLoader), findsNothing);
      final placeholder = tester.widget<EmailImagePlaceholder>(
        find.byType(EmailImagePlaceholder),
      );
      expect(placeholder.isError, _expectError);
    });
  });
}
