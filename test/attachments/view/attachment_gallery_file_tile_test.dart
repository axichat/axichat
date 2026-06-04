import 'dart:async';

import 'package:axichat/src/attachments/view/attachment_gallery_view.dart';
import 'package:axichat/src/chat/view/composer/attachment_preview.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('narrow non-media gallery tile uses compact menu layout', (
    tester,
  ) async {
    const metadata = FileMetadataData(
      id: 'zip-1',
      filename: 'attachments.zip',
      mimeType: 'application/zip',
      sizeBytes: 22,
    );

    await tester.pumpWidget(
      _wrap(
        AttachmentGalleryTile(
          metadata: metadata,
          metadataPending: false,
          stanzaId: 'stanza-1',
          allowed: true,
          downloadDelegate: AttachmentDownloadDelegate(() async => false),
          metadataReloadDelegate: AttachmentMetadataReloadDelegate(
            () async => metadata,
          ),
          onAllowPressed: null,
          metaText: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChatAttachmentPreview), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Preview'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery file tile strips unicode controls from filename', (
    tester,
  ) async {
    const metadata = FileMetadataData(
      id: 'spoofed-name',
      filename: 'invoice\u202Efdp.exe',
      mimeType: 'application/pdf',
      sizeBytes: 22,
    );

    await tester.pumpWidget(
      _wrap(
        AttachmentGalleryTile(
          metadata: metadata,
          metadataPending: false,
          stanzaId: 'stanza-spoofed-name',
          allowed: true,
          downloadDelegate: AttachmentDownloadDelegate(() async => false),
          metadataReloadDelegate: AttachmentMetadataReloadDelegate(
            () async => metadata,
          ),
          onAllowPressed: null,
          metaText: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('invoicefdp.exe'), findsOneWidget);
    expect(find.text('invoice\u202Efdp.exe'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery file tile contains expected download failures', (
    tester,
  ) async {
    const metadata = FileMetadataData(
      id: 'download-failure',
      filename: 'notes.txt',
      mimeType: 'text/plain',
      sizeBytes: 22,
    );
    var downloadCount = 0;

    await tester.pumpWidget(
      _wrap(
        AttachmentGalleryTile(
          metadata: metadata,
          metadataPending: false,
          stanzaId: 'stanza-download-failure',
          allowed: true,
          downloadDelegate: AttachmentDownloadDelegate(() async {
            downloadCount += 1;
            throw XmppMessageException();
          }),
          metadataReloadDelegate: AttachmentMetadataReloadDelegate(
            () async => metadata,
          ),
          onAllowPressed: null,
          metaText: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download and save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(downloadCount, 1);
    expect(find.text('Attachment unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview action appears for pdf and text gallery tiles', (
    tester,
  ) async {
    const pdfMetadata = FileMetadataData(
      id: 'pdf-1',
      filename: 'report.pdf',
      path: '/tmp/report.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 1200,
    );

    await tester.pumpWidget(
      _wrap(
        AttachmentGalleryTile(
          key: const ValueKey('pdf-gallery-tile'),
          metadata: pdfMetadata,
          metadataPending: false,
          stanzaId: 'stanza-pdf',
          allowed: true,
          downloadDelegate: null,
          metadataReloadDelegate: AttachmentMetadataReloadDelegate(
            () async => pdfMetadata,
          ),
          onAllowPressed: null,
          metaText: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Preview'), findsOneWidget);

    const textMetadata = FileMetadataData(
      id: 'text-1',
      filename: 'notes.txt',
      path: '/tmp/notes.txt',
      mimeType: 'application/octet-stream',
      sizeBytes: 42,
    );

    await tester.pumpWidget(
      _wrap(
        AttachmentGalleryTile(
          key: const ValueKey('text-gallery-tile'),
          metadata: textMetadata,
          metadataPending: false,
          stanzaId: 'stanza-text',
          allowed: true,
          downloadDelegate: null,
          metadataReloadDelegate: AttachmentMetadataReloadDelegate(
            () async => textMetadata,
          ),
          onAllowPressed: null,
          metaText: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local gallery tile uses local action labels', (tester) async {
    const remoteMetadata = FileMetadataData(
      id: 'text-download-1',
      filename: 'notes.txt',
      mimeType: 'text/plain',
      sizeBytes: 5,
    );
    final localMetadata = remoteMetadata.copyWith(path: '/tmp/notes.txt');

    await tester.pumpWidget(
      _wrap(
        AttachmentGalleryTile(
          key: const ValueKey('remote-text-tile'),
          metadata: remoteMetadata,
          metadataPending: false,
          stanzaId: 'stanza-text-download',
          allowed: true,
          downloadDelegate: AttachmentDownloadDelegate(() async => true),
          metadataReloadDelegate: AttachmentMetadataReloadDelegate(
            () async => localMetadata,
          ),
          onAllowPressed: null,
          metaText: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Download and save'), findsOneWidget);
    expect(find.text('Download and share'), findsOneWidget);
    expect(find.text('Download and preview'), findsOneWidget);
    expect(find.text('Not downloaded yet • 5 B'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        AttachmentGalleryTile(
          key: const ValueKey('local-text-tile'),
          metadata: localMetadata,
          metadataPending: false,
          stanzaId: 'stanza-text-download',
          allowed: true,
          downloadDelegate: AttachmentDownloadDelegate(() async => true),
          metadataReloadDelegate: AttachmentMetadataReloadDelegate(
            () async => localMetadata,
          ),
          onAllowPressed: null,
          metaText: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Download and save'), findsNothing);
    expect(find.text('Download and share'), findsNothing);
    expect(find.text('Download and preview'), findsNothing);
    expect(find.text('On this device • 5 B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local gallery file keeps actions when auto download is off', (
    tester,
  ) async {
    const metadata = FileMetadataData(
      id: 'local-policy-off-text',
      filename: 'notes.txt',
      path: '/tmp/notes.txt',
      mimeType: 'text/plain',
      sizeBytes: 5,
    );

    await tester.pumpWidget(
      _wrap(
        AttachmentGalleryTile(
          metadata: metadata,
          metadataPending: false,
          stanzaId: 'stanza-local-policy-off',
          allowed: false,
          downloadDelegate: null,
          metadataReloadDelegate: AttachmentMetadataReloadDelegate(
            () async => metadata,
          ),
          onAllowPressed: () {},
          metaText: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('On this device • 5 B'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Load attachment'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _wrap(Widget child) {
  final settingsCubit = _MockSettingsCubit();
  when(() => settingsCubit.state).thenReturn(const SettingsState());
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
  final theme = AppTheme.build(
    shadColor: ShadColor.blue,
    brightness: Brightness.light,
    platform: defaultTargetPlatform,
  );
  return ShadApp(
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<SettingsCubit>.value(
      value: settingsCubit,
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: axiSizing.attachmentPreviewExtent,
            child: child,
          ),
        ),
      ),
    ),
  );
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
