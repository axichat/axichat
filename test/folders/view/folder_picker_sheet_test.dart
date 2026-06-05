import 'dart:async';

import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/contacts/bloc/contacts_cubit.dart';
import 'package:axichat/src/folders/bloc/folders_cubit.dart';
import 'package:axichat/src/folders/view/folder_picker_sheet.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(
      const ContactDirectoryEntry(
        address: 'fallback@example.com',
        hasXmppRoster: false,
        hasEmailContact: false,
        emailNativeIds: [],
      ),
    );
  });

  testWidgets('add-to-folder sheet uses an edge-to-edge scaffold surface', (
    tester,
  ) async {
    final foldersCubit = _MockFoldersCubit();
    final chatBloc = _MockChatBloc();
    final settingsCubit = _settingsCubit();

    final chat = Chat(
      jid: 'alpha@example.com',
      title: 'Alpha',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2026),
    );
    final message = Message(
      stanzaID: 'message-1',
      senderJid: chat.jid,
      chatJid: chat.jid,
      timestamp: DateTime.utc(2026),
    );
    final foldersState = FoldersState(
      collectionId: SystemMessageCollection.important.id,
      chatJid: null,
      collections: [
        MessageCollectionEntry(
          id: 'Projects',
          title: null,
          isSystem: false,
          sortOrder: 0,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          active: true,
        ),
      ],
      memberships: const [],
      contactFolderRules: const <String, String>{},
      items: null,
      visibleItems: null,
    );
    when(() => foldersCubit.state).thenReturn(foldersState);
    when(
      () => foldersCubit.stream,
    ).thenAnswer((_) => const Stream<FoldersState>.empty());
    when(() => chatBloc.state).thenReturn(const ChatState(items: []));
    when(
      () => chatBloc.stream,
    ).thenAnswer((_) => const Stream<ChatState>.empty());

    await _pumpFolderApp(
      tester,
      settingsCubit: settingsCubit,
      foldersCubit: foldersCubit,
      chatBloc: chatBloc,
      child: Builder(
        builder: (context) {
          return Center(
            child: AxiButton.primary(
              onPressed: () => unawaited(
                showAddToFolderSheet(context, message: message, chat: chat),
              ),
              child: const Text('Open folders'),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('Open folders'));
    await tester.pumpAndSettle();

    expect(find.text('Add to folder'), findsOneWidget);
    expect(find.byType(AxiSheetActions), findsOneWidget);
    expect(
      tester
          .widgetList<AxiModalSurface>(find.byType(AxiModalSurface))
          .any((surface) => surface.padding == EdgeInsets.zero),
      isTrue,
    );
  });

  testWidgets('new folder dialog keeps symmetric field spacing', (
    tester,
  ) async {
    final foldersCubit = _MockFoldersCubit();
    final settingsCubit = _settingsCubit();

    when(() => foldersCubit.state).thenReturn(
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
      () => foldersCubit.stream,
    ).thenAnswer((_) => const Stream<FoldersState>.empty());

    await _pumpFolderApp(
      tester,
      settingsCubit: settingsCubit,
      foldersCubit: foldersCubit,
      child: Builder(
        builder: (context) {
          return Center(
            child: AxiButton.primary(
              onPressed: () => unawaited(showFolderCreateDialog(context)),
              child: const Text('Create folder'),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('Create folder'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(AxiDialogScaffold), findsOneWidget);
    expect(find.byType(AxiSheetScaffold), findsNothing);

    final Rect fieldRect = tester.getRect(find.byType(AxiTextFormField));
    final Rect headerDividerRect = tester.getRect(
      find.byType(AxiModalEdgeDivider).first,
    );
    final Rect footerDividerRect = tester.getRect(
      find.byType(AxiModalEdgeDivider).last,
    );

    expect(find.text('Folder name'), findsOneWidget);
    expect(fieldRect.top - headerDividerRect.bottom, 8);
    expect(footerDividerRect.top - fieldRect.bottom, 8);
  });

  testWidgets(
    'showContactFolderRuleSheet survives opener disposal and calls contacts cubit',
    (tester) async {
      final foldersCubit = _MockFoldersCubit();
      final contactsCubit = _MockContactsCubit();
      final settingsCubit = _settingsCubit();
      final showOpener = ValueNotifier<bool>(true);
      addTearDown(showOpener.dispose);

      final contact = ContactDirectoryEntry(
        address: 'alpha@example.com',
        hasXmppRoster: true,
        hasEmailContact: false,
        emailNativeIds: const [],
        xmppTitle: 'Alpha',
      );
      final collection = MessageCollectionEntry(
        id: 'Projects',
        title: null,
        isSystem: false,
        sortOrder: 0,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        active: true,
      );
      when(() => foldersCubit.state).thenReturn(
        FoldersState(
          collectionId: SystemMessageCollection.important.id,
          chatJid: null,
          collections: [collection],
          memberships: const [],
          contactFolderRules: const <String, String>{},
          items: null,
          visibleItems: null,
        ),
      );
      when(
        () => foldersCubit.stream,
      ).thenAnswer((_) => const Stream<FoldersState>.empty());
      when(
        () => contactsCubit.state,
      ).thenReturn(ContactsState(items: [contact], visibleItems: [contact]));
      when(
        () => contactsCubit.stream,
      ).thenAnswer((_) => const Stream<ContactsState>.empty());
      when(
        () => contactsCubit.setContactFolderRule(
          contact: any(named: 'contact'),
          collectionId: any(named: 'collectionId'),
        ),
      ).thenAnswer((_) async {});

      await _pumpFolderApp(
        tester,
        settingsCubit: settingsCubit,
        foldersCubit: foldersCubit,
        contactsCubit: contactsCubit,
        child: ValueListenableBuilder<bool>(
          valueListenable: showOpener,
          builder: (context, visible, child) {
            if (!visible) {
              return const SizedBox.shrink();
            }
            return Center(
              child: AxiButton.primary(
                onPressed: () => unawaited(
                  showContactFolderRuleSheet(context, contact: contact),
                ),
                child: const Text('Open folder rule'),
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('Open folder rule'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      showOpener.value = false;
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Projects'));
      await tester.pump();

      verify(
        () => contactsCubit.setContactFolderRule(
          contact: contact,
          collectionId: 'Projects',
        ),
      ).called(1);
    },
  );
}

Future<void> _pumpFolderApp(
  WidgetTester tester, {
  required SettingsCubit settingsCubit,
  required FoldersCubit foldersCubit,
  ChatBloc? chatBloc,
  ContactsCubit? contactsCubit,
  required Widget child,
}) {
  return tester.pumpWidget(
    BlocProvider<SettingsCubit>.value(
      value: settingsCubit,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          platform: TargetPlatform.android,
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF0F172A),
          brightness: Brightness.light,
          extensions: const <ThemeExtension<dynamic>>[
            axiBorders,
            axiRadii,
            axiSpacing,
            axiSizing,
            axiMotion,
          ],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: MultiBlocProvider(
            providers: [
              BlocProvider<FoldersCubit>.value(value: foldersCubit),
              if (chatBloc != null)
                BlocProvider<ChatBloc>.value(value: chatBloc),
              if (contactsCubit != null)
                BlocProvider<ContactsCubit>.value(value: contactsCubit),
            ],
            child: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );
}

class _MockFoldersCubit extends MockCubit<FoldersState>
    implements FoldersCubit {}

class _MockChatBloc extends MockBloc<ChatEvent, ChatState>
    implements ChatBloc {}

class _MockContactsCubit extends MockCubit<ContactsState>
    implements ContactsCubit {}

SettingsCubit _settingsCubit() {
  final settingsCubit = _MockSettingsCubit();
  when(() => settingsCubit.state).thenReturn(const SettingsState());
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
  return settingsCubit;
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
