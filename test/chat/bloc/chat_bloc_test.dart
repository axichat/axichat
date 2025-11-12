import 'dart:async';

import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

Future<void> _pumpBloc() async {
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMessageService messageService;
  late MockChatsService chatsService;
  late MockNotificationService notificationService;

  late StreamController<List<Message>> messageStreamController;
  late StreamController<Chat?> chatStreamController;

  setUpAll(() {
    registerFallbackValue(<FanOutTarget>[]);
  });

  setUp(() {
    messageService = MockMessageService();
    chatsService = MockChatsService();
    notificationService = MockNotificationService();

    messageStreamController = StreamController<List<Message>>.broadcast();
    chatStreamController = StreamController<Chat?>.broadcast();

    when(() => notificationService.dismissNotifications())
        .thenAnswer((_) async {});

    when(
      () => messageService.messageStreamForChat(
        any(),
        start: any(named: 'start'),
        end: any(named: 'end'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) => messageStreamController.stream);

    when(() => chatsService.chatStream(any()))
        .thenAnswer((_) => chatStreamController.stream);

    when(() => chatsService.myJid).thenReturn('self@axi.im');

    when(() => messageService.sendReadMarker(any(), any()))
        .thenAnswer((_) async {});

    when(
      () => chatsService.saveChatTransportPreference(
        jid: any(named: 'jid'),
        transport: any(named: 'transport'),
      ),
    ).thenAnswer((_) async {});
    when(() => chatsService.loadChatTransportPreference(any()))
        .thenAnswer((_) async => MessageTransport.xmpp);
    when(() => chatsService.loadChatViewFilter(any()))
        .thenAnswer((_) async => MessageTimelineFilter.directOnly);
    when(
      () => chatsService.saveChatViewFilter(
        jid: any(named: 'jid'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await messageStreamController.close();
    await chatStreamController.close();
  });

  final initialChat = Chat(
    jid: 'peer@axi.im',
    title: 'peer',
    type: ChatType.chat,
    lastChangeTimestamp: DateTime.now(),
  );

  blocTest<ChatBloc, ChatState>(
    'persists transport change and updates state',
    build: () {
      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        notificationService: notificationService,
      );
      chatStreamController.add(initialChat);
      messageStreamController.add(const <Message>[]);
      return bloc;
    },
    act: (bloc) => bloc.add(const ChatTransportChanged(MessageTransport.email)),
    expect: () => [
      ChatState(items: const <Message>[], chat: initialChat),
    ],
    verify: (_) {
      verify(
        () => chatsService.saveChatTransportPreference(
          jid: initialChat.jid,
          transport: MessageTransport.email,
        ),
      ).called(1);
    },
  );

  test('fan-out send uses EmailService and records report state', () async {
    final emailService = MockEmailService();
    final emailChat = initialChat.copyWith(
      deltaChatId: 1,
      emailAddress: 'peer@example.com',
    );
    final extraChat = Chat(
      jid: 'dc-2@delta.chat',
      title: 'carol',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
      deltaChatId: 2,
      emailAddress: 'carol@example.com',
    );
    final report = FanOutSendReport(
      shareId: 'share-123',
      statuses: [
        FanOutRecipientStatus(
          chat: emailChat,
          state: FanOutRecipientState.sent,
          deltaMsgId: 101,
        ),
        FanOutRecipientStatus(
          chat: extraChat,
          state: FanOutRecipientState.sent,
          deltaMsgId: 102,
        ),
      ],
    );

    when(
      () => emailService.fanOutSend(
        targets: any(named: 'targets'),
        body: any(named: 'body'),
        attachment: any(named: 'attachment'),
        shareId: any(named: 'shareId'),
        useSubjectToken: any(named: 'useSubjectToken'),
      ),
    ).thenAnswer((_) async => report);

    final bloc = ChatBloc(
      jid: emailChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      notificationService: notificationService,
      emailService: emailService,
    );

    messageStreamController.add(const <Message>[]);
    chatStreamController.add(emailChat);
    await _pumpBloc();

    bloc.add(ChatComposerRecipientAdded(FanOutTarget.chat(extraChat)));
    await _pumpBloc();

    bloc.add(const ChatMessageSent(text: 'Team status update'));
    await _pumpBloc();

    final capturedTargets = verify(
      () => emailService.fanOutSend(
        targets: captureAny(named: 'targets'),
        body: 'Team status update',
        attachment: any(named: 'attachment'),
        shareId: any(named: 'shareId'),
        useSubjectToken: any(named: 'useSubjectToken'),
      ),
    ).captured.single as List<FanOutTarget>;

    expect(
      capturedTargets.map((target) => target.key).toSet(),
      {emailChat.jid, extraChat.jid},
    );
    expect(bloc.state.fanOutReports[report.shareId], report);
    expect(
      bloc.state.fanOutDrafts[report.shareId]?.body,
      'Team status update',
    );

    await bloc.close();
  });

  test('prevents send when no recipients are selected', () async {
    final emailService = MockEmailService();
    final emailChat = initialChat.copyWith(
      deltaChatId: 1,
      emailAddress: 'peer@example.com',
    );

    final bloc = ChatBloc(
      jid: emailChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      notificationService: notificationService,
      emailService: emailService,
    );

    messageStreamController.add(const <Message>[]);
    chatStreamController.add(emailChat);
    await _pumpBloc();

    final pinnedKey = bloc.state.recipients.first.key;
    bloc.add(ChatComposerRecipientToggled(pinnedKey));
    await _pumpBloc();

    bloc.add(const ChatMessageSent(text: 'Hello world'));
    await _pumpBloc();

    expect(bloc.state.composerError, 'Select at least one recipient.');
    verifyNever(() => emailService.fanOutSend(
          targets: any(named: 'targets'),
          body: any(named: 'body'),
          attachment: any(named: 'attachment'),
          shareId: any(named: 'shareId'),
          useSubjectToken: any(named: 'useSubjectToken'),
        ));

    await bloc.close();
  });

  test('surface FanOutValidationException messages to the UI', () async {
    final emailService = MockEmailService();
    final emailChat = initialChat.copyWith(
      deltaChatId: 1,
      emailAddress: 'peer@example.com',
    );
    final extraChat = Chat(
      jid: 'dc-2@delta.chat',
      title: 'carol',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
      deltaChatId: 2,
      emailAddress: 'carol@example.com',
    );

    when(
      () => emailService.fanOutSend(
        targets: any(named: 'targets'),
        body: any(named: 'body'),
        attachment: any(named: 'attachment'),
        shareId: any(named: 'shareId'),
        useSubjectToken: any(named: 'useSubjectToken'),
      ),
    ).thenThrow(const FanOutValidationException('Too many recipients.'));

    final bloc = ChatBloc(
      jid: emailChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      notificationService: notificationService,
      emailService: emailService,
    );

    messageStreamController.add(const <Message>[]);
    chatStreamController.add(emailChat);
    await _pumpBloc();

    bloc.add(ChatComposerRecipientAdded(FanOutTarget.chat(extraChat)));
    await _pumpBloc();

    bloc.add(const ChatMessageSent(text: 'Weekly sync'));
    await _pumpBloc();

    expect(bloc.state.composerError, 'Too many recipients.');

    await bloc.close();
  });

  test('retry event replays only failed recipients', () async {
    final emailService = MockEmailService();
    final emailChat = initialChat.copyWith(
      deltaChatId: 1,
      emailAddress: 'peer@example.com',
    );
    final extraChat = Chat(
      jid: 'dc-2@delta.chat',
      title: 'carol',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
      deltaChatId: 2,
      emailAddress: 'carol@example.com',
    );

    final failureReport = FanOutSendReport(
      shareId: 'share-abc',
      statuses: [
        FanOutRecipientStatus(
          chat: emailChat,
          state: FanOutRecipientState.sent,
          deltaMsgId: 101,
        ),
        FanOutRecipientStatus(
          chat: extraChat,
          state: FanOutRecipientState.failed,
        ),
      ],
    );
    final successReport = FanOutSendReport(
      shareId: failureReport.shareId,
      statuses: [
        FanOutRecipientStatus(
          chat: extraChat,
          state: FanOutRecipientState.sent,
          deltaMsgId: 202,
        ),
      ],
    );

    final responses = <FanOutSendReport>[failureReport, successReport];
    final capturedTargets = <List<FanOutTarget>>[];
    final capturedShareIds = <String?>[];
    when(
      () => emailService.fanOutSend(
        targets: any(named: 'targets'),
        body: any(named: 'body'),
        attachment: any(named: 'attachment'),
        shareId: any(named: 'shareId'),
        useSubjectToken: any(named: 'useSubjectToken'),
      ),
    ).thenAnswer((invocation) async {
      capturedTargets.add(
        List<FanOutTarget>.from(invocation.namedArguments[#targets] as List),
      );
      capturedShareIds.add(invocation.namedArguments[#shareId] as String?);
      return responses.removeAt(0);
    });

    final bloc = ChatBloc(
      jid: emailChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      notificationService: notificationService,
      emailService: emailService,
    );

    messageStreamController.add(const <Message>[]);
    chatStreamController.add(emailChat);
    await _pumpBloc();
    bloc.add(ChatComposerRecipientAdded(FanOutTarget.chat(extraChat)));
    await _pumpBloc();

    bloc.add(const ChatMessageSent(text: 'Initial send'));
    await _pumpBloc();

    bloc.add(ChatFanOutRetryRequested(failureReport.shareId));
    await _pumpBloc();

    expect(capturedTargets.length, 2);
    expect(
      capturedTargets[1].map((target) => target.key),
      [extraChat.jid],
    );
    expect(capturedShareIds.every((id) => id == failureReport.shareId), isTrue);

    await bloc.close();
  });

  test('queued attachment sends when composer dispatches send', () async {
    final emailService = MockEmailService();
    final emailChat = initialChat.copyWith(
      deltaChatId: 1,
      emailAddress: 'peer@example.com',
    );
    const attachment = EmailAttachment(
      path: '/tmp/file.txt',
      fileName: 'file.txt',
      sizeBytes: 2048,
      mimeType: 'text/plain',
    );
    final sendCompleter = Completer<void>();
    when(
      () => emailService.sendAttachment(
        chat: any(named: 'chat'),
        attachment: any(named: 'attachment'),
      ),
    ).thenAnswer(
      (_) => sendCompleter.future.then((_) => 1),
    );

    final bloc = ChatBloc(
      jid: emailChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      notificationService: notificationService,
      emailService: emailService,
    );

    messageStreamController.add(const <Message>[]);
    chatStreamController.add(emailChat);
    await _pumpBloc();

    bloc.add(const ChatAttachmentPicked(attachment));
    await _pumpBloc();
    expect(bloc.state.pendingAttachments, hasLength(1));
    var pending = bloc.state.pendingAttachments.single;
    expect(pending.attachment, attachment);
    expect(pending.status, PendingAttachmentStatus.queued);
    verifyNever(
      () => emailService.sendAttachment(
        chat: any(named: 'chat'),
        attachment: any(named: 'attachment'),
      ),
    );

    bloc.add(const ChatMessageSent(text: 'Hello'));
    await _pumpBloc();
    pending = bloc.state.pendingAttachments.single;
    expect(pending.status, PendingAttachmentStatus.uploading);

    sendCompleter.complete();
    await _pumpBloc();
    expect(bloc.state.pendingAttachments, isEmpty);

    await bloc.close();
  });

  test('failed attachment can be retried', () async {
    final emailService = MockEmailService();
    final emailChat = initialChat.copyWith(
      deltaChatId: 1,
      emailAddress: 'peer@example.com',
    );
    const attachment = EmailAttachment(
      path: '/tmp/error.txt',
      fileName: 'error.txt',
      sizeBytes: 512,
      mimeType: 'text/plain',
    );
    var attempts = 0;
    when(
      () => emailService.sendAttachment(
        chat: any(named: 'chat'),
        attachment: any(named: 'attachment'),
      ),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) {
        throw const DeltaSafeException('failed to send');
      }
      return 1;
    });

    final bloc = ChatBloc(
      jid: emailChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      notificationService: notificationService,
      emailService: emailService,
    );

    messageStreamController.add(const <Message>[]);
    chatStreamController.add(emailChat);
    await _pumpBloc();

    bloc.add(const ChatAttachmentPicked(attachment));
    await _pumpBloc();
    expect(
      bloc.state.pendingAttachments.single.status,
      PendingAttachmentStatus.queued,
    );

    bloc.add(const ChatMessageSent(text: ''));
    await _pumpBloc();
    final failed = bloc.state.pendingAttachments.single;
    expect(failed.status, PendingAttachmentStatus.failed);
    expect(failed.errorMessage, isNotEmpty);
    expect(attempts, 1);

    bloc.add(ChatAttachmentRetryRequested(failed.id));
    await _pumpBloc();
    expect(bloc.state.pendingAttachments, isEmpty);
    expect(attempts, 2);

    await bloc.close();
  });
}
