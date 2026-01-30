import 'dart:async';

final class EmailAsyncQueue {
  Future<void> _tail = Future<void>.value();

  Future<void> run(Future<void> Function() action) async {
    final previous = _tail;
    final completer = Completer<void>();
    _tail = completer.future;
    await previous;
    try {
      await action();
    } finally {
      completer.complete();
    }
  }

  void reset() {
    _tail = Future<void>.value();
  }
}
