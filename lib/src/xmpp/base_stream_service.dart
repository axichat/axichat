// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

mixin BaseStreamService on XmppBase {
  /// Creates a paginated stream with immediate initial data from database
  /// followed by real-time updates via watch stream.
  Stream<List<T>> createPaginatedStream<T, D extends Database>({
    required Future<Stream<List<T>>> Function(D db) watchFunction,
    required Future<List<T>> Function(D db) getFunction,
  }) {
    return databaseReloadStream
        .startWith(null)
        .asyncMap(
          (_) => _dbOpReturning<D, Stream<List<T>>>(
            (db) async {
              final stream = await watchFunction(db);
              final initial = await getFunction(db);
              return stream.startWith(initial);
            },
          ),
        )
        .switchMap((stream) => stream);
  }

  /// Creates a single-item stream for watching individual entities
  Stream<T> createSingleItemStream<T, D extends Database>({
    required Future<Stream<T>> Function(D db) watchFunction,
  }) async* {
    yield* databaseReloadStream
        .startWith(null)
        .asyncMap(
          (_) => _dbOpReturning<D, Stream<T>>(
            (db) => watchFunction(db),
          ),
        )
        .switchMap((stream) => stream);
  }
}
