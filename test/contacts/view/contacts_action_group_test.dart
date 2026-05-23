// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/contacts/bloc/contacts_cubit.dart';
import 'package:axichat/src/contacts/view/contacts_list.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/folders/bloc/folders_cubit.dart';
import 'package:axichat/src/home/bloc/home_bloc.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../mocks.dart';

void main() {
  testWidgets('contacts action group shows filter import and new actions', (
    tester,
  ) async {
    final xmppService = MockXmppService();
    final homeBloc = HomeBloc(
      xmppService: xmppService,
      tabs: const <HomeTab>[HomeTab.contacts, HomeTab.chats],
    );
    addTearDown(homeBloc.close);

    final settingsCubit = MockSettingsCubit();
    when(() => settingsCubit.state).thenReturn(
      const SettingsState(endpointConfig: EndpointConfig(smtpEnabled: false)),
    );
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<HomeBloc>.value(value: homeBloc),
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
        ],
        child: MaterialApp(
          theme: ThemeData(
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
          home: ShadTheme(
            data: ShadThemeData(
              colorScheme: const ShadSlateColorScheme.light(),
              brightness: Brightness.light,
            ),
            child: const Scaffold(body: ContactsActionGroup()),
          ),
        ),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
  });

  testWidgets(
    'contacts add dialog dispatches contact add without RosterCubit',
    (tester) async {
      final xmppService = MockXmppService();
      _stubContactsShellService(
        xmppService,
        contacts: const <ContactDirectoryEntry>[],
      );
      when(
        () => xmppService.addToRoster(
          jid: 'new@example.com',
          title: any(named: 'title'),
        ),
      ).thenAnswer((_) async {});
      final homeBloc = HomeBloc(
        xmppService: xmppService,
        tabs: const <HomeTab>[HomeTab.contacts],
      );
      final contactsCubit = ContactsCubit(xmppService: xmppService);
      final settingsCubit = _settingsCubit(
        endpointConfig: const EndpointConfig(
          smtpEnabled: false,
          xmppEnabled: true,
        ),
      );
      addTearDown(homeBloc.close);
      addTearDown(contactsCubit.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<HomeBloc>.value(value: homeBloc),
            BlocProvider<ContactsCubit>.value(value: contactsCubit),
            BlocProvider<SettingsCubit>.value(value: settingsCubit),
          ],
          child: const _ContactsTestApp(child: ContactsActionGroup()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('john@axi.im'), warnIfMissed: false);
      tester.testTextInput.enterText('new@example.com');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      verify(
        () => xmppService.addToRoster(
          jid: 'new@example.com',
          title: any(named: 'title'),
        ),
      ).called(1);
      verifyNever(
        () => xmppService.addManualContact(
          address: any(named: 'address'),
          displayName: any(named: 'displayName'),
        ),
      );
    },
  );

  testWidgets('contact detail sheet shows identity and structured fields', (
    tester,
  ) async {
    const contact = ContactDirectoryEntry(
      address: 'alice@example.com',
      hasXmppRoster: true,
      hasEmailContact: true,
      emailNativeIds: <String>['email-alice'],
      xmppTitle: 'Alice Chat',
      emailDisplayName: 'Alice Mail',
      displayNameOverride: 'Alice Local',
      folderCollectionId: 'Projects',
      favorited: true,
      subscription: Subscription.both,
    );
    final xmppService = MockXmppService();
    _stubContactsShellService(
      xmppService,
      contacts: const <ContactDirectoryEntry>[contact],
    );
    final homeBloc = HomeBloc(
      xmppService: xmppService,
      tabs: const <HomeTab>[HomeTab.contacts, HomeTab.chats],
    );
    final contactsCubit = ContactsCubit(xmppService: xmppService);
    final chatsCubit = ChatsCubit(xmppService: xmppService);
    final blocklistCubit = BlocklistCubit(xmppService: xmppService);
    final foldersCubit = FoldersCubit(xmppService: xmppService);
    addTearDown(homeBloc.close);
    addTearDown(contactsCubit.close);
    addTearDown(chatsCubit.close);
    addTearDown(blocklistCubit.close);
    addTearDown(foldersCubit.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<HomeBloc>.value(value: homeBloc),
          BlocProvider<ContactsCubit>.value(value: contactsCubit),
          BlocProvider<ChatsCubit>.value(value: chatsCubit),
          BlocProvider<BlocklistCubit>.value(value: blocklistCubit),
          BlocProvider<FoldersCubit>.value(value: foldersCubit),
          BlocProvider<SettingsCubit>.value(value: _settingsCubit()),
        ],
        child: const _ContactsTestApp(child: ContactsList()),
      ),
    );
    await tester.pump();

    expect(find.byIcon(LucideIcons.star), findsOneWidget);

    await tester.tap(find.text('Alice Local'));
    await tester.pumpAndSettle();

    final summary = find.byKey(
      const ValueKey('contact-summary-alice@example.com'),
    );
    final details = find.byKey(
      const ValueKey('contact-details-alice@example.com'),
    );
    final Rect headerRect = tester.getRect(find.byType(AxiSheetHeader));
    final Rect summaryRect = tester.getRect(summary);
    expect(find.text('Details'), findsOneWidget);
    expect(summaryRect.top - headerRect.bottom, greaterThanOrEqualTo(8));
    expect(
      find.descendant(of: summary, matching: find.text('Alice Local')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('alice@example.com')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: details, matching: find.text('Projects')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: details, matching: find.text('alice@example.com')),
      findsNothing,
    );
    expect(
      find.descendant(of: details, matching: find.text('Alice Chat')),
      findsNothing,
    );
    expect(
      find.descendant(of: details, matching: find.text('Alice Mail')),
      findsNothing,
    );

    when(
      () => xmppService.openChat('alice@example.com'),
    ).thenAnswer((_) async {});

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(details, findsNothing);
    verify(() => xmppService.openChat('alice@example.com')).called(1);
  });

  testWidgets('contact detail compose closes sheet before opening compose', (
    tester,
  ) async {
    const contact = ContactDirectoryEntry(
      address: 'mail@example.com',
      hasXmppRoster: false,
      hasEmailContact: true,
      emailNativeIds: <String>['email-mail'],
      emailDisplayName: 'Mail Contact',
    );
    final xmppService = MockXmppService();
    _stubContactsShellService(
      xmppService,
      contacts: const <ContactDirectoryEntry>[contact],
    );
    final homeBloc = HomeBloc(
      xmppService: xmppService,
      tabs: const <HomeTab>[HomeTab.contacts],
    );
    final contactsCubit = ContactsCubit(xmppService: xmppService);
    final chatsCubit = ChatsCubit(xmppService: xmppService);
    final blocklistCubit = BlocklistCubit(xmppService: xmppService);
    final foldersCubit = FoldersCubit(xmppService: xmppService);
    final composeWindowCubit = ComposeWindowCubit();
    addTearDown(homeBloc.close);
    addTearDown(contactsCubit.close);
    addTearDown(chatsCubit.close);
    addTearDown(blocklistCubit.close);
    addTearDown(foldersCubit.close);
    addTearDown(composeWindowCubit.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<HomeBloc>.value(value: homeBloc),
          BlocProvider<ContactsCubit>.value(value: contactsCubit),
          BlocProvider<ChatsCubit>.value(value: chatsCubit),
          BlocProvider<BlocklistCubit>.value(value: blocklistCubit),
          BlocProvider<FoldersCubit>.value(value: foldersCubit),
          BlocProvider<ComposeWindowCubit>.value(value: composeWindowCubit),
          BlocProvider<SettingsCubit>.value(value: _settingsCubit()),
        ],
        child: const _ContactsTestApp(
          platform: TargetPlatform.macOS,
          child: ContactsList(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Mail Contact'));
    await tester.pumpAndSettle();

    final details = find.byKey(
      const ValueKey('contact-details-mail@example.com'),
    );
    expect(details, findsNothing);
    expect(find.text('Details'), findsOneWidget);

    await tester.tap(find.text('Compose email'));
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsNothing);
    expect(composeWindowCubit.state.windows, hasLength(1));
    expect(composeWindowCubit.state.windows.single.seed.jids, const <String>[
      'mail@example.com',
    ]);
  });
}

MockSettingsCubit _settingsCubit({
  EndpointConfig endpointConfig = const EndpointConfig(smtpEnabled: true),
}) {
  final settingsCubit = MockSettingsCubit();
  when(
    () => settingsCubit.state,
  ).thenReturn(SettingsState(endpointConfig: endpointConfig));
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
  return settingsCubit;
}

void _stubContactsShellService(
  MockXmppService xmppService, {
  required List<ContactDirectoryEntry> contacts,
}) {
  when(
    () => xmppService.contactDirectoryStream(),
  ).thenAnswer((_) => Stream<List<ContactDirectoryEntry>>.value(contacts));
  when(
    () => xmppService.rosterStream(),
  ).thenAnswer((_) => const Stream<List<RosterItem>>.empty());
  when(
    () => xmppService.invitesStream(),
  ).thenAnswer((_) => const Stream<List<Invite>>.empty());
  when(() => xmppService.cachedChatList).thenReturn(const <Chat>[]);
  when(
    () => xmppService.chatsStream(),
  ).thenAnswer((_) => const Stream<List<Chat>>.empty());
  when(
    () => xmppService.recipientAddressSuggestionsStream(),
  ).thenAnswer((_) => const Stream<List<String>>.empty());
  when(
    () => xmppService.contactFolderRulesStream(),
  ).thenAnswer((_) => const Stream<Map<String, String>>.empty());
  when(
    () => xmppService.demoResetStream,
  ).thenAnswer((_) => const Stream<void>.empty());
  when(
    () => xmppService.blocklistStream(),
  ).thenAnswer((_) => const Stream<List<BlocklistData>>.empty());
  when(
    () => xmppService.addressBlocklistStream(),
  ).thenAnswer((_) => const Stream<List<EmailBlocklistEntry>>.empty());
  when(
    () => xmppService.messageCollectionItemsStream(
      any(),
      chatJid: any(named: 'chatJid'),
    ),
  ).thenAnswer((_) => const Stream<List<FolderMessageItem>>.empty());
  when(
    () => xmppService.messageCollectionsStream(
      includeInactive: any(named: 'includeInactive'),
      includeSystem: any(named: 'includeSystem'),
    ),
  ).thenAnswer((_) => const Stream<List<MessageCollectionEntry>>.empty());
  when(
    () => xmppService.allMessageCollectionMembershipsStream(
      includeInactive: any(named: 'includeInactive'),
      chatJid: any(named: 'chatJid'),
    ),
  ).thenAnswer(
    (_) => const Stream<List<MessageCollectionMembershipEntry>>.empty(),
  );
}

class _ContactsTestApp extends StatelessWidget {
  const _ContactsTestApp({required this.child, this.platform});

  final Widget child;
  final TargetPlatform? platform;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        platform: platform,
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
      home: ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadSlateColorScheme.light(),
          brightness: Brightness.light,
        ),
        child: Scaffold(body: child),
      ),
    );
  }
}
