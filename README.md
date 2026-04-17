# TimeManager AI

Flutter-приложение — тайм-менеджер с глубокой интеграцией Claude AI. Календарь-планировщик с задачами, событиями, Pomodoro, аналитикой продуктивности и умным AI-ассистентом.

## Возможности

- **Календарь** (table_calendar) — режимы Месяц / Неделя / День / Повестка, маркеры задач, долгое нажатие для быстрого создания
- **Задачи** — приоритеты, дедлайны, оценка времени, теги, swipe-действия (завершить/удалить), полнотекстовый поиск
- **Pomodoro** — настраиваемый таймер 25/5/15 мин, привязка к задаче, ежедневный счётчик
- **Статистика** — графики на fl_chart: выполнено по дням, распределение по приоритетам, streak, focus-time
- **AI-Ассистент** на Claude — чат, голосовой ввод, быстрые команды:
  - Создание задачи из произвольного текста (Claude Haiku)
  - Автопланирование дня с учётом приоритетов (Claude Opus)
  - Умные напоминания (фоновая задача)
  - Еженедельный анализ продуктивности
- **Локальные уведомления** — точные напоминания через AlarmManager, действия "Выполнено" / "Отложить"
- **Фоновая работа** — WorkManager для периодических AI-задач
- **Безопасность** — API-ключ хранится в Android Keystore через flutter_secure_storage

## Технический стек

- Flutter 3.19+ / Dart 3.3+
- Riverpod 2.x — DI и state management
- Drift (SQLite) — локальное хранилище
- go_router — навигация
- flutter_local_notifications + workmanager — уведомления и фон
- dio + flutter_secure_storage — Claude API
- speech_to_text — голосовой ввод
- fl_chart — графики
- table_calendar — календарь

## Цветовая схема

Строго чёрно-тёмнозелёная: фон `#0A0A0A`, поверхности `#121212`, акцент `#1B5E20`/`#4CAF50`, шрифт Inter (через Google Fonts).

## Установка и запуск

### 1. Требования

- Flutter SDK 3.19+ ([установка](https://docs.flutter.dev/get-started/install))
- Android Studio + Android SDK (compileSdk 34, minSdk 24)
- JDK 17

### 2. Сгенерировать платформенные папки

В свежем клоне сгенерируйте Android/iOS-папки (если они отсутствуют) и подтяните зависимости:

```bash
# из корня проекта
flutter create . --project-name time_manager_ai --org com.timemanager --platforms=android
flutter pub get
```

> Если предупреждения про существующие файлы — пропустите перезапись `android/app/src/main/AndroidManifest.xml`, `MainActivity.kt`, `build.gradle.kts` (они уже настроены).

### 3. Сгенерировать код Drift

```bash
dart run build_runner build --delete-conflicting-outputs
```

Это создаст файл `lib/data/database/app_database.g.dart`.

### 4. Получить API-ключ Claude

1. Откройте https://console.anthropic.com
2. Зарегистрируйтесь / войдите
3. Перейдите в раздел **API Keys** → **Create Key**
4. Скопируйте ключ вида `sk-ant-api03-...`

> **Важно**: ключ нигде не хардкодится. Его нужно ввести в приложении: **Календарь → ⚙️ Настройки → Claude API-ключ**. Хранится в Android Keystore.

### 5. Запуск

```bash
# отладка на подключённом устройстве/эмуляторе
flutter run

# release-сборка APK
flutter build apk --release
# результат: build/app/outputs/flutter-apk/app-release.apk
```

## Структура проекта

```
lib/
├── main.dart                       # точка входа, инициализация notifications/WorkManager
├── app.dart                        # корневой MaterialApp.router
├── core/                           # тема, константы, ошибки, роутер, утилиты
├── data/
│   ├── database/                   # Drift: app_database.dart + tables/
│   ├── models/                     # доменные модели
│   └── repositories/               # CRUD-обёртки над Drift
├── features/
│   ├── calendar/                   # календарь
│   ├── tasks/                      # задачи + детальный экран
│   ├── pomodoro/                   # таймер
│   ├── statistics/                 # графики
│   ├── ai_assistant/               # Claude API + 4 use-case'а + чат
│   ├── settings/                   # настройки
│   └── shell/                      # нижняя навигация
└── services/                       # NotificationService, BackgroundService, SettingsService
```

## Архитектура

**Clean Architecture + Feature-first**. Каждая фича делится на:
- `presentation/` — экраны и провайдеры состояния
- `domain/` — use-cases, чистая бизнес-логика
- `data/` — клиенты внешних API

DI — через Riverpod `Provider`. Никаких глобальных синглтонов.

Бизнес-ошибки — через `Result<T>` (sealed class из `core/errors/failures.dart`). Исключения только на границе с инфраструктурой.

## Уведомления и фоновая работа

В `AndroidManifest.xml` объявлены все необходимые разрешения:
- `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`
- `RECEIVE_BOOT_COMPLETED` — расписание восстанавливается после перезагрузки
- `RECORD_AUDIO`, `INTERNET`, `WAKE_LOCK`, `VIBRATE`

Запрос разрешений происходит при первом запуске (см. `NotificationService.init`).

## Тестирование

```bash
flutter test
```

Покрыты unit-тестами: парсинг JSON-ответов AI (`test/use_cases/`).

## Известные ограничения

- Фоновое выполнение AI-задач (`SmartReminders`) — каркас готов, но требует поднятия минимального DI-контейнера в isolate WorkManager. Сейчас выполняется только on-demand через UI.
- iOS-сборка не настроена (требование задачи — только Android).
- Иконки приложения — дефолтные Flutter (замените `android/app/src/main/res/mipmap-*/ic_launcher.png` на свои).

## Лицензия

MIT — используйте свободно.
