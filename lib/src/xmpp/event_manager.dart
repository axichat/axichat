import 'dart:async';

final class EventHandlerAbortedException implements Exception {}

typedef EventMatcher<E> = bool Function(E);
typedef EventHandler<E> = FutureOr<void> Function(E);

class EventManager<E> {
  final _registry = <EventMatcher<E>, List<EventHandler>>{};

  bool _match<T>(E event) => event is T;

  void registerHandlers<T>(
    List<EventHandler<T>> handlers,
  ) {
    if (_registry[_match<T>] == null) {
      _registry[_match<T>] = handlers as List<EventHandler>;
    } else {
      _registry[_match<T>]!.addAll(handlers as List<EventHandler>);
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
