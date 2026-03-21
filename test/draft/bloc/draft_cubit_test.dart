// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  late MockMessageService messageService;
  late StreamController<List<Draft>> draftsController;

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
}
