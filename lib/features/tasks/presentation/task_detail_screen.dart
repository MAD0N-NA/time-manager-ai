import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/task_model.dart';
import '../../../data/repositories/task_repository.dart';
import 'providers/task_providers.dart';
import 'widgets/task_form_sheet.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({required this.taskId, super.key});
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TaskModel?> taskAsync = ref.watch(taskByIdProvider(taskId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Задача'),
        actions: <Widget>[
          taskAsync.maybeWhen(
            data: (TaskModel? t) => t == null
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final TaskModel? edited = await showModalBottomSheet<TaskModel>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: AppColors.surface,
                        builder: (_) => TaskFormSheet(initial: t),
                      );
                      if (edited != null) {
                        await ref.read(taskRepositoryProvider).update(edited);
                        ref.invalidate(taskByIdProvider(taskId));
                      }
                    },
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (BuildContext c) => AlertDialog(
                  title: const Text('Удалить задачу?'),
                  content: const Text('Это действие нельзя отменить.'),
                  actions: <Widget>[
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Удалить'),
                    ),
                  ],
                ),
              );
              if (confirm ?? false) {
                await ref.read(taskRepositoryProvider).delete(taskId);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: taskAsync.when(
        data: (TaskModel? task) {
          if (task == null) {
            return const Center(child: Text('Задача не найдена'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(task.title, style: AppTextStyles.headlineMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: <Widget>[
                          _Chip(label: task.priority.label, color: _priorityColor(task.priority)),
                          if (task.isOverdue)
                            const _Chip(label: 'Просрочено', color: AppColors.error),
                          if (task.isCompleted)
                            const _Chip(label: 'Выполнено', color: AppColors.success),
                        ],
                      ),
                    ],
                  ),
                ),
                if (task.description?.isNotEmpty ?? false) ...<Widget>[
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Описание', style: AppTextStyles.labelMedium),
                        const SizedBox(height: 8),
                        Text(task.description!, style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    children: <Widget>[
                      _Row(label: 'Дата', value: task.dueDate == null
                          ? '—'
                          : DateFormat('d MMMM, HH:mm', 'ru').format(task.dueDate!)),
                      if (task.estimatedMinutes != null)
                        _Row(label: 'Оценка', value: '${task.estimatedMinutes} мин'),
                      _Row(label: 'Pomodoro', value: '${task.pomodoroCount}'),
                      if (task.tags.isNotEmpty)
                        _Row(label: 'Теги', value: task.tags.join(', ')),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => ref.read(taskRepositoryProvider).toggleComplete(task.id).then(
                        (_) => ref.invalidate(taskByIdProvider(taskId)),
                      ),
                  icon: Icon(task.isCompleted ? Icons.replay : Icons.check),
                  label: Text(task.isCompleted ? 'Возобновить' : 'Отметить выполненной'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('Ошибка: $e')),
      ),
    );
  }

  Color _priorityColor(TaskPriority p) => switch (p) {
        TaskPriority.low => AppColors.priorityLow,
        TaskPriority.medium => AppColors.priorityMedium,
        TaskPriority.high => AppColors.priorityHigh,
        TaskPriority.urgent => AppColors.priorityUrgent,
      };
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: AppTextStyles.caption.copyWith(color: color)),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Text(label, style: AppTextStyles.labelMedium),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: AppTextStyles.bodyMedium),
          ),
        ],
      ),
    );
  }
}
