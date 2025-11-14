import 'dart:async';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';

class ChatTransportCubit extends Cubit<MessageTransport> {
  ChatTransportCubit({
    required ChatsService chatsService,
    required this.jid,
  })  : _chatsService = chatsService,
        super(MessageTransport.xmpp) {
    _initialize();
  }

  final ChatsService _chatsService;
  final String jid;
  MessageTransport _defaultTransport = MessageTransport.xmpp;
  MessageTransport? _explicitTransport;
  StreamSubscription<Chat?>? _chatSubscription;
  StreamSubscription<MessageTransport?>? _preferenceSubscription;

  Future<void> _initialize() async {
    try {
      final preference = await _chatsService.loadChatTransportPreference(jid);
      _defaultTransport = preference.defaultTransport;
      _explicitTransport = preference.isExplicit ? preference.transport : null;
      _emitCurrent();
    } on Exception {
      // Ignore load failures; fall back to defaults.
    }
    _chatSubscription = _chatsService.chatStream(jid).listen(
      (chat) {
        final nextDefault = chat?.defaultTransport ?? MessageTransport.xmpp;
        if (_defaultTransport != nextDefault) {
          _defaultTransport = nextDefault;
          _emitCurrent();
        }
      },
      onError: (_) {},
    );
    _preferenceSubscription =
        _chatsService.watchChatTransportPreference(jid).listen(
      (transport) {
        if (_explicitTransport == transport) return;
        _explicitTransport = transport;
        _emitCurrent();
      },
      onError: (_) {},
    );
  }

  MessageTransport get _currentTransport =>
      _explicitTransport ?? _defaultTransport;

  void _emitCurrent() {
    if (isClosed) return;
    final next = _currentTransport;
    if (state != next) emit(next);
  }

  @override
  Future<void> close() async {
    await _chatSubscription?.cancel();
    await _preferenceSubscription?.cancel();
    return super.close();
  }
}
