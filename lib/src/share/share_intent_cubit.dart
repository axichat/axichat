import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_handler/share_handler.dart';

class SharePayload {
  const SharePayload({required this.text});

  final String text;
}

class ShareIntentState {
  const ShareIntentState._(this.payload);

  const ShareIntentState.idle() : this._(null);

  const ShareIntentState.ready(SharePayload payload) : this._(payload);

  final SharePayload? payload;

  bool get hasPayload => payload != null;
}

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
    try {
      final initial = await _handler.getInitialSharedMedia();
      if (initial != null) {
        _handleMedia(initial);
      }
      _subscription = _handler.sharedMediaStream.listen(_handleMedia);
    } on PlatformException {
      // Share handler not available on this platform; ignore.
    }
  }

  void consume() {
    if (state.hasPayload) {
      emit(const ShareIntentState.idle());
    }
  }

  void _handleMedia(SharedMedia media) {
    final text = media.content?.trim();
    if (text == null || text.isEmpty) {
      return;
    }
    emit(ShareIntentState.ready(SharePayload(text: text)));
  }

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
