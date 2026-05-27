import 'dart:async';

import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_availability_share_state.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_registry.dart';
import 'package:axichat/src/calendar/view/availability/calendar_availability_share_sheet.dart';
import 'package:axichat/src/calendar/view/shell/calendar_task_off_grid_drag_controller.dart';
import 'package:axichat/src/calendar/view/sidebar/calendar_critical_path_share_sheet.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_task_share_sheet.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/bloc/chat_search_cubit.dart';
import 'package:axichat/src/chat/view/chat.dart' as chat_view;
import 'package:axichat/src/chat/view/composer/cutout_composer.dart';
import 'package:axichat/src/chat/view/overlays/room_members_sheet.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/draft_form.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/folders/bloc/folders_cubit.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/share/share_handoff.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/muc/occupant.dart';
import 'package:axichat/src/xmpp/muc/room_state.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'recipient_send_flow_test_helpers.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(const CalendarEvent.started());
    registerFallbackValue(const ChatPinnedMessagesOpened());
    registerFallbackValue(<DraftForwardedBlock>[]);
  });

  group('recipient send surfaces', () {
    testWidgets('chat inline composer sends exactly the submitted chips', (
      tester,
    ) async {
      final chats = [
        _chat(jid: 'alice@axi.im', title: 'Alice'),
        _chat(jid: 'bob@axi.im', title: 'Bob'),
      ];
      final harness = _RecipientSurfaceHarness(chats: chats);
      final sends = _captureChatSends(harness, chat: chats.first);

      await _pumpChatSurface(tester, harness);
      await _enterChatComposerText(tester, 'hello');
      await submitRecipientChip(tester, 'Bob');
      await tester.tap(sendIconButtonFinder().last);
      await tester.pump();

      expect(_composerRecipientIds(sends.single.recipients), [
        'alice@axi.im',
        'bob@axi.im',
      ]);
    });

    testWidgets(
      'opening pinned panel requests pins before the list has entries',
      (tester) async {
        final chat = _chat(jid: 'alice@axi.im', title: 'Alice');
        final harness = _RecipientSurfaceHarness(chats: [chat]);
        final events = _captureChatEvents(
          harness,
          state: ChatState(
            items: const <Message>[],
            messagesLoaded: true,
            chat: chat,
            pinnedMessagesStatus: ChatPinnedMessagesStatus.idle,
          ),
          jid: chat.jid,
        );

        await _pumpChatSurface(tester, harness);
        await tester.tap(_pinnedMessagesButtonFinder());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(events.whereType<ChatPinnedMessagesOpened>(), hasLength(1));
      },
    );

    testWidgets('pinned panel failure retry dispatches retry event', (
      tester,
    ) async {
      final chat = _chat(jid: 'alice@axi.im', title: 'Alice');
      final harness = _RecipientSurfaceHarness(chats: [chat]);
      final events = _captureChatEvents(
        harness,
        state: ChatState(
          items: const <Message>[],
          messagesLoaded: true,
          chat: chat,
          pinnedMessagesStatus: ChatPinnedMessagesStatus.failure,
        ),
        jid: chat.jid,
      );

      await _pumpChatSurface(tester, harness);
      await tester.tap(_pinnedMessagesButtonFinder());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Retry').last);
      await tester.pump();

      expect(events.whereType<ChatPinnedMessagesOpened>(), isEmpty);
      expect(
        events.whereType<ChatPinnedMessagesRetryRequested>(),
        hasLength(1),
      );
    });

    testWidgets('pinned composer notice hide dispatches hide event', (
      tester,
    ) async {
      final chat = _chat(jid: 'alice@axi.im', title: 'Alice');
      final harness = _RecipientSurfaceHarness(chats: [chat]);
      final events = _captureChatEvents(
        harness,
        state: ChatState(
          items: const <Message>[],
          messagesLoaded: true,
          chat: chat,
          latestPinnedMessageNotice: ChatPinnedMessageNotice(
            messageStanzaId: 'new-pin',
            chatJid: chat.jid,
            pinnedAt: DateTime.utc(2026, 5, 26),
          ),
        ),
        jid: chat.jid,
      );

      await _pumpChatSurface(tester, harness);

      expect(find.text('New pinned message'), findsWidgets);

      await tester.tap(find.byTooltip('Hide').last);
      await tester.pump();

      expect(events.whereType<ChatPinnedMessageNoticeHidden>(), hasLength(1));
    });

    testWidgets('chat inline composer excludes removed chips before sending', (
      tester,
    ) async {
      final chats = [
        _chat(jid: 'alice@axi.im', title: 'Alice'),
        _chat(jid: 'bob@axi.im', title: 'Bob'),
      ];
      final harness = _RecipientSurfaceHarness(chats: chats);
      final sends = _captureChatSends(harness, chat: chats.first);

      await _pumpChatSurface(tester, harness);
      await _enterChatComposerText(tester, 'hello');
      await submitRecipientChip(tester, 'Bob');
      await _expandRecipientChipsBar(tester);
      await tapFirstRecipientDelete(tester);
      await tester.tap(sendIconButtonFinder().last);
      await tester.pump();

      expect(_composerRecipientIds(sends.single.recipients), ['alice@axi.im']);
    });

    testWidgets(
      'chat inline composer consumes first send tap while a typed address is submitted',
      (tester) async {
        final chats = [
          _chat(jid: 'alice@axi.im', title: 'Alice'),
          _chat(
            jid: 'thread@axi.im',
            title: 'Literal alias',
            contactDisplayName: 'literal@axi.im',
          ),
        ];
        final harness = _RecipientSurfaceHarness(
          chats: chats,
          settings: const SettingsState(
            endpointConfig: EndpointConfig(smtpEnabled: false),
          ),
        );
        final sends = _captureChatSends(harness, chat: chats.first);

        await _pumpChatSurface(tester, harness);
        await _enterChatComposerText(tester, 'hello');
        await _expandRecipientChipsBar(tester);
        await assertPendingRecipientTapIsConsumed(
          tester: tester,
          pendingText: 'literal@axi.im',
          sendFinder: sendIconButtonFinder().last,
          hasSent: () => sends.isNotEmpty,
        );

        expect(_composerRecipientIds(sends.single.recipients), [
          'alice@axi.im',
          'literal@axi.im',
        ]);
      },
    );

    testWidgets('chat expanded composer sends exactly the submitted chips', (
      tester,
    ) async {
      final chats = [
        _chat(
          jid: 'alice@axi.im',
          title: 'Alice',
          transport: MessageTransport.email,
        ),
        _chat(jid: 'bob@axi.im', title: 'Bob'),
      ];
      final harness = _RecipientSurfaceHarness(
        chats: chats,
        settings: const SettingsState(emailSendConfirmationEnabled: false),
      );
      final sends = _captureChatSends(
        harness,
        chat: chats.first,
        emailServiceAvailable: true,
        emailSelfJid: 'me@example.com',
      );

      await _pumpChatSurface(tester, harness);
      await _enterChatComposerText(tester, 'hello');
      await submitRecipientChip(tester, 'Bob');
      await tester.tap(_chatExpandDraftButtonFinder());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(sendIconButtonFinder().last);
      await tester.pump();

      expect(_composerRecipientIds(sends.single.recipients), [
        'alice@axi.im',
        'bob@axi.im',
      ]);
    });

    testWidgets(
      'chat expanded composer excludes removed chips before sending',
      (tester) async {
        final chats = [
          _chat(
            jid: 'alice@axi.im',
            title: 'Alice',
            transport: MessageTransport.email,
          ),
          _chat(jid: 'bob@axi.im', title: 'Bob'),
        ];
        final harness = _RecipientSurfaceHarness(
          chats: chats,
          settings: const SettingsState(emailSendConfirmationEnabled: false),
        );
        final sends = _captureChatSends(
          harness,
          chat: chats.first,
          emailServiceAvailable: true,
          emailSelfJid: 'me@example.com',
        );

        await _pumpChatSurface(tester, harness);
        await _enterChatComposerText(tester, 'hello');
        await submitRecipientChip(tester, 'Bob');
        await tester.tap(_chatExpandDraftButtonFinder());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tapFirstRecipientDelete(tester);
        await tester.tap(sendIconButtonFinder().last);
        await tester.pump();

        expect(_composerRecipientIds(sends.single.recipients), [
          'alice@axi.im',
        ]);
      },
    );

    testWidgets(
      'chat expanded composer consumes first send tap while a typed contact is submitted',
      (tester) async {
        final chats = [
          _chat(
            jid: 'alice@axi.im',
            title: 'Alice',
            transport: MessageTransport.email,
          ),
          _chat(jid: 'bob@axi.im', title: 'Bob'),
        ];
        final harness = _RecipientSurfaceHarness(
          chats: chats,
          settings: const SettingsState(emailSendConfirmationEnabled: false),
        );
        final sends = _captureChatSends(
          harness,
          chat: chats.first,
          emailServiceAvailable: true,
          emailSelfJid: 'me@example.com',
        );

        await _pumpChatSurface(tester, harness);
        await _enterChatComposerText(tester, 'hello');
        await tester.tap(_chatExpandDraftButtonFinder());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await assertPendingRecipientTapIsConsumed(
          tester: tester,
          pendingText: 'Bob',
          sendFinder: sendIconButtonFinder().last,
          hasSent: () => sends.isNotEmpty,
        );

        expect(_composerRecipientIds(sends.single.recipients), [
          'alice@axi.im',
          'bob@axi.im',
        ]);
      },
    );

    testWidgets('draft form sends exactly the submitted chips', (tester) async {
      final chats = [
        _chat(jid: 'alice@axi.im', title: 'Alice'),
        _chat(jid: 'bob@axi.im', title: 'Bob'),
      ];
      final harness = _RecipientSurfaceHarness(chats: chats);
      final xmppTargetBatches = <List<String>>[];
      _captureDraftSends(harness, xmppTargetBatches: xmppTargetBatches);

      await tester.pumpWidget(
        harness.wrap(
          DraftForm(
            locate: harness.locate,
            jids: const ['alice@axi.im', 'bob@axi.im'],
            body: 'hello',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(sendIconButtonFinder().first);
      await tester.pump();

      expect(xmppTargetBatches, [
        ['alice@axi.im', 'bob@axi.im'],
      ]);
    });

    testWidgets('draft form excludes removed chips before sending', (
      tester,
    ) async {
      final chats = [
        _chat(jid: 'alice@axi.im', title: 'Alice'),
        _chat(jid: 'bob@axi.im', title: 'Bob'),
      ];
      final harness = _RecipientSurfaceHarness(chats: chats);
      final xmppTargetBatches = <List<String>>[];
      _captureDraftSends(harness, xmppTargetBatches: xmppTargetBatches);

      await tester.pumpWidget(
        harness.wrap(
          DraftForm(
            locate: harness.locate,
            jids: const ['alice@axi.im', 'bob@axi.im'],
            body: 'hello',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tapFirstRecipientDelete(tester);
      await tester.tap(sendIconButtonFinder().first);
      await tester.pump();

      expect(xmppTargetBatches, [
        ['bob@axi.im'],
      ]);
    });

    testWidgets(
      'draft form consumes first send tap while a typed address is submitted',
      (tester) async {
        final chats = [
          _chat(
            jid: 'thread@axi.im',
            title: 'Literal alias',
            contactDisplayName: 'literal@axi.im',
          ),
        ];
        final harness = _RecipientSurfaceHarness(
          chats: chats,
          settings: const SettingsState(
            endpointConfig: EndpointConfig(smtpEnabled: false),
          ),
        );
        final xmppTargetBatches = <List<String>>[];
        _captureDraftSends(harness, xmppTargetBatches: xmppTargetBatches);

        await tester.pumpWidget(
          harness.wrap(DraftForm(locate: harness.locate, body: 'hello')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await assertPendingRecipientTapIsConsumed(
          tester: tester,
          pendingText: 'literal@axi.im',
          sendFinder: sendIconButtonFinder().first,
          hasSent: () => xmppTargetBatches.isNotEmpty,
        );

        expect(xmppTargetBatches, [
          ['literal@axi.im'],
        ]);
      },
    );

    testWidgets('calendar task share sends exactly submitted chips', (
      tester,
    ) async {
      final harness = _RecipientSurfaceHarness(
        chats: [
          _chat(jid: 'alice@axi.im', title: 'Alice'),
          _chat(jid: 'bob@axi.im', title: 'Bob'),
        ],
      );
      final events = _captureCalendarEvents(harness);

      await tester.pumpWidget(
        harness.wrap(
          CalendarTaskShareSheet(
            task: _task(),
            availableChats: harness.chats,
            locate: harness.locate,
          ),
        ),
      );
      await tester.pump();

      await submitRecipientChip(tester, 'Alice');
      await submitRecipientChip(tester, 'Bob');
      await tester.tap(find.text('Send').last);
      await tester.pump();

      final event = events.single as CalendarTaskShareRequested;
      expect(_contactRecipientIds(event.recipients), [
        'alice@axi.im',
        'bob@axi.im',
      ]);
    });

    testWidgets('calendar task share excludes removed chips before sending', (
      tester,
    ) async {
      final harness = _RecipientSurfaceHarness(
        chats: [
          _chat(jid: 'alice@axi.im', title: 'Alice'),
          _chat(jid: 'bob@axi.im', title: 'Bob'),
        ],
      );
      final events = _captureCalendarEvents(harness);

      await tester.pumpWidget(
        harness.wrap(
          CalendarTaskShareSheet(
            task: _task(),
            availableChats: harness.chats,
            locate: harness.locate,
          ),
        ),
      );
      await tester.pump();

      await submitRecipientChip(tester, 'Alice');
      await submitRecipientChip(tester, 'Bob');
      await tapFirstRecipientDelete(tester);
      await tester.tap(find.text('Send').last);
      await tester.pump();

      final event = events.single as CalendarTaskShareRequested;
      expect(_contactRecipientIds(event.recipients), ['bob@axi.im']);
    });

    testWidgets(
      'calendar task share consumes first send tap while a typed address is submitted',
      (tester) async {
        final harness = _RecipientSurfaceHarness(
          chats: [
            _chat(
              jid: 'thread@axi.im',
              title: 'Literal alias',
              contactDisplayName: 'literal@axi.im',
            ),
          ],
        );
        final events = _captureCalendarEvents(harness);

        await tester.pumpWidget(
          harness.wrap(
            CalendarTaskShareSheet(
              task: _task(),
              availableChats: harness.chats,
              locate: harness.locate,
            ),
          ),
        );
        await tester.pump();

        await assertPendingRecipientTapIsConsumed(
          tester: tester,
          pendingText: 'literal@axi.im',
          sendFinder: find.text('Send').last,
          hasSent: () => events.isNotEmpty,
        );

        final event = events.single as CalendarTaskShareRequested;
        expect(_contactRecipientIds(event.recipients), ['literal@axi.im']);
      },
    );

    testWidgets('calendar availability share sends submitted chat chips', (
      tester,
    ) async {
      final harness = _RecipientSurfaceHarness(
        chats: [
          _chat(jid: 'alice@axi.im', title: 'Alice'),
          _chat(jid: 'bob@axi.im', title: 'Bob'),
        ],
      );
      final events = _captureCalendarEvents(harness);

      await _pumpAvailabilityRecipientsStep(tester, harness);

      await submitRecipientChip(tester, 'Alice');
      await submitRecipientChip(tester, 'Bob');
      await tester.tap(find.text('Send').last);
      await tester.pump();

      final event = events.single as CalendarAvailabilityShareRequested;
      expect(event.recipients.map((chat) => chat.jid), [
        'alice@axi.im',
        'bob@axi.im',
      ]);
    });

    testWidgets('calendar availability share excludes removed chips', (
      tester,
    ) async {
      final harness = _RecipientSurfaceHarness(
        chats: [
          _chat(jid: 'alice@axi.im', title: 'Alice'),
          _chat(jid: 'bob@axi.im', title: 'Bob'),
        ],
      );
      final events = _captureCalendarEvents(harness);

      await _pumpAvailabilityRecipientsStep(tester, harness);

      await submitRecipientChip(tester, 'Alice');
      await submitRecipientChip(tester, 'Bob');
      await tapFirstRecipientDelete(tester);
      await tester.tap(find.text('Send').last);
      await tester.pump();

      final event = events.single as CalendarAvailabilityShareRequested;
      expect(event.recipients.map((chat) => chat.jid), ['bob@axi.im']);
    });

    testWidgets(
      'calendar availability share consumes first send tap for a pending contact name',
      (tester) async {
        final harness = _RecipientSurfaceHarness(
          chats: [_chat(jid: 'bob@axi.im', title: 'Bob')],
        );
        final events = _captureCalendarEvents(harness);

        await _pumpAvailabilityRecipientsStep(tester, harness);

        await assertPendingRecipientTapIsConsumed(
          tester: tester,
          pendingText: 'Bob',
          sendFinder: find.text('Send').last,
          hasSent: () => events.isNotEmpty,
        );

        final event = events.single as CalendarAvailabilityShareRequested;
        expect(event.recipients.map((chat) => chat.jid), ['bob@axi.im']);
      },
    );

    testWidgets('critical path share sends only the visible selected chip', (
      tester,
    ) async {
      final harness = _RecipientSurfaceHarness(
        chats: [
          _chat(jid: 'alice@axi.im', title: 'Alice'),
          _chat(jid: 'bob@axi.im', title: 'Bob'),
        ],
      );
      final events = _captureCalendarEvents(harness);

      await tester.pumpWidget(
        harness.wrap(
          CalendarCriticalPathShareSheet(
            path: _criticalPath(),
            tasks: [_task()],
            availableChats: harness.chats,
            initialChat: harness.chats.first,
            locate: harness.locate,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Send').last);
      await tester.pump();

      final event = events.single as CalendarCriticalPathShareRequested;
      expect(event.recipient.jid, 'alice@axi.im');
    });

    testWidgets(
      'critical path share consumes first send tap while a replacement chip is submitted',
      (tester) async {
        final harness = _RecipientSurfaceHarness(
          chats: [
            _chat(jid: 'alice@axi.im', title: 'Alice'),
            _chat(jid: 'bob@axi.im', title: 'Bob'),
          ],
        );
        final events = _captureCalendarEvents(harness);

        await tester.pumpWidget(
          harness.wrap(
            CalendarCriticalPathShareSheet(
              path: _criticalPath(),
              tasks: [_task()],
              availableChats: harness.chats,
              initialChat: harness.chats.first,
              locate: harness.locate,
            ),
          ),
        );
        await tester.pump();

        await tapFirstRecipientDelete(tester);
        await assertPendingRecipientTapIsConsumed(
          tester: tester,
          pendingText: 'Bob',
          sendFinder: find.text('Send').last,
          hasSent: () => events.isNotEmpty,
        );

        final event = events.single as CalendarCriticalPathShareRequested;
        expect(event.recipient.jid, 'bob@axi.im');
      },
    );

    testWidgets('room invite sheet invites only submitted visible chips', (
      tester,
    ) async {
      final harness = _RecipientSurfaceHarness(
        chats: [
          _chat(jid: 'alice@axi.im', title: 'Alice'),
          _chat(jid: 'bob@axi.im', title: 'Bob'),
        ],
      );
      final invitees = <String>[];

      await tester.pumpWidget(
        harness.wrap(
          RoomMembersSheet(
            roomState: _roomState(),
            memberSections: const <RoomMemberSection>[],
            canInvite: true,
            avatarUpdateInFlight: false,
            onInvite: invitees.add,
            onAction: (_, _, _) async {},
            onOpenDirectChat: (_) async => true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Invite user'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await submitRecipientChip(tester, 'Alice');
      await submitRecipientChip(tester, 'Bob');
      await tester.tap(find.text('Send').last);
      await tester.pump();

      expect(invitees, ['alice@axi.im', 'bob@axi.im']);
    });

    testWidgets('room invite sheet excludes removed chips before sending', (
      tester,
    ) async {
      final harness = _RecipientSurfaceHarness(
        chats: [
          _chat(jid: 'alice@axi.im', title: 'Alice'),
          _chat(jid: 'bob@axi.im', title: 'Bob'),
        ],
      );
      final invitees = <String>[];

      await tester.pumpWidget(
        harness.wrap(
          RoomMembersSheet(
            roomState: _roomState(),
            memberSections: const <RoomMemberSection>[],
            canInvite: true,
            avatarUpdateInFlight: false,
            onInvite: invitees.add,
            onAction: (_, _, _) async {},
            onOpenDirectChat: (_) async => true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Invite user'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await submitRecipientChip(tester, 'Alice');
      await submitRecipientChip(tester, 'Bob');
      await tapFirstRecipientDelete(tester);
      await tester.tap(find.text('Send').last);
      await tester.pump();

      expect(invitees, ['bob@axi.im']);
    });

    testWidgets(
      'room invite sheet consumes first send tap while a contact name is submitted',
      (tester) async {
        final harness = _RecipientSurfaceHarness(
          chats: [_chat(jid: 'bob@axi.im', title: 'Bob')],
        );
        final invitees = <String>[];

        await tester.pumpWidget(
          harness.wrap(
            RoomMembersSheet(
              roomState: _roomState(),
              memberSections: const <RoomMemberSection>[],
              canInvite: true,
              avatarUpdateInFlight: false,
              onInvite: invitees.add,
              onAction: (_, _, _) async {},
              onOpenDirectChat: (_) async => true,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Invite user'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await assertPendingRecipientTapIsConsumed(
          tester: tester,
          pendingText: 'Bob',
          sendFinder: find.text('Send').last,
          hasSent: () => invitees.isNotEmpty,
        );

        expect(invitees, ['bob@axi.im']);
      },
    );
  });
}

class _RecipientSurfaceHarness {
  _RecipientSurfaceHarness({
    this.chats = const <Chat>[],
    SettingsState settings = const SettingsState(),
  }) {
    when(() => settingsCubit.state).thenReturn(settings);
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
    when(() => profileCubit.state).thenReturn(
      const ProfileState(jid: 'me@axi.im', resource: '', username: 'Me'),
    );
    when(
      () => profileCubit.stream,
    ).thenAnswer((_) => const Stream<ProfileState>.empty());
    when(() => rosterCubit.state).thenReturn(const RosterState());
    when(
      () => rosterCubit.stream,
    ).thenAnswer((_) => const Stream<RosterState>.empty());
    when(() => rosterCubit[RosterCubit.itemsCacheKey]).thenReturn(null);
    when(() => chatsCubit.state).thenReturn(
      ChatsState(
        openCalendar: false,
        items: chats,
        visibleItems: chats,
        creationStatus: RequestStatus.none,
      ),
    );
    when(
      () => chatsCubit.stream,
    ).thenAnswer((_) => const Stream<ChatsState>.empty());
    when(() => chatsCubit.selfJid).thenReturn('me@axi.im');
    when(() => calendarBloc.state).thenReturn(CalendarState.initial());
    when(
      () => calendarBloc.stream,
    ).thenAnswer((_) => const Stream<CalendarState>.empty());
    when(() => chatSearchCubit.state).thenReturn(const ChatSearchState());
    when(
      () => chatSearchCubit.stream,
    ).thenAnswer((_) => const Stream<ChatSearchState>.empty());
    when(() => blocklistCubit.state).thenReturn(
      const BlocklistAvailable(items: <BlocklistEntry>[], visibleItems: []),
    );
    when(
      () => blocklistCubit.stream,
    ).thenAnswer((_) => const Stream<BlocklistState>.empty());
    when(
      () => blocklistCubit[BlocklistCubit.blocklistItemsCacheKey],
    ).thenReturn(null);
    when(() => foldersCubit.state).thenReturn(
      const FoldersState(
        collectionId: 'important',
        chatJid: null,
        collections: null,
        memberships: null,
        contactFolderRules: <String, String>{},
        items: null,
        visibleItems: null,
      ),
    );
    when(
      () => foldersCubit.stream,
    ).thenAnswer((_) => const Stream<FoldersState>.empty());
    when(() => xmppService.demoOfflineMode).thenReturn(false);
    when(
      () => draftCubit.state,
    ).thenReturn(const DraftsAvailable(items: [], visibleItems: []));
    when(
      () => draftCubit.stream,
    ).thenAnswer((_) => const Stream<DraftState>.empty());
    when(
      () => draftCubit.loadDraftAttachments(any<List<String>>()),
    ).thenAnswer((_) async => const <Attachment>[]);
    when(
      () => draftCubit.deleteDraftAttachmentMetadata(any()),
    ).thenAnswer((_) async {});
    when(
      () => draftCubit.deleteDraft(id: any(named: 'id')),
    ).thenAnswer((_) async {});
  }

  final List<Chat> chats;
  final settingsCubit = _MockSettingsCubit();
  final profileCubit = _MockProfileCubit();
  final rosterCubit = _MockRosterCubit();
  final chatsCubit = _MockChatsCubit();
  final calendarBloc = _MockCalendarBloc();
  final chatBloc = _MockChatBloc();
  final chatSearchCubit = _MockChatSearchCubit();
  final blocklistCubit = _MockBlocklistCubit();
  final foldersCubit = _MockFoldersCubit();
  final draftCubit = _MockDraftCubit();
  final xmppService = _MockXmppService();
  final emailService = _MockEmailService();
  final calendarReminderController = _MockCalendarReminderController();

  T locate<T>() => switch (T) {
    const (SettingsCubit) => settingsCubit as T,
    const (ProfileCubit) => profileCubit as T,
    const (RosterCubit) => rosterCubit as T,
    const (ChatsCubit) => chatsCubit as T,
    const (CalendarBloc) => calendarBloc as T,
    const (ChatBloc) => chatBloc as T,
    const (ChatSearchCubit) => chatSearchCubit as T,
    const (BlocklistCubit) => blocklistCubit as T,
    const (FoldersCubit) => foldersCubit as T,
    const (DraftCubit) => draftCubit as T,
    const (XmppService) => xmppService as T,
    const (EmailService) => emailService as T,
    const (CalendarReminderController) => calendarReminderController as T,
    _ => throw StateError('No test dependency for $T'),
  };

  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        Provider<Policy>.value(value: const Policy()),
        Provider<XmppService>.value(value: xmppService),
        Provider<EmailService>.value(value: emailService),
        Provider<CalendarReminderController>.value(
          value: calendarReminderController,
        ),
        Provider<ShareComposerSeedQueue>(
          create: (_) => ShareComposerSeedQueue(),
          dispose: (_, queue) => queue.dispose(),
        ),
        ChangeNotifierProvider<CalendarStorageManager>(
          create: (_) => CalendarStorageManager(
            registry: CalendarStorageRegistry(fallback: InMemoryStorage()),
          ),
        ),
        ChangeNotifierProvider<CalendarTaskOffGridDragController>(
          create: (_) => CalendarTaskOffGridDragController(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
          BlocProvider<ProfileCubit>.value(value: profileCubit),
          BlocProvider<RosterCubit>.value(value: rosterCubit),
          BlocProvider<ChatsCubit>.value(value: chatsCubit),
          BlocProvider<CalendarBloc>.value(value: calendarBloc),
          BlocProvider<ChatBloc>.value(value: chatBloc),
          BlocProvider<ChatSearchCubit>.value(value: chatSearchCubit),
          BlocProvider<BlocklistCubit>.value(value: blocklistCubit),
          BlocProvider<FoldersCubit>.value(value: foldersCubit),
          BlocProvider<DraftCubit>.value(value: draftCubit),
        ],
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
            child: Scaffold(
              body: SizedBox(width: 900, height: 900, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

List<ChatMessageSent> _captureChatSends(
  _RecipientSurfaceHarness harness, {
  required Chat chat,
  bool emailServiceAvailable = false,
  String? emailSelfJid,
}) {
  final state = ChatState(
    items: const <Message>[],
    messagesLoaded: true,
    chat: chat,
    emailServiceAvailable: emailServiceAvailable,
    emailSelfJid: emailSelfJid,
  );
  final sends = <ChatMessageSent>[];
  when(() => harness.chatBloc.state).thenReturn(state);
  when(
    () => harness.chatBloc.stream,
  ).thenAnswer((_) => const Stream<ChatState>.empty());
  when(() => harness.chatBloc.jid).thenReturn(chat.jid);
  when(() => harness.chatBloc.add(any())).thenAnswer((invocation) {
    final event = invocation.positionalArguments.single as ChatEvent;
    if (event is ChatMessageSent) {
      sends.add(event);
      event.completer?.complete(event.pendingAttachments);
    }
  });
  return sends;
}

List<ChatEvent> _captureChatEvents(
  _RecipientSurfaceHarness harness, {
  required ChatState state,
  required String jid,
}) {
  final events = <ChatEvent>[];
  when(() => harness.chatBloc.state).thenReturn(state);
  when(
    () => harness.chatBloc.stream,
  ).thenAnswer((_) => const Stream<ChatState>.empty());
  when(() => harness.chatBloc.jid).thenReturn(jid);
  when(() => harness.chatBloc.add(any())).thenAnswer((invocation) {
    events.add(invocation.positionalArguments.single as ChatEvent);
  });
  return events;
}

List<CalendarEvent> _captureCalendarEvents(_RecipientSurfaceHarness harness) {
  final events = <CalendarEvent>[];
  when(() => harness.calendarBloc.add(any())).thenAnswer((invocation) {
    final event = invocation.positionalArguments.single as CalendarEvent;
    events.add(event);
    switch (event) {
      case CalendarTaskShareRequested(:final completer):
      case CalendarCriticalPathShareRequested(:final completer):
      case CalendarAvailabilityShareRequested(:final completer):
        completer.complete(
          const CalendarShareResult.failure(CalendarShareFailure.sendFailed),
        );
      default:
        break;
    }
  });
  return events;
}

void _captureDraftSends(
  _RecipientSurfaceHarness harness, {
  required List<List<String>> xmppTargetBatches,
}) {
  when(
    () => harness.draftCubit.sendDraft(
      id: any(named: 'id'),
      xmppTargets: any(named: 'xmppTargets'),
      emailTargets: any(named: 'emailTargets'),
      body: any(named: 'body'),
      shareTokenSignatureEnabled: any(named: 'shareTokenSignatureEnabled'),
      subject: any(named: 'subject'),
      quoteTarget: any(named: 'quoteTarget'),
      attachments: any(named: 'attachments'),
      calendarTaskIcsMessage: any(named: 'calendarTaskIcsMessage'),
      forwardedBlocks: any(named: 'forwardedBlocks'),
    ),
  ).thenAnswer((invocation) async {
    xmppTargetBatches.add(
      (invocation.namedArguments[#xmppTargets] as List<DraftXmppTarget>)
          .map((target) => target.jid)
          .toList(growable: false),
    );
    return DraftSendOutcome.success();
  });
}

Future<void> _pumpChatSurface(
  WidgetTester tester,
  _RecipientSurfaceHarness harness,
) async {
  await tester.pumpWidget(
    harness.wrap(const chat_view.Chat(syncWithOpenChatRoute: false)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _enterChatComposerText(WidgetTester tester, String text) async {
  final composerField = find.descendant(
    of: find.byType(ChatCutoutComposer, skipOffstage: false),
    matching: find.byType(AxiTextField),
    skipOffstage: false,
  );
  if (composerField.evaluate().isEmpty) {
    fail(
      'No chat composer field found; '
      'ChatCutoutComposer=${find.byType(ChatCutoutComposer, skipOffstage: false).evaluate().length}, '
      'AxiTextField=${find.byType(AxiTextField, skipOffstage: false).evaluate().length}',
    );
  }
  tester.widget<AxiTextField>(composerField).controller!.text = text;
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _expandRecipientChipsBar(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.keyboard_arrow_down).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _chatExpandDraftButtonFinder() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is AxiIconButton && widget.iconData == LucideIcons.maximize2,
  );
}

Finder _pinnedMessagesButtonFinder() {
  return find.byWidgetPredicate(
    (widget) => widget is AxiIconButton && widget.tooltip == 'Pinned messages',
  );
}

Future<void> _pumpAvailabilityRecipientsStep(
  WidgetTester tester,
  _RecipientSurfaceHarness harness,
) async {
  await tester.pumpWidget(
    harness.wrap(
      CalendarAvailabilityShareScreen(
        source: const CalendarAvailabilityShareSource.personal(),
        model: CalendarModel.empty(),
        ownerJid: 'me@axi.im',
        availableChats: harness.chats,
        lockToChat: false,
        locate: harness.locate,
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Share').last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

List<String> _contactRecipientIds(List<Contact> recipients) {
  return recipients
      .map((recipient) {
        return recipient.chatJid ??
            recipient.normalizedOrResolvedAddress ??
            recipient.jid;
      })
      .toList(growable: false);
}

List<String> _composerRecipientIds(List<ComposerRecipient> recipients) {
  return recipients.recipientAddresses(allowHint: true);
}

Chat _chat({
  required String jid,
  required String title,
  String? contactDisplayName,
  MessageTransport transport = MessageTransport.xmpp,
}) {
  return Chat(
    jid: jid,
    title: title,
    type: ChatType.chat,
    lastChangeTimestamp: DateTime.utc(2026),
    contactDisplayName: contactDisplayName,
    transport: transport,
  );
}

CalendarTask _task() {
  final timestamp = DateTime.utc(2026);
  return CalendarTask(
    id: 'task-1',
    title: 'Task',
    description: null,
    scheduledTime: null,
    duration: const Duration(minutes: 30),
    isCompleted: false,
    createdAt: timestamp,
    modifiedAt: timestamp,
    location: null,
    deadline: null,
    priority: null,
    startHour: null,
    endDate: null,
    recurrence: null,
    occurrenceOverrides: const {},
  );
}

CalendarCriticalPath _criticalPath() {
  final timestamp = DateTime.utc(2026);
  return CalendarCriticalPath(
    id: 'path-1',
    name: 'Path',
    taskIds: const ['task-1'],
    createdAt: timestamp,
    modifiedAt: timestamp,
  );
}

RoomState _roomState() {
  const roomJid = 'room@conference.axi.im';
  const selfOccupantId = '$roomJid/me';
  return RoomState(
    roomJid: roomJid,
    myOccupantJid: selfOccupantId,
    occupants: <String, Occupant>{
      selfOccupantId: Occupant(
        occupantId: selfOccupantId,
        nick: 'me',
        realJid: 'me@axi.im',
        affiliation: OccupantAffiliation.owner,
        role: OccupantRole.moderator,
      ),
    },
  );
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockProfileCubit extends Mock implements ProfileCubit {}

class _MockRosterCubit extends Mock implements RosterCubit {}

class _MockChatsCubit extends Mock implements ChatsCubit {}

class _MockDraftCubit extends Mock implements DraftCubit {}

class _MockChatBloc extends MockBloc<ChatEvent, ChatState>
    implements ChatBloc {}

class _MockChatSearchCubit extends MockCubit<ChatSearchState>
    implements ChatSearchCubit {}

class _MockBlocklistCubit extends MockCubit<BlocklistState>
    implements BlocklistCubit {}

class _MockFoldersCubit extends MockCubit<FoldersState>
    implements FoldersCubit {}

class _MockCalendarBloc extends MockBloc<CalendarEvent, CalendarState>
    implements CalendarBloc {}

class _MockXmppService extends Mock implements XmppService {}

class _MockEmailService extends Mock implements EmailService {}

class _MockCalendarReminderController extends Mock
    implements CalendarReminderController {}
