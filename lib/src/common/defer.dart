import 'dart:async';

Future<T> deferToError<T>({
  required FutureOr<T> Function() operation,
  required FutureOr<void> Function(Exception e) defer,
}) async {
  try {
    return await operation();
  } on Exception catch (e) {
    await defer(e);
    rethrow;
  }
}
