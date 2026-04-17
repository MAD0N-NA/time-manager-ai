import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/task_model.dart';

const Uuid _uuid = Uuid();

class TaskRepository {
  TaskRepository(this._db);
  final AppDatabase _db;

  Stream<List<TaskModel>> watchAll() {
    final SimpleSelectStatement<$TasksTable, TaskRow> q = _db.select(_db.tasks)
      ..orderBy(<OrderClauseGenerator<$TasksTable>>[
        ($TasksTable t) => OrderingTerm.desc(t.priority),
        ($TasksTable t) => OrderingTerm.asc(t.dueDate),
      ]);
    return q.watch().map((List<TaskRow> rows) => rows.map(TaskModel.fromRow).toList());
  }

  Stream<List<TaskModel>> watchForDay(DateTime day) {
    final DateTime start = DateTime(day.year, day.month, day.day);
    final DateTime end = start.add(const Duration(days: 1));
    final SimpleSelectStatement<$TasksTable, TaskRow> q = _db.select(_db.tasks)
      ..where(($TasksTable t) =>
          (t.dueDate.isBetweenValues(start, end)) |
          (t.startTime.isBetweenValues(start, end)))
      ..orderBy(<OrderClauseGenerator<$TasksTable>>[
        ($TasksTable t) => OrderingTerm.asc(t.startTime),
        ($TasksTable t) => OrderingTerm.desc(t.priority),
      ]);
    return q.watch().map((List<TaskRow> rows) => rows.map(TaskModel.fromRow).toList());
  }

  Stream<List<TaskModel>> watchByStatus(TaskStatus status) {
    final SimpleSelectStatement<$TasksTable, TaskRow> q = _db.select(_db.tasks)
      ..where(($TasksTable t) => t.status.equals(status.value));
    return q.watch().map((List<TaskRow> rows) => rows.map(TaskModel.fromRow).toList());
  }

  Future<List<TaskModel>> getOverdue() async {
    final List<TaskRow> rows = await (_db.select(_db.tasks)
          ..where(($TasksTable t) =>
              t.dueDate.isSmallerThanValue(DateTime.now()) &
              t.status.equals(TaskStatus.completed.value).not()))
        .get();
    return rows.map(TaskModel.fromRow).toList();
  }

  Future<List<TaskModel>> getForRange(DateTime from, DateTime to) async {
    final List<TaskRow> rows = await (_db.select(_db.tasks)
          ..where(($TasksTable t) =>
              t.dueDate.isBetweenValues(from, to) | t.startTime.isBetweenValues(from, to)))
        .get();
    return rows.map(TaskModel.fromRow).toList();
  }

  Future<TaskModel?> getById(String id) async {
    final TaskRow? row = await (_db.select(_db.tasks)..where(($TasksTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : TaskModel.fromRow(row);
  }

  Future<TaskModel> create(TaskModel task) async {
    final TaskModel withId = task.id.isEmpty ? task.copyWith(id: _uuid.v4()) : task;
    await _db.into(_db.tasks).insert(withId.toCompanion());
    return withId;
  }

  Future<void> update(TaskModel task) async {
    final TaskModel updated = task.copyWith(updatedAt: DateTime.now());
    await _db.update(_db.tasks).replace(updated.toCompanion());
  }

  Future<void> toggleComplete(String id) async {
    final TaskModel? task = await getById(id);
    if (task == null) return;
    final bool nowCompleted = !task.isCompleted;
    final TaskModel updated = task.copyWith(
      status: nowCompleted ? TaskStatus.completed : TaskStatus.pending,
      completedAt: nowCompleted ? DateTime.now() : null,
      clearCompletedAt: !nowCompleted,
      updatedAt: DateTime.now(),
    );
    await update(updated);
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.tasks)..where(($TasksTable t) => t.id.equals(id))).go();
  }

  Future<List<TaskModel>> search(String query) async {
    final String pattern = '%${query.toLowerCase()}%';
    final List<TaskRow> rows = await (_db.select(_db.tasks)
          ..where(($TasksTable t) =>
              t.title.lower().like(pattern) | t.description.lower().like(pattern) | t.tags.lower().like(pattern)))
        .get();
    return rows.map(TaskModel.fromRow).toList();
  }
}

final Provider<TaskRepository> taskRepositoryProvider = Provider<TaskRepository>((Ref ref) {
  return TaskRepository(ref.watch(appDatabaseProvider));
});
