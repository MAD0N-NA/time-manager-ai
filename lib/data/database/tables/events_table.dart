import 'package:drift/drift.dart';

@DataClassName('EventRow')
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startDateTime => dateTime()();
  DateTimeColumn get endDateTime => dateTime()();
  TextColumn get location => text().nullable()();
  BoolColumn get isAllDay => boolean().withDefault(const Constant(false))();
  IntColumn get color => integer().withDefault(const Constant(0xFF1B5E20))();
  TextColumn get recurrenceRule => text().nullable()();
  IntColumn get reminderMinutesBefore => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
