// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/chat/view/overlays/room_members_sheet.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/muc/occupant.dart';
import 'package:axichat/src/xmpp/muc/room_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('self member tile uses the standard selected surface styling', (
    tester,
  ) async {
    const roomJid = 'room@conference.axi.im';
    const selfOccupantId = '$roomJid/self';

    await tester.pumpWidget(
      _RoomMembersSheetTestApp(
        child: RoomMembersSheet(
          roomState: RoomState(
            roomJid: roomJid,
            myOccupantJid: selfOccupantId,
            occupants: <String, Occupant>{
              selfOccupantId: Occupant(
                occupantId: selfOccupantId,
                nick: 'self',
                realJid: 'self@axi.im',
                affiliation: OccupantAffiliation.member,
                role: OccupantRole.participant,
              ),
            },
          ),
          memberSections: <RoomMemberSection>[
            RoomMemberSection(
              kind: RoomMemberSectionKind.members,
              members: <RoomMemberEntry>[
                RoomMemberEntry(
                  occupant: Occupant(
                    occupantId: selfOccupantId,
                    nick: 'self',
                    realJid: 'self@axi.im',
                    affiliation: OccupantAffiliation.member,
                    role: OccupantRole.participant,
                  ),
                  actions: const <MucModerationAction>[],
                ),
              ],
            ),
          ],
          canInvite: false,
          avatarUpdateInFlight: false,
          onInvite: (_) {},
          onAction: (_, _, _) async {},
          onOpenDirectChat: (_) async {},
        ),
      ),
    );

    final tileFinder = find.byWidgetPredicate(
      (widget) => widget is AxiListTile && widget.title == 'self',
    );
    final bubbleFinder = find.ancestor(
      of: tileFinder,
      matching: find.byType(CutoutSurface),
    );
    final bubble = tester.widget<CutoutSurface>(bubbleFinder.first);
    final shape = bubble.shape as SquircleBorder;
    final context = tester.element(tileFinder);
    final colors = ShadTheme.of(context).colorScheme;
    final expectedBackground = Color.alphaBlend(
      colors.primary.withValues(alpha: 0.06),
      colors.card,
    );

    expect(bubble.backgroundColor, expectedBackground);
    expect(bubble.borderColor, colors.border);
    expect(shape.side.color, colors.border);
  });

  testWidgets(
    'member action panel expands inside the tile bubble and respects async loading',
    (tester) async {
      final actionCompleter = Completer<void>();
      var moderationCalls = 0;
      var directChatCalls = 0;
      const roomJid = 'room@conference.axi.im';
      const selfOccupantId = '$roomJid/self';
      const memberOccupantId = '$roomJid/alice';

      await tester.pumpWidget(
        _RoomMembersSheetTestApp(
          child: RoomMembersSheet(
            roomState: RoomState(
              roomJid: roomJid,
              myOccupantJid: selfOccupantId,
              occupants: <String, Occupant>{
                selfOccupantId: Occupant(
                  occupantId: selfOccupantId,
                  nick: 'self',
                  realJid: 'self@axi.im',
                  affiliation: OccupantAffiliation.member,
                  role: OccupantRole.participant,
                ),
                memberOccupantId: Occupant(
                  occupantId: memberOccupantId,
                  nick: 'alice',
                  realJid: 'alice@axi.im',
                  affiliation: OccupantAffiliation.member,
                  role: OccupantRole.participant,
                ),
              },
            ),
            memberSections: <RoomMemberSection>[
              RoomMemberSection(
                kind: RoomMemberSectionKind.members,
                members: <RoomMemberEntry>[
                  RoomMemberEntry(
                    occupant: Occupant(
                      occupantId: memberOccupantId,
                      nick: 'alice',
                      realJid: 'alice@axi.im',
                      affiliation: OccupantAffiliation.member,
                      role: OccupantRole.participant,
                    ),
                    actions: <MucModerationAction>[MucModerationAction.kick],
                    directChatJid: 'alice@axi.im',
                  ),
                ],
              ),
            ],
            canInvite: false,
            avatarUpdateInFlight: false,
            onInvite: (_) {},
            onAction: (occupantId, action, actionLabel) {
              expect(occupantId, memberOccupantId);
              expect(action, MucModerationAction.kick);
              expect(actionLabel, 'Kick');
              moderationCalls += 1;
              return actionCompleter.future;
            },
            onOpenDirectChat: (_) async {
              directChatCalls += 1;
            },
          ),
        ),
      );

      final tileFinder = find.byWidgetPredicate(
        (widget) => widget is AxiListTile && widget.title == 'alice',
      );
      final bubbleFinder = find.ancestor(
        of: tileFinder,
        matching: find.byType(CutoutSurface),
      );
      final collapsedHeight = tester.getSize(bubbleFinder.first).height;

      await tester.tap(find.text('alice'));
      await tester.pumpAndSettle();

      expect(find.text('Open DM'), findsOneWidget);
      expect(find.text('Kick'), findsOneWidget);

      final expandedHeight = tester.getSize(bubbleFinder.first).height;
      expect(expandedHeight, greaterThan(collapsedHeight));

      await tester.tap(find.text('Kick'));
      await tester.pump();

      expect(moderationCalls, 1);
      expect(find.byType(AxiProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Open DM'));
      await tester.pump();
      expect(directChatCalls, 0);

      actionCompleter.complete();
      await tester.pumpAndSettle();

      expect(find.byType(AxiProgressIndicator), findsNothing);

      await tester.tap(find.text('Open DM'));
      await tester.pumpAndSettle();
      expect(directChatCalls, 1);
    },
  );

  testWidgets('member tile bubble fills the available sheet width', (
    tester,
  ) async {
    const roomJid = 'room@conference.axi.im';
    const selfOccupantId = '$roomJid/self';
    const memberOccupantId = '$roomJid/alice';

    await tester.pumpWidget(
      _RoomMembersSheetTestApp(
        child: RoomMembersSheet(
          roomState: RoomState(
            roomJid: roomJid,
            myOccupantJid: selfOccupantId,
            occupants: <String, Occupant>{
              selfOccupantId: Occupant(
                occupantId: selfOccupantId,
                nick: 'self',
                realJid: 'self@axi.im',
                affiliation: OccupantAffiliation.member,
                role: OccupantRole.participant,
              ),
              memberOccupantId: Occupant(
                occupantId: memberOccupantId,
                nick: 'alice',
                realJid: 'alice@axi.im',
                affiliation: OccupantAffiliation.member,
                role: OccupantRole.participant,
              ),
            },
          ),
          memberSections: <RoomMemberSection>[
            RoomMemberSection(
              kind: RoomMemberSectionKind.members,
              members: <RoomMemberEntry>[
                RoomMemberEntry(
                  occupant: Occupant(
                    occupantId: memberOccupantId,
                    nick: 'alice',
                    realJid: 'alice@axi.im',
                    affiliation: OccupantAffiliation.member,
                    role: OccupantRole.participant,
                  ),
                  actions: <MucModerationAction>[MucModerationAction.kick],
                  directChatJid: 'alice@axi.im',
                ),
              ],
            ),
          ],
          canInvite: false,
          avatarUpdateInFlight: false,
          onInvite: (_) {},
          onAction: (_, _, _) async {},
          onOpenDirectChat: (_) async {},
        ),
      ),
    );

    final tileFinder = find.byWidgetPredicate(
      (widget) => widget is AxiListTile && widget.title == 'alice',
    );
    final bubbleFinder = find.ancestor(
      of: tileFinder,
      matching: find.byType(CutoutSurface),
    );
    final bubbleRect = tester.getRect(bubbleFinder.first);
    final sheetRect = tester.getRect(find.byType(RoomMembersSheet));

    expect(bubbleRect.left, closeTo(sheetRect.left + axiSpacing.m, 0.001));
    expect(bubbleRect.right, closeTo(sheetRect.right - axiSpacing.m, 0.001));
  });

  testWidgets('member action timeout clears loading after 10 seconds', (
    tester,
  ) async {
    final neverCompletes = Completer<void>();
    const roomJid = 'room@conference.axi.im';
    const selfOccupantId = '$roomJid/self';
    const memberOccupantId = '$roomJid/alice';

    await tester.pumpWidget(
      _RoomMembersSheetTestApp(
        child: RoomMembersSheet(
          roomState: RoomState(
            roomJid: roomJid,
            myOccupantJid: selfOccupantId,
            occupants: <String, Occupant>{
              selfOccupantId: Occupant(
                occupantId: selfOccupantId,
                nick: 'self',
                realJid: 'self@axi.im',
                affiliation: OccupantAffiliation.admin,
                role: OccupantRole.moderator,
              ),
              memberOccupantId: Occupant(
                occupantId: memberOccupantId,
                nick: 'alice',
                realJid: 'alice@axi.im',
                affiliation: OccupantAffiliation.member,
                role: OccupantRole.participant,
              ),
            },
          ),
          memberSections: <RoomMemberSection>[
            RoomMemberSection(
              kind: RoomMemberSectionKind.members,
              members: <RoomMemberEntry>[
                RoomMemberEntry(
                  occupant: Occupant(
                    occupantId: memberOccupantId,
                    nick: 'alice',
                    realJid: 'alice@axi.im',
                    affiliation: OccupantAffiliation.member,
                    role: OccupantRole.participant,
                  ),
                  actions: <MucModerationAction>[MucModerationAction.kick],
                ),
              ],
            ),
          ],
          canInvite: false,
          avatarUpdateInFlight: false,
          onInvite: (_) {},
          onAction: (occupantId, action, actionLabel) {
            expect(occupantId, memberOccupantId);
            expect(action, MucModerationAction.kick);
            expect(actionLabel, 'Kick');
            return neverCompletes.future;
          },
          onOpenDirectChat: (_) async {},
        ),
      ),
    );

    await tester.tap(find.text('alice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kick'));
    await tester.pump();

    expect(find.byType(AxiProgressIndicator), findsWidgets);

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    expect(find.byType(AxiProgressIndicator), findsNothing);
  });

  testWidgets('leave and destroy room actions confirm before running', (
    tester,
  ) async {
    var leaveCalls = 0;
    var destroyCalls = 0;
    final leaveCompleter = Completer<void>();
    final destroyCompleter = Completer<void>();
    const roomJid = 'room@conference.axi.im';
    const selfOccupantId = '$roomJid/self';

    await tester.pumpWidget(
      _RoomMembersSheetTestApp(
        child: RoomMembersSheet(
          roomState: RoomState(
            roomJid: roomJid,
            myOccupantJid: selfOccupantId,
            occupants: <String, Occupant>{
              selfOccupantId: Occupant(
                occupantId: selfOccupantId,
                nick: 'self',
                realJid: 'self@axi.im',
                affiliation: OccupantAffiliation.owner,
                role: OccupantRole.moderator,
              ),
            },
          ),
          memberSections: const <RoomMemberSection>[],
          canInvite: false,
          avatarUpdateInFlight: false,
          onInvite: (_) {},
          onAction: (_, _, _) async {},
          onOpenDirectChat: (_) async {},
          onLeaveRoom: () {
            leaveCalls += 1;
            return leaveCompleter.future;
          },
          onDestroyRoom: () {
            destroyCalls += 1;
            return destroyCompleter.future;
          },
        ),
      ),
    );

    await tester.tap(find.text('Leave room'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Leave room?'), findsOneWidget);
    expect(find.text('Leave room'), findsNWidgets(2));

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(leaveCalls, 0);

    await tester.tap(find.text('Leave room'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Leave room').last);
    await tester.pump();

    expect(leaveCalls, 1);
    expect(find.byType(AxiProgressIndicator), findsWidgets);

    leaveCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Destroy room'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Destroy room?'), findsOneWidget);

    await tester.tap(find.text('Destroy room').last);
    await tester.pump();

    expect(destroyCalls, 1);

    destroyCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  });
}

class _RoomMembersSheetTestApp extends StatelessWidget {
  const _RoomMembersSheetTestApp({required this.child});

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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
          child: Scaffold(body: child),
        ),
      ),
    );
  }
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
