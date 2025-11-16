import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';

/// Persists email spam markers locally so UI components can reflect which
/// addresses were flagged.
class EmailSpamService {
  EmailSpamService({required Future<XmppDatabase> Function() databaseBuilder})
      : _databaseBuilder = databaseBuilder;

  final Future<XmppDatabase> Function() _databaseBuilder;

  Future<XmppDatabase> _resolveDatabase() => _databaseBuilder();

  Future<void> mark(String address) async {
    final database = await _resolveDatabase();
    await database.addEmailSpam(address);
  }

  Future<void> unmark(String address) async {
    final database = await _resolveDatabase();
    await database.removeEmailSpam(address);
  }

  Stream<List<EmailSpamEntry>> watchEntries() async* {
    final database = await _resolveDatabase();
    yield* database.watchEmailSpamlist();
  }
}
