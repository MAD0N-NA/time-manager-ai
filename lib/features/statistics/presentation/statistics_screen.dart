import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/task_model.dart';
import '../../../data/repositories/pomodoro_repository.dart';
import '../../../data/repositories/task_repository.dart';

class StatsSummary {
  StatsSummary({
    required this.byDay,
    required this.totalCompleted,
    required this.totalCreated,
    required this.streak,
    required this.focusMinutes,
    required this.pomodoroCount,
  });

  final Map<DateTime, int> byDay;
  final int totalCompleted;
  final int totalCreated;
  final int streak;
  final int focusMinutes;
  final int pomodoroCount;
}

final FutureProvider<StatsSummary> statsSummaryProvider = FutureProvider<StatsSummary>((Ref ref) async {
  final TaskRepository taskRepo = ref.watch(taskRepositoryProvider);
  final PomodoroRepository pomoRepo = ref.watch(pomodoroRepositoryProvider);

  final DateTime now = DateTime.now();
  final DateTime from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));

  final List<TaskModel> tasksRange = await taskRepo.getForRange(from, now);

  final Map<DateTime, int> byDay = <DateTime, int>{};
  int completed = 0;
  for (final TaskModel t in tasksRange) {
    if (t.isCompleted && t.completedAt != null) {
      final DateTime key = DateTime(t.completedAt!.year, t.completedAt!.month, t.completedAt!.day);
      byDay[key] = (byDay[key] ?? 0) + 1;
      completed++;
    }
  }

  // Заполняем недостающие дни нулями
  for (int i = 0; i < 30; i++) {
    final DateTime day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
    byDay.putIfAbsent(day, () => 0);
  }

  // Streak — дни подряд с >0 выполненных
  int streak = 0;
  for (int i = 0; i < 365; i++) {
    final DateTime day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
    if ((byDay[day] ?? 0) > 0) {
      streak++;
    } else if (i > 0) {
      break;
    }
  }

  final List<PomodoroSessionRow> pomodoros =
      await pomoRepo.getRange(from, now);
  final List<PomodoroSessionRow> completedPomodoros =
      pomodoros.where((PomodoroSessionRow s) => s.wasCompleted && s.type == 0).toList();

  return StatsSummary(
    byDay: byDay,
    totalCompleted: completed,
    totalCreated: tasksRange.length,
    streak: streak,
    focusMinutes: completedPomodoros.fold<int>(0, (int sum, PomodoroSessionRow s) => sum + s.durationMinutes),
    pomodoroCount: completedPomodoros.length,
  );
});

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<StatsSummary> async = ref.watch(statsSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('Ошибка: $e')),
        data: (StatsSummary s) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(statsSummaryProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Metric(
                        icon: Icons.local_fire_department,
                        label: 'Streak',
                        value: '${s.streak}',
                        unit: 'дней',
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Metric(
                        icon: Icons.check_circle,
                        label: 'Выполнено',
                        value: '${s.totalCompleted}',
                        unit: 'за 30 дн',
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Metric(
                        icon: Icons.timer,
                        label: 'Focus',
                        value: '${s.focusMinutes}',
                        unit: 'мин',
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Metric(
                        icon: Icons.emoji_events,
                        label: 'Pomodoro',
                        value: '${s.pomodoroCount}',
                        unit: 'сессий',
                        color: AppColors.priorityHigh,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Задачи за последние 30 дней',
                    style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 220,
                    child: _CompletedChart(byDay: s.byDay),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Распределение по приоритетам',
                    style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                _PriorityPie(ref: ref),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.labelMedium),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(value, style: AppTextStyles.headlineLarge.copyWith(color: color)),
              const SizedBox(width: 4),
              Text(unit, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletedChart extends StatelessWidget {
  const _CompletedChart({required this.byDay});
  final Map<DateTime, int> byDay;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<DateTime, int>> sorted = byDay.entries.toList()
      ..sort((MapEntry<DateTime, int> a, MapEntry<DateTime, int> b) => a.key.compareTo(b.key));

    final List<FlSpot> spots = <FlSpot>[];
    for (int i = 0; i < sorted.length; i++) {
      spots.add(FlSpot(i.toDouble(), sorted[i].value.toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 7,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int idx = value.toInt();
                if (idx < 0 || idx >= sorted.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('d/M').format(sorted[idx].key),
                    style: AppTextStyles.caption,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.accent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  AppColors.accent.withValues(alpha: 0.3),
                  AppColors.accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityPie extends ConsumerWidget {
  const _PriorityPie({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<TaskModel>>(
      future: ref.read(taskRepositoryProvider).getForRange(
            DateTime.now().subtract(const Duration(days: 30)),
            DateTime.now().add(const Duration(days: 30)),
          ),
      builder: (BuildContext c, AsyncSnapshot<List<TaskModel>> snap) {
        if (!snap.hasData) {
          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        }
        final List<TaskModel> tasks = snap.data!;
        final Map<TaskPriority, int> counts = <TaskPriority, int>{};
        for (final TaskModel t in tasks) {
          counts[t.priority] = (counts[t.priority] ?? 0) + 1;
        }
        if (counts.isEmpty) {
          return AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Нет данных', style: AppTextStyles.bodyMedium),
              ),
            ),
          );
        }

        final List<PieChartSectionData> sections = counts.entries
            .map(
              (MapEntry<TaskPriority, int> e) => PieChartSectionData(
                value: e.value.toDouble(),
                color: switch (e.key) {
                  TaskPriority.low => AppColors.priorityLow,
                  TaskPriority.medium => AppColors.priorityMedium,
                  TaskPriority.high => AppColors.priorityHigh,
                  TaskPriority.urgent => AppColors.priorityUrgent,
                },
                title: '${e.value}',
                radius: 60,
                titleStyle: AppTextStyles.labelMedium.copyWith(color: Colors.black),
              ),
            )
            .toList();

        return AppCard(
          child: SizedBox(
            height: 200,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 30,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: counts.keys
                      .map((TaskPriority p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: switch (p) {
                                      TaskPriority.low => AppColors.priorityLow,
                                      TaskPriority.medium => AppColors.priorityMedium,
                                      TaskPriority.high => AppColors.priorityHigh,
                                      TaskPriority.urgent => AppColors.priorityUrgent,
                                    },
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(p.label, style: AppTextStyles.bodySmall),
                              ],
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
