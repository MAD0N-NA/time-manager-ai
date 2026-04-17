import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

const Uuid _uuid = Uuid();

enum PomodoroType {
  work(0),
  shortBreak(1),
  longBreak(2);

  const PomodoroType(this.value);
  final int value;

  static PomodoroType fromValue(int v) =>
      PomodoroType.values.firstWhere((PomodoroType e) => e.value == v, orElse: () => PomodoroType.work);
}

class PomodoroRepository {
  PomodoroRepository(this._db);
  final AppDatabase _db;

  Future<String> startSession({
    required PomodoroType type,
    required int durationMinutes,
    String? taskId,
  }) async {
    final String id = _uuid.v4();
    await _db.into(_db.pomodoroSessions).insert(
          PomodoroSessionsCompanion.insert(
            id: id,
            startedAt: DateTime.now(),
            durationMinutes: durationMinutes,
            type: Value<int>(type.value),
            taskId: Value<String?>(taskId),
          ),
        );
    return id;
  }

  Future<void> completeSession(String id) async {
    await (_db.update(_db.pomodoroSessions)
          ..where(($PomodoroSessionsTable s) => s.id.equals(id)))
        .write(
      PomodoroSessionsCompanion(
        completedAt: Value<DateTime>(DateTime.now()),
        wasCompleted: const Value<bool>(true),
      ),
    );
  }

  Future<int> countTodayCompleted() async {
    final DateTime start = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    final List<PomodoroSessionRow> rows = await (_db.select(_db.pomodoroSessions)
          ..where(($PomodoroSessionsTable s) =>
              s.startedAt.isBiggerOrEqualValue(start) &
              s.wasCompleted.equals(true) &
              s.type.equals(PomodoroType.work.value)))
        .get();
    return rows.length;
  }

  Future<List<PomodoroSessionRow>> getRange(DateTime from, DateTime to) async {
    return (_db.select(_db.pomodoroSessions)
          ..where(($PomodoroSessionsTable s) => s.startedAt.isBetweenValues(from, to)))
        .get();
  }
}

final Provider<PomodoroRepository> pomodoroRepositoryProvider = Provider<PomodoroRepository>((Ref ref) {
  return PomodoroRepository(ref.watch(appDatabaseProvider));
});
