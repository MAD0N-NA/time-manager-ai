import 'package:drift/drift.dart';

@DataClassName('PomodoroSessionRow')
class PomodoroSessions extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get durationMinutes => integer()();
  IntColumn get type => integer().withDefault(const Constant(0))(); // 0=work,1=short,2=long
  BoolColumn get wasCompleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
