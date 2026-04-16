import 'dart:async';

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
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../mocks.dart';

class _InMemoryHydratedStorage implements Storage {
  final Map<String, dynamic> _values = <String, dynamic>{};

  @override
  dynamic read(String key) => _values[key];

  @override
  Future<void> write(String key, dynamic value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clear() async {
    _values.clear();
  }

  @override
  Future<void> close() async {}
}

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

Future<void> _pumpHomeBadgeSurface(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

DateTime _timestamp(int day, {int hour = 0}) =>
    DateTime.utc(2026, 1, day, hour);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockXmppService xmppService;
  late SettingsCubit settingsCubit;
  late ChatsCubit chatsCubit;
  late FoldersCubit foldersCubit;
  late HomeBloc homeBloc;
  late ProfileCubit profileCubit;
  late CalendarTaskOffGridDragController dragController;
  late StreamController<Map<HomeBadgeBucket, DateTime>>
  homeBadgeSeenMarkersController;
  late Map<HomeBadgeBucket, DateTime> homeBadgeSeenMarkers;

  setUpAll(() {
    registerFallbackValue(FakeMessageEvent());
    registerFallbackValue(HomeBadgeBucket.drafts);
    registerFallbackValue(DateTime.utc(2026, 1, 1));
  });

  setUp(() {
    final storage = _InMemoryHydratedStorage();
    HydratedBloc.storage = storage;

    xmppService = MockXmppService();
    homeBadgeSeenMarkersController =
        StreamController<Map<HomeBadgeBucket, DateTime>>.broadcast();
    homeBadgeSeenMarkers = <HomeBadgeBucket, DateTime>{};
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
    when(
      () => xmppService.settingsSyncUpdateStream,
    ).thenAnswer((_) => const Stream<Map<String, dynamic>>.empty());
    when(
      () => xmppService.seedSettingsSyncSnapshot(any()),
    ).thenAnswer((_) async {});
    when(
      () => xmppService.updateSettingsSyncSnapshot(any()),
    ).thenAnswer((_) async {});
    when(
      () => xmppService.updateAttachmentAutoDownloadSettings(
        imagesEnabled: any(named: 'imagesEnabled'),
        videosEnabled: any(named: 'videosEnabled'),
        documentsEnabled: any(named: 'documentsEnabled'),
        archivesEnabled: any(named: 'archivesEnabled'),
      ),
    ).thenReturn(null);
    when(
      () => xmppService.homeBadgeSeenMarkersStream,
    ).thenAnswer((_) => homeBadgeSeenMarkersController.stream);
    when(
      () => xmppService.markHomeBadgeBucketSeen(
        bucket: any(named: 'bucket'),
        seenAt: any(named: 'seenAt'),
      ),
    ).thenAnswer((invocation) async {
      final bucket = invocation.namedArguments[#bucket] as HomeBadgeBucket;
      final seenAt = (invocation.namedArguments[#seenAt] as DateTime).toUtc();
      final current = homeBadgeSeenMarkers[bucket];
      if (current != null && !seenAt.isAfter(current)) {
        return;
      }
      homeBadgeSeenMarkers = <HomeBadgeBucket, DateTime>{
        ...homeBadgeSeenMarkers,
        bucket: seenAt,
      };
      homeBadgeSeenMarkersController.add(
        Map<HomeBadgeBucket, DateTime>.unmodifiable(homeBadgeSeenMarkers),
      );
    });

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
    await homeBadgeSeenMarkersController.close();
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
    'missing markers keep existing non-chat items badged after marker load',
    (tester) async {
      final controller = HomeBadgeSurfaceHarnessController(
        draftItems: <int, DateTime>{1: _timestamp(1)},
        importantItems: <String, DateTime>{
          'chat-a@example.com\nm1': _timestamp(1),
        },
        spamItems: <String, DateTime>{'spam@example.com': _timestamp(1)},
        badgeSeenMarkersLoaded: false,
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
      await _pumpHomeBadgeSurface(tester);

      expect(_badgeCount(tester, 'home-tab-badge-drafts'), isNull);
      expect(_badgeCount(tester, 'home-tab-badge-folders'), isNull);
      expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), isNull);

      controller.update(badgeSeenMarkersLoaded: true);
      await _pumpHomeBadgeSurface(tester);

      expect(_badgeCount(tester, 'home-tab-badge-drafts'), 1);
      expect(_badgeCount(tester, 'home-tab-badge-folders'), 2);
      expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 3);
    },
  );

  testWidgets(
    'folder, tab, and bottom bar badges update for add, remove, and view',
    (tester) async {
      final controller = HomeBadgeSurfaceHarnessController(
        chatsUnreadCount: 7,
        contactIds: {'alice@example.com', 'bob@example.com'},
        draftItems: <int, DateTime>{
          1: _timestamp(1),
          2: _timestamp(2),
          3: _timestamp(3),
        },
        importantItems: <String, DateTime>{
          'chat-a@example.com\nm1': _timestamp(1),
          'chat-b@example.com\nm2': _timestamp(2),
        },
        spamItems: <String, DateTime>{'spam@example.com': _timestamp(1)},
        badgeSeenMarkers: <HomeBadgeBucket, DateTime>{
          HomeBadgeBucket.drafts: _timestamp(0),
          HomeBadgeBucket.important: _timestamp(0),
          HomeBadgeBucket.spam: _timestamp(0),
        },
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
      await _pumpHomeBadgeSurface(tester);

      expect(_badgeCount(tester, 'home-folders-badge-important'), 2);
      expect(_badgeCount(tester, 'home-folders-badge-spam'), 1);
      expect(_badgeCount(tester, 'home-tab-badge-contacts'), 2);
      expect(_badgeCount(tester, 'home-tab-badge-drafts'), 3);
      expect(_badgeCount(tester, 'home-tab-badge-folders'), 3);
      expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 15);

      controller.update(contactIds: {'alice@example.com'});
      await _pumpHomeBadgeSurface(tester);

      expect(_badgeCount(tester, 'home-tab-badge-contacts'), 1);
      expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 14);

      controller.update(activeTab: HomeTab.contacts);
      await _pumpHomeBadgeSurface(tester);

      expect(_badgeCount(tester, 'home-tab-badge-contacts'), isNull);
      expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 13);

      controller.update(
        activeTab: HomeTab.contacts,
        contactIds: {'alice@example.com', 'carol@example.com'},
      );
      await _pumpHomeBadgeSurface(tester);

      expect(_badgeCount(tester, 'home-tab-badge-contacts'), isNull);
      expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 13);

      controller.update(
        activeTab: HomeTab.folders,
        foldersSection: FolderHomeSection.important,
        updateFoldersSection: true,
      );
      await _pumpHomeBadgeSurface(tester);

      expect(_badgeCount(tester, 'home-folders-badge-important'), isNull);
      expect(_badgeCount(tester, 'home-folders-badge-spam'), 1);
      expect(_badgeCount(tester, 'home-tab-badge-folders'), 1);
      expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 11);

      controller.update(
        activeTab: HomeTab.folders,
        foldersSection: FolderHomeSection.important,
        updateFoldersSection: true,
        importantItems: <String, DateTime>{
          'chat-a@example.com\nm1': _timestamp(1),
          'chat-b@example.com\nm2': _timestamp(2),
          'chat-c@example.com\nm3': _timestamp(3),
        },
      );
      await _pumpHomeBadgeSurface(tester);

      expect(_badgeCount(tester, 'home-folders-badge-important'), isNull);
      expect(_badgeCount(tester, 'home-tab-badge-folders'), 1);
      expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 11);

      controller.update(
        activeTab: HomeTab.folders,
        foldersSection: null,
        updateFoldersSection: true,
        spamItems: const <String, DateTime>{},
      );
      await _pumpHomeBadgeSurface(tester);

      expect(_badgeCount(tester, 'home-folders-badge-spam'), isNull);
      expect(_badgeCount(tester, 'home-tab-badge-folders'), isNull);
      expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 10);
    },
  );

  testWidgets('draft, important, and spam markers persist across restart', (
    tester,
  ) async {
    final controller = HomeBadgeSurfaceHarnessController(
      draftItems: <int, DateTime>{1: _timestamp(1)},
      importantItems: <String, DateTime>{
        'chat-a@example.com\nm1': _timestamp(1),
      },
      spamItems: <String, DateTime>{'spam@example.com': _timestamp(1)},
      activeTab: HomeTab.drafts,
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
    await _pumpHomeBadgeSurface(tester);

    controller.update(
      activeTab: HomeTab.drafts,
      draftItems: <int, DateTime>{1: _timestamp(1), 2: _timestamp(2)},
    );
    await _pumpHomeBadgeSurface(tester);
    expect(_badgeCount(tester, 'home-tab-badge-drafts'), isNull);

    controller.update(
      activeTab: HomeTab.folders,
      foldersSection: FolderHomeSection.important,
      updateFoldersSection: true,
      importantItems: <String, DateTime>{
        'chat-a@example.com\nm1': _timestamp(1),
        'chat-b@example.com\nm2': _timestamp(2),
      },
    );
    await _pumpHomeBadgeSurface(tester);
    expect(_badgeCount(tester, 'home-folders-badge-important'), isNull);

    controller.update(
      activeTab: HomeTab.folders,
      foldersSection: FolderHomeSection.spam,
      updateFoldersSection: true,
      spamItems: <String, DateTime>{
        'spam@example.com': _timestamp(1),
        'spam-2@example.com': _timestamp(2),
      },
    );
    await _pumpHomeBadgeSurface(tester);
    expect(_badgeCount(tester, 'home-folders-badge-spam'), isNull);

    controller.update(
      activeTab: HomeTab.chats,
      foldersSection: null,
      updateFoldersSection: true,
    );
    await _pumpHomeBadgeSurface(tester);

    expect(_badgeCount(tester, 'home-tab-badge-drafts'), isNull);
    expect(_badgeCount(tester, 'home-tab-badge-folders'), isNull);
    expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

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
    await _pumpHomeBadgeSurface(tester);

    expect(_badgeCount(tester, 'home-tab-badge-drafts'), isNull);
    expect(_badgeCount(tester, 'home-tab-badge-folders'), isNull);
    expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), isNull);
  });

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
    await _pumpHomeBadgeSurface(tester);

    expect(_badgeCount(tester, 'home-tab-badge-contacts'), 1);
    expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 1);

    controller.update(contactIds: {'alice@example.com', 'bob@example.com'});
    await _pumpHomeBadgeSurface(tester);

    expect(_badgeCount(tester, 'home-tab-badge-contacts'), 2);
    expect(_badgeCount(tester, 'home-bottom-nav-badge-home'), 2);
  });
}
