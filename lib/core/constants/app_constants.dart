/// Глобальные константы приложения.
class AppConstants {
  AppConstants._();

  static const String appName = 'TimeManager AI';

  // Gemini API (Google AI Studio)
  // Базовый URL без модели — модель подставляется в клиенте.
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  static const String defaultModel = 'gemini-2.0-flash';
  static const String fastModel = 'gemini-2.0-flash-lite';

  // Хранилище
  static const String secureStorageApiKey = 'gemini_api_key';
  static const String prefsModelKey = 'gemini_model';
  static const String prefsWorkStartHour = 'work_start_hour';
  static const String prefsWorkEndHour = 'work_end_hour';
  static const String prefsDailyDigestHour = 'daily_digest_hour';
  static const String prefsPomodoroWork = 'pomodoro_work_minutes';
  static const String prefsPomodoroShortBreak = 'pomodoro_short_break_minutes';
  static const String prefsPomodoroLongBreak = 'pomodoro_long_break_minutes';
  static const String prefsOnboardingComplete = 'onboarding_complete';

  // Notifications
  static const String notifChannelTasks = 'task_reminders';
  static const String notifChannelTasksName = 'Task Reminders';
  static const String notifChannelPomodoro = 'pomodoro';
  static const String notifChannelPomodoroName = 'Pomodoro';
  static const String notifChannelDigest = 'digest';
  static const String notifChannelDigestName = 'Daily/Weekly Digest';

  // Background tasks
  static const String bgTaskHourlyAi = 'hourly_ai_check';
  static const String bgTaskWeeklyReport = 'weekly_ai_report';
  static const String bgTaskDailyDigest = 'daily_digest';

  // Defaults
  static const int defaultWorkStartHour = 9;
  static const int defaultWorkEndHour = 18;
  static const int defaultDailyDigestHour = 8;
  static const int defaultPomodoroWork = 25;
  static const int defaultPomodoroShortBreak = 5;
  static const int defaultPomodoroLongBreak = 15;
  static const int defaultReminderMinutesBefore = 15;
}
