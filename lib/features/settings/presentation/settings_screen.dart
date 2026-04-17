import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/database/app_database.dart';
import '../../ai_assistant/data/claude_api_client.dart';
import '../../../services/settings_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _hasKey = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadKeyState();
  }

  Future<void> _loadKeyState() async {
    final bool has = await ref.read(claudeApiClientProvider).hasApiKey();
    if (mounted) setState(() {
      _hasKey = has;
      _loading = false;
    });
  }

  Future<void> _editApiKey() async {
    final TextEditingController ctrl = TextEditingController();
    final String? key = await showDialog<String>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Claude API-ключ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Получите ключ на console.anthropic.com → API Keys.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'sk-ant-...',
                prefixIcon: Icon(Icons.key),
              ),
              autofocus: true,
              obscureText: true,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (key != null && key.isNotEmpty) {
      await ref.read(claudeApiClientProvider).saveApiKey(key);
      await _loadKeyState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API-ключ сохранён')),
        );
      }
    }
  }

  Future<void> _clearApiKey() async {
    await ref.read(claudeApiClientProvider).clearApiKey();
    await _loadKeyState();
  }

  Future<void> _exportData() async {
    final AppDatabase db = ref.read(appDatabaseProvider);
    final List<TaskRow> tasks = await db.select(db.tasks).get();
    final List<EventRow> events = await db.select(db.events).get();
    final List<ProjectRow> projects = await db.select(db.projects).get();

    final Map<String, Object?> data = <String, Object?>{
      'exportedAt': DateTime.now().toIso8601String(),
      'tasks': tasks.map((TaskRow t) => t.toJson()).toList(),
      'events': events.map((EventRow e) => e.toJson()).toList(),
      'projects': projects.map((ProjectRow p) => p.toJson()).toList(),
    };

    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/timemanager_export_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonEncode(data));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сохранено: ${file.path}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final SettingsService settings = ref.watch(settingsServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Text('AI', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _hasKey ? Icons.check_circle : Icons.key_off,
                          color: _hasKey ? AppColors.accent : AppColors.warning,
                        ),
                        title: const Text('Claude API-ключ'),
                        subtitle: Text(_hasKey ? 'Установлен' : 'Не задан'),
                        trailing: _hasKey
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: _clearApiKey,
                              )
                            : null,
                        onTap: _editApiKey,
                      ),
                      const Divider(height: 1, color: AppColors.divider),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.psychology_outlined),
                        title: const Text('Модель'),
                        subtitle: Text(settings.model),
                        trailing: PopupMenuButton<String>(
                          onSelected: (String v) async {
                            await settings.setModel(v);
                            if (mounted) setState(() {});
                          },
                          itemBuilder: (_) => const <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: AppConstants.defaultModel,
                              child: Text('Claude Opus 4.7'),
                            ),
                            PopupMenuItem<String>(
                              value: AppConstants.fastModel,
                              child: Text('Claude Haiku 4.5'),
                            ),
                          ],
                          icon: const Icon(Icons.more_vert),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Рабочий день', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    children: <Widget>[
                      _HourPicker(
                        label: 'Начало',
                        hour: settings.workStartHour,
                        onChanged: (int h) async {
                          await settings.setWorkStartHour(h);
                          setState(() {});
                        },
                      ),
                      const Divider(height: 1, color: AppColors.divider),
                      _HourPicker(
                        label: 'Окончание',
                        hour: settings.workEndHour,
                        onChanged: (int h) async {
                          await settings.setWorkEndHour(h);
                          setState(() {});
                        },
                      ),
                      const Divider(height: 1, color: AppColors.divider),
                      _HourPicker(
                        label: 'Утренняя сводка',
                        hour: settings.dailyDigestHour,
                        onChanged: (int h) async {
                          await settings.setDailyDigestHour(h);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Pomodoro', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    children: <Widget>[
                      _MinutesPicker(
                        label: 'Работа',
                        minutes: settings.pomodoroWorkMinutes,
                        options: const <int>[15, 20, 25, 30, 45, 60],
                        onChanged: (int v) async {
                          await settings.setPomodoroWorkMinutes(v);
                          setState(() {});
                        },
                      ),
                      const Divider(height: 1, color: AppColors.divider),
                      _MinutesPicker(
                        label: 'Короткий перерыв',
                        minutes: settings.pomodoroShortBreak,
                        options: const <int>[3, 5, 7, 10],
                        onChanged: (int v) async {
                          await settings.setPomodoroShortBreak(v);
                          setState(() {});
                        },
                      ),
                      const Divider(height: 1, color: AppColors.divider),
                      _MinutesPicker(
                        label: 'Длинный перерыв',
                        minutes: settings.pomodoroLongBreak,
                        options: const <int>[10, 15, 20, 30],
                        onChanged: (int v) async {
                          await settings.setPomodoroLongBreak(v);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Данные', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download),
                    title: const Text('Экспорт в JSON'),
                    onTap: _exportData,
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    '${AppConstants.appName} • v1.0.0',
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ),
    );
  }
}

class _HourPicker extends StatelessWidget {
  const _HourPicker({required this.label, required this.hour, required this.onChanged});
  final String label;
  final int hour;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: TextButton(
        onPressed: () async {
          final TimeOfDay? picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: hour, minute: 0),
          );
          if (picked != null) {
            HapticFeedback.selectionClick();
            onChanged(picked.hour);
          }
        },
        child: Text('${hour.toString().padLeft(2, '0')}:00',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent)),
      ),
    );
  }
}

class _MinutesPicker extends StatelessWidget {
  const _MinutesPicker({
    required this.label,
    required this.minutes,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int minutes;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: DropdownButton<int>(
        value: options.contains(minutes) ? minutes : options.first,
        underline: const SizedBox.shrink(),
        items: options
            .map((int v) => DropdownMenuItem<int>(value: v, child: Text('$v мин')))
            .toList(),
        onChanged: (int? v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
