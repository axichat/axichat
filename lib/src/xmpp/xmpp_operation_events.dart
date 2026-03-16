// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:moxxmpp/moxxmpp.dart' as mox;

enum XmppOperationKind {
  pubSubBookmarks,
  pubSubConversations,
  pubSubDrafts,
  pubSubSpam,
  pubSubAddressBlock,
  pubSubAvatarMetadata,
  pubSubFetch,
  mamGlobalSync,
  mamMucSync,
  mamFetch,
  mucCreate,
  mucJoin,
  selfAvatarPublish,
}

enum XmppOperationStage { start, end }

extension XmppOperationStageState on XmppOperationStage {
  bool get isStart => this == XmppOperationStage.start;
  bool get isEnd => this == XmppOperationStage.end;
}

final class XmppOperationEvent extends mox.XmppEvent {
  XmppOperationEvent({
    required this.kind,
    required this.stage,
    this.isSuccess = true,
  });

  final XmppOperationKind kind;
  final XmppOperationStage stage;
  final bool isSuccess;
}
