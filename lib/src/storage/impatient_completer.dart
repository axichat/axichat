import 'dart:async';

class ImpatientCompleter<T> {
  ImpatientCompleter(this.completer);

  final Completer<T> completer;

  Future<T> get future => completer.future;

  bool get isCompleted => completer.isCompleted;

  T? get value => isCompleted ? _value : null;
  late final T _value;

  void complete(T value) {
    completer.complete(value);
    _value = value;
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    completer.completeError(error, stackTrace);
  }
}
