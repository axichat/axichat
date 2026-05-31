import 'dart:typed_data';

import 'package:axichat/src/chat/view/timeline/message/email_image_extension.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart' as html_widget;
import 'package:flutter_test/flutter_test.dart';

const String _httpsImageHtml = '<img src="https://example.com/p.png" />';
const String _httpImageHtml = '<img src="http://example.com/p.png" />';
const bool _shouldLoadDisabled = false;
const bool _shouldLoadEnabled = true;

class _EmailImageHarness extends StatelessWidget {
  const _EmailImageHarness({required this.html, required this.shouldLoad});

  final String html;
  final bool shouldLoad;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: html_widget.Html(
          data: html,
          extensions: [createEmailImageExtension(shouldLoad: shouldLoad)],
        ),
      ),
    );
  }
}

void main() {
  group('EmailImageExtension', () {
    setUp(clearEmailImageByteCacheForTesting);
    tearDown(clearEmailImageByteCacheForTesting);

    testWidgets('blocks remote images when loading is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _EmailImageHarness(
          html: _httpsImageHtml,
          shouldLoad: _shouldLoadDisabled,
        ),
      );
      await tester.pump();

      expect(find.byType(AxiProgressIndicator), findsNothing);
      expect(find.byType(EmailImagePlaceholder), findsNothing);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('rejects non-https sources when loading is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _EmailImageHarness(
          html: _httpImageHtml,
          shouldLoad: _shouldLoadEnabled,
        ),
      );
      await tester.pump();

      expect(find.byType(AxiProgressIndicator), findsNothing);
      expect(find.byType(EmailImagePlaceholder), findsNothing);
      expect(find.byType(Image), findsNothing);
    });

    test('returns cached remote image bytes', () {
      final bytes = Uint8List.fromList(const [1, 2, 3]);

      cacheEmailImageBytesForTesting('https://example.com/image.png', bytes);

      expect(
        cachedEmailImageBytesForTesting('https://example.com/image.png'),
        same(bytes),
      );
      expect(emailImageByteCacheEntryCountForTesting(), 1);
      expect(emailImageByteCacheSizeBytesForTesting(), bytes.length);
    });

    test('does not cache empty remote image bytes', () {
      cacheEmailImageBytesForTesting(
        'https://example.com/empty.png',
        Uint8List(0),
      );

      expect(
        emailImageByteCacheContainsForTesting('https://example.com/empty.png'),
        isFalse,
      );
      expect(emailImageByteCacheEntryCountForTesting(), 0);
    });

    test('evicts least recently used remote image bytes by entry count', () {
      final bytes = Uint8List.fromList(const [1]);
      cacheEmailImageBytesForTesting('https://example.com/first.png', bytes);
      cacheEmailImageBytesForTesting('https://example.com/second.png', bytes);
      expect(
        cachedEmailImageBytesForTesting('https://example.com/first.png'),
        same(bytes),
      );

      for (var index = 0; index < 63; index += 1) {
        cacheEmailImageBytesForTesting(
          'https://example.com/fill-$index.png',
          bytes,
        );
      }

      expect(emailImageByteCacheEntryCountForTesting(), 64);
      expect(
        emailImageByteCacheContainsForTesting('https://example.com/first.png'),
        isTrue,
      );
      expect(
        emailImageByteCacheContainsForTesting('https://example.com/second.png'),
        isFalse,
      );
    });

    test('evicts oldest remote image bytes by total size', () {
      final bytes = Uint8List(1024 * 1024);

      for (var index = 0; index < 25; index += 1) {
        cacheEmailImageBytesForTesting(
          'https://example.com/large-$index.png',
          bytes,
        );
      }

      expect(emailImageByteCacheEntryCountForTesting(), 24);
      expect(emailImageByteCacheSizeBytesForTesting(), 24 * 1024 * 1024);
      expect(
        emailImageByteCacheContainsForTesting(
          'https://example.com/large-0.png',
        ),
        isFalse,
      );
      expect(
        emailImageByteCacheContainsForTesting(
          'https://example.com/large-24.png',
        ),
        isTrue,
      );
    });
  });
}
