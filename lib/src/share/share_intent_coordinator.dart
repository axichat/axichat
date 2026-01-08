// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:collection';

import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:equatable/equatable.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

const int _shareIntentDispatchSeedStart = 0;

class ShareIntentDraftPayload extends Equatable {
  ShareIntentDraftPayload({
    this.text,
    List<EmailAttachment> attachments = const <EmailAttachment>[],
  }) : attachments = List<EmailAttachment>.unmodifiable(attachments);

  final String? text;
  final List<EmailAttachment> attachments;

  bool get hasText => text != null && text!.trim().isNotEmpty;

  bool get hasAttachments => attachments.isNotEmpty;

  bool get isEmpty => !hasText && !hasAttachments;

  @override
  List<Object?> get props => [text, attachments];
}

class ShareIntentDispatch extends Equatable {
  const ShareIntentDispatch({
    required this.id,
    required this.jid,
    required this.normalizedJid,
    required this.payload,
  });

  final int id;
  final String jid;
  final String normalizedJid;
  final ShareIntentDraftPayload payload;

  @override
  List<Object?> get props => [id, jid, normalizedJid, payload];
}

class ShareIntentCoordinator {
  final StreamController<ShareIntentDispatch> _controller =
      StreamController<ShareIntentDispatch>.broadcast();
  final Map<String, Queue<ShareIntentDispatch>> _pendingByJid =
      <String, Queue<ShareIntentDispatch>>{};
  int _nextDispatchId = _shareIntentDispatchSeedStart;

  Stream<ShareIntentDispatch> get stream => _controller.stream;

  static String? normalizeJid(String? raw) {
    final String? trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    try {
      return mox.JID.fromString(trimmed).toBare().toString().toLowerCase();
    } on Exception {
      return trimmed.toLowerCase();
    }
  }

  ShareIntentDispatch? enqueueForChat({
    required String jid,
    required ShareIntentDraftPayload payload,
  }) {
    if (payload.isEmpty) {
      return null;
    }
    final String? normalizedJid = normalizeJid(jid);
    if (normalizedJid == null) {
      return null;
    }
    final dispatch = ShareIntentDispatch(
      id: _nextDispatchId++,
      jid: jid,
      normalizedJid: normalizedJid,
      payload: payload,
    );
    _pendingByJid
        .putIfAbsent(
          normalizedJid,
          () => Queue<ShareIntentDispatch>(),
        )
        .add(dispatch);
    _controller.add(dispatch);
    return dispatch;
  }

  List<ShareIntentDispatch> drainForChat(String jid) {
    final String? normalizedJid = normalizeJid(jid);
    if (normalizedJid == null) {
      return const <ShareIntentDispatch>[];
    }
    final Queue<ShareIntentDispatch>? queue =
        _pendingByJid.remove(normalizedJid);
    if (queue == null || queue.isEmpty) {
      return const <ShareIntentDispatch>[];
    }
    return List<ShareIntentDispatch>.unmodifiable(queue);
  }

  ShareIntentDispatch? consume(int dispatchId) {
    for (final entry in _pendingByJid.entries.toList()) {
      final queue = entry.value;
      ShareIntentDispatch? removed;
      for (final dispatch in queue) {
        if (dispatch.id != dispatchId) {
          continue;
        }
        removed = dispatch;
        break;
      }
      if (removed == null) {
        continue;
      }
      queue.remove(removed);
      if (queue.isEmpty) {
        _pendingByJid.remove(entry.key);
      }
      return removed;
    }
    return null;
  }

  void dispose() {
    _pendingByJid.clear();
    unawaited(_controller.close());
  }
}
