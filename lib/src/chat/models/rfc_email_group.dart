// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/synthetic_forward.dart';
import 'package:axichat/src/storage/models.dart';

final class RfcEmailGroup {
  const RfcEmailGroup({
    required this.messages,
    required this.bodySources,
    required this.attachmentIdsByStanzaId,
    required this.duplicateBodyStanzaIds,
  });

  final List<Message> messages;
  final List<Message> bodySources;
  final Map<String, List<String>> attachmentIdsByStanzaId;
  final Set<String> duplicateBodyStanzaIds;

  Message get leader =>
      bodySources.where((message) => !hasAttachments(message)).firstOrNull ??
      _nonGeneratedCaptionMessages
          .where((message) => !hasAttachments(message))
          .firstOrNull ??
      bodySources.firstOrNull ??
      _nonGeneratedCaptionMessages.firstOrNull ??
      messages.first;

  Message get quoteTarget =>
      bodySources.where(_hasDeltaMessageId).firstOrNull ??
      messages.where(_hasDeltaMessageId).firstOrNull ??
      leader;

  bool contains(Message message) =>
      messages.any((item) => item.stanzaID == message.stanzaID);

  bool isLeader(Message message) => leader.stanzaID == message.stanzaID;

  bool isBodySource(Message message) =>
      bodySources.any((item) => item.stanzaID == message.stanzaID);

  bool isDuplicateBodyMessage(Message message) =>
      duplicateBodyStanzaIds.contains(message.stanzaID);

  bool hasAttachments(Message message) =>
      attachmentIdsByStanzaId[message.stanzaID]?.isNotEmpty == true;

  bool get hasAnyAttachments =>
      attachmentIdsByStanzaId.values.any((ids) => ids.isNotEmpty);

  Iterable<Message> get _nonGeneratedCaptionMessages =>
      messages.where((message) => !_isGeneratedAttachmentCaptionOnly(message));

  bool shouldHideTimelineMessage(Message message) =>
      !isLeader(message) &&
      !hasAttachments(message) &&
      (isBodySource(message) ||
          isDuplicateBodyMessage(message) ||
          message.body?.trim().isNotEmpty == true ||
          message.htmlBody?.trim().isNotEmpty == true ||
          _isGeneratedAttachmentCaptionOnly(message));

  bool shouldSuppressTimelineText(Message message) =>
      !isLeader(message) &&
      (hasAttachments(message) || isDuplicateBodyMessage(message));

  static bool _hasDeltaMessageId(Message message) {
    final deltaMsgId = message.deltaMsgId;
    return deltaMsgId != null && deltaMsgId > 0;
  }
}

Map<String, RfcEmailGroup> buildRfcEmailGroupsByMessageStanzaId({
  required List<Message> messages,
  required List<String> Function(Message message) attachmentsForMessage,
  required String Function(Message message) bodyTextForMessage,
  bool Function(Message message)? isAuthoritativeBody,
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
    final candidates = <_RfcEmailBodyCandidate>[];
    final duplicateBodyStanzaIds = <String>{};
    for (final message in orderedMessages) {
      final bodyText = bodyTextForMessage(message);
      final canonicalText = _canonicalRfcEmailBodyText(bodyText);
      if (canonicalText.isEmpty) {
        continue;
      }
      candidates.add(
        _RfcEmailBodyCandidate(
          message: message,
          bodyText: bodyText,
          canonicalText: canonicalText,
          authoritative: isAuthoritativeBody?.call(message) ?? false,
        ),
      );
    }
    final hasAuthoritativeCandidate = candidates.any(
      (candidate) => candidate.authoritative,
    );
    final bodySources = <Message>[];
    final bodyCanonicalTexts = <String>{};
    for (final candidate in candidates) {
      if (hasAuthoritativeCandidate && !candidate.authoritative) {
        duplicateBodyStanzaIds.add(candidate.message.stanzaID);
        continue;
      }
      if (bodyCanonicalTexts.add(candidate.canonicalText)) {
        bodySources.add(candidate.message);
      } else {
        duplicateBodyStanzaIds.add(candidate.message.stanzaID);
      }
    }
    if (requireMeaningfulBody && bodySources.isEmpty) {
      continue;
    }
    final group = RfcEmailGroup(
      messages: List<Message>.unmodifiable(orderedMessages),
      bodySources: List<Message>.unmodifiable(bodySources),
      attachmentIdsByStanzaId: Map<String, List<String>>.unmodifiable(
        attachmentIdsByStanzaId,
      ),
      duplicateBodyStanzaIds: Set<String>.unmodifiable(duplicateBodyStanzaIds),
    );
    for (final message in orderedMessages) {
      byStanzaId[message.stanzaID] = group;
    }
  }
  return Map<String, RfcEmailGroup>.unmodifiable(byStanzaId);
}

String _canonicalRfcEmailBodyText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed.replaceAll(RegExp(r'\s+'), ' ');
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

String? resolvedEmailHtmlBodyForMessage({
  required Message message,
  required Map<int, String> emailFullHtmlByDeltaId,
  bool deriveHtmlIfMissing = true,
}) {
  final deltaMessageId = message.deltaMsgId;
  if (deltaMessageId == null) {
    return message.htmlBody;
  }
  final fullHtml = emailFullHtmlByDeltaId[deltaMessageId];
  if (!message.hasRfc822BodyContent) {
    return fullHtml ?? message.htmlBody;
  }
  if (emailHtmlHasVisibleBodyContent(
    message.htmlBody,
    deriveIfMissing: deriveHtmlIfMissing,
  )) {
    return message.htmlBody;
  }
  return fullHtml;
}

EmailHtmlDerivation? emailHtmlDerivationForBody(
  String? html, {
  bool deriveIfMissing = true,
}) {
  final normalizedHtml = HtmlContentCodec.normalizeHtml(html);
  if (normalizedHtml == null) {
    return null;
  }
  return deriveIfMissing
      ? HtmlContentCodec.emailDerivations(normalizedHtml)
      : HtmlContentCodec.cachedEmailDerivations(normalizedHtml);
}

bool emailHtmlHasVisibleBodyContent(
  String? html, {
  bool deriveIfMissing = true,
}) {
  final derivation = emailHtmlDerivationForBody(
    html,
    deriveIfMissing: deriveIfMissing,
  );
  if (derivation == null) {
    return false;
  }
  return derivation.visibleBodyText.isNotEmpty ||
      derivation.containsRemoteImages;
}

String emailHtmlVisibleBodyText(String? html, {bool deriveIfMissing = true}) {
  final derivation = emailHtmlDerivationForBody(
    html,
    deriveIfMissing: deriveIfMissing,
  );
  if (derivation == null) {
    return '';
  }
  return derivation.visibleBodyText;
}

String rfcEmailBodyText({
  required Message message,
  required String? resolvedHtmlBody,
  bool deriveHtmlIfMissing = true,
}) {
  final body = _plainEmailBodyCandidate(message);
  if (message.hasGeneratedEmailAttachmentCaption &&
      _looksGeneratedEmailAttachmentCaption(body)) {
    return '';
  }
  if (body.isNotEmpty &&
      !(message.hasRfc822BodyContent &&
          HtmlContentCodec.looksLikeCssBodyText(body))) {
    return body;
  }
  final html = resolvedHtmlBody ?? message.htmlBody;
  return emailHtmlVisibleBodyText(html, deriveIfMissing: deriveHtmlIfMissing);
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
  final previewBody = ChatSubjectCodec.previewBodyText(body).trim();
  final forwardedContent = splitForwardedBodyContent(body);
  if (forwardedContent.body.trim().isEmpty) {
    return previewBody;
  }
  final forwardedSubject = forwardedContent.subject?.trim();
  final forwardedBody = forwardedSubject?.isNotEmpty == true
      ? ChatSubjectCodec.stripRepeatedSubject(
          body: forwardedContent.body,
          subject: forwardedSubject!,
        )
      : forwardedContent.body;
  return ChatSubjectCodec.previewBodyText(forwardedBody).trim();
}

bool _looksGeneratedEmailAttachmentCaption(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.startsWith('\u{1F4CE} ')) {
    return true;
  }
  return RegExp(r'^[^\r\n]+\.[^\s./\\]{1,16}\s+\([^)]+\)$').hasMatch(trimmed);
}

bool _isGeneratedAttachmentCaptionOnly(Message message) {
  if (!message.hasGeneratedEmailAttachmentCaption) {
    return false;
  }
  return _looksGeneratedEmailAttachmentCaption(
    _plainEmailBodyCandidate(message),
  );
}

final class _RfcEmailBodyCandidate {
  const _RfcEmailBodyCandidate({
    required this.message,
    required this.bodyText,
    required this.canonicalText,
    required this.authoritative,
  });

  final Message message;
  final String bodyText;
  final String canonicalText;
  final bool authoritative;
}
