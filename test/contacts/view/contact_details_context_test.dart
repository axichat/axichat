import 'dart:async';

import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/contacts/bloc/contacts_cubit.dart';
import 'package:axichat/src/contacts/view/contacts_list.dart';
import 'package:axichat/src/folders/bloc/folders_cubit.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('showContactDetailsSheet builds with required providers', (
    tester,
  ) async {
    final contact = ContactDirectoryEntry(
      address: 'alpha@example.com',
      hasXmppRoster: true,
      hasEmailContact: false,
      emailNativeIds: const [],
      xmppTitle: 'Alpha',
    );

    await tester.pumpWidget(
      _ContactDetailsHarness(
        contact: contact,
        childBuilder: (context) => AxiButton.primary(
          onPressed: () {
            unawaited(
              showContactDetailsSheet(context: context, contact: contact),
            );
          },
          child: const Text('Open contact details'),
        ),
      ),
    );

    await tester.tap(find.text('Open contact details'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final summary = find.byKey(
      const ValueKey<String>('contact-summary-alpha@example.com'),
    );
    expect(summary, findsOneWidget);
  });
}

class _ContactDetailsHarness extends StatelessWidget {
  _ContactDetailsHarness({required this.contact, required this.childBuilder})
    : settingsCubit = _settingsCubit(),
      contactsCubit = _contactsCubit(contact),
      blocklistCubit = _blocklistCubit(),
      foldersCubit = _foldersCubit(),
      chatsCubit = _chatsCubit();

  final ContactDirectoryEntry contact;
  final WidgetBuilder childBuilder;
  final SettingsCubit settingsCubit;
  final ContactsCubit contactsCubit;
  final BlocklistCubit blocklistCubit;
  final FoldersCubit foldersCubit;
  final ChatsCubit chatsCubit;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.build(
      shadColor: ShadColor.blue,
      brightness: Brightness.light,
      platform: defaultTargetPlatform,
    );
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>.value(value: settingsCubit),
        BlocProvider<ContactsCubit>.value(value: contactsCubit),
        BlocProvider<BlocklistCubit>.value(value: blocklistCubit),
        BlocProvider<FoldersCubit>.value(value: foldersCubit),
        BlocProvider<ChatsCubit>.value(value: chatsCubit),
      ],
      child: ShadApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(child: Builder(builder: childBuilder)),
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

ContactsCubit _contactsCubit(ContactDirectoryEntry contact) {
  final cubit = _MockContactsCubit();
  when(
    () => cubit.state,
  ).thenReturn(ContactsState(items: [contact], visibleItems: [contact]));
  when(
    () => cubit.stream,
  ).thenAnswer((_) => const Stream<ContactsState>.empty());
  return cubit;
}

BlocklistCubit _blocklistCubit() {
  final cubit = _MockBlocklistCubit();
  when(
    () => cubit.state,
  ).thenReturn(const BlocklistAvailable(items: [], visibleItems: []));
  when(
    () => cubit.stream,
  ).thenAnswer((_) => const Stream<BlocklistState>.empty());
  return cubit;
}

FoldersCubit _foldersCubit() {
  final cubit = _MockFoldersCubit();
  when(() => cubit.state).thenReturn(
    FoldersState(
      collectionId: SystemMessageCollection.important.id,
      chatJid: null,
      collections: const [],
      memberships: const [],
      contactFolderRules: const <String, String>{},
      items: null,
      visibleItems: null,
    ),
  );
  when(
    () => cubit.stream,
  ).thenAnswer((_) => const Stream<FoldersState>.empty());
  return cubit;
}

ChatsCubit _chatsCubit() {
  final cubit = _MockChatsCubit();
  when(() => cubit.state).thenReturn(
    const ChatsState(
      openCalendar: false,
      items: [],
      creationStatus: RequestStatus.none,
    ),
  );
  when(() => cubit.stream).thenAnswer((_) => const Stream<ChatsState>.empty());
  return cubit;
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockContactsCubit extends Mock implements ContactsCubit {}

class _MockBlocklistCubit extends Mock implements BlocklistCubit {}

class _MockFoldersCubit extends Mock implements FoldersCubit {}

class _MockChatsCubit extends Mock implements ChatsCubit {}
