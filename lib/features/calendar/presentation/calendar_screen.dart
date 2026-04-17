import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/task_model.dart';
import '../../../data/repositories/task_repository.dart';
import '../../tasks/presentation/widgets/task_form_sheet.dart';
import '../../tasks/presentation/widgets/task_tile.dart';
import 'providers/calendar_providers.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  Future<void> _createTask(BuildContext context, WidgetRef ref, {DateTime? defaultDate}) async {
    HapticFeedback.mediumImpact();
    final TaskModel? created = await showModalBottomSheet<TaskModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (BuildContext c) => TaskFormSheet(
        initial: defaultDate == null
            ? null
            : TaskModel(
                id: '',
                title: '',
                priority: TaskPriority.medium,
                status: TaskStatus.pending,
                dueDate: defaultDate,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
      ),
    );
    if (created != null) {
      await ref.read(taskRepositoryProvider).create(created);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime selected = ref.watch(selectedDayProvider);
    final DateTime focused = ref.watch(focusedDayProvider);
    final CalendarMode mode = ref.watch(calendarModeProvider);
    final AsyncValue<List<TaskModel>> tasksAsync = ref.watch(tasksForSelectedDayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Календарь'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Настройки',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createTask(context, ref, defaultDate: selected),
        icon: const Icon(Icons.add, size: 24),
        label: const Text('Добавить'),
      ),
      body: Column(
        children: <Widget>[
          // Переключатель режимов
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<CalendarMode>(
              segments: const <ButtonSegment<CalendarMode>>[
                ButtonSegment<CalendarMode>(value: CalendarMode.month, label: Text('Месяц')),
                ButtonSegment<CalendarMode>(value: CalendarMode.week, label: Text('Неделя')),
                ButtonSegment<CalendarMode>(value: CalendarMode.day, label: Text('День')),
                ButtonSegment<CalendarMode>(value: CalendarMode.agenda, label: Text('Повестка')),
              ],
              selected: <CalendarMode>{mode},
              showSelectedIcon: false,
              onSelectionChanged: (Set<CalendarMode> s) =>
                  ref.read(calendarModeProvider.notifier).state = s.first,
            ),
          ),
          // Календарь (кроме режима повестки)
          if (mode != CalendarMode.agenda)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: TableCalendar<TaskModel>(
                firstDay: DateTime.utc(2020),
                lastDay: DateTime.utc(2035),
                focusedDay: focused,
                selectedDayPredicate: (DateTime d) => isSameDay(selected, d),
                calendarFormat: switch (mode) {
                  CalendarMode.week || CalendarMode.day => CalendarFormat.week,
                  _ => CalendarFormat.month,
                },
                availableGestures: AvailableGestures.horizontalSwipe,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: AppTextStyles.titleMedium,
                  leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.accent),
                  rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.accent),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: AppTextStyles.labelMedium,
                  weekendStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.textDisabled),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  selectedDecoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                  defaultTextStyle: AppTextStyles.bodyMedium,
                  weekendTextStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  outsideDaysVisible: false,
                  markerDecoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 3,
                ),
                onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
                  HapticFeedback.selectionClick();
                  ref.read(selectedDayProvider.notifier).state = selectedDay;
                  ref.read(focusedDayProvider.notifier).state = focusedDay;
                },
                onPageChanged: (DateTime f) =>
                    ref.read(focusedDayProvider.notifier).state = f,
                onDayLongPressed: (DateTime d, DateTime _) =>
                    _createTask(context, ref, defaultDate: d.copyWith(hour: 9, minute: 0)),
              ),
            ),
          const SizedBox(height: 12),
          // Заголовок дня
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                Text(
                  DateFormat('EEEE, d MMMM', 'ru').format(selected),
                  style: AppTextStyles.titleLarge,
                ),
                const Spacer(),
                tasksAsync.when(
                  data: (List<TaskModel> tasks) => Text(
                    '${tasks.where((TaskModel t) => t.isCompleted).length}/${tasks.length}',
                    style: AppTextStyles.bodySmall,
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: tasksAsync.when(
              data: (List<TaskModel> tasks) {
                if (tasks.isEmpty) {
                  return EmptyState(
                    icon: Icons.event_available,
                    title: 'На этот день ничего не запланировано',
                    subtitle: 'Используйте AI-ассистента или добавьте задачу вручную',
                    action: FilledButton.icon(
                      onPressed: () => _createTask(context, ref, defaultDate: selected),
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить задачу'),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext c, int i) {
                    final TaskModel t = tasks[i];
                    return TaskTile(
                      task: t,
                      onToggle: () => ref.read(taskRepositoryProvider).toggleComplete(t.id),
                      onTap: () => context.push(AppRoutes.taskDetailPath(t.id)),
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
