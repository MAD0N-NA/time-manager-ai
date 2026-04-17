import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../database/app_database.dart';

/// Приоритет задачи.
enum TaskPriority {
  low(0),
  medium(1),
  high(2),
  urgent(3);

  const TaskPriority(this.value);
  final int value;

  static TaskPriority fromValue(int v) =>
      TaskPriority.values.firstWhere((TaskPriority e) => e.value == v, orElse: () => TaskPriority.medium);

  String get label => switch (this) {
        TaskPriority.low => 'Низкий',
        TaskPriority.medium => 'Средний',
        TaskPriority.high => 'Высокий',
        TaskPriority.urgent => 'Срочно',
      };
}

/// Статус задачи.
enum TaskStatus {
  pending(0),
  inProgress(1),
  completed(2),
  cancelled(3);

  const TaskStatus(this.value);
  final int value;

  static TaskStatus fromValue(int v) =>
      TaskStatus.values.firstWhere((TaskStatus e) => e.value == v, orElse: () => TaskStatus.pending);
}

/// Доменная модель задачи.
@immutable
class TaskModel {
  const TaskModel({
    required this.id,
    required this.title,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.dueDate,
    this.startTime,
    this.endTime,
    this.projectId,
    this.categoryId,
    this.parentTaskId,
    this.isRecurring = false,
    this.recurrenceRule,
    this.tags = const <String>[],
    this.reminderMinutesBefore,
    this.completedAt,
    this.pomodoroCount = 0,
    this.estimatedMinutes,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final TaskPriority priority;
  final TaskStatus status;
  final String? projectId;
  final String? categoryId;
  final String? parentTaskId;
  final bool isRecurring;
  final String? recurrenceRule;
  final List<String> tags;
  final int? reminderMinutesBefore;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final int pomodoroCount;
  final int? estimatedMinutes;

  bool get isCompleted => status == TaskStatus.completed;
  bool get isOverdue =>
      dueDate != null && !isCompleted && dueDate!.isBefore(DateTime.now());

  factory TaskModel.fromRow(TaskRow row) {
    final List<dynamic> tagsList = jsonDecode(row.tags) as List<dynamic>;
    return TaskModel(
      id: row.id,
      title: row.title,
      description: row.description,
      dueDate: row.dueDate,
      startTime: row.startTime,
      endTime: row.endTime,
      priority: TaskPriority.fromValue(row.priority),
      status: TaskStatus.fromValue(row.status),
      projectId: row.projectId,
      categoryId: row.categoryId,
      parentTaskId: row.parentTaskId,
      isRecurring: row.isRecurring,
      recurrenceRule: row.recurrenceRule,
      tags: tagsList.map((dynamic e) => e.toString()).toList(),
      reminderMinutesBefore: row.reminderMinutesBefore,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      completedAt: row.completedAt,
      pomodoroCount: row.pomodoroCount,
      estimatedMinutes: row.estimatedMinutes,
    );
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    DateTime? startTime,
    DateTime? endTime,
    TaskPriority? priority,
    TaskStatus? status,
    String? projectId,
    String? categoryId,
    String? parentTaskId,
    bool? isRecurring,
    String? recurrenceRule,
    List<String>? tags,
    int? reminderMinutesBefore,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    int? pomodoroCount,
    int? estimatedMinutes,
    bool clearDueDate = false,
    bool clearCompletedAt = false,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      projectId: projectId ?? this.projectId,
      categoryId: categoryId ?? this.categoryId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      tags: tags ?? this.tags,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      pomodoroCount: pomodoroCount ?? this.pomodoroCount,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    );
  }

  TasksCompanion toCompanion() => TasksCompanion(
        id: Value<String>(id),
        title: Value<String>(title),
        description: Value<String?>(description),
        dueDate: Value<DateTime?>(dueDate),
        startTime: Value<DateTime?>(startTime),
        endTime: Value<DateTime?>(endTime),
        priority: Value<int>(priority.value),
        status: Value<int>(status.value),
        projectId: Value<String?>(projectId),
        categoryId: Value<String?>(categoryId),
        parentTaskId: Value<String?>(parentTaskId),
        isRecurring: Value<bool>(isRecurring),
        recurrenceRule: Value<String?>(recurrenceRule),
        tags: Value<String>(jsonEncode(tags)),
        reminderMinutesBefore: Value<int?>(reminderMinutesBefore),
        createdAt: Value<DateTime>(createdAt),
        updatedAt: Value<DateTime>(updatedAt),
        completedAt: Value<DateTime?>(completedAt),
        pomodoroCount: Value<int>(pomodoroCount),
        estimatedMinutes: Value<int?>(estimatedMinutes),
      );
}
