// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_handler/share_handler.dart';

part 'share_intent_models.dart';

class ShareIntentCubit extends Cubit<ShareIntentState> {
  static const int _maxSharedTextLength = 32 * 1024;
  static const int _maxSharedAttachmentCount = 32;
  static const int _maxSharedAttachmentPathLength = 4096;

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
      _subscription = _handler.sharedMediaStream.listen(
        _handleMedia,
        onDone: () {
          _subscription = null;
        },
      );
      final SharedMedia? initial = await _handler.getInitialSharedMedia();
      if (initial != null) {
        final SharePayload? payload = _sanitizePayload(initial);
        if (payload == null) {
          return;
        }
        if (state.payload != null) {
          return;
        }
        emit(ShareIntentState.ready(payload));
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
    final SharePayload? payload = _sanitizePayload(media);
    if (payload == null) {
      return;
    }
    emit(ShareIntentState.ready(payload));
  }

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  SharePayload? _sanitizePayload(SharedMedia media) {
    final String? sanitizedText = _sanitizeSharedText(
      media.content ?? '',
    );
    final List<ShareAttachmentPayload> attachments = _sanitizeSharedAttachments(
      media.attachments,
    );
    if (sanitizedText == null && attachments.isEmpty) {
      return null;
    }
    return SharePayload(text: sanitizedText, attachments: attachments);
  }

  String? _sanitizeSharedText(String text) {
    final String normalized = text.replaceAll('\u0000', '').trim();
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
      if (path.contains('\u0000')) continue;
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
    _subscription = null;
    return super.close();
  }
}
