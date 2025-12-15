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
  const DemoContactAvatar({
    required this.assetPath,
    required this.hash,
  });

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
  static const String _washingtonJid = 'washington@$_demoDomain';
  static const String _jeffersonJid = 'jefferson@$_demoDomain';
  static const String _adamsJid = 'adams@$_demoDomain';
  static const String _madisonJid = 'madison@$_demoDomain';
  static const String _hamiltonJid = 'hamilton@$_demoDomain';
  static const String _groupJid = 'founders@$_demoConferenceDomain';

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
  };

  static Map<String, DemoContactAvatar> avatarAssets() =>
      Map<String, DemoContactAvatar>.unmodifiable(_avatars);

  static const DemoAttachmentAsset groupAttachment = DemoAttachmentAsset(
    id: 'demo-abstract18',
    assetPath: 'assets/images/avatars/abstract/abstract18.png',
    fileName: 'abstract18.png',
    mimeType: 'image/png',
  );

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
    final now = DateTime.now();
    const washingtonJid = _washingtonJid;
    const jeffersonJid = _jeffersonJid;
    const adamsJid = _adamsJid;
    const madisonJid = _madisonJid;
    const hamiltonJid = _hamiltonJid;
    const groupJid = _groupJid;
    const gmailJid = 'eliot@gmail.com';

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
        body: 'On it.',
        timestamp: now.subtract(const Duration(minutes: 8)),
      ),
      message(
        stanzaId: 'demo-washington-3',
        senderJid: washingtonJid,
        chatJid: washingtonJid,
        body:
            'French powder ships leave soon; keep your lines steady while we hold the river posts tight until they land.',
        timestamp: now.subtract(const Duration(minutes: 14)),
      ),
      message(
        stanzaId: 'demo-washington-2',
        senderJid: washingtonJid,
        chatJid: washingtonJid,
        body: 'The winter camp strains the army. Can you secure more supplies?',
        timestamp: now.subtract(const Duration(minutes: 17)),
      ),
      message(
        stanzaId: 'demo-washington-1',
        senderJid: kDemoSelfJid,
        chatJid: washingtonJid,
        body: 'Working Paris for muskets and powder now.',
        timestamp: now.subtract(const Duration(minutes: 20)),
      ),
    ];

    final jeffersonMessages = [
      message(
        stanzaId: 'demo-jefferson-4',
        senderJid: kDemoSelfJid,
        chatJid: jeffersonJid,
        body: 'Looks good.',
        timestamp: now.subtract(const Duration(minutes: 46)),
      ),
      message(
        stanzaId: 'demo-jefferson-3',
        senderJid: jeffersonJid,
        chatJid: jeffersonJid,
        body: 'Adjusting grievances order before committee meets.',
        timestamp: now.subtract(const Duration(minutes: 49)),
      ),
      message(
        stanzaId: 'demo-jefferson-2',
        senderJid: kDemoSelfJid,
        chatJid: jeffersonJid,
        body:
            'The tone is bold; consider tightening the grievances sequence so the close lands harder.',
        timestamp: now.subtract(const Duration(minutes: 52)),
      ),
      message(
        stanzaId: 'demo-jefferson-1',
        senderJid: jeffersonJid,
        chatJid: jeffersonJid,
        body: 'Preamble centers natural rights. Thoughts?',
        timestamp: now.subtract(const Duration(minutes: 55)),
      ),
    ];

    final adamsMessages = [
      message(
        stanzaId: 'demo-adams-4',
        senderJid: adamsJid,
        chatJid: adamsJid,
        body: 'Good. I will press the hesitant delegations.',
        timestamp: now.subtract(const Duration(minutes: 62)),
      ),
      message(
        stanzaId: 'demo-adams-3',
        senderJid: adamsJid,
        chatJid: adamsJid,
        body: 'We move quickly.',
        timestamp: now.subtract(const Duration(minutes: 64)),
      ),
      message(
        stanzaId: 'demo-adams-2',
        senderJid: kDemoSelfJid,
        chatJid: adamsJid,
        body: 'Tell them a unified procurement will keep New England supplied.',
        timestamp: now.subtract(const Duration(minutes: 66)),
      ),
      message(
        stanzaId: 'demo-adams-1',
        senderJid: adamsJid,
        chatJid: adamsJid,
        body:
            'Militias are eager but fear losing stores if Congress delays aid.',
        timestamp: now.subtract(const Duration(minutes: 70)),
      ),
    ];

    final madisonMessages = [
      message(
        stanzaId: 'demo-madison-4',
        senderJid: kDemoSelfJid,
        chatJid: madisonJid,
        body:
            'Send me the outline; I will annotate margins tonight and return it.',
        timestamp: now.subtract(const Duration(minutes: 76)),
      ),
      message(
        stanzaId: 'demo-madison-3',
        senderJid: madisonJid,
        chatJid: madisonJid,
        body: 'Drafting notes on representation to circulate quietly.',
        timestamp: now.subtract(const Duration(minutes: 78)),
      ),
      message(
        stanzaId: 'demo-madison-2',
        senderJid: kDemoSelfJid,
        chatJid: madisonJid,
        body:
            'Agreed. Independence must rest on a compact sturdy enough to last.',
        timestamp: now.subtract(const Duration(minutes: 82)),
      ),
      message(
        stanzaId: 'demo-madison-1',
        senderJid: madisonJid,
        chatJid: madisonJid,
        body: 'We need unity now, but a workable union after victory.',
        timestamp: now.subtract(const Duration(minutes: 86)),
      ),
    ];

    final hamiltonMessages = [
      message(
        stanzaId: 'demo-hamilton-4',
        senderJid: kDemoSelfJid,
        chatJid: hamiltonJid,
        body:
            'We can float a short loan if New York pledges customs. Keep them moving.',
        timestamp: now.subtract(const Duration(minutes: 91)),
      ),
      message(
        stanzaId: 'demo-hamilton-3',
        senderJid: hamiltonJid,
        chatJid: hamiltonJid,
        body: 'Then we must secure the ports quickly.',
        timestamp: now.subtract(const Duration(minutes: 93)),
      ),
      message(
        stanzaId: 'demo-hamilton-2',
        senderJid: kDemoSelfJid,
        chatJid: hamiltonJid,
        body: 'French loans can steady us, paired with reliable customs soon.',
        timestamp: now.subtract(const Duration(minutes: 96)),
      ),
      message(
        stanzaId: 'demo-hamilton-1',
        senderJid: hamiltonJid,
        chatJid: hamiltonJid,
        body: 'Army finance is threadbare; credit dries faster each week.',
        timestamp: now.subtract(const Duration(minutes: 100)),
      ),
    ];

    final roomOccupants = <String, Occupant>{
      '$groupJid/Franklin': Occupant(
        occupantId: '$groupJid/Franklin',
        nick: 'Franklin',
        realJid: kDemoSelfJid,
        affiliation: OccupantAffiliation.owner,
        role: OccupantRole.moderator,
        chatType: ChatType.groupChat,
      ),
      '$groupJid/Washington': Occupant(
        occupantId: '$groupJid/Washington',
        nick: 'Washington',
        realJid: washingtonJid,
        affiliation: OccupantAffiliation.admin,
        role: OccupantRole.participant,
        chatType: ChatType.groupChat,
      ),
      '$groupJid/Jefferson': Occupant(
        occupantId: '$groupJid/Jefferson',
        nick: 'Jefferson',
        realJid: jeffersonJid,
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.participant,
        chatType: ChatType.groupChat,
      ),
      '$groupJid/Adams': Occupant(
        occupantId: '$groupJid/Adams',
        nick: 'Adams',
        realJid: adamsJid,
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.participant,
        chatType: ChatType.groupChat,
      ),
      '$groupJid/Madison': Occupant(
        occupantId: '$groupJid/Madison',
        nick: 'Madison',
        realJid: madisonJid,
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.participant,
        chatType: ChatType.groupChat,
      ),
      '$groupJid/Hamilton': Occupant(
        occupantId: '$groupJid/Hamilton',
        nick: 'Hamilton',
        realJid: hamiltonJid,
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.participant,
        chatType: ChatType.groupChat,
      ),
    };

    final groupMessages = [
      Message(
        stanzaID: 'demo-group-7',
        senderJid: '$groupJid/Franklin',
        chatJid: groupJid,
        body: '',
        timestamp: now.subtract(const Duration(minutes: 2)),
        occupantID: '$groupJid/Franklin',
        acked: true,
        received: true,
        displayed: true,
        fileMetadataID: groupAttachment.id,
      ),
      message(
        stanzaId: 'demo-group-6',
        senderJid: '$groupJid/Hamilton',
        chatJid: groupJid,
        body:
            'Creditors will watch; independence must come with a revenue plan.',
        timestamp: now.subtract(const Duration(minutes: 25)),
        occupantId: '$groupJid/Hamilton',
      ),
      message(
        stanzaId: 'demo-group-5b',
        senderJid: '$groupJid/Madison',
        chatJid: groupJid,
        body:
            'Also: whoever drafts the instructions should leave room for amendments later.',
        timestamp: now.subtract(const Duration(minutes: 26)),
        occupantId: '$groupJid/Madison',
      ),
      message(
        stanzaId: 'demo-group-5',
        senderJid: '$groupJid/Madison',
        chatJid: groupJid,
        body: 'States must pledge stores once we adopt the declaration.',
        timestamp: now.subtract(const Duration(minutes: 27)),
        occupantId: '$groupJid/Madison',
      ),
      message(
        stanzaId: 'demo-group-4',
        senderJid: '$groupJid/Washington',
        chatJid: groupJid,
        body: 'Declare it, and the army will defend it.',
        timestamp: now.subtract(const Duration(minutes: 29)),
        occupantId: '$groupJid/Washington',
      ),
      message(
        stanzaId: 'demo-group-3',
        senderJid: '$groupJid/Franklin',
        chatJid: groupJid,
        body:
            'Let the words sing; we must all hang together after we sign, and a clean preamble will steady wavering hands.',
        timestamp: now.subtract(const Duration(minutes: 31)),
        occupantId: '$groupJid/Franklin',
      ),
      message(
        stanzaId: 'demo-group-2',
        senderJid: '$groupJid/Adams',
        chatJid: groupJid,
        body: 'We need every colony behind this or it fractures.',
        timestamp: now.subtract(const Duration(minutes: 33)),
        occupantId: '$groupJid/Adams',
      ),
      message(
        stanzaId: 'demo-group-1',
        senderJid: '$groupJid/Jefferson',
        chatJid: groupJid,
        body: 'Drafting the opening on equal rights now.',
        timestamp: now.subtract(const Duration(minutes: 35)),
        occupantId: '$groupJid/Jefferson',
      ),
    ];

    final groupChat = Chat(
      jid: groupJid,
      title: 'Founders',
      type: ChatType.groupChat,
      myNickname: kDemoSelfDisplayName,
      contactJid: groupJid,
      lastChangeTimestamp: groupMessages.first.timestamp!,
      lastMessage: groupMessages.first.body,
    );

    return [
      DemoChatScript(
        chat: directChat(
          washingtonJid,
          'Washington',
          washingtonMessages,
        ),
        messages: washingtonMessages,
      ),
      DemoChatScript(
        chat: directChat(
          jeffersonJid,
          'Jefferson',
          jeffersonMessages,
        ),
        messages: jeffersonMessages,
      ),
      DemoChatScript(
        chat: directChat(
          adamsJid,
          'Adams',
          adamsMessages,
        ),
        messages: adamsMessages,
      ),
      DemoChatScript(
        chat: directChat(
          madisonJid,
          'Madison',
          madisonMessages,
        ),
        messages: madisonMessages,
      ),
      DemoChatScript(
        chat: directChat(
          hamiltonJid,
          'Hamilton',
          hamiltonMessages,
        ),
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
        attachments: const [
          gmailDocAttachment,
          gmailDocAttachment2,
        ],
      ),
      DemoChatScript(
        chat: groupChat,
        messages: groupMessages,
        attachments: const [groupAttachment],
        roomState: RoomState(
          roomJid: groupJid,
          occupants: roomOccupants,
          myOccupantId: '$groupJid/Franklin',
        ),
      ),
    ];
  }
}
