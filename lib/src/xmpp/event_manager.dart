import 'dart:async';

import 'package:moxxmpp/moxxmpp.dart' as mox;

class EventManager {
  final _registry = <Type, List<FutureOr<void> Function()>>{};

  void registerHandlers<T extends mox.XmppEvent>(
      List<FutureOr<void> Function()> handlers) {
    if (_registry[T] == null) {
      _registry[T] = handlers;
    } else {
      _registry[T]!.addAll(handlers);
    }
  }

  Future<void> executeHandlers<T extends mox.XmppEvent>() async {
    for (final handler in _registry[T] ?? []) {
      await handler();
    }
  }
}
