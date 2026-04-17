import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/task_model.dart';
import '../../../../data/repositories/task_repository.dart';

enum TaskFilter { today, tomorrow, week, overdue, all }

final StateProvider<TaskFilter> taskFilterProvider =
    StateProvider<TaskFilter>((Ref ref) => TaskFilter.today);

final StreamProvider<List<TaskModel>> filteredTasksProvider =
    StreamProvider<List<TaskModel>>((Ref ref) {
  final TaskFilter filter = ref.watch(taskFilterProvider);
  final TaskRepository repo = ref.watch(taskRepositoryProvider);
  final DateTime now = DateTime.now();

  return repo.watchAll().map((List<TaskModel> tasks) {
    return switch (filter) {
      TaskFilter.today => tasks.where((TaskModel t) => _sameDay(t.dueDate, now)).toList(),
      TaskFilter.tomorrow =>
        tasks.where((TaskModel t) => _sameDay(t.dueDate, now.add(const Duration(days: 1)))).toList(),
      TaskFilter.week => tasks.where((TaskModel t) {
          if (t.dueDate == null) return false;
          final DateTime end = now.add(const Duration(days: 7));
          return t.dueDate!.isAfter(now.subtract(const Duration(days: 1))) &&
              t.dueDate!.isBefore(end);
        }).toList(),
      TaskFilter.overdue => tasks.where((TaskModel t) => t.isOverdue).toList(),
      TaskFilter.all => tasks,
    };
  });
});

bool _sameDay(DateTime? a, DateTime b) {
  if (a == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

final FutureProvider.family<TaskModel?, String> taskByIdProvider =
    FutureProvider.family<TaskModel?, String>((Ref ref, String id) {
  return ref.watch(taskRepositoryProvider).getById(id);
});
