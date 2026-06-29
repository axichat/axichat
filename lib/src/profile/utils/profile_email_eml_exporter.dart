// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:axichat/src/chat/models/rfc_email_group.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/util/email_header_safety.dart';
import 'package:axichat/src/storage/database.dart' show MessageAttachmentData;
import 'package:axichat/src/storage/models.dart';
import 'package:path/path.dart' as p;

const String profileEmailEmlExportTempDirectoryName = 'profile_email_exports';
const int _messageAttachmentLookupBatchSize = 900;
const int _emailContentResolutionConcurrency = 6;

typedef ProfileEmailEmlExportProgressCallback =
    void Function(ProfileEmailEmlExportProgress progress);

class ProfileEmailEmlContent {
  const ProfileEmailEmlContent({
    this.mimeHeaders,
    this.rfc822PlainText,
    this.rfc822HtmlBody,
    this.fullHtml,
    this.bodyUnavailable = false,
    this.warning,
  });

  final String? mimeHeaders;
  final String? rfc822PlainText;
  final String? rfc822HtmlBody;
  final String? fullHtml;
  final bool bodyUnavailable;
  final String? warning;
}

class ProfileEmailEmlExportResult {
  const ProfileEmailEmlExportResult({
    required this.file,
    required this.messageCount,
    this.warnings = const <String>[],
  });

  final File file;
  final int messageCount;
  final List<String> warnings;
}

class ProfileEmailEmlExportProgress {
  const ProfileEmailEmlExportProgress({
    required this.completedItems,
    required this.totalItems,
  });

  final int completedItems;
  final int totalItems;
}

class ProfileEmailEmlExporter {
  const ProfileEmailEmlExporter._();

  static Future<ProfileEmailEmlExportResult> exportMessages({
    required List<Chat> chats,
    required Future<List<Message>> Function(String jid) loadHistory,
    required Future<Map<String, List<MessageAttachmentData>>> Function(
      Iterable<String> messageIds,
    )
    loadMessageAttachmentsForMessages,
    required Future<List<MessageAttachmentData>> Function(
      String transportGroupId,
    )
    loadMessageAttachmentsForGroup,
    required Future<List<FileMetadataData>> Function(Iterable<String> ids)
    loadFileMetadataByIds,
    required Future<ProfileEmailEmlContent> Function(Message message)
    loadEmailContent,
    ProfileEmailEmlExportProgressCallback? onProgress,
    int contentResolutionConcurrency = _emailContentResolutionConcurrency,
  }) async {
    final directory = await appOwnedTemporaryDirectory(
      profileEmailEmlExportTempDirectoryName,
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipFile = File(p.join(directory.path, 'emails-$timestamp.zip'));
    final emlDirectory = Directory(p.join(directory.path, 'emails-$timestamp'));
    final zipEncoder = ZipFileEncoder();
    var zipOpen = false;
    var exportedMessages = 0;
    final warnings = <String>[];

    try {
      await emlDirectory.create(recursive: true);
      final jobs = <_EmailExportJob>[];

      for (final chat in chats) {
        final messages = _messagesForEmailExport(
          chat: chat,
          messages: await loadHistory(chat.jid),
        );
        if (messages.isEmpty) {
          continue;
        }

        final messageIds = messages
            .map((message) => message.id)
            .whereType<String>()
            .where((id) => id.trim().isNotEmpty)
            .toList(growable: false);
        final attachmentsByMessage = <String, List<MessageAttachmentData>>{};
        for (
          var index = 0;
          index < messageIds.length;
          index += _messageAttachmentLookupBatchSize
        ) {
          final end =
              index + _messageAttachmentLookupBatchSize < messageIds.length
              ? index + _messageAttachmentLookupBatchSize
              : messageIds.length;
          attachmentsByMessage.addAll(
            await loadMessageAttachmentsForMessages(
              messageIds.sublist(index, end),
            ),
          );
        }
        final refsByStanzaId = <String, List<_EmailAttachmentRef>>{};
        final metadataIds = <String>{};
        for (final message in messages) {
          var messageAttachments = attachmentsByMessage[message.id] ?? const [];
          final transportGroupId = messageAttachments.isEmpty
              ? null
              : messageAttachments.first.transportGroupId?.trim();
          if (transportGroupId != null && transportGroupId.isNotEmpty) {
            messageAttachments = await loadMessageAttachmentsForGroup(
              transportGroupId,
            );
          }
          final refs = _attachmentRefsForMessage(
            message: message,
            attachments: messageAttachments,
          );
          if (refs.isNotEmpty) {
            refsByStanzaId[message.stanzaID] = refs;
            metadataIds.addAll(refs.map((ref) => ref.fileMetadataId));
          }
        }

        final metadataItems = await loadFileMetadataByIds(metadataIds);
        final metadataById = {
          for (final metadata in metadataItems) metadata.id: metadata,
        };
        final exportItems = _emailExportItemsForMessages(
          messages: messages,
          refsByStanzaId: refsByStanzaId,
        );

        for (final item in exportItems) {
          final itemWarnings = <String>[];
          final attachments = await _attachmentsForExportItem(
            item: item,
            refsByStanzaId: refsByStanzaId,
            metadataById: metadataById,
            warnings: itemWarnings,
          );
          jobs.add(
            _EmailExportJob(
              chat: chat,
              item: item,
              attachments: attachments,
              warnings: itemWarnings,
            ),
          );
        }
      }

      if (jobs.isEmpty) {
        throw const ProfileEmailEmlExportEmptyException();
      }

      onProgress?.call(
        ProfileEmailEmlExportProgress(
          completedItems: 0,
          totalItems: jobs.length,
        ),
      );
      final resolvedJobs = await _resolveEmailExportJobs(
        jobs: jobs,
        contentResolutionConcurrency: contentResolutionConcurrency,
        loadEmailContent: loadEmailContent,
        onProgress: onProgress,
      );

      zipEncoder.create(zipFile.path);
      zipOpen = true;

      for (final resolvedJob in resolvedJobs) {
        warnings.addAll(resolvedJob.warnings);
        final source = resolvedJob.source;
        if (source == null) {
          continue;
        }
        final message = source.message;
        final content = source.content;
        final emlFile = File(
          p.join(
            emlDirectory.path,
            _emlFilename(message, exportedMessages + 1),
          ),
        );
        await _writeEmlFile(
          file: emlFile,
          chat: resolvedJob.job.chat,
          message: message,
          content: content,
          attachments: resolvedJob.job.attachments,
        );
        await zipEncoder.addFile(
          emlFile,
          'messages/${p.basename(emlFile.path)}',
        );
        exportedMessages++;
      }

      if (exportedMessages == 0) {
        if (warnings.isNotEmpty) {
          throw ProfileEmailEmlExportIncompleteException(warnings);
        }
        throw const ProfileEmailEmlExportEmptyException();
      }

      await zipEncoder.close();
      zipOpen = false;
      return ProfileEmailEmlExportResult(
        file: zipFile,
        messageCount: exportedMessages,
        warnings: warnings,
      );
    } catch (_) {
      if (zipOpen) {
        try {
          await zipEncoder.close();
        } on Exception {
          // Keep the original export error.
        }
      }
      try {
        if (await zipFile.exists()) {
          await zipFile.delete();
        }
      } on Exception {
        // Keep the original export error.
      }
      rethrow;
    } finally {
      try {
        if (await emlDirectory.exists()) {
          await emlDirectory.delete(recursive: true);
        }
      } on Exception {
        // Temporary file cleanup is best-effort.
      }
    }
  }
}

Future<List<_ResolvedEmailExportJob>> _resolveEmailExportJobs({
  required List<_EmailExportJob> jobs,
  required int contentResolutionConcurrency,
  required Future<ProfileEmailEmlContent> Function(Message message)
  loadEmailContent,
  required ProfileEmailEmlExportProgressCallback? onProgress,
}) async {
  final results = List<_ResolvedEmailExportJob?>.filled(jobs.length, null);
  var nextIndex = 0;
  var completedItems = 0;
  final workerCount = _boundedWorkerCount(
    requested: contentResolutionConcurrency,
    totalItems: jobs.length,
  );

  Future<void> runWorker() async {
    while (true) {
      final index = nextIndex;
      nextIndex++;
      if (index >= jobs.length) {
        return;
      }
      results[index] = await _resolveEmailExportJob(
        job: jobs[index],
        loadEmailContent: loadEmailContent,
      );
      completedItems++;
      onProgress?.call(
        ProfileEmailEmlExportProgress(
          completedItems: completedItems,
          totalItems: jobs.length,
        ),
      );
    }
  }

  await Future.wait(
    List<Future<void>>.generate(workerCount, (_) => runWorker()),
  );
  return results.cast<_ResolvedEmailExportJob>();
}

int _boundedWorkerCount({required int requested, required int totalItems}) {
  if (totalItems <= 0) {
    return 0;
  }
  if (requested <= 1) {
    return 1;
  }
  return requested < totalItems ? requested : totalItems;
}

Future<_ResolvedEmailExportJob> _resolveEmailExportJob({
  required _EmailExportJob job,
  required Future<ProfileEmailEmlContent> Function(Message message)
  loadEmailContent,
}) async {
  final warnings = List<String>.of(job.warnings);
  if (warnings.isNotEmpty) {
    return _ResolvedEmailExportJob(job: job, warnings: warnings);
  }
  try {
    final source = await _loadEmailContentForExportItem(
      item: job.item,
      attachments: job.attachments,
      loadEmailContent: loadEmailContent,
      addWarning: (message, warning) {
        warnings.add('${message.stanzaID}: $warning');
      },
    );
    return _ResolvedEmailExportJob(
      job: job,
      source: source,
      warnings: warnings,
    );
  } on Exception {
    warnings.add(
      '${job.item.messages.first.stanzaID}: Full email content could not be exported.',
    );
    return _ResolvedEmailExportJob(job: job, warnings: warnings);
  }
}

class ProfileEmailEmlExportEmptyException implements Exception {
  const ProfileEmailEmlExportEmptyException();
}

class ProfileEmailEmlExportIncompleteException implements Exception {
  ProfileEmailEmlExportIncompleteException(Iterable<String> warnings)
    : warnings = List<String>.unmodifiable(warnings);

  final List<String> warnings;

  @override
  String toString() =>
      'ProfileEmailEmlExportIncompleteException: ${warnings.join(' ')}';
}

class _EmailAttachmentRef {
  const _EmailAttachmentRef({
    required this.fileMetadataId,
    required this.sortOrder,
  });

  final String fileMetadataId;
  final int sortOrder;
}

class _EmailExportItem {
  const _EmailExportItem({required this.messages});

  final List<Message> messages;
}

class _EmailExportSource {
  const _EmailExportSource({required this.message, required this.content});

  final Message message;
  final ProfileEmailEmlContent content;
}

class _EmailExportJob {
  const _EmailExportJob({
    required this.chat,
    required this.item,
    required this.attachments,
    required this.warnings,
  });

  final Chat chat;
  final _EmailExportItem item;
  final List<FileMetadataData> attachments;
  final List<String> warnings;
}

class _ResolvedEmailExportJob {
  const _ResolvedEmailExportJob({
    required this.job,
    this.source,
    this.warnings = const <String>[],
  });

  final _EmailExportJob job;
  final _EmailExportSource? source;
  final List<String> warnings;
}

List<Message> _messagesForEmailExport({
  required Chat chat,
  required List<Message> messages,
}) {
  if (messages.isEmpty) {
    return const [];
  }
  return messages
      .where((message) {
        if (message.pseudoMessageType != null) {
          return false;
        }
        if (message.isEmailBacked) {
          return true;
        }
        return chat.defaultTransport.isEmail;
      })
      .toList(growable: false);
}

List<_EmailExportItem> _emailExportItemsForMessages({
  required List<Message> messages,
  required Map<String, List<_EmailAttachmentRef>> refsByStanzaId,
}) {
  final rfcEmailGroupsByStanzaId = buildRfcEmailGroupsByMessageStanzaId(
    messages: messages,
    attachmentsForMessage: (message) =>
        refsByStanzaId[message.stanzaID]
            ?.map((ref) => ref.fileMetadataId)
            .toList(growable: false) ??
        const <String>[],
    bodyTextForMessage: (_) => '',
    requireMeaningfulBody: false,
  );
  final items = <_EmailExportItem>[];
  final renderedRfcEmailGroupKeys = <String>{};
  for (final message in messages) {
    final rfcEmailGroup = rfcEmailGroupsByStanzaId[message.stanzaID];
    final rfcEmailGroupKey = message.emailRfcGroupKey;
    if (rfcEmailGroup != null && rfcEmailGroupKey != null) {
      if (!renderedRfcEmailGroupKeys.add(rfcEmailGroupKey)) {
        continue;
      }
      items.add(_EmailExportItem(messages: rfcEmailGroup.messages));
      continue;
    }
    items.add(_EmailExportItem(messages: [message]));
  }
  return items;
}

List<_EmailAttachmentRef> _attachmentRefsForMessage({
  required Message message,
  required List<MessageAttachmentData> attachments,
}) {
  if (attachments.isEmpty) {
    final fallbackId = message.fileMetadataID?.trim();
    if (fallbackId == null || fallbackId.isEmpty) {
      return const [];
    }
    return <_EmailAttachmentRef>[
      _EmailAttachmentRef(fileMetadataId: fallbackId, sortOrder: 0),
    ];
  }
  final ordered = attachments.toList(growable: false)
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return ordered
      .map(
        (attachment) => _EmailAttachmentRef(
          fileMetadataId: attachment.fileMetadataId,
          sortOrder: attachment.sortOrder,
        ),
      )
      .toList(growable: false);
}

Future<_EmailExportSource?> _loadEmailContentForExportItem({
  required _EmailExportItem item,
  required List<FileMetadataData> attachments,
  required Future<ProfileEmailEmlContent> Function(Message message)
  loadEmailContent,
  required void Function(Message message, String warning) addWarning,
}) async {
  final contentByStanzaId = <String, ProfileEmailEmlContent>{};
  for (final message in item.messages) {
    final content = await loadEmailContent(message);
    contentByStanzaId[message.stanzaID] = content;
  }
  for (final preferBody in const [true, false]) {
    for (final message in item.messages) {
      final content =
          contentByStanzaId[message.stanzaID] ?? const ProfileEmailEmlContent();
      if (_emailContentWarning(content) != null) {
        continue;
      }
      final hasResolvedBody = _hasResolvedBodyContent(message, content);
      if (preferBody != hasResolvedBody) {
        continue;
      }
      if (!_hasCompleteEmailContentForExportItem(
        item: item,
        message: message,
        content: content,
        contentByStanzaId: contentByStanzaId,
        attachments: attachments,
      )) {
        continue;
      }
      if (!_hasExportableEmlContent(message, content, attachments)) {
        continue;
      }
      return _EmailExportSource(message: message, content: content);
    }
  }

  for (final message in item.messages) {
    final content =
        contentByStanzaId[message.stanzaID] ?? const ProfileEmailEmlContent();
    final warning = _emailContentWarning(content);
    if (warning != null) {
      addWarning(message, warning);
    }
  }
  final warningMessage = item.messages.first;
  if (!item.messages.any((message) {
    final content =
        contentByStanzaId[message.stanzaID] ?? const ProfileEmailEmlContent();
    return _hasCompleteEmailContentForExportItem(
      item: item,
      message: message,
      content: content,
      contentByStanzaId: contentByStanzaId,
      attachments: attachments,
    );
  })) {
    addWarning(warningMessage, 'Full email content was not available.');
  }
  if (!item.messages.any((message) {
    final content =
        contentByStanzaId[message.stanzaID] ?? const ProfileEmailEmlContent();
    return _hasExportableEmlContent(message, content, attachments);
  })) {
    addWarning(warningMessage, 'Email has no exportable content.');
  }
  return null;
}

String? _emailContentWarning(ProfileEmailEmlContent content) {
  final warning = content.warning?.trim();
  return warning == null || warning.isEmpty ? null : warning;
}

bool _hasCompleteEmailContentForExportItem({
  required _EmailExportItem item,
  required Message message,
  required ProfileEmailEmlContent content,
  required Map<String, ProfileEmailEmlContent> contentByStanzaId,
  required List<FileMetadataData> attachments,
}) {
  if (!_hasCompleteEmailContent(message, content, attachments)) {
    return false;
  }
  if (item.messages.length == 1 || _hasResolvedBodyContent(message, content)) {
    return true;
  }
  return item.messages.every((candidate) {
    if (!candidate.isEmailBacked) {
      return true;
    }
    final candidateContent =
        contentByStanzaId[candidate.stanzaID] ?? const ProfileEmailEmlContent();
    if (_emailContentWarning(candidateContent) != null) {
      return false;
    }
    return _hasResolvedBodyContent(candidate, candidateContent) ||
        candidate.rfc822BodyContentUnavailable ||
        candidateContent.bodyUnavailable;
  });
}

Future<List<FileMetadataData>> _attachmentsForExportItem({
  required _EmailExportItem item,
  required Map<String, List<_EmailAttachmentRef>> refsByStanzaId,
  required Map<String, FileMetadataData> metadataById,
  required List<String> warnings,
}) async {
  final attachments = <FileMetadataData>[];
  final seenMetadataIds = <String>{};
  for (final message in item.messages) {
    for (final ref in refsByStanzaId[message.stanzaID] ?? const []) {
      if (!seenMetadataIds.add(ref.fileMetadataId)) {
        continue;
      }
      final metadata = metadataById[ref.fileMetadataId];
      if (metadata == null) {
        warnings.add('Missing attachment metadata ${ref.fileMetadataId}.');
        continue;
      }
      final path = metadata.path?.trim();
      if (path == null || path.isEmpty || !await File(path).exists()) {
        warnings.add(
          'Attachment ${metadata.id} file is not available locally.',
        );
        continue;
      }
      attachments.add(metadata);
    }
  }
  return attachments;
}

Future<void> _writeEmlFile({
  required File file,
  required Chat chat,
  required Message message,
  required ProfileEmailEmlContent content,
  required List<FileMetadataData> attachments,
}) async {
  final sink = file.openWrite();
  try {
    final plainText = _resolvedPlainText(message, content);
    final htmlBody = _resolvedHtmlBody(message, content);
    final hasPlain = _hasValue(plainText);
    final hasHtml = _hasValue(htmlBody);
    final hasAttachments = attachments.isNotEmpty;
    final mixedBoundary = _mimeBoundary('mixed', message.stanzaID);
    final alternativeBoundary = _mimeBoundary('alternative', message.stanzaID);

    _writeHeader(
      sink,
      'From',
      _headerFromRaw(content.mimeHeaders, 'from') ??
          _addressHeaderValue(message.senderJid),
    );
    _writeHeader(
      sink,
      'To',
      _headerFromRaw(content.mimeHeaders, 'to') ??
          _addressHeaderValue(_recipientAddress(chat, message)),
    );
    _writeOptionalHeader(sink, 'Cc', _headerFromRaw(content.mimeHeaders, 'cc'));
    _writeHeader(sink, 'Subject', _subjectHeader(message, content.mimeHeaders));
    _writeHeader(
      sink,
      'Date',
      _headerFromRaw(content.mimeHeaders, 'date') ??
          _formatRfc822Date(message.timestamp ?? DateTime.now().toUtc()),
    );
    _writeHeader(
      sink,
      'Message-ID',
      _messageIdHeader(message, content.mimeHeaders),
    );
    _writeLine(sink, 'MIME-Version: 1.0');

    if (hasAttachments) {
      _writeLine(
        sink,
        'Content-Type: multipart/mixed; boundary="$mixedBoundary"',
      );
      _writeBlankLine(sink);
      await _writeBodyPart(
        sink,
        plainText: plainText,
        htmlBody: htmlBody,
        hasPlain: hasPlain,
        hasHtml: hasHtml,
        parentBoundary: mixedBoundary,
        alternativeBoundary: alternativeBoundary,
      );
      for (final attachment in attachments) {
        await _writeAttachmentPart(sink, mixedBoundary, attachment);
      }
      _writeLine(sink, '--$mixedBoundary--');
      return;
    }

    if (hasPlain && hasHtml) {
      _writeLine(
        sink,
        'Content-Type: multipart/alternative; boundary="$alternativeBoundary"',
      );
      _writeBlankLine(sink);
      _writeTextPart(
        sink,
        boundary: alternativeBoundary,
        mimeType: 'text/plain',
        content: plainText!,
      );
      _writeTextPart(
        sink,
        boundary: alternativeBoundary,
        mimeType: 'text/html',
        content: htmlBody!,
      );
      _writeLine(sink, '--$alternativeBoundary--');
      return;
    }

    _writeSingleBody(sink, plainText: plainText, htmlBody: htmlBody);
  } finally {
    await sink.flush();
    await sink.close();
  }
}

Future<void> _writeBodyPart(
  IOSink sink, {
  required String? plainText,
  required String? htmlBody,
  required bool hasPlain,
  required bool hasHtml,
  required String parentBoundary,
  required String alternativeBoundary,
}) async {
  _writeLine(sink, '--$parentBoundary');
  if (hasPlain && hasHtml) {
    _writeLine(
      sink,
      'Content-Type: multipart/alternative; boundary="$alternativeBoundary"',
    );
    _writeBlankLine(sink);
    _writeTextPart(
      sink,
      boundary: alternativeBoundary,
      mimeType: 'text/plain',
      content: plainText!,
    );
    _writeTextPart(
      sink,
      boundary: alternativeBoundary,
      mimeType: 'text/html',
      content: htmlBody!,
    );
    _writeLine(sink, '--$alternativeBoundary--');
    return;
  }
  _writeSingleBody(sink, plainText: plainText, htmlBody: htmlBody);
}

void _writeSingleBody(
  IOSink sink, {
  required String? plainText,
  required String? htmlBody,
}) {
  final body = _hasValue(htmlBody) ? htmlBody! : plainText ?? '';
  final mimeType = _hasValue(htmlBody) ? 'text/html' : 'text/plain';
  _writeLine(sink, 'Content-Type: $mimeType; charset=utf-8');
  _writeLine(sink, 'Content-Transfer-Encoding: base64');
  _writeBlankLine(sink);
  _writeBase64String(sink, body);
}

void _writeTextPart(
  IOSink sink, {
  required String boundary,
  required String mimeType,
  required String content,
}) {
  _writeLine(sink, '--$boundary');
  _writeLine(sink, 'Content-Type: $mimeType; charset=utf-8');
  _writeLine(sink, 'Content-Transfer-Encoding: base64');
  _writeBlankLine(sink);
  _writeBase64String(sink, content);
}

Future<void> _writeAttachmentPart(
  IOSink sink,
  String boundary,
  FileMetadataData metadata,
) async {
  final filename = sanitizeEmailAttachmentFilename(
    metadata.filename,
    fallbackPath: metadata.path,
  );
  final mimeType =
      sanitizeEmailMimeType(metadata.mimeType) ?? 'application/octet-stream';
  final path = metadata.path?.trim();
  if (path == null || path.isEmpty) {
    throw StateError('Attachment ${metadata.id} has no local path.');
  }
  _writeLine(sink, '--$boundary');
  _writeLine(
    sink,
    'Content-Type: $mimeType; name="${_quotedHeaderParam(filename)}"',
  );
  _writeLine(
    sink,
    'Content-Disposition: attachment; filename="${_quotedHeaderParam(filename)}"',
  );
  _writeLine(sink, 'Content-Transfer-Encoding: base64');
  _writeBlankLine(sink);
  await _writeBase64File(sink, File(path));
}

void _writeHeader(IOSink sink, String name, String value) {
  _writeLine(sink, '$name: $value');
}

void _writeOptionalHeader(IOSink sink, String name, String? value) {
  if (value == null || value.trim().isEmpty) {
    return;
  }
  _writeHeader(sink, name, value);
}

void _writeLine(IOSink sink, String line) {
  sink.add(utf8.encode('$line\r\n'));
}

void _writeBlankLine(IOSink sink) {
  _writeLine(sink, '');
}

void _writeBase64String(IOSink sink, String value) {
  _writeWrappedBase64(sink, base64.encode(utf8.encode(value)));
}

Future<void> _writeBase64File(IOSink sink, File file) async {
  var pending = '';
  await for (final chunk in base64.encoder.bind(file.openRead())) {
    pending += chunk;
    while (pending.length >= 76) {
      _writeLine(sink, pending.substring(0, 76));
      pending = pending.substring(76);
    }
  }
  if (pending.isNotEmpty) {
    _writeLine(sink, pending);
  }
}

void _writeWrappedBase64(IOSink sink, String value) {
  for (var index = 0; index < value.length; index += 76) {
    final end = index + 76 > value.length ? value.length : index + 76;
    _writeLine(sink, value.substring(index, end));
  }
}

String? _resolvedPlainText(Message message, ProfileEmailEmlContent content) {
  if (_hasValue(content.rfc822PlainText)) {
    return content.rfc822PlainText;
  }
  if (_canUseStoredBodyForEml(message) && _hasValue(message.body)) {
    return message.body;
  }
  return null;
}

String? _resolvedHtmlBody(Message message, ProfileEmailEmlContent content) {
  if (_hasValue(content.rfc822HtmlBody)) {
    return content.rfc822HtmlBody;
  }
  if (_hasValue(content.fullHtml)) {
    return content.fullHtml;
  }
  if (_canUseStoredBodyForEml(message) && _hasValue(message.htmlBody)) {
    return message.htmlBody;
  }
  return null;
}

bool _canUseStoredBodyForEml(Message message) {
  if (!message.isEmailBacked) {
    return true;
  }
  final deltaMsgId = message.deltaMsgId;
  return message.hasRfc822BodyContent || deltaMsgId == null || deltaMsgId <= 0;
}

bool _hasResolvedBodyContent(Message message, ProfileEmailEmlContent content) {
  return _hasValue(_resolvedPlainText(message, content)) ||
      _hasValue(_resolvedHtmlBody(message, content));
}

bool _hasCompleteEmailContent(
  Message message,
  ProfileEmailEmlContent content,
  List<FileMetadataData> attachments,
) {
  if (!message.isEmailBacked) {
    return true;
  }
  if (_hasValue(content.rfc822PlainText) || _hasValue(content.rfc822HtmlBody)) {
    return true;
  }
  if (_hasValue(content.fullHtml)) {
    return true;
  }
  final deltaMsgId = message.deltaMsgId;
  if ((message.hasRfc822BodyContent || deltaMsgId == null || deltaMsgId <= 0) &&
      (_hasValue(message.body) || _hasValue(message.htmlBody))) {
    return true;
  }
  if ((message.rfc822BodyContentUnavailable || content.bodyUnavailable) &&
      _hasBodylessExportableEmlContent(message, content, attachments)) {
    return true;
  }
  return false;
}

bool _hasBodylessExportableEmlContent(
  Message message,
  ProfileEmailEmlContent content,
  List<FileMetadataData> attachments,
) {
  return _hasValue(message.subject) ||
      _hasValue(_headerFromRaw(content.mimeHeaders, 'subject')) ||
      attachments.isNotEmpty;
}

bool _hasExportableEmlContent(
  Message message,
  ProfileEmailEmlContent content,
  List<FileMetadataData> attachments,
) {
  return _hasValue(_resolvedPlainText(message, content)) ||
      _hasValue(_resolvedHtmlBody(message, content)) ||
      _hasValue(message.subject) ||
      _hasValue(_headerFromRaw(content.mimeHeaders, 'subject')) ||
      attachments.isNotEmpty;
}

String _recipientAddress(Chat chat, Message message) {
  final localAddress = chat.emailFromAddress?.trim();
  final senderIsLocal =
      localAddress != null &&
      localAddress.isNotEmpty &&
      sameNormalizedAddressValue(message.senderJid, localAddress);
  final candidates = senderIsLocal
      ? <String?>[
          chat.emailAddress,
          chat.contactJid,
          chat.jid,
          message.chatJid,
          localAddress,
        ]
      : <String?>[
          localAddress,
          chat.emailAddress,
          chat.contactJid,
          chat.jid,
          message.chatJid,
        ];
  for (final candidate in candidates) {
    final trimmed = candidate?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return 'unknown@example.invalid';
}

String _addressHeaderValue(String value) {
  final sanitized = sanitizeEmailHeaderValue(value);
  return sanitized == null || sanitized.isEmpty
      ? 'unknown@example.invalid'
      : sanitized;
}

String _messageIdHeader(Message message, String? rawHeaders) {
  final rawMessageId = _headerFromRaw(rawHeaders, 'message-id');
  if (rawMessageId != null && rawMessageId.trim().isNotEmpty) {
    return rawMessageId;
  }
  final candidate = <String?>[message.originID, message.stanzaID, message.id]
      .firstWhere(
        (value) => value?.trim().isNotEmpty == true,
        orElse: () => DateTime.now().microsecondsSinceEpoch.toString(),
      )!;
  final normalized = candidate.trim().replaceAll(
    RegExp(r'[^a-zA-Z0-9._%+-]'),
    '.',
  );
  return '<$normalized@axichat.local>';
}

String _subjectHeader(Message message, String? rawHeaders) {
  final subject = message.subject?.trim();
  if (subject != null && subject.isNotEmpty) {
    return _encodedHeaderText(subject);
  }
  final rawSubject = _headerFromRaw(rawHeaders, 'subject');
  if (rawSubject != null && rawSubject.trim().isNotEmpty) {
    return rawSubject;
  }
  return '(no subject)';
}

String? _headerFromRaw(String? rawHeaders, String headerName) {
  final sanitized = sanitizeRawEmailHeaders(rawHeaders);
  if (sanitized == null) {
    return null;
  }
  final target = headerName.toLowerCase();
  final lines = sanitized.split('\n');
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final separator = line.indexOf(':');
    if (separator <= 0) {
      continue;
    }
    final name = line.substring(0, separator).trim().toLowerCase();
    if (name != target) {
      continue;
    }
    var value = line.substring(separator + 1).trim();
    while (index + 1 < lines.length &&
        (lines[index + 1].startsWith(' ') ||
            lines[index + 1].startsWith('\t'))) {
      value = '$value ${lines[index + 1].trim()}';
      index++;
    }
    return sanitizeEmailHeaderValue(value);
  }
  return null;
}

String _encodedHeaderText(String value) {
  final sanitized = sanitizeEmailHeaderValue(value) ?? '';
  if (sanitized.codeUnits.every((unit) => unit >= 32 && unit <= 126)) {
    return sanitized;
  }
  return '=?UTF-8?B?${base64.encode(utf8.encode(sanitized))}?=';
}

String _quotedHeaderParam(String value) =>
    value.replaceAll('\\', r'\\').replaceAll('"', r'\"');

String _mimeBoundary(String label, String seed) {
  final safeSeed = seed.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  final suffix = safeSeed.isEmpty
      ? DateTime.now().microsecondsSinceEpoch.toString()
      : safeSeed;
  return '----=_Axichat_${label}_$suffix';
}

String _emlFilename(Message message, int index) {
  final timestamp = message.timestamp
      ?.toUtc()
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('-', '')
      .replaceAll('.', '')
      .replaceAll('Z', 'z');
  final subject = sanitizeEmailAttachmentFilename(
    message.subject,
    fallbackName: 'message',
  ).replaceAll(' ', '_');
  final id = message.stanzaID.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  final prefix = index.toString().padLeft(6, '0');
  final timestampLabel = timestamp ?? 'undated';
  return '$prefix-$timestampLabel-${subject}_$id.eml';
}

String _formatRfc822Date(DateTime value) {
  final utc = value.toUtc();
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  String two(int number) => number.toString().padLeft(2, '0');
  return '${weekdays[utc.weekday - 1]}, ${two(utc.day)} '
      '${months[utc.month - 1]} ${utc.year} ${two(utc.hour)}:'
      '${two(utc.minute)}:${two(utc.second)} +0000';
}

bool _hasValue(String? value) => value?.trim().isNotEmpty == true;
