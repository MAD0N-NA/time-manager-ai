import 'package:flutter/foundation.dart';

import '../database/app_database.dart';

enum ProjectStatus {
  active(0),
  archived(1),
  completed(2);

  const ProjectStatus(this.value);
  final int value;

  static ProjectStatus fromValue(int v) =>
      ProjectStatus.values.firstWhere((ProjectStatus e) => e.value == v, orElse: () => ProjectStatus.active);
}

@immutable
class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.name,
    required this.color,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.icon,
    this.startDate,
    this.deadline,
  });

  final String id;
  final String name;
  final String? description;
  final int color;
  final String? icon;
  final DateTime? startDate;
  final DateTime? deadline;
  final ProjectStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProjectModel.fromRow(ProjectRow row) => ProjectModel(
        id: row.id,
        name: row.name,
        description: row.description,
        color: row.color,
        icon: row.icon,
        startDate: row.startDate,
        deadline: row.deadline,
        status: ProjectStatus.fromValue(row.status),
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  ProjectsCompanion toCompanion() => ProjectsCompanion(
        id: Value<String>(id),
        name: Value<String>(name),
        description: Value<String?>(description),
        color: Value<int>(color),
        icon: Value<String?>(icon),
        startDate: Value<DateTime?>(startDate),
        deadline: Value<DateTime?>(deadline),
        status: Value<int>(status.value),
        createdAt: Value<DateTime>(createdAt),
        updatedAt: Value<DateTime>(updatedAt),
      );
}
