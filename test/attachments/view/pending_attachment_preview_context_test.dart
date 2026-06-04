import 'dart:async';
import 'dart:io';

import 'package:axichat/src/attachments/view/pending_attachment_preview.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets(
    'showPendingAttachmentPreview survives opener disposal and calls remove',
    (tester) async {
      final settingsCubit = _settingsCubit();
      final showOpener = ValueNotifier<bool>(true);
      final file = File(
        'test/calendar/view/goldens/calendar_grid_day.png',
      ).absolute;
      var removeCount = 0;
      late BuildContext openerContext;
      addTearDown(showOpener.dispose);

      await tester.pumpWidget(
        _PreviewHarness(
          settingsCubit: settingsCubit,
          showOpener: showOpener,
          onContext: (context) {
            openerContext = context;
          },
        ),
      );

      await tester.runAsync(() async {
        unawaited(
          showPendingAttachmentPreview(
            context: openerContext,
            pending: PendingAttachment(
              id: 'pending-1',
              attachment: Attachment(
                path: file.path,
                fileName: 'preview.png',
                sizeBytes: file.lengthSync(),
                mimeType: 'image/png',
              ),
            ),
            onRemove: () {
              removeCount += 1;
            },
            removeTooltip: 'Remove attachment',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await _pumpUntilFound(tester, find.byTooltip('Remove attachment'));
      expect(tester.takeException(), isNull);

      showOpener.value = false;
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Remove attachment'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(removeCount, 1);
    },
  );
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _PreviewHarness extends StatelessWidget {
  const _PreviewHarness({
    required this.settingsCubit,
    required this.showOpener,
    required this.onContext,
  });

  final SettingsCubit settingsCubit;
  final ValueNotifier<bool> showOpener;
  final ValueChanged<BuildContext> onContext;

  @override
  Widget build(BuildContext context) {
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
            body: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: showOpener,
                builder: (context, visible, child) {
                  if (!visible) {
                    return const SizedBox.shrink();
                  }
                  return Builder(
                    builder: (context) {
                      onContext(context);
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

SettingsCubit _settingsCubit() {
  final cubit = _MockSettingsCubit();
  when(() => cubit.state).thenReturn(const SettingsState());
  when(
    () => cubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => cubit.animationDuration).thenReturn(Duration.zero);
  return cubit;
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
