import 'dart:async';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';

class ChatTransportCubit extends Cubit<MessageTransport> {
  ChatTransportCubit({
    required ChatsService chatsService,
    required this.jid,
  })  : _chatsService = chatsService,
        super(MessageTransport.xmpp) {
    _subscription = _chatsService
        .watchChatTransportPreference(jid)
        .listen(emit, onError: (_) {});
  }

  final ChatsService _chatsService;
  final String jid;
  StreamSubscription<MessageTransport>? _subscription;

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
