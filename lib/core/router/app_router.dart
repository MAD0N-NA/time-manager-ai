import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_assistant/presentation/ai_assistant_screen.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/pomodoro/presentation/pomodoro_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/statistics/presentation/statistics_screen.dart';
import '../../features/tasks/presentation/task_detail_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/shell/main_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRoutes {
  static const String calendar = '/calendar';
  static const String tasks = '/tasks';
  static const String aiAssistant = '/ai';
  static const String pomodoro = '/pomodoro';
  static const String statistics = '/statistics';
  static const String settings = '/settings';
  static const String taskDetail = '/tasks/:id';

  static String taskDetailPath(String id) => '/tasks/$id';
}

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.calendar,
    routes: <RouteBase>[
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return MainShell(child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.calendar,
            pageBuilder: (BuildContext c, GoRouterState s) =>
                const NoTransitionPage<void>(child: CalendarScreen()),
          ),
          GoRoute(
            path: AppRoutes.tasks,
            pageBuilder: (BuildContext c, GoRouterState s) =>
                const NoTransitionPage<void>(child: TasksScreen()),
          ),
          GoRoute(
            path: AppRoutes.aiAssistant,
            pageBuilder: (BuildContext c, GoRouterState s) =>
                const NoTransitionPage<void>(child: AiAssistantScreen()),
          ),
          GoRoute(
            path: AppRoutes.pomodoro,
            pageBuilder: (BuildContext c, GoRouterState s) =>
                const NoTransitionPage<void>(child: PomodoroScreen()),
          ),
          GoRoute(
            path: AppRoutes.statistics,
            pageBuilder: (BuildContext c, GoRouterState s) =>
                const NoTransitionPage<void>(child: StatisticsScreen()),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext c, GoRouterState s) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.taskDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext c, GoRouterState s) =>
            TaskDetailScreen(taskId: s.pathParameters['id']!),
      ),
    ],
  );
}

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) => buildRouter());
