import 'dart:async';

final class EventHandlerAbortedException implements Exception {}

typedef EventMatcher<E> = bool Function(E);
typedef EventHandler<E> = FutureOr<void> Function(E);

class EventManager<E> {
  final _registry = <EventMatcher<E>, List>{};

  bool _match<T extends E>(E event) => event is T;

  void registerHandler<T extends E>(
    EventHandler<T> handler,
  ) {
    if (_registry[_match<T>] == null) {
      _registry[_match<T>] = [handler];
    } else {
      _registry[_match<T>]!.add(handler);
    }
  }

  void registerHandlers<T extends E>(
    List<EventHandler<T>> handlers,
  ) {
    if (_registry[_match<T>] == null) {
      _registry[_match<T>] = handlers;
    } else {
      _registry[_match<T>]!.addAll(handlers);
    }
  }

  void unregisterHandlers<T extends E>() {
    _registry[_match<T>] = [];
  }

  Future<void> executeHandlers(E event) async {
    for (final match in _registry.keys) {
      if (!match(event)) continue;
      try {
        await Future.wait(
          _registry[match]!.map((e) async => await e(event)),
          eagerError: true,
        );
      } on EventHandlerAbortedException catch (_) {
        continue;
      }
    }
  }
}
