import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('RecipientChipsBar overlay submits a suggested chat', (
    tester,
  ) async {
    Contact? added;
    await tester.pumpWidget(
      _wrap(
        RecipientChipsBar(
          recipients: const <ComposerRecipient>[],
          availableChats: [_chat()],
          latestStatuses: const {},
          selfIdentity: const SelfAvatar(),
          onRecipientAdded: (target) {
            added = target;
            return true;
          },
          onRecipientRemoved: (_) {},
        ),
      ),
    );

    final field = tester.widget<AxiTextField>(find.byType(AxiTextField));
    field.controller!.text = 'Alpha';
    field.onSubmitted?.call('Alpha');
    await tester.pump();

    expect(added?.chat?.jid, 'alpha@axi.im');
  });
}

Widget _wrap(Widget child) {
  final settingsCubit = _MockSettingsCubit();
  when(() => settingsCubit.state).thenReturn(const SettingsState());
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
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
        child: Scaffold(body: child),
      ),
    ),
  );
}

Chat _chat() {
  return Chat(
    jid: 'alpha@axi.im',
    title: 'Alpha',
    type: ChatType.chat,
    lastChangeTimestamp: DateTime(2026),
  );
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
