// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_handler/share_handler.dart';

part 'share_intent_models.dart';

const int _maxSharedTextLength = 32 * 1024;
const int _maxSharedAttachmentCount = 32;
const int _maxSharedAttachmentPathLength = 4096;
const String _sharedTextNullToken = '\u0000';
const String _sharedAttachmentNullToken = _sharedTextNullToken;
const String _sharedTextEmpty = '';
const String _sharedAttachmentImageMimeType = 'image/*';
const String _sharedAttachmentVideoMimeType = 'video/*';
const String _sharedAttachmentAudioMimeType = 'audio/*';
const String _sharedAttachmentFileMimeType = 'application/octet-stream';

class ShareIntentCubit extends Cubit<ShareIntentState> {
  ShareIntentCubit({ShareHandlerPlatform? handler})
      : _handler = handler ?? ShareHandlerPlatform.instance,
        super(const ShareIntentState.idle());

  final ShareHandlerPlatform _handler;
  StreamSubscription<SharedMedia>? _subscription;

  Future<void> initialize() async {
    if (!_isSupportedPlatform) {
      return;
    }
    if (_subscription != null) {
      return;
    }
    try {
      _subscription = _handler.sharedMediaStream.listen(_handleMedia);
      final initial = await _handler.getInitialSharedMedia();
      if (initial != null) {
        _handleMedia(initial);
      }
    } on PlatformException {
      await _subscription?.cancel();
      _subscription = null;
      // Share handler not available on this platform; ignore.
    }
  }

  Future<void> consume() async {
    if (state.hasPayload) {
      emit(const ShareIntentState.idle());
      await _resetInitialSharedMedia();
    }
  }

  Future<void> _resetInitialSharedMedia() async {
    if (!_isSupportedPlatform) {
      return;
    }
    try {
      await _handler.resetInitialSharedMedia();
    } on PlatformException {
      // Share handler reset not available; ignore.
    }
  }

  void _handleMedia(SharedMedia media) {
    final String? sanitizedText = _sanitizeSharedText(
      media.content ?? _sharedTextEmpty,
    );
    final List<ShareAttachmentPayload> attachments = _sanitizeSharedAttachments(
      media.attachments,
    );
    if (sanitizedText == null && attachments.isEmpty) {
      return;
    }
    emit(
      ShareIntentState.ready(
        SharePayload(text: sanitizedText, attachments: attachments),
      ),
    );
  }

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String? _sanitizeSharedText(String text) {
    final String normalized = text.replaceAll(_sharedTextNullToken, '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.length > _maxSharedTextLength) {
      return null;
    }
    return normalized;
  }

  List<ShareAttachmentPayload> _sanitizeSharedAttachments(
    List<SharedAttachment?>? attachments,
  ) {
    if (attachments == null || attachments.isEmpty) {
      return const <ShareAttachmentPayload>[];
    }
    final Set<String> seenPaths = <String>{};
    final List<ShareAttachmentPayload> sanitized = <ShareAttachmentPayload>[];
    for (final attachment in attachments) {
      if (attachment == null) continue;
      final String path = attachment.path.trim();
      if (path.isEmpty) continue;
      if (path.length > _maxSharedAttachmentPathLength) continue;
      if (path.contains(_sharedAttachmentNullToken)) continue;
      if (!seenPaths.add(path)) continue;
      sanitized.add(ShareAttachmentPayload(path: path, type: attachment.type));
      if (sanitized.length >= _maxSharedAttachmentCount) {
        break;
      }
    }
    return List.unmodifiable(sanitized);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
