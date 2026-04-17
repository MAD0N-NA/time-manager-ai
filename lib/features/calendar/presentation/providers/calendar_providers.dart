import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/event_model.dart';
import '../../../../data/models/task_model.dart';
import '../../../../data/repositories/event_repository.dart';
import '../../../../data/repositories/task_repository.dart';

enum CalendarMode { month, week, day, agenda }

final StateProvider<DateTime> selectedDayProvider =
    StateProvider<DateTime>((Ref ref) => DateTime.now());

final StateProvider<DateTime> focusedDayProvider =
    StateProvider<DateTime>((Ref ref) => DateTime.now());

final StateProvider<CalendarMode> calendarModeProvider =
    StateProvider<CalendarMode>((Ref ref) => CalendarMode.month);

/// Задачи выбранного дня.
final StreamProvider<List<TaskModel>> tasksForSelectedDayProvider =
    StreamProvider<List<TaskModel>>((Ref ref) {
  final DateTime day = ref.watch(selectedDayProvider);
  final TaskRepository repo = ref.watch(taskRepositoryProvider);
  return repo.watchForDay(day);
});

/// События выбранного дня.
final StreamProvider<List<EventModel>> eventsForSelectedDayProvider =
    StreamProvider<List<EventModel>>((Ref ref) {
  final DateTime day = ref.watch(selectedDayProvider);
  final EventRepository repo = ref.watch(eventRepositoryProvider);
  return repo.watchForDay(day);
});
