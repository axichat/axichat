// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/storage/models.dart';

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
  }) : messages = List<Message>.of(messages);

  final Chat chat;
  final List<Message> messages;
  final RoomState? roomState;
  final List<DemoAttachmentAsset> attachments;
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
    }) =>
        Message(
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
        body: 'If all checks out, we can finish it the same day.',
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

    final groupMessages = [
      message(
        stanzaId: 'demo-group-6',
        senderJid: '$groupJid/Alex',
        chatJid: groupJid,
        body: 'If everyone shows up at once, this chat is going to explode.',
        timestamp: now.subtract(const Duration(minutes: 25)),
        occupantId: '$groupJid/Alex',
      ),
      message(
        stanzaId: 'demo-group-5b',
        senderJid: '$groupJid/James',
        chatJid: groupJid,
        body: 'Can someone pin the details so nobody misses them?',
        timestamp: now.subtract(const Duration(minutes: 26)),
        occupantId: '$groupJid/James',
      ),
      message(
        stanzaId: 'demo-group-5',
        senderJid: '$groupJid/James',
        chatJid: groupJid,
        body: 'Let us pick who is doing what before we start.',
        timestamp: now.subtract(const Duration(minutes: 27)),
        occupantId: '$groupJid/James',
      ),
      message(
        stanzaId: 'demo-group-4',
        senderJid: '$groupJid/George',
        chatJid: groupJid,
        body: 'Set a start time and people will show up.',
        timestamp: now.subtract(const Duration(minutes: 29)),
        occupantId: '$groupJid/George',
      ),
      message(
        stanzaId: 'demo-group-3',
        senderJid: '$groupJid/Ben',
        chatJid: groupJid,
        body:
            'Give me five minutes, then I will post a quick recap so anyone joining late can catch up.',
        timestamp: now.subtract(const Duration(minutes: 31)),
        occupantId: '$groupJid/Ben',
      ),
      message(
        stanzaId: 'demo-group-2',
        senderJid: '$groupJid/John',
        chatJid: groupJid,
        body: 'If one step gets missed, everything slows down.',
        timestamp: now.subtract(const Duration(minutes: 33)),
        occupantId: '$groupJid/John',
      ),
      message(
        stanzaId: 'demo-group-1',
        senderJid: '$groupJid/Thomas',
        chatJid: groupJid,
        body: "I'm writing a short note so everyone is on the same page.",
        timestamp: now.subtract(const Duration(minutes: 35)),
        occupantId: '$groupJid/Thomas',
      ),
    ];

    final latestGroupMessage = groupMessages.firstWhere(
      (message) => (message.body ?? '').trim().isNotEmpty,
      orElse: () => groupMessages.first,
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
    final contact1FirstTimestamp =
        now.subtract(const Duration(days: 2, hours: 3));
    final contact1SecondTimestamp =
        contact1FirstTimestamp.add(const Duration(minutes: 49));
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

    return [
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
        attachments: const [gmailDocAttachment, gmailDocAttachment2],
      ),
      DemoChatScript(
        chat: Chat(
          jid: contact1Jid,
          title: contact1Jid,
          type: ChatType.chat,
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
        roomState: RoomState(
          roomJid: groupJid,
          occupants: roomOccupants,
          myOccupantId: '$groupJid/Ben',
        ),
      ),
    ];
  }
}
