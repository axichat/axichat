import 'package:drift/drift.dart';

@DataClassName('DayEventEntry')
class DayEvents extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();

  DateTimeColumn get startDate => dateTime()();

  DateTimeColumn get endDate => dateTime()();

  TextColumn get description => text().nullable()();

  /// Stored as JSON string produced by [ReminderPreferences.toJson].
  ///
  /// We keep this non-null so downstream services can decode without
  /// branching.
  TextColumn get reminders => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get modifiedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
