import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/project_model.dart';

const Uuid _uuid = Uuid();

class ProjectRepository {
  ProjectRepository(this._db);
  final AppDatabase _db;

  Stream<List<ProjectModel>> watchAll() {
    return _db.select(_db.projects).watch().map(
          (List<ProjectRow> rows) => rows.map(ProjectModel.fromRow).toList(),
        );
  }

  Future<ProjectModel> create(ProjectModel project) async {
    final ProjectModel withId = project.id.isEmpty
        ? ProjectModel(
            id: _uuid.v4(),
            name: project.name,
            description: project.description,
            color: project.color,
            icon: project.icon,
            startDate: project.startDate,
            deadline: project.deadline,
            status: project.status,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
        : project;
    await _db.into(_db.projects).insert(withId.toCompanion());
    return withId;
  }

  Future<void> delete(String id) =>
      (_db.delete(_db.projects)..where(($ProjectsTable p) => p.id.equals(id))).go();
}

final Provider<ProjectRepository> projectRepositoryProvider = Provider<ProjectRepository>((Ref ref) {
  return ProjectRepository(ref.watch(appDatabaseProvider));
});
