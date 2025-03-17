import 'dart:async';

class ImpatientCompleter<T> {
  ImpatientCompleter(this.completer);

  final Completer<T> completer;
  bool _hasListener = false;

  Future<T> get future {
    _hasListener = true;
    return completer.future;
  }

  bool get isCompleted => completer.isCompleted;

  T? get value => isCompleted ? _value : null;
  late final T _value;

  void complete(T value) {
    completer.complete(value);
    _value = value;
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!_hasListener) return;
    completer.completeError(error, stackTrace);
  }
}
