// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  testWidgets(
    'fallback avatar colors use the full address, not just the local part',
    (tester) async {
      await tester.pumpWidget(
        const _AxiAvatarTestApp(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                key: Key('address-avatar-1'),
                child: AxiAvatar(
                  avatar: AvatarPresentation.avatar(
                    label: 'sample@example.com',
                    colorSeed: 'sample@example.com',
                    loading: false,
                  ),
                ),
              ),
              SizedBox(
                key: Key('address-avatar-2'),
                child: AxiAvatar(
                  avatar: AvatarPresentation.avatar(
                    label: 'sample@example.net',
                    colorSeed: 'sample@example.net',
                    loading: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      final firstColor = _avatarBackgroundColor(
        tester,
        const Key('address-avatar-1'),
      );
      final secondColor = _avatarBackgroundColor(
        tester,
        const Key('address-avatar-2'),
      );

      expect(firstColor, isNot(equals(secondColor)));
    },
  );

  testWidgets('chat avatars keep the label but seed color from address', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _AxiAvatarTestApp(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              key: Key('email-avatar-1'),
              child: AxiAvatar(
                avatar: AvatarPresentation.avatar(
                  label: 'Sample',
                  colorSeed: 'sample@example.com',
                  loading: false,
                ),
              ),
            ),
            SizedBox(
              key: Key('email-avatar-2'),
              child: AxiAvatar(
                avatar: AvatarPresentation.avatar(
                  label: 'Sample',
                  colorSeed: 'sample@example.net',
                  loading: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final firstColor = _avatarBackgroundColor(
      tester,
      const Key('email-avatar-1'),
    );
    final secondColor = _avatarBackgroundColor(
      tester,
      const Key('email-avatar-2'),
    );

    expect(firstColor, isNot(equals(secondColor)));
    expect(find.text('S'), findsNWidgets(2));
  });

  testWidgets(
    'hydrated avatars keep the placeholder while avatar bytes load from a path',
    (tester) async {
      final xmppService = _MockXmppService();
      final avatarLoad = Completer<Uint8List?>();
      when(() => xmppService.cachedSafeAvatarBytes(any())).thenReturn(null);
      when(
        () => xmppService.resolveSafeAvatarBytes(
          avatarPath: any(named: 'avatarPath'),
          avatarBytes: any(named: 'avatarBytes'),
        ),
      ).thenAnswer((_) => avatarLoad.future);

      await tester.pumpWidget(
        _AxiAvatarTestApp(
          xmppService: xmppService,
          child: const HydratedAxiAvatar(
            avatar: AvatarPresentation.avatar(
              label: 'sample@example.com',
              colorSeed: 'sample@example.com',
              avatar: Avatar(path: '/avatars/self.enc'),
              loading: false,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(AxiProgressIndicator), findsNothing);

      avatarLoad.complete(Uint8List.fromList(<int>[1, 2, 3, 4]));
    },
  );

  testWidgets(
    'hydrated avatars show the image without a spinner after avatar bytes load',
    (tester) async {
      final xmppService = _MockXmppService();
      final avatarLoad = Completer<Uint8List?>();
      when(() => xmppService.cachedSafeAvatarBytes(any())).thenReturn(null);
      when(
        () => xmppService.resolveSafeAvatarBytes(
          avatarPath: any(named: 'avatarPath'),
          avatarBytes: any(named: 'avatarBytes'),
        ),
      ).thenAnswer((_) => avatarLoad.future);

      await tester.pumpWidget(
        _AxiAvatarTestApp(
          xmppService: xmppService,
          child: const HydratedAxiAvatar(
            avatar: AvatarPresentation.avatar(
              label: 'sample@example.com',
              colorSeed: 'sample@example.com',
              avatar: Avatar(path: '/avatars/self.enc'),
              loading: false,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AxiProgressIndicator), findsNothing);

      avatarLoad.complete(Uint8List.fromList(_transparentPngBytes));
      await tester.pumpAndSettle();

      expect(find.byType(AxiProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'hydrated avatars do not show a spinner when avatar bytes fail to load',
    (tester) async {
      final xmppService = _MockXmppService();
      final avatarLoad = Completer<Uint8List?>();
      when(() => xmppService.cachedSafeAvatarBytes(any())).thenReturn(null);
      when(
        () => xmppService.resolveSafeAvatarBytes(
          avatarPath: any(named: 'avatarPath'),
          avatarBytes: any(named: 'avatarBytes'),
        ),
      ).thenAnswer((_) => avatarLoad.future);

      await tester.pumpWidget(
        _AxiAvatarTestApp(
          xmppService: xmppService,
          child: const HydratedAxiAvatar(
            avatar: AvatarPresentation.avatar(
              label: 'sample@example.com',
              colorSeed: 'sample@example.com',
              avatar: Avatar(path: '/avatars/self.enc'),
              loading: false,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AxiProgressIndicator), findsNothing);

      avatarLoad.completeError(Exception('avatar load failed'));
      await tester.pumpAndSettle();

      expect(find.byType(AxiProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'hydrated avatars keep the current image visible while a new path resolves',
    (tester) async {
      final xmppService = _MockXmppService();
      final avatarLoad = Completer<Uint8List?>();
      when(() => xmppService.cachedSafeAvatarBytes(any())).thenReturn(null);
      when(
        () => xmppService.resolveSafeAvatarBytes(
          avatarPath: any(named: 'avatarPath'),
          avatarBytes: any(named: 'avatarBytes'),
        ),
      ).thenAnswer((invocation) {
        final path = invocation.namedArguments[#avatarPath] as String?;
        if (path == '/avatars/new.enc') {
          return avatarLoad.future;
        }
        return Future<Uint8List?>.value(null);
      });

      await tester.pumpWidget(
        _AxiAvatarTestApp(
          xmppService: xmppService,
          child: HydratedAxiAvatar(
            avatar: AvatarPresentation.avatar(
              label: 'sample@example.com',
              colorSeed: 'sample@example.com',
              avatar: Avatar(path: '/avatars/old.enc', hash: 'old-hash'),
              loading: false,
            ),
            avatarBytes: Uint8List.fromList(_transparentPngBytes),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);

      await tester.pumpWidget(
        _AxiAvatarTestApp(
          xmppService: xmppService,
          child: const HydratedAxiAvatar(
            avatar: AvatarPresentation.avatar(
              label: 'sample@example.com',
              colorSeed: 'sample@example.com',
              avatar: Avatar(path: '/avatars/new.enc', hash: 'new-hash'),
              loading: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(AxiProgressIndicator), findsNothing);

      avatarLoad.complete(Uint8List.fromList(_transparentPngBytes));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
    },
  );

  testWidgets(
    'hydrated avatar retries the path resolution when external loading settles',
    (tester) async {
      final xmppService = _MockXmppService();
      var cacheReady = false;
      when(() => xmppService.cachedSafeAvatarBytes(any())).thenAnswer(
        (_) => cacheReady ? Uint8List.fromList(_transparentPngBytes) : null,
      );
      when(
        () => xmppService.resolveSafeAvatarBytes(
          avatarPath: any(named: 'avatarPath'),
          avatarBytes: any(named: 'avatarBytes'),
        ),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        _AxiAvatarTestApp(
          xmppService: xmppService,
          child: const HydratedAxiAvatar(
            avatar: AvatarPresentation.avatar(
              label: 'sample@example.com',
              colorSeed: 'sample@example.com',
              avatar: Avatar(path: '/avatars/self.enc'),
              loading: true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AxiProgressIndicator), findsOneWidget);

      cacheReady = true;
      await tester.pumpWidget(
        _AxiAvatarTestApp(
          xmppService: xmppService,
          child: const HydratedAxiAvatar(
            avatar: AvatarPresentation.avatar(
              label: 'sample@example.com',
              colorSeed: 'sample@example.com',
              avatar: Avatar(path: '/avatars/self.enc'),
              loading: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AxiProgressIndicator), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    },
  );
}

Color _avatarBackgroundColor(WidgetTester tester, Key avatarKey) {
  final coloredBoxFinder = find.descendant(
    of: find.byKey(avatarKey),
    matching: find.byType(ColoredBox),
  );
  final coloredBox = tester.widget<ColoredBox>(coloredBoxFinder.first);
  return coloredBox.color;
}

class _AxiAvatarTestApp extends StatelessWidget {
  const _AxiAvatarTestApp({required this.child, this.xmppService});

  final Widget child;
  final XmppService? xmppService;

  @override
  Widget build(BuildContext context) {
    final settingsCubit = _MockSettingsCubit();
    when(() => settingsCubit.state).thenReturn(const SettingsState());
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
    Widget child = BlocProvider<SettingsCubit>.value(
      value: settingsCubit,
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
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: Scaffold(body: Center(child: this.child)),
        ),
      ),
    );
    if (xmppService != null) {
      child = RepositoryProvider<XmppService>.value(
        value: xmppService!,
        child: child,
      );
    }
    return child;
  }
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockXmppService extends Mock implements XmppService {}

const List<int> _transparentPngBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
