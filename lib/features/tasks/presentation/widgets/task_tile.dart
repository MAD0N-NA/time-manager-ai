import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/task_model.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    required this.task,
    required this.onToggle,
    this.onTap,
    super.key,
  });

  final TaskModel task;
  final VoidCallback onToggle;
  final VoidCallback? onTap;

  Color _priorityColor() {
    return switch (task.priority) {
      TaskPriority.low => AppColors.priorityLow,
      TaskPriority.medium => AppColors.priorityMedium,
      TaskPriority.high => AppColors.priorityHigh,
      TaskPriority.urgent => AppColors.priorityUrgent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('HH:mm');
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: <Widget>[
          // Цветная полоска приоритета
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: _priorityColor(),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          // Чекбокс
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              onToggle();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: task.isCompleted ? AppColors.accent : Colors.transparent,
                border: Border.all(
                  color: task.isCompleted ? AppColors.accent : AppColors.border,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: task.isCompleted
                  ? const Icon(Icons.check, size: 18, color: Colors.black)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Заголовок и метаданные
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLarge.copyWith(
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    color: task.isCompleted ? AppColors.textDisabled : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (task.dueDate != null || task.estimatedMinutes != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      if (task.dueDate != null) ...<Widget>[
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: task.isOverdue ? AppColors.error : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          fmt.format(task.dueDate!),
                          style: AppTextStyles.caption.copyWith(
                            color: task.isOverdue ? AppColors.error : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (task.estimatedMinutes != null) ...<Widget>[
                        const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('${task.estimatedMinutes} мин', style: AppTextStyles.caption),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (task.pomodoroCount > 0) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.timer_rounded, size: 12, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text('${task.pomodoroCount}', style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
