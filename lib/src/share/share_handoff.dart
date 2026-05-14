// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';

import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/email/service/attachment_optimizer.dart';
import 'package:axichat/src/share/bloc/share_intent_cubit.dart';
import 'package:path/path.dart' as p;

final class ShareComposerSeed {
  ShareComposerSeed({
    required this.id,
    required this.jid,
    required this.body,
    required Iterable<Attachment> attachments,
  }) : attachments = List<Attachment>.unmodifiable(attachments);

  final int id;
  final String jid;
  final String body;
  final List<Attachment> attachments;
}

final class ShareComposerSeedQueue {
  final StreamController<ShareComposerSeed> _controller =
      StreamController<ShareComposerSeed>.broadcast(sync: true);
  final Map<String, List<ShareComposerSeed>> _pendingByJid =
      <String, List<ShareComposerSeed>>{};
  var _nextId = 1;

  Stream<ShareComposerSeed> get stream => _controller.stream;

  ShareComposerSeed enqueue({
    required String jid,
    required String body,
    required Iterable<Attachment> attachments,
  }) {
    final normalizedJid = jid.trim();
    final seed = ShareComposerSeed(
      id: _nextId++,
      jid: normalizedJid,
      body: body,
      attachments: attachments,
    );
    (_pendingByJid[normalizedJid] ??= <ShareComposerSeed>[]).add(seed);
    _controller.add(seed);
    return seed;
  }

  List<ShareComposerSeed> pendingFor(String jid) {
    final pending = _pendingByJid[jid.trim()];
    if (pending == null || pending.isEmpty) {
      return const <ShareComposerSeed>[];
    }
    return List<ShareComposerSeed>.unmodifiable(pending);
  }

  bool take(ShareComposerSeed seed) {
    final pending = _pendingByJid[seed.jid.trim()];
    if (pending == null || pending.isEmpty) {
      return false;
    }
    final index = pending.indexWhere(
      (candidate) => candidate.id == seed.id && candidate.jid == seed.jid,
    );
    if (index == -1) {
      return false;
    }
    pending.removeAt(index);
    if (pending.isEmpty) {
      _pendingByJid.remove(seed.jid);
    }
    return true;
  }

  void dispose() {
    unawaited(_controller.close());
  }
}

Future<List<Attachment>> prepareSharedAttachments({
  required List<ShareAttachmentPayload> attachments,
  required bool optimize,
}) async {
  if (attachments.isEmpty) {
    return const <Attachment>[];
  }
  final prepared = <Attachment>[];
  for (final ShareAttachmentPayload attachment in attachments) {
    final normalizedPath = _normalizeSharedAttachmentPath(attachment.path);
    if (normalizedPath.isEmpty) {
      continue;
    }
    final file = File(normalizedPath);
    final entityType = await FileSystemEntity.type(
      normalizedPath,
      followLinks: false,
    );
    if (entityType != FileSystemEntityType.file || !await file.exists()) {
      continue;
    }
    final fileName = _resolveSharedAttachmentFileName(normalizedPath);
    final sizeBytes = await _resolveSharedAttachmentSizeBytes(file);
    final mimeType = await _resolveSharedAttachmentMimeType(
      fileName: fileName,
      path: normalizedPath,
      attachment: attachment,
    );
    Attachment attachmentValue = Attachment(
      path: normalizedPath,
      fileName: fileName,
      sizeBytes: sizeBytes >= 1 ? sizeBytes : 0,
      mimeType: mimeType,
    );
    if (optimize) {
      attachmentValue = await EmailAttachmentOptimizer.optimize(
        attachmentValue,
      );
    }
    prepared.add(attachmentValue);
  }
  return List<Attachment>.unmodifiable(prepared);
}

String _normalizeSharedAttachmentPath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  if (!trimmed.startsWith('file://')) {
    return trimmed;
  }
  final resolved = Uri.tryParse(trimmed)?.toFilePath();
  if (resolved == null || resolved.isEmpty) {
    return trimmed;
  }
  return resolved;
}

String _resolveSharedAttachmentFileName(String path) {
  final baseName = p.basename(path);
  if (baseName.isNotEmpty) {
    return baseName;
  }
  return path;
}

Future<String> _resolveSharedAttachmentMimeType({
  required String fileName,
  required String path,
  required ShareAttachmentPayload attachment,
}) async {
  final resolvedMimeType = await resolveMimeTypeFromPath(
    path: path,
    fileName: fileName,
    declaredMimeType: attachment.type.mimeTypeFallback,
  );
  return resolvedMimeType ?? attachment.type.mimeTypeFallback;
}

Future<int> _resolveSharedAttachmentSizeBytes(File file) async {
  try {
    return await file.length();
  } on Exception {
    return 0;
  }
}
