import 'package:drift/drift.dart';

@DataClassName('ProductivityStatRow')
class ProductivityStats extends Table {
  DateTimeColumn get date => dateTime()();
  IntColumn get tasksCompleted => integer().withDefault(const Constant(0))();
  IntColumn get pomodoroCount => integer().withDefault(const Constant(0))();
  IntColumn get focusMinutes => integer().withDefault(const Constant(0))();
  RealColumn get score => real().withDefault(const Constant(0.0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{date};
}
