import 'dart:async';

class ImpatientCompleter<T> {
  ImpatientCompleter(this.completer);

  final Completer<T> completer;
  bool _hasListener = false;
  bool _hasValue = false;

  Future<T> get future {
    _hasListener = true;
    return completer.future;
  }

  bool get isCompleted => completer.isCompleted;

  T? get value => _hasValue ? _value : null;
  late final T _value;

  void complete(T value) {
    if (isCompleted) return;
    completer.complete(value);
    _value = value;
    _hasValue = true;
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!_hasListener) return;
    completer.completeError(error, stackTrace);
  }
}
