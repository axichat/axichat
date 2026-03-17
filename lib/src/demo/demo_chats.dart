// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/xmpp/muc/occupant.dart';
import 'package:axichat/src/xmpp/muc/room_state.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';

class DemoAttachmentAsset {
  const DemoAttachmentAsset({
    required this.id,
    required this.assetPath,
    required this.fileName,
    required this.mimeType,
  });

  final String id;
  final String assetPath;
  final String fileName;
  final String mimeType;
}

class DemoContactAvatar {
  const DemoContactAvatar({required this.assetPath, required this.hash});

  final String assetPath;
  final String hash;
}

class DemoChatScript {
  DemoChatScript({
    required this.chat,
    required List<Message> messages,
    this.roomState,
    this.attachments = const <DemoAttachmentAsset>[],
    this.pinnedMessageStanzaIds = const <String>[],
  }) : messages = List<Message>.of(messages);

  final Chat chat;
  final List<Message> messages;
  final RoomState? roomState;
  final List<DemoAttachmentAsset> attachments;
  final List<String> pinnedMessageStanzaIds;
}

class DemoChats {
  DemoChats._();

  static const String _demoDomain = 'axi.im';
  static const String _demoConferenceDomain = 'conference.$_demoDomain';
  static const String _washingtonJid = 'george@$_demoDomain';
  static const String _jeffersonJid = 'thomas@$_demoDomain';
  static const String _adamsJid = 'john@$_demoDomain';
  static const String _madisonJid = 'james@$_demoDomain';
  static const String _hamiltonJid = 'alex@$_demoDomain';
  static const String _groupJid = 'team@$_demoConferenceDomain';
  static const String contact1Jid = 'noah@outlook.com';

  static const Map<String, DemoContactAvatar> _avatars =
      <String, DemoContactAvatar>{
        kDemoSelfJid: DemoContactAvatar(
          assetPath: 'assets/images/avatars/stem/atom.png',
          hash: 'demo-avatar-franklin',
        ),
        _washingtonJid: DemoContactAvatar(
          assetPath: 'assets/images/avatars/misc/sword.png',
          hash: 'demo-avatar-washington',
        ),
        _jeffersonJid: DemoContactAvatar(
          assetPath: 'assets/images/avatars/music/violin.png',
          hash: 'demo-avatar-jefferson',
        ),
        _adamsJid: DemoContactAvatar(
          assetPath: 'assets/images/avatars/misc/chess.png',
          hash: 'demo-avatar-adams',
        ),
        _madisonJid: DemoContactAvatar(
          assetPath: 'assets/images/avatars/stem/compass.png',
          hash: 'demo-avatar-madison',
        ),
        _hamiltonJid: DemoContactAvatar(
          assetPath: 'assets/images/avatars/music/microphone.png',
          hash: 'demo-avatar-hamilton',
        ),
        _groupJid: DemoContactAvatar(
          assetPath: 'assets/images/avatars/misc/founders_star.png',
          hash: 'demo-avatar-founders',
        ),
      };

  static Map<String, DemoContactAvatar> avatarAssets() =>
      Map<String, DemoContactAvatar>.unmodifiable(_avatars);

  static const DemoAttachmentAsset composerAttachment = DemoAttachmentAsset(
    id: 'demo-abstract14',
    assetPath: 'assets/images/avatars/abstract/abstract14.png',
    fileName: 'abstract14.png',
    mimeType: 'image/png',
  );

  static const DemoAttachmentAsset composerAttachmentAltA = DemoAttachmentAsset(
    id: 'demo-abstract18-composer',
    assetPath: 'assets/images/avatars/abstract/abstract18.png',
    fileName: 'abstract18.png',
    mimeType: 'image/png',
  );

  static const DemoAttachmentAsset composerAttachmentAltB = DemoAttachmentAsset(
    id: 'demo-abstract5-composer',
    assetPath: 'assets/images/avatars/abstract/abstract5.png',
    fileName: 'abstract5.png',
    mimeType: 'image/png',
  );

  static const DemoAttachmentAsset gmailDocAttachment = DemoAttachmentAsset(
    id: 'demo-gmail-doc1',
    assetPath: 'assets/licenses/document.txt',
    fileName: 'document.txt',
    mimeType: 'text/plain',
  );

  static const DemoAttachmentAsset gmailDocAttachment2 = DemoAttachmentAsset(
    id: 'demo-gmail-doc2',
    assetPath: 'assets/licenses/document2.txt',
    fileName: 'document2.txt',
    mimeType: 'text/plain',
  );

  static const DemoAttachmentAsset groupBannerAttachment = DemoAttachmentAsset(
    id: 'demo-group-banner',
    assetPath: 'assets/images/axichat_banner.png',
    fileName: 'axichat_banner.png',
    mimeType: 'image/png',
  );

  static const List<DemoAttachmentAsset> composerAttachments = [
    composerAttachment,
    composerAttachmentAltA,
    composerAttachmentAltB,
  ];

  static String get groupJid => _groupJid;

  static final List<DemoChatScript> _scripts = _buildScripts();

  static List<DemoChatScript> scripts({String? openJid}) => _scripts
      .map(
        (script) => DemoChatScript(
          chat: script.chat.copyWith(open: script.chat.jid == openJid),
          messages: script.messages,
          roomState: script.roomState,
          attachments: List<DemoAttachmentAsset>.of(script.attachments),
          pinnedMessageStanzaIds: List<String>.of(
            script.pinnedMessageStanzaIds,
          ),
        ),
      )
      .toList();

  static String? get defaultOpenJid =>
      _scripts.isNotEmpty ? _scripts.first.chat.jid : null;

  static List<Chat> initialChats({String? openJid}) =>
      scripts(openJid: openJid).map((script) => script.chat).toList();

  static DemoChatScript? scriptFor(String jid) {
    for (final script in scripts()) {
      if (script.chat.jid == jid) {
        return script;
      }
    }
    return null;
  }

  static List<DemoChatScript> _buildScripts() {
    final now = demoNow();
    const washingtonJid = _washingtonJid;
    const jeffersonJid = _jeffersonJid;
    const adamsJid = _adamsJid;
    const madisonJid = _madisonJid;
    const hamiltonJid = _hamiltonJid;
    const groupJid = _groupJid;
    const gmailJid = 'eliot@gmail.com';
    const contact1Jid = DemoChats.contact1Jid;
    const scrollDebugJid = 'scroll-debug@$_demoDomain';

    Chat directChat(String jid, String title, List<Message> messages) => Chat(
      jid: jid,
      title: title,
      type: ChatType.chat,
      contactJid: jid,
      lastChangeTimestamp: messages.first.timestamp!,
      lastMessage: messages.first.body,
    );

    Message message({
      required String stanzaId,
      required String senderJid,
      required String chatJid,
      required String body,
      required DateTime timestamp,
      String? occupantId,
    }) => Message(
      stanzaID: stanzaId,
      senderJid: senderJid,
      chatJid: chatJid,
      body: body,
      timestamp: timestamp,
      occupantID: occupantId,
      acked: true,
      received: true,
      displayed: true,
    );

    Message taskShareMessage({
      required String stanzaId,
      required String senderJid,
      required String chatJid,
      required String body,
      required DateTime timestamp,
      required CalendarTask task,
      String? occupantId,
    }) =>
        message(
          stanzaId: stanzaId,
          senderJid: senderJid,
          chatJid: chatJid,
          body: body,
          timestamp: timestamp,
          occupantId: occupantId,
        ).copyWith(
          pseudoMessageType: PseudoMessageType.calendarTaskIcs,
          pseudoMessageData: CalendarTaskIcsMessage(task: task).toJson(),
        );

    List<Message> scrollDebugMessages() {
      const messageCount = 240;
      return List<Message>.generate(messageCount, (index) {
        final sequence = messageCount - index;
        final isEarliest = sequence == 1;
        final senderJid = index.isEven ? scrollDebugJid : kDemoSelfJid;
        final body = isEarliest
            ? 'Pinned anchor for infinite scroll debugging. This is the earliest message in the demo thread.'
            : 'Infinite scroll debug message $sequence of $messageCount. Keep paging backward until you reach the pinned anchor.';
        return message(
          stanzaId: 'demo-scroll-$sequence',
          senderJid: senderJid,
          chatJid: scrollDebugJid,
          body: body,
          timestamp: now.subtract(Duration(minutes: 2 + (index * 6))),
        );
      });
    }

    final washingtonMessages = [
      message(
        stanzaId: 'demo-washington-4',
        senderJid: kDemoSelfJid,
        chatJid: washingtonJid,
        body: 'Sounds good.',
        timestamp: now.subtract(const Duration(minutes: 8)),
      ),
      message(
        stanzaId: 'demo-washington-3',
        senderJid: washingtonJid,
        chatJid: washingtonJid,
        body:
            'I got home late, so dinner is still on the stove. If you are nearby, can you turn it off for me?',
        timestamp: now.subtract(const Duration(minutes: 14)),
      ),
      message(
        stanzaId: 'demo-washington-2',
        senderJid: washingtonJid,
        chatJid: washingtonJid,
        body: 'Also can you leave the porch light on tonight?',
        timestamp: now.subtract(const Duration(minutes: 17)),
      ),
      message(
        stanzaId: 'demo-washington-1',
        senderJid: kDemoSelfJid,
        chatJid: washingtonJid,
        body: 'Yep, I can handle both.',
        timestamp: now.subtract(const Duration(minutes: 20)),
      ),
    ];

    final jeffersonMessages = [
      message(
        stanzaId: 'demo-jefferson-4',
        senderJid: kDemoSelfJid,
        chatJid: jeffersonJid,
        body: 'Nice one.',
        timestamp: now.subtract(const Duration(minutes: 46)),
      ),
      message(
        stanzaId: 'demo-jefferson-3',
        senderJid: jeffersonJid,
        chatJid: jeffersonJid,
        body: 'I finally fixed that weird rattle in the kitchen drawer.',
        timestamp: now.subtract(const Duration(minutes: 49)),
      ),
      message(
        stanzaId: 'demo-jefferson-2',
        senderJid: kDemoSelfJid,
        chatJid: jeffersonJid,
        body:
            'Try opening and closing it a few times first, then check if it still catches.',
        timestamp: now.subtract(const Duration(minutes: 52)),
      ),
      message(
        stanzaId: 'demo-jefferson-1',
        senderJid: jeffersonJid,
        chatJid: jeffersonJid,
        body: 'Yeah, way smoother now.',
        timestamp: now.subtract(const Duration(minutes: 55)),
      ),
    ];

    final adamsMessages = [
      message(
        stanzaId: 'demo-adams-4',
        senderJid: adamsJid,
        chatJid: adamsJid,
        body: "Great, I'll message everyone in a bit.",
        timestamp: now.subtract(const Duration(minutes: 62)),
      ),
      message(
        stanzaId: 'demo-adams-3',
        senderJid: adamsJid,
        chatJid: adamsJid,
        body: 'Yep that works.',
        timestamp: now.subtract(const Duration(minutes: 64)),
      ),
      message(
        stanzaId: 'demo-adams-2',
        senderJid: kDemoSelfJid,
        chatJid: adamsJid,
        body:
            'Ask them to pick whatever is easiest so nobody has to wait around.',
        timestamp: now.subtract(const Duration(minutes: 66)),
      ),
      message(
        stanzaId: 'demo-adams-1',
        senderJid: adamsJid,
        chatJid: adamsJid,
        body: 'Most of it arrived, but two things are still missing.',
        timestamp: now.subtract(const Duration(minutes: 70)),
      ),
    ];

    final madisonMessages = [
      message(
        stanzaId: 'demo-madison-4',
        senderJid: kDemoSelfJid,
        chatJid: madisonJid,
        body: "Send it over and I'll clean it up tonight.",
        timestamp: now.subtract(const Duration(minutes: 76)),
      ),
      message(
        stanzaId: 'demo-madison-3',
        senderJid: madisonJid,
        chatJid: madisonJid,
        body: "I'm trimming the slow parts so it moves faster.",
        timestamp: now.subtract(const Duration(minutes: 78)),
      ),
      message(
        stanzaId: 'demo-madison-2',
        senderJid: kDemoSelfJid,
        chatJid: madisonJid,
        body: 'Cool, keep it short so it is easy to read on phones.',
        timestamp: now.subtract(const Duration(minutes: 82)),
      ),
      message(
        stanzaId: 'demo-madison-1',
        senderJid: madisonJid,
        chatJid: madisonJid,
        body: 'It feels quick now, but a few lines still overlap.',
        timestamp: now.subtract(const Duration(minutes: 86)),
      ),
    ];

    final hamiltonMessages = [
      message(
        stanzaId: 'demo-hamilton-4',
        senderJid: kDemoSelfJid,
        chatJid: hamiltonJid,
        body: 'We can go for it if the numbers still look right.',
        timestamp: now.subtract(const Duration(minutes: 91)),
      ),
      message(
        stanzaId: 'demo-hamilton-3',
        senderJid: hamiltonJid,
        chatJid: hamiltonJid,
        body: "Cool, I'll double check everything tomorrow.",
        timestamp: now.subtract(const Duration(minutes: 93)),
      ),
      message(
        stanzaId: 'demo-hamilton-2',
        senderJid: kDemoSelfJid,
        chatJid: hamiltonJid,
        body: 'If it all checks out, we can finish it the same day.',
        timestamp: now.subtract(const Duration(minutes: 96)),
      ),
      message(
        stanzaId: 'demo-hamilton-1',
        senderJid: hamiltonJid,
        chatJid: hamiltonJid,
        body: 'Looks fine overall, but the photos are pretty vague.',
        timestamp: now.subtract(const Duration(minutes: 100)),
      ),
    ];

    final roomOccupants = <String, Occupant>{
      '$groupJid/Ben': Occupant(
        occupantId: '$groupJid/Ben',
        nick: 'Ben',
        realJid: kDemoSelfJid,
        affiliation: OccupantAffiliation.owner,
        role: OccupantRole.moderator,
        chatType: ChatType.groupChat,
      ),
      '$groupJid/George': Occupant(
        occupantId: '$groupJid/George',
        nick: 'George',
        realJid: washingtonJid,
        affiliation: OccupantAffiliation.admin,
        role: OccupantRole.participant,
        chatType: ChatType.groupChat,
      ),
      '$groupJid/Thomas': Occupant(
        occupantId: '$groupJid/Thomas',
        nick: 'Thomas',
        realJid: jeffersonJid,
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.participant,
        chatType: ChatType.groupChat,
      ),
      '$groupJid/John': Occupant(
        occupantId: '$groupJid/John',
        nick: 'John',
        realJid: adamsJid,
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.participant,
        chatType: ChatType.groupChat,
      ),
      '$groupJid/James': Occupant(
        occupantId: '$groupJid/James',
        nick: 'James',
        realJid: madisonJid,
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.participant,
        chatType: ChatType.groupChat,
      ),
      '$groupJid/Alex': Occupant(
        occupantId: '$groupJid/Alex',
        nick: 'Alex',
        realJid: hamiltonJid,
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.participant,
        chatType: ChatType.groupChat,
      ),
    };

    final progressTaskTimestamp = now.subtract(const Duration(minutes: 24));
    final progressTask = CalendarTask(
      id: 'demo-group-task-progress',
      title: 'Release hardening backlog',
      createdAt: progressTaskTimestamp,
      modifiedAt: progressTaskTimestamp,
      priority: TaskPriority.critical,
      checklist: const <TaskChecklistItem>[
        TaskChecklistItem(
          id: 'demo-group-task-progress-check-1',
          label: 'Regression sweep',
          isCompleted: true,
        ),
        TaskChecklistItem(
          id: 'demo-group-task-progress-check-2',
          label: 'Crash triage',
          isCompleted: true,
        ),
        TaskChecklistItem(
          id: 'demo-group-task-progress-check-3',
          label: 'QA sign-off prep',
          isCompleted: true,
        ),
        TaskChecklistItem(
          id: 'demo-group-task-progress-check-4',
          label: 'Release notes review',
        ),
        TaskChecklistItem(
          id: 'demo-group-task-progress-check-5',
          label: 'Launch checklist final pass',
        ),
      ],
    );
    final planningTaskTimestamp = now.subtract(const Duration(minutes: 23));
    final planningStart = DateTime(
      now.year,
      now.month,
      now.day,
      18,
      30,
    ).add(const Duration(days: 1));
    final planningTask = CalendarTask(
      id: 'demo-group-task-next-meet',
      title: 'Team rollout sync meeting',
      description: 'Finalize rollout tasks and assignments.',
      scheduledTime: planningStart,
      duration: const Duration(minutes: 45),
      endDate: planningStart.add(const Duration(minutes: 45)),
      location: 'Axi HQ, Room Atlas',
      createdAt: planningTaskTimestamp,
      modifiedAt: planningTaskTimestamp,
      priority: TaskPriority.important,
    );

    final groupMessages = [
      message(
        stanzaId: 'demo-group-6',
        senderJid: '$groupJid/Alex',
        chatJid: groupJid,
        body: "I kicked off the release drill at 4, and it’s still a little flaky.",
        timestamp: now.subtract(const Duration(minutes: 25)),
        occupantId: '$groupJid/Alex',
      ),
      message(
        stanzaId: 'demo-group-5b',
        senderJid: '$groupJid/James',
        chatJid: groupJid,
        body:
            'I can grab the store metadata and screenshots once legal gives us a thumbs-up.',
        timestamp: now.subtract(const Duration(minutes: 26)),
        occupantId: '$groupJid/James',
      ),
      message(
        stanzaId: 'demo-group-5',
        senderJid: '$groupJid/James',
        chatJid: groupJid,
        body:
            'After launch I can keep an eye on logs and take care of the support handoff.',
        timestamp: now.subtract(const Duration(minutes: 27)),
        occupantId: '$groupJid/James',
      ),
      message(
        stanzaId: 'demo-group-4',
        senderJid: '$groupJid/George',
        chatJid: groupJid,
        body:
            'Let’s stop UI polish at 2:30, then lock translations and theme tweaks.',
        timestamp: now.subtract(const Duration(minutes: 29)),
        occupantId: '$groupJid/George',
      ),
      message(
        stanzaId: 'demo-group-3',
        senderJid: '$groupJid/Ben',
        chatJid: groupJid,
        body:
            'I’ll post the launch playbook right after CI gives us the final artifact hash.',
        timestamp: now.subtract(const Duration(minutes: 31)),
        occupantId: '$groupJid/Ben',
      ),
      message(
        stanzaId: 'demo-group-banner-1',
        senderJid: '$groupJid/Thomas',
        chatJid: groupJid,
        body: 'Here\'s the new banner',
        timestamp: now.subtract(const Duration(minutes: 30)),
        occupantId: '$groupJid/Thomas',
      ).copyWith(fileMetadataID: groupBannerAttachment.id),
      message(
        stanzaId: 'demo-group-2',
        senderJid: '$groupJid/John',
        chatJid: groupJid,
        body: 'If CI flakes again, we pause, rerun, then keep moving.',
        timestamp: now.subtract(const Duration(minutes: 33)),
        occupantId: '$groupJid/John',
      ),
      message(
        stanzaId: 'demo-group-1',
        senderJid: '$groupJid/Thomas',
        chatJid: groupJid,
        body: "I put together a launch primer so everyone can see the full status.",
        timestamp: now.subtract(const Duration(minutes: 35)),
        occupantId: '$groupJid/Thomas',
      ),
      taskShareMessage(
        stanzaId: 'demo-group-task-share-1',
        senderJid: '$groupJid/Ben',
        chatJid: groupJid,
        body:
            'Quick check-in: hardening is mostly done, and three deployment checks are still open.',
        timestamp: progressTaskTimestamp,
        occupantId: '$groupJid/Ben',
        task: progressTask,
      ),
      taskShareMessage(
        stanzaId: 'demo-group-task-share-2',
        senderJid: '$groupJid/Ben',
        chatJid: groupJid,
        body:
            'Let’s lock the final rehearsal slot so comms, support, and QA can run it together.',
        timestamp: planningTaskTimestamp,
        occupantId: '$groupJid/Ben',
        task: planningTask,
      ),
    ];

    final latestGroupMessage = groupMessages.fold<Message>(
      groupMessages.first,
      (latest, current) {
        final latestTimestamp = latest.timestamp;
        final currentTimestamp = current.timestamp;
        if (latestTimestamp == null) {
          return current;
        }
        if (currentTimestamp == null) {
          return latest;
        }
        return currentTimestamp.isAfter(latestTimestamp) ? current : latest;
      },
    );
    final groupChat = Chat(
      jid: groupJid,
      title: 'Team',
      type: ChatType.groupChat,
      myNickname: kDemoSelfDisplayName,
      contactJid: groupJid,
      lastChangeTimestamp: latestGroupMessage.timestamp!,
      lastMessage: latestGroupMessage.body,
    );
    final contact1FirstTimestamp = now.subtract(
      const Duration(days: 2, hours: 3),
    );
    final contact1SecondTimestamp = contact1FirstTimestamp.add(
      const Duration(minutes: 49),
    );
    final contact1Messages = [
      message(
        stanzaId: 'demo-contact1-2',
        senderJid: kDemoSelfJid,
        chatJid: contact1Jid,
        body: "Yes, it was nice to meet you. What's up?",
        timestamp: contact1SecondTimestamp,
      ),
      message(
        stanzaId: 'demo-contact1-1',
        senderJid: contact1Jid,
        chatJid: contact1Jid,
        body: 'Hi, is this Ben? We met at the Flutter Conference',
        timestamp: contact1FirstTimestamp,
      ),
    ];
    final scrollMessages = scrollDebugMessages();

    return [
      DemoChatScript(
        chat: directChat(scrollDebugJid, 'Infinite Scroll', scrollMessages),
        messages: scrollMessages,
        pinnedMessageStanzaIds: const ['demo-scroll-1'],
      ),
      DemoChatScript(
        chat: directChat(washingtonJid, 'George', washingtonMessages),
        messages: washingtonMessages,
      ),
      DemoChatScript(
        chat: directChat(jeffersonJid, 'Thomas', jeffersonMessages),
        messages: jeffersonMessages,
      ),
      DemoChatScript(
        chat: directChat(adamsJid, 'John', adamsMessages),
        messages: adamsMessages,
      ),
      DemoChatScript(
        chat: directChat(madisonJid, 'James', madisonMessages),
        messages: madisonMessages,
      ),
      DemoChatScript(
        chat: directChat(hamiltonJid, 'Alex', hamiltonMessages),
        messages: hamiltonMessages,
      ),
      DemoChatScript(
        chat: Chat(
          jid: gmailJid,
          title: gmailJid,
          type: ChatType.chat,
          transport: MessageTransport.email,
          contactJid: gmailJid,
          contactDisplayName: gmailJid,
          emailAddress: gmailJid,
          lastChangeTimestamp: now.subtract(const Duration(minutes: 1)),
          lastMessage: 'Hello, Gmail user',
        ),
        messages: [
          message(
            stanzaId: 'demo-gmail-3',
            senderJid: kDemoSelfJid,
            chatJid: gmailJid,
            body: 'Hello, Gmail user',
            timestamp: now.subtract(const Duration(minutes: 1)),
          ),
          message(
            stanzaId: 'demo-gmail-4',
            senderJid: kDemoSelfJid,
            chatJid: gmailJid,
            body: "Here's the new banner",
            timestamp: now.subtract(const Duration(minutes: 2)),
            occupantId: gmailJid,
          ).copyWith(fileMetadataID: groupBannerAttachment.id),
          message(
            stanzaId: 'demo-gmail-2',
            senderJid: gmailJid,
            chatJid: gmailJid,
            body: 'Adding one more file.',
            timestamp: now.subtract(const Duration(minutes: 3)),
            occupantId: gmailJid,
          ).copyWith(fileMetadataID: gmailDocAttachment2.id),
          message(
            stanzaId: 'demo-gmail-1',
            senderJid: gmailJid,
            chatJid: gmailJid,
            body: 'Here are two documents for you.',
            timestamp: now.subtract(const Duration(minutes: 5)),
            occupantId: gmailJid,
          ).copyWith(fileMetadataID: gmailDocAttachment.id),
        ],
        attachments: const [
          gmailDocAttachment,
          gmailDocAttachment2,
          groupBannerAttachment,
        ],
      ),
      DemoChatScript(
        chat: Chat(
          jid: contact1Jid,
          title: contact1Jid,
          type: ChatType.chat,
          transport: MessageTransport.email,
          contactJid: contact1Jid,
          contactDisplayName: contact1Jid,
          emailAddress: contact1Jid,
          lastChangeTimestamp: contact1Messages.first.timestamp!,
          lastMessage: contact1Messages.first.body,
        ),
        messages: contact1Messages,
        attachments: const [gmailDocAttachment, gmailDocAttachment2],
      ),
      DemoChatScript(
        chat: groupChat,
        messages: groupMessages,
        attachments: const [groupBannerAttachment],
        roomState: RoomState(
          roomJid: groupJid,
          occupants: roomOccupants,
          myOccupantJid: '$groupJid/Ben',
        ),
      ),
    ];
  }
}
