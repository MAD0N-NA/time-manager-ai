import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/models/task_model.dart';

/// Bottom sheet для создания/редактирования задачи.
class TaskFormSheet extends StatefulWidget {
  const TaskFormSheet({this.initial, super.key});
  final TaskModel? initial;

  @override
  State<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<TaskFormSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _estimateCtrl;
  late TaskPriority _priority;
  DateTime? _dueDate;
  int? _reminderMinutes;

  @override
  void initState() {
    super.initState();
    final TaskModel? init = widget.initial;
    _titleCtrl = TextEditingController(text: init?.title ?? '');
    _descCtrl = TextEditingController(text: init?.description ?? '');
    _estimateCtrl = TextEditingController(text: init?.estimatedMinutes?.toString() ?? '');
    _priority = init?.priority ?? TaskPriority.medium;
    _dueDate = init?.dueDate;
    _reminderMinutes = init?.reminderMinutesBefore;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _estimateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate ?? now),
    );
    if (time == null) return;

    setState(() {
      _dueDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название задачи')),
      );
      return;
    }
    HapticFeedback.mediumImpact();

    final TaskModel task = (widget.initial ??
            TaskModel(
              id: const Uuid().v4(),
              title: '',
              priority: TaskPriority.medium,
              status: TaskStatus.pending,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ))
        .copyWith(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      priority: _priority,
      dueDate: _dueDate,
      clearDueDate: _dueDate == null,
      reminderMinutesBefore: _reminderMinutes,
      estimatedMinutes: int.tryParse(_estimateCtrl.text),
      updatedAt: DateTime.now(),
    );
    Navigator.of(context).pop(task);
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.initial == null ? 'Новая задача' : 'Изменить задачу',
                style: AppTextStyles.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Название', hintText: 'Например, написать отчёт'),
              autofocus: widget.initial == null,
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Описание', hintText: 'Необязательно'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Text('Приоритет', style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: TaskPriority.values
                  .map(
                    (TaskPriority p) => ChoiceChip(
                      label: Text(p.label),
                      selected: _priority == p,
                      onSelected: (_) => setState(() => _priority = p),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event),
                    label: Text(_dueDate == null
                        ? 'Срок'
                        : DateFormat('d MMM HH:mm', 'ru').format(_dueDate!)),
                  ),
                ),
                if (_dueDate != null) ...<Widget>[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => _dueDate = null),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _estimateCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Оценка (мин)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _reminderMinutes,
                    decoration: const InputDecoration(labelText: 'Напомнить'),
                    items: const <DropdownMenuItem<int?>>[
                      DropdownMenuItem<int?>(value: null, child: Text('Нет')),
                      DropdownMenuItem<int?>(value: 1, child: Text('за 1 мин')),
                      DropdownMenuItem<int?>(value: 5, child: Text('за 5 мин')),
                      DropdownMenuItem<int?>(value: 15, child: Text('за 15 мин')),
                      DropdownMenuItem<int?>(value: 30, child: Text('за 30 мин')),
                      DropdownMenuItem<int?>(value: 60, child: Text('за час')),
                      DropdownMenuItem<int?>(value: 1440, child: Text('за сутки')),
                    ],
                    onChanged: (int? v) => setState(() => _reminderMinutes = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}
