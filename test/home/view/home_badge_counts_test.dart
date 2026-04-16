import 'package:axichat/src/calendar/view/shell/calendar_task_off_grid_drag_controller.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/axi_badge.dart';
import 'package:axichat/src/common/ui/ui.dart'
    show axiBorders, axiMotion, axiRadii, axiSizing, axiSpacing;
import 'package:axichat/src/folders/bloc/folders_cubit.dart';
import 'package:axichat/src/home/bloc/home_bloc.dart';
import 'package:axichat/src/home/view/home_screen.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../mocks.dart';

class _InMemoryHydratedStorage extends Mock implements Storage {}

class _HomeBadgeHarnessApp extends StatelessWidget {
  const _HomeBadgeHarnessApp({
    required this.controller,
    required this.chatsCubit,
    required this.foldersCubit,
    required this.homeBloc,
    required this.profileCubit,
    required this.settingsCubit,
    required this.dragController,
  });

  final HomeBadgeSurfaceHarnessController controller;
  final ChatsCubit chatsCubit;
  final FoldersCubit foldersCubit;
  final HomeBloc homeBloc;
  final ProfileCubit profileCubit;
  final SettingsCubit settingsCubit;
  final CalendarTaskOffGridDragController dragController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CalendarTaskOffGridDragController>.value(
          value: dragController,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
          BlocProvider<ChatsCubit>.value(value: chatsCubit),
          BlocProvider<FoldersCubit>.value(value: foldersCubit),
          BlocProvider<HomeBloc>.value(value: homeBloc),
          BlocProvider<ProfileCubit>.value(value: profileCubit),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            extensions: <ThemeExtension<dynamic>>[
              axiBorders,
              axiRadii,
              axiSpacing,
              axiSizing,
              axiMotion,
            ],
          ),
          home: EnvScope(
            child: ShadTheme(
              data: ShadThemeData(
                colorScheme: const ShadSlateColorScheme.light(),
                brightness: Brightness.light,
              ),
              child: Scaffold(
                body: HomeBadgeSurfaceHarness(controller: controller),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

int? _badgeCount(WidgetTester tester, String key) {
  final finder = find.byKey(ValueKey<String>(key));
  if (finder.evaluate().isEmpty) {
    return null;
  }
  return tester.widgetList<AxiCountBadge>(finder).first.count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockXmppService xmppService;
  late SettingsCubit settingsCubit;
  late ChatsCubit chatsCubit;
  late FoldersCubit foldersCubit;
  late HomeBloc homeBloc;
  late ProfileCubit profileCubit;
  late CalendarTaskOffGridDragController dragController;

  setUpAll(() {
    registerFallbackValue(FakeMessageEvent());
  });

  setUp(() {
    final storage = _InMemoryHydratedStorage();
    when(() => storage.read(any())).thenReturn(null);
    when(() => storage.write(any(), any<dynamic>())).thenAnswer((_) async {});
    when(() => storage.delete(any())).thenAnswer((_) async {});
    when(() => storage.clear()).thenAnswer((_) async {});
    HydratedBloc.storage = storage;

    xmppService = MockXmppService();
    when(() => xmppService.cachedChatList).thenReturn(const <Chat>[]);
    when(
      () => xmppService.chatsStream(),
    ).thenAnswer((_) => const Stream<List<Chat>>.empty());
    when(
      () => xmppService.recipientAddressSuggestionsStream(),
    ).thenAnswer((_) => const Stream<List<String>>.empty());
    when(
      () => xmppService.demoResetStream,
    ).thenAnswer((_) => const Stream<void>.empty());
    when(
      () => xmppService.messageCollectionItemsStream(
        any(),
        chatJid: any(named: 'chatJid'),
      ),
    ).thenAnswer((_) => const Stream<List<FolderMessageItem>>.empty());
    when(() => xmppService.myJid).thenReturn('owner@example.com');
    when(() => xmppService.resource).thenReturn('resource');
    when(() => xmppService.username).thenReturn('owner');
    when(() => xmppService.selfAvatarHydrating).thenReturn(false);
    when(() => xmppService.cachedSelfAvatar).thenReturn(null);
    when(
      () => xmppService.selfAvatarStream,
    ).thenAnswer((_) => const Stream<Avatar?>.empty());
    when(
      () => xmppService.selfAvatarHydratingStream,
    ).thenAnswer((_) => const Stream<bool>.empty());
    when(
      () => xmppService.storedConversationMessageCountStream(),
    ).thenAnswer((_) => const Stream<int>.empty());
    when(() => xmppService.getOwnAvatar()).thenAnswer((_) async => null);

    settingsCubit = SettingsCubit();
    chatsCubit = ChatsCubit(xmppService: xmppService);
    foldersCubit = FoldersCubit(xmppService: xmppService);
    homeBloc = HomeBloc(
      xmppService: xmppService,
      tabs: const <HomeTab>[
        HomeTab.chats,
        HomeTab.contacts,
        HomeTab.drafts,
        HomeTab.folders,
      ],
    );
    profileCubit = ProfileCubit(xmppService: xmppService);
    dragController = CalendarTaskOffGridDragController();
  });

  tearDown(() async {
    await profileCubit.close();
    await homeBloc.close();
    await foldersCubit.close();
    await chatsCubit.close();
    await settingsCubit.close();
    dragController.dispose();
  });

  test(
    'home aggregate sums unread chats, contacts, drafts, and folder counts',
    () {
      final counts = resolveHomeBadgeCountsForTesting(
        chatsUnreadCount: 7,
        contactsCount: 2,
        draftCount: 3,
        importantCount: 2,
        spamCount: 1,
      );

      expect(counts.contacts, 2);
      expect(counts.important, 2);
      expect(counts.spam, 1);
      expect(counts.folders, 3);
      expect(counts.home, 15);
      expect(counts.tabs[HomeTab.chats], 7);
      expect(counts.tabs[HomeTab.contacts], 2);
      expect(counts.tabs[HomeTab.drafts], 3);
      expect(counts.tabs[HomeTab.folders], 3);
    },
  );

  test('incremental badge state removes missing unseen ids', () {
    final seeded = seedIncrementalBadgeStateForTesting<String>(
      currentIds: {'a', 'b'},
      visible: false,
    );
    final advanced = advanceIncrementalBadgeStateForTesting<String>(
      previousIds: seeded.trackedIds,
      pendingIds: seeded.pendingIds,
      currentIds: {'b', 'c'},
      visible: false,
    );

    expect(seeded.count, 2);
    expect(advanced.count, 2);
    expect(advanced.pendingIds, {'b', 'c'});
    expect(advanced.trackedIds, {'b', 'c'});
  });

  testWidgets(
    'folder, tab, and bottom bar badges update for add, remove, and view',
    (tester) async {
      final controller = HomeBadgeSurfaceHarnessController(
        chatsUnreadCount: 7,
        contactIds: {'alice@example.com', 'bob@example.com'},
        draftIds: {1, 2, 3},
        importantIds: {'chat-a@example.com\nm1', 'chat-b@example.com\nm2'},
        spamIds: {'spam@example.com'},
        activeTab: HomeTab.chats,
      );

      await tester.pumpWidget(
        _HomeBadgeHarnessApp(
          controller: controller,
          chatsCubit: chatsCubit,
          foldersCubit: foldersCubit,
          homeBloc: homeBloc,
          profileCubit: profileCubit,
          settingsCubit: settingsCubit,
          dragController: dragController,
        ),
      );
      await tester.pumpAndSettle();

      expect(_badgeCount(tester, 'home-folders-badge-important'), 2);
      expect(_badgeCount(tester, 'home-folders-badge-spam'), 1);
      expect(_badgeCount(tester, 'home-tab-badge-contacts'), 2);
      expect(_badgeCount(tester, 'home-tab-badge-drafts'), 3);
      expect(_badgeCount(tester, 'home-tab-badge-folders'), 3);
      expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 15);

      controller.update(contactIds: {'alice@example.com'});
      await tester.pumpAndSettle();

      expect(_badgeCount(tester, 'home-tab-badge-contacts'), 1);
      expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 14);

      controller.update(activeTab: HomeTab.contacts);
      await tester.pumpAndSettle();

      expect(_badgeCount(tester, 'home-tab-badge-contacts'), isNull);
      expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 13);

      controller.update(
        activeTab: HomeTab.contacts,
        contactIds: {'alice@example.com', 'carol@example.com'},
      );
      await tester.pumpAndSettle();

      expect(_badgeCount(tester, 'home-tab-badge-contacts'), isNull);
      expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 13);

      controller.update(
        activeTab: HomeTab.folders,
        foldersSection: FolderHomeSection.important,
        updateFoldersSection: true,
      );
      await tester.pumpAndSettle();

      expect(_badgeCount(tester, 'home-folders-badge-important'), isNull);
      expect(_badgeCount(tester, 'home-folders-badge-spam'), 1);
      expect(_badgeCount(tester, 'home-tab-badge-folders'), 1);
      expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 11);

      controller.update(
        activeTab: HomeTab.folders,
        foldersSection: FolderHomeSection.important,
        updateFoldersSection: true,
        importantIds: {
          'chat-a@example.com\nm1',
          'chat-b@example.com\nm2',
          'chat-c@example.com\nm3',
        },
      );
      await tester.pumpAndSettle();

      expect(_badgeCount(tester, 'home-folders-badge-important'), isNull);
      expect(_badgeCount(tester, 'home-tab-badge-folders'), 1);
      expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 11);

      controller.update(
        activeTab: HomeTab.folders,
        foldersSection: null,
        updateFoldersSection: true,
        spamIds: const <String>{},
      );
      await tester.pumpAndSettle();

      expect(_badgeCount(tester, 'home-folders-badge-spam'), isNull);
      expect(_badgeCount(tester, 'home-tab-badge-folders'), isNull);
      expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 10);
    },
  );

  testWidgets('profile selection does not suppress new non-chat badge counts', (
    tester,
  ) async {
    final controller = HomeBadgeSurfaceHarnessController(
      contactIds: {'alice@example.com'},
      activeTab: HomeTab.contacts,
      selectedBottomIndex: 3,
    );

    await tester.pumpWidget(
      _HomeBadgeHarnessApp(
        controller: controller,
        chatsCubit: chatsCubit,
        foldersCubit: foldersCubit,
        homeBloc: homeBloc,
        profileCubit: profileCubit,
        settingsCubit: settingsCubit,
        dragController: dragController,
      ),
    );
    await tester.pumpAndSettle();

    expect(_badgeCount(tester, 'home-tab-badge-contacts'), 1);
    expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 1);

    controller.update(contactIds: {'alice@example.com', 'bob@example.com'});
    await tester.pumpAndSettle();

    expect(_badgeCount(tester, 'home-tab-badge-contacts'), 2);
    expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 2);
  });
}
