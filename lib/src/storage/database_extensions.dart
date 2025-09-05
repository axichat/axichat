import 'package:logging/logging.dart';

import 'database.dart';
import 'state_store.dart';

/// Exception thrown when database operations fail
class DatabaseException implements Exception {
  const DatabaseException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'DatabaseException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Extension methods for common database operation patterns
///
/// IMPORTANT: These extensions should only be used when you already have
/// a database instance available. For service-level database coordination,
/// use the _dbOp* functions which handle database lifecycle with Completers.
extension DatabaseOperations on XmppDatabase {
  static final _log = Logger('DatabaseOperations');

  /// Executes a database query with consistent error handling
  Future<T> executeQuery<T>({
    required Future<T> Function() operation,
    String? operationName,
  }) async {
    final name = operationName ?? 'database operation';
    try {
      _log.fine('Executing $name...');
      final result = await operation();
      _log.fine('Completed $name successfully');
      return result;
    } catch (e, stackTrace) {
      _log.severe('Failed to execute $name', e, stackTrace);
      throw DatabaseException('Failed to execute $name: ${e.toString()}', e);
    }
  }

  /// Executes a database operation without return value with consistent error handling
  Future<void> executeOperation({
    required Future<void> Function() operation,
    String? operationName,
  }) async {
    final name = operationName ?? 'database operation';
    try {
      _log.fine('Executing $name...');
      await operation();
      _log.fine('Completed $name successfully');
    } catch (e, stackTrace) {
      _log.severe('Failed to execute $name', e, stackTrace);
      throw DatabaseException('Failed to execute $name: ${e.toString()}', e);
    }
  }

  /// Safely retrieves a single item, returning null if not found
  Future<T?> safeGetItem<T>({
    required Future<T?> Function() getter,
    String? itemName,
  }) async {
    final name = itemName ?? 'item';
    try {
      return await getter();
    } catch (e, stackTrace) {
      _log.warning('Failed to retrieve $name, returning null', e, stackTrace);
      return null;
    }
  }

  /// Safely retrieves a list, returning empty list if operation fails
  Future<List<T>> safeGetList<T>({
    required Future<List<T>> Function() getter,
    String? listName,
  }) async {
    final name = listName ?? 'list';
    try {
      return await getter();
    } catch (e, stackTrace) {
      _log.warning(
          'Failed to retrieve $name, returning empty list', e, stackTrace);
      return <T>[];
    }
  }
}

/// Extension methods for state store operations
///
/// IMPORTANT: These extensions should only be used when you already have
/// a state store instance available. For service-level state store coordination,
/// use the _dbOp* functions which handle state store lifecycle with Completers.
extension StateStoreOperations on XmppStateStore {
  static final _log = Logger('StateStoreOperations');

  /// Executes a state store query with consistent error handling
  Future<T> executeQuery<T>({
    required Future<T> Function() operation,
    String? operationName,
  }) async {
    final name = operationName ?? 'state store operation';
    try {
      _log.fine('Executing $name...');
      final result = await operation();
      _log.fine('Completed $name successfully');
      return result;
    } catch (e, stackTrace) {
      _log.severe('Failed to execute $name', e, stackTrace);
      throw DatabaseException('Failed to execute $name: ${e.toString()}', e);
    }
  }

  /// Executes a state store operation without return value with consistent error handling
  Future<void> executeOperation({
    required Future<void> Function() operation,
    String? operationName,
  }) async {
    final name = operationName ?? 'state store operation';
    try {
      _log.fine('Executing $name...');
      await operation();
      _log.fine('Completed $name successfully');
    } catch (e, stackTrace) {
      _log.severe('Failed to execute $name', e, stackTrace);
      throw DatabaseException('Failed to execute $name: ${e.toString()}', e);
    }
  }

  /// Safely retrieves a value, returning null if not found
  Future<T?> safeGetValue<T>({
    required RegisteredStateKey key,
    String? valueName,
  }) async {
    final name = valueName ?? 'value for ${key.value}';
    try {
      return read(key: key) as T?;
    } catch (e, stackTrace) {
      _log.warning('Failed to retrieve $name, returning null', e, stackTrace);
      return null;
    }
  }

  /// Safely writes a value, returning false on failure
  Future<bool> safeWrite<T>({
    required RegisteredStateKey key,
    required T? value,
    String? operationName,
  }) async {
    final name = operationName ?? 'write ${key.value}';
    try {
      return await write(key: key, value: value);
    } catch (e, stackTrace) {
      _log.warning('Failed to $name, returning false', e, stackTrace);
      return false;
    }
  }
}
