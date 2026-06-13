import 'dart:io';
import 'dart:typed_data';

import 'package:axichat/src/chat/view/composer/attachment_preview.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/ui/axi_sizing.dart';
import 'package:axichat/src/common/ui/axi_spacing.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_tools;
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  test('mobile save branch passes attachment bytes to file picker', () async {
    final tempDir = Directory.systemTemp.createTempSync(
      'axichat-attachment-save-mobile-test-',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final file = File('${tempDir.path}/bundle.zip')
      ..writeAsBytesSync(<int>[1, 2, 3]);
    final filePicker = _FakeFilePicker();

    await saveAttachmentFileWithPicker(
      file: file,
      filename: 'bundle.zip',
      platform: TargetPlatform.android,
      filePicker: filePicker,
    );

    expect(filePicker.savedFileName, 'bundle.zip');
    expect(filePicker.savedBytes, Uint8List.fromList(<int>[1, 2, 3]));
  });

  test('desktop save branch asks for a path without bytes', () async {
    final tempDir = Directory.systemTemp.createTempSync(
      'axichat-attachment-save-desktop-test-',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final file = File('${tempDir.path}/bundle.zip')
      ..writeAsBytesSync(<int>[1, 2, 3]);
    final filePicker = _FakeFilePicker();

    await saveAttachmentFileWithPicker(
      file: file,
      filename: 'bundle.zip',
      platform: TargetPlatform.macOS,
      filePicker: filePicker,
    );

    expect(filePicker.savedFileName, 'bundle.zip');
    expect(filePicker.savedBytes, isNull);
  });

  testWidgets('type mismatch approval still requires high-risk confirmation', (
    tester,
  ) async {
    bool? allowed;

    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                allowed = await confirmExportAllowed(
                  context,
                  metadata: const FileMetadataData(
                    id: 'risky-mismatch-attachment',
                    filename: 'payload.html',
                    mimeType: 'text/plain',
                  ),
                  report: const FileTypeReport(
                    detectedMimeType: 'text/html',
                    declaredMimeType: 'text/plain',
                    extensionMimeType: 'text/html',
                  ),
                  confirmLabel: 'Save',
                );
              },
              child: const Text('start export'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('start export'));
    await tester.pumpAndSettle();

    expect(find.text('Attachment type mismatch'), findsOneWidget);
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(find.text('Potentially unsafe file'), findsOneWidget);
    expect(allowed, isNull);
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(allowed, isTrue);
  });

  testWidgets('file bubbles show local availability in metadata line', (
    tester,
  ) async {
    const remoteMetadata = FileMetadataData(
      id: 'remote-text-status',
      filename: 'notes.txt',
      mimeType: 'text/plain',
      sizeBytes: 5,
    );

    await tester.pumpWidget(
      _wrap(
        ChatAttachmentPreview(
          key: const ValueKey('remote-file-status'),
          stanzaId: 'remote-file-status',
          metadata: remoteMetadata,
          allowed: true,
          downloadDelegate: AttachmentDownloadDelegate(() async => false),
          metadataReloadDelegate: AttachmentMetadataReloadDelegate(
            () async => remoteMetadata,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not downloaded yet • 5 B'), findsOneWidget);

    final tempDir = Directory.systemTemp.createTempSync(
      'axichat-file-status-test-',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final file = File('${tempDir.path}/notes.txt')..writeAsStringSync('hello');
    final localMetadata = remoteMetadata.copyWith(
      id: 'local-text-status',
      path: file.path,
    );

    await tester.pumpWidget(
      _wrap(
        ChatAttachmentPreview(
          key: const ValueKey('local-file-status'),
          stanzaId: 'local-file-status',
          metadata: localMetadata,
          allowed: true,
        ),
      ),
    );
    await _pumpUntil(
      tester,
      () => find.text('On this device • 5 B').evaluate().isNotEmpty,
    );

    expect(find.text('On this device • 5 B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local attachments still render when not allowed', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'axichat-blocked-local-attachment-test-',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final file = File('${tempDir.path}/notes.txt')..writeAsStringSync('hello');

    await tester.pumpWidget(
      _wrap(
        ChatAttachmentPreview(
          stanzaId: 'blocked-local-file',
          metadata: FileMetadataData(
            id: 'blocked-local-file',
            filename: 'notes.txt',
            path: file.path,
            mimeType: 'text/plain',
            sizeBytes: 5,
          ),
          allowed: false,
          onAllowPressed: () {},
        ),
      ),
    );
    await _pumpUntil(
      tester,
      () => find.text('On this device • 5 B').evaluate().isNotEmpty,
    );

    expect(find.text('On this device • 5 B'), findsOneWidget);
    expect(find.text('Attachment blocked'), findsNothing);
    expect(find.text('Load attachment'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remote attachments still show blocked state when not allowed', (
    tester,
  ) async {
    const metadata = FileMetadataData(
      id: 'blocked-remote-file',
      filename: 'notes.txt',
      mimeType: 'text/plain',
      sizeBytes: 5,
      sourceUrls: ['https://example.com/notes.txt'],
    );

    await tester.pumpWidget(
      _wrap(
        ChatAttachmentPreview(
          stanzaId: 'blocked-remote-file',
          metadata: metadata,
          allowed: false,
          onAllowPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Attachment blocked'), findsOneWidget);
    expect(find.text('Load attachment'), findsOneWidget);
    expect(find.text('On this device • 5 B'), findsNothing);
    expect(find.text('Not downloaded yet • 5 B'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('file bubble status does not overflow at narrow widths', (
    tester,
  ) async {
    const metadata = FileMetadataData(
      id: 'narrow-remote-text-status',
      filename: 'very-long-file-name-that-forces-compact-actions.txt',
      mimeType: 'text/plain',
      sizeBytes: 5,
    );

    await tester.pumpWidget(
      _wrap(
        ChatAttachmentPreview(
          stanzaId: 'narrow-remote-text-status',
          metadata: metadata,
          allowed: true,
          downloadDelegate: AttachmentDownloadDelegate(() async => false),
          metadataReloadDelegate: AttachmentMetadataReloadDelegate(
            () async => metadata,
          ),
        ),
        width: 120,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not downloaded yet • 5 B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'local chat image bubbles decode at display size but previews stay full size',
    (tester) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'axichat-attachment-preview-test-',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final image = image_tools.Image(width: 2, height: 1, numChannels: 4);
      image_tools.fill(image, color: image_tools.ColorRgba8(255, 0, 0, 255));
      final pngBytes = image_tools.encodePng(image, level: 1);
      final file = File('${tempDir.path}/image.png')
        ..writeAsBytesSync(pngBytes);

      await tester.pumpWidget(
        _wrap(
          ChatAttachmentPreview(
            stanzaId: 'stanza-1',
            metadata: FileMetadataData(
              id: 'image-1',
              filename: 'image.png',
              path: file.path,
              mimeType: 'image/png',
              sizeBytes: pngBytes.length,
              width: 1200,
              height: 600,
            ),
            allowed: true,
          ),
        ),
      );
      await _pumpUntil(tester, () => find.byType(Image).evaluate().isNotEmpty);

      final bubbleImage = tester.widget<Image>(find.byType(Image).first);
      final bubbleProvider = bubbleImage.image;
      expect(bubbleProvider, isA<ResizeImage>());
      final bubbleResizeProvider = bubbleProvider as ResizeImage;
      expect(bubbleResizeProvider.width, isNotNull);
      expect(bubbleResizeProvider.height, isNotNull);
      expect(bubbleResizeProvider.width, lessThan(1200));
      expect(bubbleResizeProvider.height, lessThan(600));

      await tester.tap(find.byIcon(LucideIcons.eye).first);
      await _pumpUntil(
        tester,
        () => tester
            .widgetList<Image>(find.byType(Image))
            .any((image) => image.fit == BoxFit.contain),
      );

      final fullPreviewImage = tester
          .widgetList<Image>(find.byType(Image))
          .where((image) => image.fit == BoxFit.contain)
          .single;
      expect(fullPreviewImage.image, isNot(isA<ResizeImage>()));
    },
  );

  testWidgets('local image validation preserves preview extent', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'axichat-image-validation-extent-test-',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final image = image_tools.Image(width: 2, height: 1, numChannels: 4);
    image_tools.fill(image, color: image_tools.ColorRgba8(255, 0, 0, 255));
    final pngBytes = image_tools.encodePng(image, level: 1);
    final file = File('${tempDir.path}/image.png')..writeAsBytesSync(pngBytes);
    final metadata = FileMetadataData(
      id: 'stable-image-extent',
      filename: 'image.png',
      path: file.path,
      mimeType: 'image/png',
      sizeBytes: pngBytes.length,
      width: 1200,
      height: 600,
    );

    await tester.pumpWidget(
      _wrap(
        ChatAttachmentPreview(
          stanzaId: 'stable-image-extent',
          metadata: metadata,
          allowed: true,
        ),
      ),
    );
    final pendingSize = tester.getSize(find.byType(ChatAttachmentPreview));
    await _pumpUntil(tester, () => find.byType(Image).evaluate().isNotEmpty);
    final loadedSize = tester.getSize(find.byType(ChatAttachmentPreview));

    expect(pendingSize.height, moreOrLessEquals(loadedSize.height));

    await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    await tester.pump();
    await tester.pumpWidget(
      _wrap(
        ChatAttachmentPreview(
          stanzaId: 'stable-image-extent',
          metadata: metadata,
          allowed: true,
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(ChatAttachmentPreview)).height,
      moreOrLessEquals(loadedSize.height),
    );
  });

  testWidgets('pending metadata reserves media preview extent', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ChatAttachmentPreview(
          stanzaId: 'pending-metadata',
          metadata: null,
          metadataPending: true,
          allowed: true,
        ),
      ),
    );

    final pendingSize = tester.getSize(find.byType(ChatAttachmentPreview));
    expect(pendingSize.height, greaterThan(axiSizing.attachmentPreviewExtent));
  });

  testWidgets('local image body tap is handled by parent message wrapper', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'axichat-attachment-parent-tap-test-',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final image = image_tools.Image(width: 2, height: 1, numChannels: 4);
    image_tools.fill(image, color: image_tools.ColorRgba8(255, 0, 0, 255));
    final pngBytes = image_tools.encodePng(image, level: 1);
    final file = File('${tempDir.path}/image.png')..writeAsBytesSync(pngBytes);
    var parentTaps = 0;

    await tester.pumpWidget(
      _wrap(
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            parentTaps += 1;
          },
          child: ChatAttachmentPreview(
            stanzaId: 'stanza-parent-tap',
            metadata: FileMetadataData(
              id: 'image-parent-tap',
              filename: 'image.png',
              path: file.path,
              mimeType: 'image/png',
              sizeBytes: pngBytes.length,
              width: 1200,
              height: 600,
            ),
            allowed: true,
          ),
        ),
      ),
    );
    await _pumpUntil(tester, () => find.byType(Image).evaluate().isNotEmpty);

    await tester.tap(find.byType(Image).first, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(parentTaps, 1);
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('local image attachments show metadata on bubble and preview', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'axichat-attachment-metadata-test-',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final image = image_tools.Image(width: 1, height: 3, numChannels: 4);
    image_tools.fill(image, color: image_tools.ColorRgba8(0, 255, 0, 255));
    final pngBytes = image_tools.encodePng(image, level: 1);
    final file = File('${tempDir.path}/narrow.png')..writeAsBytesSync(pngBytes);

    await tester.pumpWidget(
      _wrap(
        ChatAttachmentPreview(
          stanzaId: 'stanza-metadata',
          metadata: FileMetadataData(
            id: 'image-metadata',
            filename: 'narrow-timeline-image.png',
            path: file.path,
            mimeType: 'image/png',
            sizeBytes: pngBytes.length,
            width: 1,
            height: 3,
          ),
          allowed: true,
          messageDetails: const [TextSpan(text: '12:34')],
        ),
      ),
    );
    await _pumpUntil(
      tester,
      () => find.text('narrow-timeline-image.png').evaluate().isNotEmpty,
    );

    expect(find.text('narrow-timeline-image.png'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(LucideIcons.eye).first);
    await _pumpUntil(
      tester,
      () => tester
          .widgetList<Image>(find.byType(Image))
          .any((image) => image.fit == BoxFit.contain),
    );

    expect(find.text('narrow-timeline-image.png'), findsAtLeastNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('full image preview expands tiny images for metadata width', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'axichat-attachment-metadata-width-test-',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final image = image_tools.Image(width: 1, height: 1, numChannels: 4);
    image_tools.fill(image, color: image_tools.ColorRgba8(0, 0, 255, 255));
    final pngBytes = image_tools.encodePng(image, level: 1);
    final file = File(
      '${tempDir.path}/tiny-image-with-a-very-long-filename.png',
    )..writeAsBytesSync(pngBytes);
    const filename =
        'tiny-image-with-a-very-long-filename-that-needs-wrapping.png';

    await tester.pumpWidget(
      _wrap(
        ChatAttachmentPreview(
          stanzaId: 'stanza-tiny-image',
          metadata: FileMetadataData(
            id: 'tiny-image',
            filename: filename,
            path: file.path,
            mimeType: 'image/png',
            sizeBytes: pngBytes.length,
            width: 1,
            height: 1,
          ),
          allowed: true,
        ),
        mediaSize: const Size(480, 600),
        width: 360,
      ),
    );
    await _pumpUntil(tester, () => find.byType(Image).evaluate().isNotEmpty);

    await tester.tap(find.byIcon(LucideIcons.eye).first);
    await _pumpUntil(
      tester,
      () => find.byType(InteractiveViewer).evaluate().isNotEmpty,
    );

    final previewSize = tester.getSize(find.byType(InteractiveViewer));
    final previewMinWidth =
        (axiSizing.iconButtonTapTarget * 4) + (axiSpacing.xs * 3);
    expect(previewSize.width, greaterThanOrEqualTo(previewMinWidth));
    expect(
      tester.getSize(find.text(filename).last).width,
      equals(previewSize.width),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('full image preview keeps tall images wide enough for actions', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'axichat-attachment-tall-preview-test-',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final image = image_tools.Image(width: 1, height: 300, numChannels: 4);
    image_tools.fill(image, color: image_tools.ColorRgba8(0, 0, 255, 255));
    final pngBytes = image_tools.encodePng(image, level: 1);
    final file = File('${tempDir.path}/tall.png')..writeAsBytesSync(pngBytes);

    await tester.pumpWidget(
      _wrap(
        ChatAttachmentPreview(
          stanzaId: 'stanza-tall-image',
          metadata: FileMetadataData(
            id: 'tall-image',
            filename: 'tall.png',
            path: file.path,
            mimeType: 'image/png',
            sizeBytes: pngBytes.length,
            width: 1,
            height: 300,
          ),
          allowed: true,
        ),
      ),
    );
    await _pumpUntil(tester, () => find.byType(Image).evaluate().isNotEmpty);

    await tester.tap(find.byIcon(LucideIcons.eye).first);
    await _pumpUntil(
      tester,
      () => find.byType(InteractiveViewer).evaluate().isNotEmpty,
    );

    final previewSize = tester.getSize(find.byType(InteractiveViewer));
    final saveRect = tester.getRect(find.byIcon(LucideIcons.save).last);
    final closeRect = tester.getRect(find.byIcon(LucideIcons.x).last);
    expect(find.byIcon(LucideIcons.send), findsOneWidget);
    expect(closeRect.right - saveRect.left, greaterThan(previewSize.width));
    expect(tester.takeException(), isNull);
  });

  testWidgets('local chat image bubble decode dimensions are capped', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'axichat-attachment-preview-test-',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final image = image_tools.Image(width: 2, height: 1, numChannels: 4);
    image_tools.fill(image, color: image_tools.ColorRgba8(255, 0, 0, 255));
    final pngBytes = image_tools.encodePng(image, level: 1);
    final file = File('${tempDir.path}/image.png')..writeAsBytesSync(pngBytes);

    await tester.pumpWidget(
      _wrap(
        ChatAttachmentPreview(
          stanzaId: 'stanza-1',
          metadata: FileMetadataData(
            id: 'image-1',
            filename: 'image.png',
            path: file.path,
            mimeType: 'image/png',
            sizeBytes: pngBytes.length,
            width: 4000,
            height: 2000,
          ),
          allowed: true,
        ),
        mediaSize: const Size(1200, 800),
        devicePixelRatio: 4,
        width: 1000,
      ),
    );
    await _pumpUntil(tester, () => find.byType(Image).evaluate().isNotEmpty);

    final bubbleImage = tester.widget<Image>(find.byType(Image).first);
    final bubbleProvider = bubbleImage.image;
    expect(bubbleProvider, isA<ResizeImage>());
    final bubbleResizeProvider = bubbleProvider as ResizeImage;
    expect(bubbleResizeProvider.width, lessThanOrEqualTo(1280));
    expect(bubbleResizeProvider.height, lessThanOrEqualTo(1280));
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  const maxPumpCount = 80;
  for (var index = 0; index < maxPumpCount; index += 1) {
    if (condition()) return;
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue);
}

Widget _wrap(
  Widget child, {
  Size mediaSize = const Size(240, 320),
  double devicePixelRatio = 2,
  double width = 200,
}) {
  final settingsCubit = _MockSettingsCubit();
  when(() => settingsCubit.state).thenReturn(const SettingsState());
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(
    () => settingsCubit.animationDuration,
  ).thenReturn(const Duration(milliseconds: 200));
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
        child: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              size: mediaSize,
              devicePixelRatio: devicePixelRatio,
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _FakeFilePicker extends FilePicker {
  String? savedFileName;
  Uint8List? savedBytes;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    savedFileName = fileName;
    savedBytes = bytes;
    return null;
  }
}
