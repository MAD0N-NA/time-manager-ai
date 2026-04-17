import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/event_model.dart';

const Uuid _uuid = Uuid();

class EventRepository {
  EventRepository(this._db);
  final AppDatabase _db;

  Stream<List<EventModel>> watchForDay(DateTime day) {
    final DateTime start = DateTime(day.year, day.month, day.day);
    final DateTime end = start.add(const Duration(days: 1));
    final SimpleSelectStatement<$EventsTable, EventRow> q = _db.select(_db.events)
      ..where(($EventsTable e) =>
          e.startDateTime.isSmallerThanValue(end) & e.endDateTime.isBiggerOrEqualValue(start))
      ..orderBy(<OrderClauseGenerator<$EventsTable>>[
        ($EventsTable e) => OrderingTerm.asc(e.startDateTime),
      ]);
    return q.watch().map((List<EventRow> rows) => rows.map(EventModel.fromRow).toList());
  }

  Future<List<EventModel>> getForRange(DateTime from, DateTime to) async {
    final List<EventRow> rows = await (_db.select(_db.events)
          ..where(($EventsTable e) =>
              e.startDateTime.isSmallerThanValue(to) & e.endDateTime.isBiggerOrEqualValue(from)))
        .get();
    return rows.map(EventModel.fromRow).toList();
  }

  Future<EventModel> create(EventModel event) async {
    final EventModel withId = event.id.isEmpty ? event.copyWith(id: _uuid.v4()) : event;
    await _db.into(_db.events).insert(withId.toCompanion());
    return withId;
  }

  Future<void> update(EventModel event) async {
    await _db.update(_db.events).replace(event.copyWith(updatedAt: DateTime.now()).toCompanion());
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.events)..where(($EventsTable e) => e.id.equals(id))).go();
  }
}

final Provider<EventRepository> eventRepositoryProvider = Provider<EventRepository>((Ref ref) {
  return EventRepository(ref.watch(appDatabaseProvider));
});
