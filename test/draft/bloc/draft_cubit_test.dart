// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
import 'package:axichat/src/email/models/fan_out_recipient_status.dart';
import 'package:axichat/src/email/models/fan_out_send_report.dart';
import 'package:axichat/src/email/util/synthetic_forward_html.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../mocks.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.temporaryPath);

  final String temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMessageService messageService;
  late StreamController<List<Draft>> draftsController;

  setUpAll(() {
    registerFallbackValue(<Contact>[]);
    registerFallbackValue(
      const Attachment(path: 'fallback', fileName: 'fallback', sizeBytes: 0),
    );
  });

  setUp(() {
    messageService = MockMessageService();
    draftsController = StreamController<List<Draft>>.broadcast(sync: true);

    when(
      () => messageService.draftsStream(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) => draftsController.stream);
  });

  tearDown(() async {
    await draftsController.close();
  });

  DraftForwardedBlock forwardedBlock({
    DraftForwardedBlockConversionState conversionState =
        DraftForwardedBlockConversionState.originalHtml,
    String? convertedText,
  }) {
    return DraftForwardedBlock(
      blockId: 'forward-block-1',
      sourceMessageId: 'source-message-1',
      senderJid: 'sender@axi.im',
      senderLabel: 'Sender',
      timestamp: DateTime.utc(2026, 3, 11, 8),
      originalSubject: 'Original subject',
      originalPlainText: 'Original text',
      originalHtml: '<p>Original <strong>HTML</strong></p>',
      conversionState: conversionState,
      convertedText: convertedText,
    );
  }

  test(
    'saveDraft keeps the latest streamed items when the draft stream updates during save',
    () async {
      final savedDraft = Draft(
        id: 1,
        jids: const <String>['peer@axi.im'],
        body: 'Hello world',
        subject: 'Subject',
        draftSyncId: 'draft-1',
        draftUpdatedAt: DateTime.utc(2025, 1, 1),
        draftSourceId: 'source-1',
      );
      when(
        () => messageService.saveDraft(
          id: any(named: 'id'),
          jids: any(named: 'jids'),
          body: any(named: 'body'),
          subject: any(named: 'subject'),
          quotingStanzaId: any(named: 'quotingStanzaId'),
          quotingReferenceKind: any(named: 'quotingReferenceKind'),
          attachments: any(named: 'attachments'),
        ),
      ).thenAnswer((_) async {
        draftsController.add([savedDraft]);
        return savedDraft;
      });

      final cubit = DraftCubit(messageService: messageService);
      addTearDown(cubit.close);

      await cubit.saveDraft(
        id: null,
        jids: const <String>['peer@axi.im'],
        body: 'Hello world',
        subject: 'Subject',
      );

      expect(cubit.state, isA<DraftSaveComplete>());
      expect(cubit.state.items, equals([savedDraft]));
      expect(cubit.state.visibleItems, equals([savedDraft]));
    },
  );

  test(
    'sendDraft still succeeds when deleting the saved draft fails',
    () async {
      when(
        () => messageService.sendMessage(
          jid: 'peer@axi.im',
          text: 'hello',
          htmlBody: null,
          encryptionProtocol: EncryptionProtocol.none,
          quotedReference: null,
          calendarTaskIcs: null,
          calendarTaskIcsReadOnly: CalendarTaskIcsMessage.defaultReadOnly,
          chatType: ChatType.chat,
        ),
      ).thenAnswer((_) async {});
      when(() => messageService.loadDraft(1)).thenAnswer((_) async => null);
      when(
        () => messageService.deleteDraft(id: 1),
      ).thenThrow(Exception('delete failed'));

      final cubit = DraftCubit(messageService: messageService);
      addTearDown(cubit.close);

      final outcome = await cubit.sendDraft(
        id: 1,
        xmppTargets: const [
          DraftXmppTarget(
            jid: 'peer@axi.im',
            encryptionProtocol: EncryptionProtocol.none,
            chatType: ChatType.chat,
          ),
        ],
        emailTargets: const [],
        body: 'hello',
        shareTokenSignatureEnabled: false,
      );

      expect(outcome.succeeded, isTrue);
      expect(cubit.state, isA<DraftSendComplete>());
    },
  );

  test('sendDraft rejects snapshots without concrete targets', () async {
    final cubit = DraftCubit(messageService: messageService);
    addTearDown(cubit.close);

    final outcome = await cubit.sendDraft(
      id: 1,
      xmppTargets: const [],
      emailTargets: const [],
      body: 'hello',
      shareTokenSignatureEnabled: false,
    );

    expect(outcome.succeeded, isFalse);
    expect(cubit.state, isA<DraftFailure>());
    verifyNever(() => messageService.deleteDraft(id: 1));
  });

  test(
    'sendDraft sends XMPP before email so mixed retry cannot duplicate email after XMPP failure',
    () async {
      final emailService = MockEmailService();
      when(
        () => messageService.sendMessage(
          jid: 'xmpp@axi.im',
          text: 'hello',
          htmlBody: null,
          encryptionProtocol: EncryptionProtocol.none,
          quotedReference: null,
          calendarTaskIcs: null,
          calendarTaskIcsReadOnly: CalendarTaskIcsMessage.defaultReadOnly,
          chatType: ChatType.chat,
        ),
      ).thenThrow(Exception('xmpp failed'));
      when(
        () => emailService.fanOutSend(
          targets: any(named: 'targets'),
          body: any(named: 'body'),
          htmlBody: any(named: 'htmlBody'),
          attachment: any(named: 'attachment'),
          htmlCaption: any(named: 'htmlCaption'),
          shareId: any(named: 'shareId'),
          subject: any(named: 'subject'),
          quotedStanzaId: any(named: 'quotedStanzaId'),
          useSubjectToken: any(named: 'useSubjectToken'),
          tokenAsSignature: any(named: 'tokenAsSignature'),
        ),
      ).thenAnswer(
        (_) async => const FanOutSendReport(shareId: 'share', statuses: []),
      );
      final cubit = DraftCubit(
        messageService: messageService,
        emailService: emailService,
      );
      addTearDown(cubit.close);

      final outcome = await cubit.sendDraft(
        id: null,
        xmppTargets: const [
          DraftXmppTarget(
            jid: 'xmpp@axi.im',
            encryptionProtocol: EncryptionProtocol.none,
            chatType: ChatType.chat,
          ),
        ],
        emailTargets: [
          Contact.address(address: 'mail@example.com', displayName: 'Mail'),
        ],
        body: 'hello',
        shareTokenSignatureEnabled: false,
      );

      expect(outcome.succeeded, isFalse);
      verifyNever(
        () => emailService.fanOutSend(
          targets: any(named: 'targets'),
          body: any(named: 'body'),
          htmlBody: any(named: 'htmlBody'),
          attachment: any(named: 'attachment'),
          htmlCaption: any(named: 'htmlCaption'),
          shareId: any(named: 'shareId'),
          subject: any(named: 'subject'),
          quotedStanzaId: any(named: 'quotedStanzaId'),
          useSubjectToken: any(named: 'useSubjectToken'),
          tokenAsSignature: any(named: 'tokenAsSignature'),
        ),
      );
      expect(cubit.state, isA<DraftFailure>());
    },
  );

  test(
    'sendDraft reports completed XMPP when later email send fails',
    () async {
      final emailService = MockEmailService();
      when(
        () => messageService.sendMessage(
          jid: 'xmpp@axi.im',
          text: 'hello',
          htmlBody: null,
          encryptionProtocol: EncryptionProtocol.none,
          quotedReference: null,
          calendarTaskIcs: null,
          calendarTaskIcsReadOnly: CalendarTaskIcsMessage.defaultReadOnly,
          chatType: ChatType.chat,
        ),
      ).thenAnswer((_) async {});
      when(
        () => emailService.fanOutSend(
          targets: any(named: 'targets'),
          body: any(named: 'body'),
          htmlBody: any(named: 'htmlBody'),
          attachment: any(named: 'attachment'),
          htmlCaption: any(named: 'htmlCaption'),
          shareId: any(named: 'shareId'),
          subject: any(named: 'subject'),
          quotedStanzaId: any(named: 'quotedStanzaId'),
          useSubjectToken: any(named: 'useSubjectToken'),
          tokenAsSignature: any(named: 'tokenAsSignature'),
        ),
      ).thenThrow(Exception('email failed'));
      final cubit = DraftCubit(
        messageService: messageService,
        emailService: emailService,
      );
      addTearDown(cubit.close);

      final outcome = await cubit.sendDraft(
        id: 1,
        xmppTargets: const [
          DraftXmppTarget(
            jid: 'xmpp@axi.im',
            encryptionProtocol: EncryptionProtocol.none,
            chatType: ChatType.chat,
          ),
        ],
        emailTargets: [
          Contact.address(address: 'mail@example.com', displayName: 'Mail'),
        ],
        body: 'hello',
        shareTokenSignatureEnabled: false,
      );

      expect(outcome.succeeded, isFalse);
      expect(outcome.completedTransports, {DraftSendTransport.xmpp});
      verifyNever(() => messageService.deleteDraft(id: 1));
      expect(cubit.state, isA<DraftFailure>());
    },
  );

  test(
    'sendDraft reports completed email recipients on partial fan-out failure',
    () async {
      final emailService = MockEmailService();
      when(
        () => emailService.fanOutSend(
          targets: any(named: 'targets'),
          body: any(named: 'body'),
          htmlBody: any(named: 'htmlBody'),
          attachment: any(named: 'attachment'),
          htmlCaption: any(named: 'htmlCaption'),
          shareId: any(named: 'shareId'),
          subject: any(named: 'subject'),
          quotedStanzaId: any(named: 'quotedStanzaId'),
          useSubjectToken: any(named: 'useSubjectToken'),
          tokenAsSignature: any(named: 'tokenAsSignature'),
        ),
      ).thenAnswer(
        (_) async => FanOutSendReport(
          shareId: 'share',
          statuses: [
            FanOutRecipientStatus(
              chat: Chat(
                jid: 'a@example.com',
                title: 'A',
                type: ChatType.chat,
                lastChangeTimestamp: DateTime.utc(2026),
              ),
              state: FanOutRecipientState.sent,
            ),
            FanOutRecipientStatus(
              chat: Chat(
                jid: 'b@example.com',
                title: 'B',
                type: ChatType.chat,
                lastChangeTimestamp: DateTime.utc(2026),
              ),
              state: FanOutRecipientState.failed,
            ),
          ],
        ),
      );
      final cubit = DraftCubit(
        messageService: messageService,
        emailService: emailService,
      );
      addTearDown(cubit.close);

      final outcome = await cubit.sendDraft(
        id: 1,
        xmppTargets: const [],
        emailTargets: [
          Contact.address(address: 'a@example.com', displayName: 'A'),
          Contact.address(address: 'b@example.com', displayName: 'B'),
        ],
        body: 'hello',
        shareTokenSignatureEnabled: false,
      );

      expect(outcome.succeeded, isFalse);
      expect(outcome.completedTransports, isEmpty);
      expect(outcome.completedEmailRecipientKeys, contains('a@example.com'));
      expect(
        outcome.latestEmailRecipientStatuses['b@example.com'],
        FanOutRecipientState.failed,
      );
      verifyNever(() => messageService.deleteDraft(id: 1));
      expect(cubit.state, isA<DraftFailure>());
    },
  );

  test(
    'sendDraft completes email recipients only after every email unit succeeds',
    () async {
      final emailService = MockEmailService();
      final tempDir = await Directory.systemTemp.createTemp(
        'axichat-draft-cubit-partial-',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
      addTearDown(() {
        PathProviderPlatform.instance = originalPathProvider;
      });
      final file = File('${tempDir.path}/notes.txt');
      await file.writeAsString('notes', flush: true);
      var callIndex = 0;
      final targetAddressesByCall = <List<String>>[];
      when(
        () => emailService.fanOutSend(
          targets: any(named: 'targets'),
          body: any(named: 'body'),
          htmlBody: any(named: 'htmlBody'),
          attachment: any(named: 'attachment'),
          htmlCaption: any(named: 'htmlCaption'),
          shareId: any(named: 'shareId'),
          subject: any(named: 'subject'),
          quotedStanzaId: any(named: 'quotedStanzaId'),
          useSubjectToken: any(named: 'useSubjectToken'),
          tokenAsSignature: any(named: 'tokenAsSignature'),
        ),
      ).thenAnswer((invocation) async {
        callIndex += 1;
        final targets = invocation.namedArguments[#targets] as List<Contact>;
        final addresses = targets
            .map((target) => target.preferredEmailAddress ?? target.key)
            .toList(growable: false);
        targetAddressesByCall.add(addresses);
        return FanOutSendReport(
          shareId: 'share',
          statuses: addresses
              .map(
                (address) => FanOutRecipientStatus(
                  chat: Chat(
                    jid: address,
                    title: address,
                    type: ChatType.chat,
                    lastChangeTimestamp: DateTime.utc(2026),
                  ),
                  state: callIndex == 1 && address == 'b@example.com'
                      ? FanOutRecipientState.failed
                      : FanOutRecipientState.sent,
                ),
              )
              .toList(growable: false),
        );
      });
      final task = CalendarTask(
        id: 'partial-task',
        title: 'Review launch notes',
        createdAt: DateTime.utc(2026, 3, 11, 8),
        modifiedAt: DateTime.utc(2026, 3, 11, 9),
      );
      final cubit = DraftCubit(
        messageService: messageService,
        emailService: emailService,
      );
      addTearDown(cubit.close);

      final outcome = await cubit.sendDraft(
        id: null,
        xmppTargets: const [],
        emailTargets: [
          Contact.address(address: 'a@example.com', displayName: 'A'),
          Contact.address(address: 'b@example.com', displayName: 'B'),
        ],
        body: 'Please review',
        attachments: [
          Attachment(
            path: file.path,
            fileName: 'notes.txt',
            sizeBytes: await file.length(),
            mimeType: 'text/plain',
          ),
        ],
        calendarTaskIcsMessage: CalendarTaskIcsMessage(
          task: task,
          readOnly: false,
        ),
        shareTokenSignatureEnabled: false,
      );

      expect(outcome.succeeded, isFalse);
      expect(targetAddressesByCall, [
        ['a@example.com', 'b@example.com'],
        ['a@example.com'],
      ]);
      expect(outcome.completedEmailRecipientKeys, contains('a@example.com'));
      expect(
        outcome.completedEmailRecipientKeys,
        isNot(contains('b@example.com')),
      );
      expect(
        outcome.latestEmailRecipientStatuses['b@example.com'],
        FanOutRecipientState.failed,
      );
      expect(cubit.state, isA<DraftFailure>());
    },
  );

  test('sendDraft sends calendar task email attachment separately', () async {
    final emailService = MockEmailService();
    final tempDir = await Directory.systemTemp.createTemp(
      'axichat-draft-cubit-',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    addTearDown(() {
      PathProviderPlatform.instance = originalPathProvider;
    });
    final normalFile = File('${tempDir.path}/notes.txt');
    await normalFile.writeAsString('notes', flush: true);
    final fanOutCalls = <Map<Symbol, dynamic>>[];
    when(
      () => emailService.fanOutSend(
        targets: any(named: 'targets'),
        body: any(named: 'body'),
        htmlBody: any(named: 'htmlBody'),
        attachment: any(named: 'attachment'),
        htmlCaption: any(named: 'htmlCaption'),
        shareId: any(named: 'shareId'),
        subject: any(named: 'subject'),
        quotedStanzaId: any(named: 'quotedStanzaId'),
        useSubjectToken: any(named: 'useSubjectToken'),
        tokenAsSignature: any(named: 'tokenAsSignature'),
      ),
    ).thenAnswer((invocation) async {
      fanOutCalls.add(Map<Symbol, dynamic>.from(invocation.namedArguments));
      return const FanOutSendReport(shareId: 'share', statuses: []);
    });
    final task = CalendarTask(
      id: 'task-email',
      title: 'Review launch notes',
      createdAt: DateTime.utc(2026, 3, 11, 8),
      modifiedAt: DateTime.utc(2026, 3, 11, 9),
    );

    final cubit = DraftCubit(
      messageService: messageService,
      emailService: emailService,
    );
    addTearDown(cubit.close);

    final outcome = await cubit.sendDraft(
      id: null,
      xmppTargets: const [],
      emailTargets: [
        Contact.address(address: 'peer@axi.im', displayName: 'Peer'),
      ],
      body: 'Please review',
      attachments: [
        Attachment(
          path: normalFile.path,
          fileName: 'notes.txt',
          sizeBytes: await normalFile.length(),
          mimeType: 'text/plain',
        ),
      ],
      calendarTaskIcsMessage: CalendarTaskIcsMessage(
        task: task,
        readOnly: false,
      ),
      shareTokenSignatureEnabled: false,
    );

    expect(outcome.succeeded, isTrue);
    final sentAttachments = fanOutCalls
        .map((call) => call[#attachment])
        .whereType<Attachment>()
        .toList(growable: false);
    expect(sentAttachments, hasLength(2));
    expect(sentAttachments.first.fileName, 'notes.txt');
    expect(sentAttachments.first.caption, 'Please review');
    expect(sentAttachments.last.mimeType, 'text/calendar');
    expect(sentAttachments.last.fileName.endsWith('.ics'), isTrue);
    expect(sentAttachments.last.caption, isNull);
    expect(fanOutCalls.first[#htmlCaption], isNull);
    expect(fanOutCalls.last[#htmlCaption], isNull);
    expect(cubit.state, isA<DraftSendComplete>());
  });

  test('sendDraft leaves normal email drafts without generated HTML', () async {
    final emailService = MockEmailService();
    final fanOutCalls = <Map<Symbol, dynamic>>[];
    when(
      () => emailService.fanOutSend(
        targets: any(named: 'targets'),
        body: any(named: 'body'),
        htmlBody: any(named: 'htmlBody'),
        attachment: any(named: 'attachment'),
        htmlCaption: any(named: 'htmlCaption'),
        shareId: any(named: 'shareId'),
        subject: any(named: 'subject'),
        quotedStanzaId: any(named: 'quotedStanzaId'),
        useSubjectToken: any(named: 'useSubjectToken'),
        tokenAsSignature: any(named: 'tokenAsSignature'),
      ),
    ).thenAnswer((invocation) async {
      fanOutCalls.add(Map<Symbol, dynamic>.from(invocation.namedArguments));
      return const FanOutSendReport(shareId: 'share', statuses: []);
    });
    final cubit = DraftCubit(
      messageService: messageService,
      emailService: emailService,
    );
    addTearDown(cubit.close);

    final outcome = await cubit.sendDraft(
      id: null,
      xmppTargets: const [],
      emailTargets: [
        Contact.address(address: 'peer@axi.im', displayName: 'Peer'),
      ],
      body: 'Plain body',
      shareTokenSignatureEnabled: false,
    );

    expect(outcome.succeeded, isTrue);
    expect(fanOutCalls.single[#body], 'Plain body');
    expect(fanOutCalls.single[#htmlBody], isNull);
  });

  test(
    'sendDraft preserves original forwarded HTML while unconverted',
    () async {
      final emailService = MockEmailService();
      final fanOutCalls = <Map<Symbol, dynamic>>[];
      when(
        () => emailService.fanOutSend(
          targets: any(named: 'targets'),
          body: any(named: 'body'),
          htmlBody: any(named: 'htmlBody'),
          attachment: any(named: 'attachment'),
          htmlCaption: any(named: 'htmlCaption'),
          shareId: any(named: 'shareId'),
          subject: any(named: 'subject'),
          quotedStanzaId: any(named: 'quotedStanzaId'),
          useSubjectToken: any(named: 'useSubjectToken'),
          tokenAsSignature: any(named: 'tokenAsSignature'),
        ),
      ).thenAnswer((invocation) async {
        fanOutCalls.add(Map<Symbol, dynamic>.from(invocation.namedArguments));
        return const FanOutSendReport(shareId: 'share', statuses: []);
      });
      final cubit = DraftCubit(
        messageService: messageService,
        emailService: emailService,
      );
      addTearDown(cubit.close);

      final outcome = await cubit.sendDraft(
        id: null,
        xmppTargets: const [],
        emailTargets: [
          Contact.address(address: 'peer@axi.im', displayName: 'Peer'),
        ],
        body: 'Intro note',
        forwardedBlocks: [forwardedBlock()],
        shareTokenSignatureEnabled: false,
      );

      expect(outcome.succeeded, isTrue);
      expect(fanOutCalls, hasLength(1));
      expect(
        fanOutCalls.single[#body],
        allOf(
          contains('Intro note'),
          contains('-------- Forwarded message --------'),
          contains('Original text'),
        ),
      );
      final htmlBody = fanOutCalls.single[#htmlBody] as String?;
      expect(hasSyntheticForwardHtmlMarker(html: htmlBody), isTrue);
      expect(htmlBody, contains('-------- Forwarded message --------'));
      expect(htmlBody, contains('Original <strong>HTML</strong>'));
    },
  );

  test('sendDraft excludes original forwarded HTML after conversion', () async {
    final emailService = MockEmailService();
    final fanOutCalls = <Map<Symbol, dynamic>>[];
    when(
      () => emailService.fanOutSend(
        targets: any(named: 'targets'),
        body: any(named: 'body'),
        htmlBody: any(named: 'htmlBody'),
        attachment: any(named: 'attachment'),
        htmlCaption: any(named: 'htmlCaption'),
        shareId: any(named: 'shareId'),
        subject: any(named: 'subject'),
        quotedStanzaId: any(named: 'quotedStanzaId'),
        useSubjectToken: any(named: 'useSubjectToken'),
        tokenAsSignature: any(named: 'tokenAsSignature'),
      ),
    ).thenAnswer((invocation) async {
      fanOutCalls.add(Map<Symbol, dynamic>.from(invocation.namedArguments));
      return const FanOutSendReport(shareId: 'share', statuses: []);
    });
    final cubit = DraftCubit(
      messageService: messageService,
      emailService: emailService,
    );
    addTearDown(cubit.close);

    final outcome = await cubit.sendDraft(
      id: null,
      xmppTargets: const [],
      emailTargets: [
        Contact.address(address: 'peer@axi.im', displayName: 'Peer'),
      ],
      body: 'Intro note',
      forwardedBlocks: [
        forwardedBlock(
          conversionState: DraftForwardedBlockConversionState.convertedText,
          convertedText: 'Edited forwarded text',
        ),
      ],
      shareTokenSignatureEnabled: false,
    );

    expect(outcome.succeeded, isTrue);
    expect(fanOutCalls, hasLength(1));
    expect(
      fanOutCalls.single[#body],
      allOf(
        contains('Intro note'),
        contains('Edited forwarded text'),
        isNot(contains('Original text')),
      ),
    );
    final htmlBody = fanOutCalls.single[#htmlBody] as String?;
    expect(hasSyntheticForwardHtmlMarker(html: htmlBody), isFalse);
    expect(htmlBody, contains('Edited forwarded text'));
    expect(htmlBody, isNot(contains('Original <strong>HTML</strong>')));
  });

  test(
    'sendDraft does not resurrect original text after converted forward is emptied',
    () async {
      final emailService = MockEmailService();
      final fanOutCalls = <Map<Symbol, dynamic>>[];
      when(
        () => emailService.fanOutSend(
          targets: any(named: 'targets'),
          body: any(named: 'body'),
          htmlBody: any(named: 'htmlBody'),
          attachment: any(named: 'attachment'),
          htmlCaption: any(named: 'htmlCaption'),
          shareId: any(named: 'shareId'),
          subject: any(named: 'subject'),
          quotedStanzaId: any(named: 'quotedStanzaId'),
          useSubjectToken: any(named: 'useSubjectToken'),
          tokenAsSignature: any(named: 'tokenAsSignature'),
        ),
      ).thenAnswer((invocation) async {
        fanOutCalls.add(Map<Symbol, dynamic>.from(invocation.namedArguments));
        return const FanOutSendReport(shareId: 'share', statuses: []);
      });
      final cubit = DraftCubit(
        messageService: messageService,
        emailService: emailService,
      );
      addTearDown(cubit.close);

      final outcome = await cubit.sendDraft(
        id: null,
        xmppTargets: const [],
        emailTargets: [
          Contact.address(address: 'peer@axi.im', displayName: 'Peer'),
        ],
        body: 'Intro note',
        forwardedBlocks: [
          forwardedBlock(
            conversionState: DraftForwardedBlockConversionState.convertedText,
            convertedText: '',
          ),
        ],
        shareTokenSignatureEnabled: false,
      );

      expect(outcome.succeeded, isTrue);
      expect(fanOutCalls.single[#body], 'Intro note');
      expect(fanOutCalls.single[#htmlBody], 'Intro note');
      expect(fanOutCalls.single[#body], isNot(contains('Original text')));
      expect(
        fanOutCalls.single[#htmlBody],
        isNot(contains('Original <strong>HTML</strong>')),
      );
    },
  );

  test(
    'sendDraft sends calendar task payload through XMPP message path',
    () async {
      final task = CalendarTask(
        id: 'task-1',
        title: 'Review launch notes',
        createdAt: DateTime.utc(2026, 3, 11, 8),
        modifiedAt: DateTime.utc(2026, 3, 11, 9),
      );
      when(
        () => messageService.sendMessage(
          jid: 'peer@axi.im',
          text: '',
          encryptionProtocol: EncryptionProtocol.none,
          quotedReference: null,
          calendarTaskIcs: task,
          calendarTaskIcsReadOnly: false,
          chatType: ChatType.chat,
        ),
      ).thenAnswer((_) async {});

      final cubit = DraftCubit(messageService: messageService);
      addTearDown(cubit.close);

      final outcome = await cubit.sendDraft(
        id: null,
        xmppTargets: const [
          DraftXmppTarget(
            jid: 'peer@axi.im',
            encryptionProtocol: EncryptionProtocol.none,
            chatType: ChatType.chat,
          ),
        ],
        emailTargets: const [],
        body: '',
        calendarTaskIcsMessage: CalendarTaskIcsMessage(
          task: task,
          readOnly: false,
        ),
        shareTokenSignatureEnabled: false,
      );

      expect(outcome.succeeded, isTrue);
      verify(
        () => messageService.sendMessage(
          jid: 'peer@axi.im',
          text: '',
          encryptionProtocol: EncryptionProtocol.none,
          quotedReference: null,
          calendarTaskIcs: task,
          calendarTaskIcsReadOnly: false,
          chatType: ChatType.chat,
        ),
      ).called(1);
      expect(cubit.state, isA<DraftSendComplete>());
    },
  );
}
