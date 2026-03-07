// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/chats/view/widgets/transport_aware_avatar.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
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
                child: AxiAvatar(jid: 'eliot@axichat.com'),
              ),
              SizedBox(
                key: Key('address-avatar-2'),
                child: AxiAvatar(jid: 'eliot@tuta.com'),
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

  testWidgets(
    'transport aware email avatars keep the label but seed color from address',
    (tester) async {
      final selfIdentity = const SelfIdentitySnapshot(
        selfJid: null,
        avatarPath: null,
      );
      await tester.pumpWidget(
        _AxiAvatarTestApp(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                key: const Key('email-avatar-1'),
                child: TransportAwareAvatar(
                  chat: _emailChat(
                    address: 'eliot@axichat.com',
                    displayName: 'Eliot',
                  ),
                  selfIdentity: selfIdentity,
                  showBadge: false,
                ),
              ),
              SizedBox(
                key: const Key('email-avatar-2'),
                child: TransportAwareAvatar(
                  chat: _emailChat(
                    address: 'eliot@tuta.com',
                    displayName: 'Eliot',
                  ),
                  selfIdentity: selfIdentity,
                  showBadge: false,
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
      expect(find.text('E'), findsNWidgets(2));
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

Chat _emailChat({required String address, required String displayName}) {
  return Chat(
    jid: address,
    title: displayName,
    type: ChatType.chat,
    lastChangeTimestamp: DateTime(2026),
    transport: MessageTransport.email,
    contactDisplayName: displayName,
    emailAddress: address,
  );
}

class _AxiAvatarTestApp extends StatelessWidget {
  const _AxiAvatarTestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settingsCubit = _MockSettingsCubit();
    when(() => settingsCubit.state).thenReturn(const SettingsState());
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
    return BlocProvider<SettingsCubit>.value(
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
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );
  }
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
