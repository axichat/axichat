// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/storage/models.dart';

final class RfcEmailGroup {
  const RfcEmailGroup({
    required this.messages,
    required this.bodySources,
    required this.attachmentIdsByStanzaId,
  });

  final List<Message> messages;
  final List<Message> bodySources;
  final Map<String, List<String>> attachmentIdsByStanzaId;

  Message get leader => bodySources.firstOrNull ?? messages.first;

  Message get quoteTarget =>
      bodySources.where(_hasDeltaMessageId).firstOrNull ??
      messages.where(_hasDeltaMessageId).firstOrNull ??
      leader;

  bool contains(Message message) =>
      messages.any((item) => item.stanzaID == message.stanzaID);

  bool isLeader(Message message) => leader.stanzaID == message.stanzaID;

  bool isBodySource(Message message) =>
      bodySources.any((item) => item.stanzaID == message.stanzaID);

  bool hasAttachments(Message message) =>
      attachmentIdsByStanzaId[message.stanzaID]?.isNotEmpty == true;

  bool get hasAnyAttachments =>
      attachmentIdsByStanzaId.values.any((ids) => ids.isNotEmpty);

  bool shouldHideTimelineMessage(Message message) =>
      !isLeader(message) && isBodySource(message) && !hasAttachments(message);

  bool shouldSuppressTimelineText(Message message) =>
      !isLeader(message) && hasAttachments(message);

  static bool _hasDeltaMessageId(Message message) {
    final deltaMsgId = message.deltaMsgId;
    return deltaMsgId != null && deltaMsgId > 0;
  }
}

Map<String, RfcEmailGroup> buildRfcEmailGroupsByMessageStanzaId({
  required List<Message> messages,
  required List<String> Function(Message message) attachmentsForMessage,
  required bool Function(Message message) hasMeaningfulBody,
  bool requireMeaningfulBody = true,
}) {
  final grouped = <String, List<Message>>{};
  for (final message in messages) {
    final groupKey = rfcEmailGroupKey(message);
    if (groupKey == null) {
      continue;
    }
    grouped.putIfAbsent(groupKey, () => <Message>[]).add(message);
  }
  final byStanzaId = <String, RfcEmailGroup>{};
  for (final messagesInGroup in grouped.values) {
    if (messagesInGroup.length < 2) {
      continue;
    }
    final orderedMessages = _messagesInRfcEmailOrder(messagesInGroup);
    if (!_hasCompatibleRfcEmailSubjects(orderedMessages)) {
      continue;
    }
    final attachmentIdsByStanzaId = <String, List<String>>{};
    for (final message in orderedMessages) {
      final attachmentIds = attachmentsForMessage(message)
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      attachmentIdsByStanzaId[message.stanzaID] = attachmentIds;
    }
    final bodySources = orderedMessages
        .where(hasMeaningfulBody)
        .toList(growable: false);
    if (requireMeaningfulBody && bodySources.isEmpty) {
      continue;
    }
    final group = RfcEmailGroup(
      messages: List<Message>.unmodifiable(orderedMessages),
      bodySources: List<Message>.unmodifiable(bodySources),
      attachmentIdsByStanzaId: Map<String, List<String>>.unmodifiable(
        attachmentIdsByStanzaId,
      ),
    );
    for (final message in orderedMessages) {
      byStanzaId[message.stanzaID] = group;
    }
  }
  return Map<String, RfcEmailGroup>.unmodifiable(byStanzaId);
}

List<Message> _messagesInRfcEmailOrder(List<Message> messages) {
  final indexedMessages = <({int index, Message message})>[];
  for (var index = 0; index < messages.length; index += 1) {
    indexedMessages.add((index: index, message: messages[index]));
  }
  indexedMessages.sort((a, b) {
    final aTimestamp = a.message.timestamp;
    final bTimestamp = b.message.timestamp;
    if (aTimestamp != null && bTimestamp != null) {
      final timestampOrder = aTimestamp.compareTo(bTimestamp);
      if (timestampOrder != 0) {
        return timestampOrder;
      }
    }
    final aDeltaMsgId = a.message.deltaMsgId;
    final bDeltaMsgId = b.message.deltaMsgId;
    if (aDeltaMsgId != null && bDeltaMsgId != null) {
      final deltaOrder = aDeltaMsgId.compareTo(bDeltaMsgId);
      if (deltaOrder != 0) {
        return deltaOrder;
      }
    }
    if (aTimestamp != null && bTimestamp == null) {
      return -1;
    }
    if (aTimestamp == null && bTimestamp != null) {
      return 1;
    }
    return a.index.compareTo(b.index);
  });
  return [for (final indexedMessage in indexedMessages) indexedMessage.message];
}

bool _hasCompatibleRfcEmailSubjects(List<Message> messages) {
  final subjects = <String>{};
  for (final message in messages) {
    final subject = message.subject?.trim().toLowerCase();
    if (subject == null || subject.isEmpty) {
      continue;
    }
    subjects.add(subject);
    if (subjects.length > 1) {
      return false;
    }
  }
  return true;
}

String? rfcEmailGroupKey(Message message) {
  return message.emailRfcGroupKey;
}

String rfcEmailBodyText({
  required Message message,
  required String? resolvedHtmlBody,
}) {
  final body = _plainEmailBodyCandidate(message);
  if (body.isNotEmpty) {
    return body;
  }
  final normalizedHtml = HtmlContentCodec.normalizeHtml(
    resolvedHtmlBody ?? message.htmlBody,
  );
  if (normalizedHtml == null) {
    return '';
  }
  return HtmlContentCodec.toPlainText(normalizedHtml).trim();
}

bool rfcEmailHasMeaningfulBody({
  required Message message,
  required String? resolvedHtmlBody,
}) {
  final body = _plainEmailBodyCandidate(message);
  if (body.isNotEmpty) {
    return true;
  }
  final normalizedHtml = HtmlContentCodec.normalizeHtml(
    resolvedHtmlBody ?? message.htmlBody,
  );
  if (normalizedHtml == null) {
    return false;
  }
  return HtmlContentCodec.toPlainText(normalizedHtml).trim().isNotEmpty;
}

String _plainEmailBodyCandidate(Message message) {
  final split = ChatSubjectCodec.splitEmailBody(
    body: message.body,
    subject: message.subject,
  );
  final subject = split.subject?.trim();
  final body = subject?.isNotEmpty == true
      ? ChatSubjectCodec.stripRepeatedSubject(
          body: split.body,
          subject: subject!,
        )
      : split.body;
  return ChatSubjectCodec.previewBodyText(body).trim();
}
