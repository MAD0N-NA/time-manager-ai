import 'package:drift/drift.dart';

@DataClassName('TaskRow')
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get startTime => dateTime().nullable()();
  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(1))();
  IntColumn get status => integer().withDefault(const Constant(0))();
  TextColumn get projectId => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get parentTaskId => text().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurrenceRule => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  IntColumn get reminderMinutesBefore => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get pomodoroCount => integer().withDefault(const Constant(0))();
  IntColumn get estimatedMinutes => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
