import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/errors/failures.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/repositories/ai_conversation_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../domain/use_cases/create_task_from_voice.dart';
import '../../tasks/presentation/widgets/task_form_sheet.dart';
import 'providers/chat_controller.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;
  bool _speechReady = false;

  static const List<String> _quickActions = <String>[
    'Запланируй мой день',
    'Проанализируй продуктивность',
    'Создай задачу: ',
    'Что самое важное сегодня?',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider.notifier).initIfNeeded();
    });
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechReady = await _speech.initialize(
      onError: (Object e) => debugPrint('Speech error: $e'),
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (!_speechReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Голосовой ввод недоступен')),
      );
      return;
    }
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
    } else {
      HapticFeedback.mediumImpact();
      setState(() => _listening = true);
      await _speech.listen(
        localeId: 'ru_RU',
        onResult: (SpeechRecognitionResult r) {
          setState(() => _input.text = r.recognizedWords);
          if (r.finalResult) {
            setState(() => _listening = false);
          }
        },
      );
    }
  }

  Future<void> _send([String? text]) async {
    final String message = (text ?? _input.text).trim();
    if (message.isEmpty) return;
    _input.clear();
    HapticFeedback.lightImpact();
    await ref.read(chatControllerProvider.notifier).sendMessage(message);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _createTaskFromText() async {
    final TextEditingController ctrl = TextEditingController();
    final String? text = await showDialog<String>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Создать задачу через AI'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Опиши задачу свободным текстом...',
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Создать')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await ref.read(createTaskFromVoiceUseCaseProvider).call(text);

    if (!mounted) return;
    Navigator.of(context).pop();

    await result.when<Future<void>>(
      success: (task) async {
        final edited = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          builder: (_) => TaskFormSheet(initial: task),
        );
        if (edited != null) {
          await ref.read(taskRepositoryProvider).create(edited);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Задача создана')),
            );
          }
        }
      },
      failure: (Failure f) async {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: ${f.message}')),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ChatState state = ref.watch(chatControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: <Widget>[
            Icon(Icons.auto_awesome, color: AppColors.accent, size: 22),
            SizedBox(width: 8),
            Text('AI-Ассистент'),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Новый разговор',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(chatControllerProvider.notifier).resetConversation(),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Быстрые команды
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _quickActions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (BuildContext c, int i) => ActionChip(
                avatar: const Icon(Icons.bolt, size: 16, color: AppColors.accent),
                label: Text(_quickActions[i]),
                onPressed: () {
                  if (i == 2) {
                    _createTaskFromText();
                  } else {
                    _send(_quickActions[i]);
                  }
                },
              ),
            ),
          ),
          // Сообщения
          Expanded(
            child: state.messages.isEmpty
                ? _Welcome(onCreateTask: _createTaskFromText)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: state.messages.length + (state.isLoading ? 1 : 0),
                    itemBuilder: (BuildContext c, int i) {
                      if (i >= state.messages.length) {
                        return const _TypingBubble();
                      }
                      final ChatMessage m = state.messages[i];
                      return _MessageBubble(message: m);
                    },
                  ),
          ),
          if (state.error != null)
            Container(
              color: AppColors.error.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.error!, style: AppTextStyles.bodySmall)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => ref.read(chatControllerProvider.notifier).clearError(),
                  ),
                ],
              ),
            ),
          // Поле ввода
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: _toggleListening,
                    icon: Icon(
                      _listening ? Icons.mic : Icons.mic_none,
                      color: _listening ? AppColors.accent : AppColors.textSecondary,
                      size: 28,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(
                        hintText: 'Спросите что-нибудь...',
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.accentGlow,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: state.isLoading ? null : () => _send(),
                      icon: const Icon(Icons.send_rounded, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onCreateTask});
  final VoidCallback onCreateTask;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                gradient: AppColors.accentGlow,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, size: 48, color: Colors.black),
            ),
            const SizedBox(height: 24),
            Text('Привет! Я ваш AI-ассистент', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Помогу спланировать день, проанализировать продуктивность или создать задачи из голоса.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateTask,
              icon: const Icon(Icons.add_task),
              label: const Text('Создать задачу через AI'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: <Color>[AppColors.primary, AppColors.primaryDark],
                )
              : null,
          color: isUser ? null : AppColors.surface,
          border: isUser ? null : Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: SelectableText(
          message.content,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isUser ? AppColors.textPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Думаю...'),
          ],
        ),
      ),
    );
  }
}
