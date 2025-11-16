import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';

/// Simple helper that stores blocked email addresses in the local database so
/// the rest of the app can query/modify the list without talking directly to
/// [XmppDatabase].
class EmailBlockingService {
  EmailBlockingService({required Future<XmppDatabase> Function() databaseBuilder})
      : _databaseBuilder = databaseBuilder;

  final Future<XmppDatabase> Function() _databaseBuilder;

  Future<XmppDatabase> _resolveDatabase() => _databaseBuilder();

  Future<void> block(String address) async {
    final database = await _resolveDatabase();
    await database.addEmailBlock(address);
  }

  Future<void> unblock(String address) async {
    final database = await _resolveDatabase();
    await database.removeEmailBlock(address);
  }

  Future<bool> isBlocked(String address) async {
    final database = await _resolveDatabase();
    return database.isEmailAddressBlocked(address);
  }

  Stream<List<EmailBlocklistEntry>> watchEntries() async* {
    final database = await _resolveDatabase();
    yield* database.watchEmailBlocklist();
  }
}
