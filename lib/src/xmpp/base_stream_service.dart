part of 'package:axichat/src/xmpp/xmpp_service.dart';

mixin BaseStreamService on XmppBase {
  /// Creates a paginated stream with immediate initial data from database
  /// followed by real-time updates via watch stream.
  Stream<List<T>> createPaginatedStream<T, D extends Database>({
    required Future<Stream<List<T>>> Function(D db) watchFunction,
    required Future<List<T>> Function(D db) getFunction,
  }) {
    return StreamCompleter.fromFuture(
      Future.value(
        _dbOpReturning<D, Stream<List<T>>>(
          (db) async {
            final stream = await watchFunction(db);
            final initial = await getFunction(db);
            return stream.startWith(initial);
          },
        ),
      ),
    );
  }

  /// Creates a single-item stream for watching individual entities
  Stream<T> createSingleItemStream<T, D extends Database>({
    required Future<Stream<T>> Function(D db) watchFunction,
  }) async* {
    final stream = await _dbOpReturning<D, Future<Stream<T>>>(
      (db) => watchFunction(db),
    );
    yield* await stream;
  }
}
