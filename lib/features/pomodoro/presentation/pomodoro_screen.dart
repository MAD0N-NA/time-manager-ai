import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/repositories/pomodoro_repository.dart';
import '../../../services/notification_service.dart';
import '../../../services/settings_service.dart';

enum PomodoroState { idle, running, paused, completed }

class PomodoroController extends StateNotifier<PomodoroSnapshot> {
  PomodoroController(this._repo, this._notif, this._settings)
      : super(PomodoroSnapshot.initial(_settings.pomodoroWorkMinutes));

  final PomodoroRepository _repo;
  final NotificationService _notif;
  final SettingsService _settings;
  Timer? _timer;
  String? _sessionId;

  Future<void> start({String? taskId}) async {
    if (state.state == PomodoroState.running) return;
    HapticFeedback.mediumImpact();
    final int duration = _durationForType(state.type);
    _sessionId = await _repo.startSession(
      type: state.type,
      durationMinutes: duration,
      taskId: taskId,
    );
    state = state.copyWith(state: PomodoroState.running, totalSeconds: duration * 60);
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(state: PomodoroState.paused);
  }

  void resume() {
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    state = state.copyWith(state: PomodoroState.running);
  }

  void reset() {
    _timer?.cancel();
    state = PomodoroSnapshot.initial(_durationForType(state.type), type: state.type);
  }

  void switchType(PomodoroType type) {
    _timer?.cancel();
    state = PomodoroSnapshot.initial(_durationForType(type), type: type);
  }

  int _durationForType(PomodoroType type) => switch (type) {
        PomodoroType.work => _settings.pomodoroWorkMinutes,
        PomodoroType.shortBreak => _settings.pomodoroShortBreak,
        PomodoroType.longBreak => _settings.pomodoroLongBreak,
      };

  void _tick(Timer t) {
    if (state.elapsedSeconds + 1 >= state.totalSeconds) {
      _timer?.cancel();
      state = state.copyWith(elapsedSeconds: state.totalSeconds, state: PomodoroState.completed);
      _onComplete();
    } else {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    }
  }

  Future<void> _onComplete() async {
    HapticFeedback.heavyImpact();
    if (_sessionId != null) {
      await _repo.completeSession(_sessionId!);
      _sessionId = null;
    }
    final String label = switch (state.type) {
      PomodoroType.work => 'Работа завершена! Время для перерыва.',
      PomodoroType.shortBreak => 'Перерыв окончен. Возвращаемся к работе!',
      PomodoroType.longBreak => 'Длинный перерыв окончен!',
    };
    await _notif.showPomodoroComplete(message: label);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class PomodoroSnapshot {
  PomodoroSnapshot({
    required this.type,
    required this.elapsedSeconds,
    required this.totalSeconds,
    required this.state,
  });

  factory PomodoroSnapshot.initial(int minutes, {PomodoroType type = PomodoroType.work}) =>
      PomodoroSnapshot(
        type: type,
        elapsedSeconds: 0,
        totalSeconds: minutes * 60,
        state: PomodoroState.idle,
      );

  final PomodoroType type;
  final int elapsedSeconds;
  final int totalSeconds;
  final PomodoroState state;

  double get progress => totalSeconds == 0 ? 0 : elapsedSeconds / totalSeconds;
  int get remainingSeconds => totalSeconds - elapsedSeconds;

  PomodoroSnapshot copyWith({
    PomodoroType? type,
    int? elapsedSeconds,
    int? totalSeconds,
    PomodoroState? state,
  }) =>
      PomodoroSnapshot(
        type: type ?? this.type,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        totalSeconds: totalSeconds ?? this.totalSeconds,
        state: state ?? this.state,
      );
}

final StateNotifierProvider<PomodoroController, PomodoroSnapshot> pomodoroControllerProvider =
    StateNotifierProvider<PomodoroController, PomodoroSnapshot>((Ref ref) {
  return PomodoroController(
    ref.watch(pomodoroRepositoryProvider),
    ref.watch(notificationServiceProvider),
    ref.watch(settingsServiceProvider),
  );
});

final FutureProvider<int> pomodoroTodayCountProvider = FutureProvider<int>((Ref ref) {
  return ref.watch(pomodoroRepositoryProvider).countTodayCompleted();
});

class PomodoroScreen extends ConsumerWidget {
  const PomodoroScreen({super.key});

  String _format(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PomodoroSnapshot snap = ref.watch(pomodoroControllerProvider);
    final PomodoroController ctrl = ref.read(pomodoroControllerProvider.notifier);
    final AsyncValue<int> todayCount = ref.watch(pomodoroTodayCountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pomodoro')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            // Переключатель типа
            SegmentedButton<PomodoroType>(
              segments: const <ButtonSegment<PomodoroType>>[
                ButtonSegment<PomodoroType>(value: PomodoroType.work, label: Text('Работа')),
                ButtonSegment<PomodoroType>(value: PomodoroType.shortBreak, label: Text('Короткий')),
                ButtonSegment<PomodoroType>(value: PomodoroType.longBreak, label: Text('Длинный')),
              ],
              selected: <PomodoroType>{snap.type},
              showSelectedIcon: false,
              onSelectionChanged: snap.state == PomodoroState.running
                  ? null
                  : (Set<PomodoroType> s) => ctrl.switchType(s.first),
            ),
            const SizedBox(height: 32),
            // Круговой таймер
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      CustomPaint(
                        size: Size.infinite,
                        painter: _CircularTimerPainter(progress: snap.progress),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(_format(snap.remainingSeconds),
                              style: AppTextStyles.displayLarge.copyWith(fontSize: 56)),
                          const SizedBox(height: 8),
                          Text(
                            switch (snap.type) {
                              PomodoroType.work => 'Фокус',
                              PomodoroType.shortBreak => 'Короткий перерыв',
                              PomodoroType.longBreak => 'Длинный перерыв',
                            },
                            style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (snap.state == PomodoroState.idle || snap.state == PomodoroState.completed)
                  _ActionButton(icon: Icons.play_arrow, onPressed: () => ctrl.start(), label: 'Старт'),
                if (snap.state == PomodoroState.running)
                  _ActionButton(icon: Icons.pause, onPressed: ctrl.pause, label: 'Пауза'),
                if (snap.state == PomodoroState.paused) ...<Widget>[
                  _ActionButton(icon: Icons.play_arrow, onPressed: ctrl.resume, label: 'Продолжить'),
                  const SizedBox(width: 12),
                  _ActionButton(
                    icon: Icons.stop,
                    onPressed: ctrl.reset,
                    label: 'Стоп',
                    secondary: true,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Row(
                children: <Widget>[
                  const Icon(Icons.local_fire_department, color: AppColors.accent, size: 28),
                  const SizedBox(width: 12),
                  Text('Сессий сегодня:', style: AppTextStyles.bodyMedium),
                  const Spacer(),
                  Text(
                    todayCount.maybeWhen(data: (int v) => v.toString(), orElse: () => '—'),
                    style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.onPressed,
    required this.label,
    this.secondary = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String label;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: secondary
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            )
          : FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}

class _CircularTimerPainter extends CustomPainter {
  _CircularTimerPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 16;

    final Paint trackPaint = Paint()
      ..color = AppColors.surfaceElevated
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawCircle(center, radius, trackPaint);

    final Paint progressPaint = Paint()
      ..shader = const SweepGradient(
        colors: <Color>[AppColors.accent, AppColors.primary],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 14;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularTimerPainter old) => old.progress != progress;
}
