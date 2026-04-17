import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/logger.dart';

/// Точка входа для WorkManager. Должна быть top-level и помечена как vm:entry-point.
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((String task, Map<String, dynamic>? inputData) async {
    debugPrint('Background task started: $task');
    try {
      switch (task) {
        case AppConstants.bgTaskHourlyAi:
          // Здесь можно поднять минимальный контейнер DI и запустить SmartRemindersUseCase
          // (полная реализация требует передачи API-ключа через secure storage)
          break;
        case AppConstants.bgTaskWeeklyReport:
          break;
        case AppConstants.bgTaskDailyDigest:
          break;
      }
      return true;
    } catch (e, st) {
      debugPrint('BG task failed: $e\n$st');
      return false;
    }
  });
}

/// Регистрирует фоновые задачи через WorkManager.
class BackgroundService {
  Future<void> init() async {
    await Workmanager().initialize(
      backgroundCallbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    appLogger.i('Workmanager initialized');
  }

  Future<void> registerPeriodicAiCheck() async {
    await Workmanager().registerPeriodicTask(
      AppConstants.bgTaskHourlyAi,
      AppConstants.bgTaskHourlyAi,
      frequency: const Duration(hours: 1),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  Future<void> registerWeeklyReport() async {
    await Workmanager().registerPeriodicTask(
      AppConstants.bgTaskWeeklyReport,
      AppConstants.bgTaskWeeklyReport,
      frequency: const Duration(days: 7),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  Future<void> cancelAll() => Workmanager().cancelAll();
}
