import 'package:flutter/material.dart';

/// Цветовая палитра приложения — строго чёрно-тёмнозелёная.
class AppColors {
  AppColors._();

  // Основные фоновые цвета
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF121212);
  static const Color surfaceElevated = Color(0xFF1A1F1B);

  // Акценты — тёмно-зелёный
  static const Color primary = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFF2E7D32);
  static const Color primaryDark = Color(0xFF0D3311);
  static const Color accent = Color(0xFF4CAF50);

  // Текст
  static const Color textPrimary = Color(0xFFE8F5E9);
  static const Color textSecondary = Color(0xFF81C784);
  static const Color textDisabled = Color(0xFF4A5D4F);

  // Состояния
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFCF6679);
  static const Color info = Color(0xFF4FC3F7);

  // Границы и разделители
  static const Color divider = Color(0xFF1F2E23);
  static const Color border = Color(0xFF2A3D30);

  // Приоритеты задач
  static const Color priorityLow = Color(0xFF66BB6A);
  static const Color priorityMedium = Color(0xFFFFA726);
  static const Color priorityHigh = Color(0xFFFF7043);
  static const Color priorityUrgent = Color(0xFFEF5350);

  // Градиенты
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF000000),
      Color(0xFF0D3311),
      Color(0xFF1B5E20),
    ],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF121212),
      Color(0xFF1A1F1B),
    ],
  );

  static const LinearGradient accentGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF2E7D32),
      Color(0xFF4CAF50),
    ],
  );
}
