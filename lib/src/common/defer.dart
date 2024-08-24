import 'dart:async';

Future<T> deferToError<T>({
  required FutureOr<T> Function() operation,
  required FutureOr<void> Function() defer,
}) async {
  try {
    return await operation();
  } catch (e) {
    await defer();
    rethrow;
  }
}
