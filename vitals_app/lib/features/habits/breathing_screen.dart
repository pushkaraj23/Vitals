import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide Baseline;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../providers/providers.dart';

enum _Phase { idle, running, paused, done }

/// Guided breathing: an expanding circle for inhale and exhale.
class BreathingScreen extends ConsumerStatefulWidget {
  const BreathingScreen({super.key});

  @override
  ConsumerState<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends ConsumerState<BreathingScreen> {
  static const _inhaleSeconds = 4;
  static const _exhaleSeconds = 6;
  static const _cycleSeconds = _inhaleSeconds + _exhaleSeconds;
  static const _choices = [1, 3, 5];

  int _minutes = 3;
  _Phase _phase = _Phase.idle;
  int _elapsed = 0;
  Timer? _timer;

  int get _total => _minutes * 60;
  int get _inCycle => _elapsed % _cycleSeconds;
  bool get _inhaling => _inCycle < _inhaleSeconds;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _phase = _Phase.running;
      _elapsed = 0;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed++;
        if (_elapsed >= _total) {
          _phase = _Phase.done;
          _timer?.cancel();
        }
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _phase = _Phase.paused);
  }

  void _resume() {
    setState(() => _phase = _Phase.running);
    _startTimer();
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _phase = _Phase.idle;
      _elapsed = 0;
    });
  }

  Future<void> _logHabit() async {
    final habits = ref.read(habitsProvider).value ?? const [];
    final match = habits.where((h) => h.id.contains('breathing')).toList();
    if (match.isEmpty) {
      showSnack(context, 'Nice session. No breathing habit in your plan yet.');
      return;
    }
    final habit = match.first;
    if (habit.isDoneOn(DateTime.now())) {
      showSnack(context, '"${habit.title}" is already done for today.');
      return;
    }
    try {
      await ref.read(habitsProvider.notifier).toggle(habit.id);
      if (mounted) showSnack(context, 'Logged "${habit.title}" for today.');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not log the habit. Try again.');
    }
  }

  String _clock(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Breathing')),
      body: SafeArea(
        child: CenteredBody(
          maxWidth: 560,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_phase == _Phase.idle) ..._idle(),
              if (_phase == _Phase.running || _phase == _Phase.paused)
                ..._session(),
              if (_phase == _Phase.done) ..._done(),
              const SizedBox(height: 24),
              Text(
                'Breathe gently. If you feel light-headed, return to normal '
                'breathing and stop.',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _idle() {
    return [
      const SizedBox(height: 12),
      Text('Take a calm minute', style: AppText.screenTitle),
      const SizedBox(height: 8),
      Text(
        'Breathe in for $_inhaleSeconds seconds, out for $_exhaleSeconds. '
        'Follow the circle.',
        style: AppText.bodyMuted,
      ),
      const SizedBox(height: 24),
      Center(child: _Circle(size: 150, label: 'Ready', animate: false, duration: Duration.zero)),
      const SizedBox(height: 28),
      Text('How long?', style: AppText.label),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (final m in _choices)
            AppChip(
              label: '$m min',
              selected: _minutes == m,
              onTap: () => setState(() => _minutes = m),
            ),
        ],
      ),
      const SizedBox(height: 24),
      PillButton(
        label: 'Start $_minutes-minute session',
        icon: Icons.play_arrow_rounded,
        onPressed: _start,
      ),
    ];
  }

  List<Widget> _session() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final running = _phase == _Phase.running;
    final phaseSeconds = _inhaling ? _inhaleSeconds : _exhaleSeconds;
    final secondsLeftInPhase =
        _inhaling ? _inhaleSeconds - _inCycle : _cycleSeconds - _inCycle;
    final label = !running
        ? 'Paused'
        : _inhaling
            ? 'Breathe in'
            : 'Breathe out';
    final big = running && _inhaling;
    final size = reduce ? 200.0 : (big || !running && _inhaling ? 260.0 : 150.0);

    return [
      const SizedBox(height: 12),
      Center(
        child: SizedBox(
          height: 300,
          child: Center(
            child: _Circle(
              size: size,
              label: label,
              sublabel: running ? '$secondsLeftInPhase' : null,
              animate: !reduce,
              duration: reduce ? Duration.zero : Duration(seconds: phaseSeconds),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          '${_clock(_total - _elapsed)} left',
          style: AppText.sectionTitle,
        ),
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: _elapsed / _total,
          minHeight: 6,
          backgroundColor: AppColors.line,
          color: AppColors.ink,
        ),
      ),
      if (reduce) ...[
        const SizedBox(height: 8),
        Text(
          'Animations are reduced, so the circle stays still. Follow the words.',
          style: AppText.caption,
          textAlign: TextAlign.center,
        ),
      ],
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: PillButton(
              label: 'Stop',
              icon: Icons.stop_rounded,
              variant: PillButtonVariant.secondary,
              onPressed: _stop,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PillButton(
              label: running ? 'Pause' : 'Resume',
              icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
              onPressed: running ? _pause : _resume,
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _done() {
    return [
      const SizedBox(height: 24),
      Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(
            color: AppColors.mintCard,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 56, color: AppColors.flagGreen),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        'Well done',
        style: AppText.screenTitle,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        'You finished $_minutes ${_minutes == 1 ? 'minute' : 'minutes'} of slow breathing.',
        style: AppText.bodyMuted,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      PillButton(
        label: 'Log as today\'s habit',
        icon: Icons.check_circle_outline_rounded,
        onPressed: _logHabit,
      ),
      const SizedBox(height: 12),
      PillButton(
        label: 'Go again',
        variant: PillButtonVariant.secondary,
        onPressed: _stop,
      ),
    ];
  }
}

class _Circle extends StatelessWidget {
  const _Circle({
    required this.size,
    required this.label,
    required this.animate,
    required this.duration,
    this.sublabel,
  });

  final double size;
  final String label;
  final String? sublabel;
  final bool animate;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: sublabel == null ? label : '$label, $sublabel',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: animate ? duration : Duration.zero,
        curve: Curves.easeInOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.skyCard,
          border: Border.all(color: AppColors.accent, width: 6),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppText.cardTitle),
            if (sublabel != null)
              Text(sublabel!, style: AppText.bigNumber.copyWith(fontSize: 28)),
          ],
        ),
      ),
    );
  }
}
