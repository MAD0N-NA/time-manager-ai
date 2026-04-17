import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

/// Простые пользовательские настройки.
class SettingsService {
  SettingsService(this._prefs);
  final SharedPreferences _prefs;

  String get model => _prefs.getString(AppConstants.prefsModelKey) ?? AppConstants.defaultModel;
  Future<void> setModel(String value) => _prefs.setString(AppConstants.prefsModelKey, value);

  int get workStartHour =>
      _prefs.getInt(AppConstants.prefsWorkStartHour) ?? AppConstants.defaultWorkStartHour;
  Future<void> setWorkStartHour(int v) => _prefs.setInt(AppConstants.prefsWorkStartHour, v);

  int get workEndHour =>
      _prefs.getInt(AppConstants.prefsWorkEndHour) ?? AppConstants.defaultWorkEndHour;
  Future<void> setWorkEndHour(int v) => _prefs.setInt(AppConstants.prefsWorkEndHour, v);

  int get dailyDigestHour =>
      _prefs.getInt(AppConstants.prefsDailyDigestHour) ?? AppConstants.defaultDailyDigestHour;
  Future<void> setDailyDigestHour(int v) => _prefs.setInt(AppConstants.prefsDailyDigestHour, v);

  int get pomodoroWorkMinutes =>
      _prefs.getInt(AppConstants.prefsPomodoroWork) ?? AppConstants.defaultPomodoroWork;
  Future<void> setPomodoroWorkMinutes(int v) => _prefs.setInt(AppConstants.prefsPomodoroWork, v);

  int get pomodoroShortBreak =>
      _prefs.getInt(AppConstants.prefsPomodoroShortBreak) ?? AppConstants.defaultPomodoroShortBreak;
  Future<void> setPomodoroShortBreak(int v) =>
      _prefs.setInt(AppConstants.prefsPomodoroShortBreak, v);

  int get pomodoroLongBreak =>
      _prefs.getInt(AppConstants.prefsPomodoroLongBreak) ?? AppConstants.defaultPomodoroLongBreak;
  Future<void> setPomodoroLongBreak(int v) =>
      _prefs.setInt(AppConstants.prefsPomodoroLongBreak, v);

  bool get onboardingComplete => _prefs.getBool(AppConstants.prefsOnboardingComplete) ?? false;
  Future<void> setOnboardingComplete(bool v) =>
      _prefs.setBool(AppConstants.prefsOnboardingComplete, v);
}

final FutureProvider<SharedPreferences> sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((Ref ref) async {
  return SharedPreferences.getInstance();
});

final Provider<SettingsService> settingsServiceProvider = Provider<SettingsService>((Ref ref) {
  final SharedPreferences prefs = ref.watch(sharedPreferencesProvider).requireValue;
  return SettingsService(prefs);
});
