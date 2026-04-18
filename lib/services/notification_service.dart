import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/constants/app_constants.dart';
import '../core/utils/logger.dart';
import '../data/models/task_model.dart';

/// Сервис локальных уведомлений + точные напоминания через AlarmManager.
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      // На Android — берём системную таймзону через timezone package
      // (плагин flutter_timezone не используем чтобы избежать лишней зависимости)
      tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('ic_notification');
    const InitializationSettings settings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onNotificationBackgroundResponse,
    );

    await _createChannels();

    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    _initialized = true;
    appLogger.i('NotificationService initialized');
  }

  Future<void> _createChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(const AndroidNotificationChannel(
      AppConstants.notifChannelTasks,
      AppConstants.notifChannelTasksName,
      description: 'Напоминания о задачах и событиях',
      importance: Importance.high,
      enableVibration: true,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      AppConstants.notifChannelPomodoro,
      AppConstants.notifChannelPomodoroName,
      description: 'Сигналы Pomodoro-таймера',
      importance: Importance.high,
      enableVibration: true,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      AppConstants.notifChannelDigest,
      AppConstants.notifChannelDigestName,
      description: 'Утренние сводки и еженедельные отчёты',
      importance: Importance.defaultImportance,
    ));
  }

  Future<void> scheduleTaskReminder(TaskModel task) async {
    if (task.dueDate == null || task.reminderMinutesBefore == null) return;
    final DateTime when = task.dueDate!.subtract(Duration(minutes: task.reminderMinutesBefore!));
    if (when.isBefore(DateTime.now())) return;

    try {
      await _plugin.zonedSchedule(
        task.id.hashCode,
        'Скоро: ${task.title}',
        task.description ?? 'Не забудьте выполнить задачу',
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.notifChannelTasks,
            AppConstants.notifChannelTasksName,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_notification',
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction('complete', 'Выполнено', showsUserInterface: false),
              AndroidNotificationAction('snooze', 'Отложить 10 мин', showsUserInterface: false),
            ],
          ),
        ),
        payload: 'task:${task.id}',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      appLogger.w('scheduleTaskReminder failed: $e\n$st');
    }
  }

  Future<void> cancelTaskReminder(String taskId) async {
    try {
      await _plugin.cancel(taskId.hashCode);
    } catch (e) {
      appLogger.w('cancelTaskReminder failed: $e');
    }
  }

  Future<void> showPomodoroComplete({required String message}) async {
    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        'Pomodoro завершён',
        message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.notifChannelPomodoro,
            AppConstants.notifChannelPomodoroName,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_notification',
          ),
        ),
      );
    } catch (e, st) {
      appLogger.w('showPomodoroComplete failed: $e\n$st');
    }
  }

  Future<void> showSmartReminder({
    required String taskId,
    required String title,
    required String body,
    bool urgent = false,
  }) async {
    try {
      await _plugin.show(
        taskId.hashCode ^ DateTime.now().minute,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.notifChannelTasks,
            AppConstants.notifChannelTasksName,
            importance: urgent ? Importance.max : Importance.high,
            priority: urgent ? Priority.max : Priority.high,
            icon: 'ic_notification',
          ),
        ),
        payload: 'task:$taskId',
      );
    } catch (e, st) {
      appLogger.w('showSmartReminder failed: $e\n$st');
    }
  }

  Future<void> showDigest({required String title, required String body}) async {
    try {
      await _plugin.show(
        'digest'.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.notifChannelDigest,
            AppConstants.notifChannelDigestName,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: 'ic_notification',
            styleInformation: BigTextStyleInformation(''),
          ),
        ),
        payload: 'digest',
      );
    } catch (e, st) {
      appLogger.w('showDigest failed: $e\n$st');
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    appLogger.i('Notification tapped: ${response.payload}, action: ${response.actionId}');
    // Обработка через NotificationActionHandler из main.dart
  }

  @pragma('vm:entry-point')
  static void _onNotificationBackgroundResponse(NotificationResponse response) {
    debugPrint('BG notification: ${response.payload}, action: ${response.actionId}');
  }
}

final Provider<NotificationService> notificationServiceProvider =
    Provider<NotificationService>((Ref ref) {
  return NotificationService();
});
