/// Глобальные константы приложения.
class AppConstants {
  AppConstants._();

  static const String appName = 'TimeManager AI';

  // OpenRouter (OpenAI-совместимый API, работает из РФ без VPN)
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  // Бесплатные модели — суффикс :free
  static const String defaultModel = 'deepseek/deepseek-chat:free';
  static const String fastModel = 'meta-llama/llama-3.3-70b-instruct:free';

  // Хранилище
  static const String secureStorageApiKey = 'openrouter_api_key';
  static const String prefsModelKey = 'ai_model';
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
