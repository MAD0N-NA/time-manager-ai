import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/task_model.dart';
import '../../../data/repositories/task_repository.dart';
import 'providers/task_providers.dart';
import 'widgets/task_form_sheet.dart';
import 'widgets/task_tile.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  static const Map<TaskFilter, String> _labels = <TaskFilter, String>{
    TaskFilter.today: 'Сегодня',
    TaskFilter.tomorrow: 'Завтра',
    TaskFilter.week: 'Неделя',
    TaskFilter.overdue: 'Просрочено',
    TaskFilter.all: 'Все',
  };

  Future<void> _addTask(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final TaskModel? created = await showModalBottomSheet<TaskModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (BuildContext c) => const TaskFormSheet(),
    );
    if (created != null) {
      await ref.read(taskRepositoryProvider).create(created);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TaskFilter filter = ref.watch(taskFilterProvider);
    final AsyncValue<List<TaskModel>> tasksAsync = ref.watch(filteredTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Задачи'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Поиск',
            onPressed: () => showSearch<void>(context: context, delegate: _TaskSearchDelegate(ref)),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTask(context, ref),
        child: const Icon(Icons.add, size: 28),
      ),
      body: Column(
        children: <Widget>[
          // Фильтры
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: TaskFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (BuildContext c, int i) {
                final TaskFilter f = TaskFilter.values[i];
                final bool selected = f == filter;
                return ChoiceChip(
                  label: Text(_labels[f]!),
                  selected: selected,
                  onSelected: (_) => ref.read(taskFilterProvider.notifier).state = f,
                );
              },
            ),
          ),
          Expanded(
            child: tasksAsync.when(
              data: (List<TaskModel> tasks) {
                if (tasks.isEmpty) {
                  return EmptyState(
                    icon: Icons.task_alt,
                    title: 'Задач нет',
                    subtitle: 'Добавьте первую задачу через AI или кнопку +',
                    action: FilledButton.icon(
                      onPressed: () => _addTask(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Создать'),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext c, int i) {
                    final TaskModel t = tasks[i];
                    return Dismissible(
                      key: ValueKey<String>(t.id),
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.check_circle, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (DismissDirection dir) async {
                        if (dir == DismissDirection.startToEnd) {
                          await ref.read(taskRepositoryProvider).toggleComplete(t.id);
                          return false;
                        }
                        return true;
                      },
                      onDismissed: (_) => ref.read(taskRepositoryProvider).delete(t.id),
                      child: TaskTile(
                        task: t,
                        onToggle: () => ref.read(taskRepositoryProvider).toggleComplete(t.id),
                        onTap: () => context.push(AppRoutes.taskDetailPath(t.id)),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, _) => Center(child: Text('Ошибка: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskSearchDelegate extends SearchDelegate<void> {
  _TaskSearchDelegate(this.ref);
  final WidgetRef ref;

  @override
  List<Widget>? buildActions(BuildContext context) => <Widget>[
        if (query.isNotEmpty)
          IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
      ];

  @override
  Widget? buildLeading(BuildContext context) =>
      IconButton(onPressed: () => close(context, null), icon: const Icon(Icons.arrow_back));

  @override
  Widget buildResults(BuildContext context) => _buildResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildResults();

  Widget _buildResults() {
    if (query.trim().isEmpty) {
      return const Center(child: Text('Введите запрос'));
    }
    return FutureBuilder<List<TaskModel>>(
      future: ref.read(taskRepositoryProvider).search(query),
      builder: (BuildContext c, AsyncSnapshot<List<TaskModel>> snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<TaskModel> tasks = snap.data ?? <TaskModel>[];
        if (tasks.isEmpty) return const Center(child: Text('Ничего не найдено'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (BuildContext c, int i) {
            final TaskModel t = tasks[i];
            return TaskTile(
              task: t,
              onToggle: () => ref.read(taskRepositoryProvider).toggleComplete(t.id),
              onTap: () {
                close(c, null);
                c.push(AppRoutes.taskDetailPath(t.id));
              },
            );
          },
        );
      },
    );
  }
}
