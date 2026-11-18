import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Baseline;

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/metric_format.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/daily_reading.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/habit.dart';
import '../../providers/providers.dart';

/// At most this many habits can be active at once.
const maxActiveHabits = 3;

/// Which habits are in the active plan. `null` means "the first three".
/// Resets when the persona changes.
class ActiveHabitIdsNotifier extends Notifier<Set<String>?> {
  @override
  Set<String>? build() {
    ref.watch(personaIdProvider);
    return null;
  }

  Set<String> resolve(List<Habit> habits) =>
      state ?? habits.take(maxActiveHabits).map((h) => h.id).toSet();

  void activate(List<Habit> habits, String id) {
    final next = {...resolve(habits), id};
    if (next.length <= maxActiveHabits) state = next;
  }

  void pause(List<Habit> habits, String id) {
    state = {...resolve(habits)}..remove(id);
  }
}

final activeHabitIdsProvider =
    NotifierProvider<ActiveHabitIdsNotifier, Set<String>?>(
      ActiveHabitIdsNotifier.new,
    );

class _Suggestion {
  const _Suggestion(this.id, this.title, this.subtitle, this.domain, this.days);

  final String id;
  final String title;
  final String subtitle;
  final HealthDomain domain;
  final int days;
}

const _suggestions = <_Suggestion>[
  _Suggestion('s_wind_down', 'Screens off 30 minutes before bed',
      'A calmer wind-down can make settling easier', HealthDomain.sleep, 5),
  _Suggestion('s_regular_wake', 'Wake at the same time',
      'A steady wake time supports a steady body clock', HealthDomain.sleep, 6),
  _Suggestion('s_walk', '15-minute walk',
      'Gentle movement most days of the week', HealthDomain.activity, 5),
  _Suggestion('s_stairs', 'Take the stairs',
      'Small bursts of movement through the day', HealthDomain.activity, 5),
  _Suggestion('s_breathing', '3-minute breathing break',
      'Slow breathing once a day', HealthDomain.stressRecovery, 5),
  _Suggestion('s_unplug', 'Short break from screens',
      'Step away for five minutes every couple of hours',
      HealthDomain.stressRecovery, 5),
  _Suggestion('s_water', 'Drink water through the day',
      'Keep a bottle within reach', HealthDomain.heart, 7),
  _Suggestion('s_stretch', 'Easy stretching',
      'Five minutes to loosen up after sitting', HealthDomain.heart, 4),
  _Suggestion('s_fresh_air', 'Fresh-air break',
      'A few minutes outside, breathing easy', HealthDomain.respiratory, 5),
];

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  HealthDomain? _category;

  Future<void> _toggle(Habit habit) async {
    try {
      await ref.read(habitsProvider.notifier).toggle(habit.id);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not update "${habit.title}". Try again.');
    }
  }

  Future<void> _add(List<Habit> habits, _Suggestion s) async {
    final active = ref.read(activeHabitIdsProvider.notifier).resolve(habits);
    if (active.length >= maxActiveHabits) {
      showSnack(context, 'You have $maxActiveHabits active habits. Pause one first.');
      return;
    }
    final habit = Habit(
      id: s.id,
      title: s.title,
      subtitle: s.subtitle,
      domain: s.domain,
      targetDaysPerWeek: s.days,
    );
    try {
      await ref.read(habitsProvider.notifier).add(habit);
      ref.read(activeHabitIdsProvider.notifier).activate([...habits, habit], s.id);
      if (mounted) showSnack(context, 'Added "${s.title}" to your plan.');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not add the habit. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider);
    // Rebuild when the active selection changes.
    ref.watch(activeHabitIdsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CenteredBody(
          child: habitsAsync.when(
            loading: () => const ListSkeleton(),
            error: (e, _) => FeatureError(
              what: 'your habits',
              onRetry: () => ref.invalidate(habitsProvider),
            ),
            data: _buildData,
          ),
        ),
      ),
    );
  }

  Widget _buildData(List<Habit> habits) {
    final activeIds = ref.read(activeHabitIdsProvider.notifier).resolve(habits);
    final active = [for (final h in habits) if (activeIds.contains(h.id)) h];
    final paused = [for (final h in habits) if (!activeIds.contains(h.id)) h];
    final atLimit = active.length >= maxActiveHabits;
    final doneToday = active.where((h) => h.isDoneOn(DateTime.now())).length;
    final bestStreak = active.isEmpty
        ? 0
        : active.map((h) => h.currentStreak()).reduce((a, b) => a > b ? a : b);

    final existingIds = habits.map((h) => h.id).toSet();
    final suggestions = [
      for (final s in _suggestions)
        if (!existingIds.contains(s.id) &&
            (_category == null || s.domain == _category))
          s,
    ];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(habitsProvider);
        try {
          await ref.read(habitsProvider.future);
        } catch (_) {}
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text('Habits', style: AppText.screenTitle),
          const SizedBox(height: 4),
          Text(
            'A few small goals beat a long list. Pick up to $maxActiveHabits.',
            style: AppText.bodyMuted,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  background: AppColors.mintCard,
                  icon: Icons.local_fire_department_rounded,
                  value: '$bestStreak',
                  label: bestStreak == 1 ? 'day streak' : 'day streak (best)',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  background: AppColors.creamCard,
                  icon: Icons.check_circle_rounded,
                  value: '$doneToday/${active.length}',
                  label: 'done today',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionHeader(title: 'Your plan · ${active.length}/$maxActiveHabits'),
          const SizedBox(height: 12),
          if (active.isEmpty)
            SoftSurface(
              child: EmptyState(
                title: 'No active habits',
                message: 'Choose a suggestion below to start your plan.',
                icon: Icons.spa_outlined,
              ),
            )
          else
            for (final h in active)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HabitCard(
                  habit: h,
                  onToggle: () => _toggle(h),
                  onPause: () => ref
                      .read(activeHabitIdsProvider.notifier)
                      .pause(habits, h.id),
                ),
              ),
          if (atLimit)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.creamCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You have $maxActiveHabits active habits, which is the '
                      'limit. Pause one to add another.',
                      style: AppText.caption.copyWith(color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          _ImpactCard(active: active),
          const SizedBox(height: 20),
          _BreathingLinkCard(onTap: () => context.push(AppRoutes.breathing)),
          if (paused.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: 'Paused'),
            const SizedBox(height: 12),
            for (final h in paused)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftSurface(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Icon(h.domain.icon, color: AppColors.muted),
                      const SizedBox(width: 12),
                      Expanded(child: Text(h.title, style: AppText.body)),
                      TextButton(
                        onPressed: atLimit
                            ? null
                            : () => ref
                                  .read(activeHabitIdsProvider.notifier)
                                  .activate(habits, h.id),
                        child: const Text('Resume'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          const SectionHeader(title: 'Suggested habits'),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                AppChip(
                  label: 'All',
                  selected: _category == null,
                  onTap: () => setState(() => _category = null),
                ),
                for (final d in HealthDomain.values) ...[
                  const SizedBox(width: 8),
                  AppChip(
                    label: d.label,
                    icon: d.icon,
                    selected: _category == d,
                    onTap: () => setState(() => _category = d),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (suggestions.isEmpty)
            const SoftSurface(
              child: EmptyState(
                title: 'No more suggestions here',
                message: 'Try another category.',
                icon: Icons.lightbulb_outline_rounded,
              ),
            )
          else
            for (final s in suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftSurface(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.lavenderCard,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(s.domain.icon, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title, style: AppText.cardTitle),
                            Text(s.subtitle, style: AppText.caption),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      PillButton(
                        label: 'Add',
                        expanded: false,
                        height: 40,
                        variant: PillButtonVariant.secondary,
                        onPressed: atLimit ? null : () => _add(habits, s),
                      ),
                    ],
                  ),
                ),
              ),
          if (atLimit && suggestions.isNotEmpty)
            Text(
              'Adding is switched off until you pause a habit.',
              style: AppText.caption,
            ),
          const SizedBox(height: 16),
          const DisclaimerBanner(),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.background,
    required this.icon,
    required this.value,
    required this.label,
  });

  final Color background;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      color: background,
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppText.bigNumber.copyWith(fontSize: 26)),
                Text(label, style: AppText.caption.copyWith(color: AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.onToggle,
    required this.onPause,
  });

  final Habit habit;
  final VoidCallback onToggle;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final done = habit.isDoneOn(DateTime.now());
    final week = habit.completionsThisWeek();
    final target = habit.targetDaysPerWeek;
    final progress = target == 0 ? 0.0 : (week / target).clamp(0.0, 1.0);
    final streak = habit.currentStreak();
    final isBreathing = habit.id.contains('breathing');

    return SoftSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.title, style: AppText.cardTitle),
                    const SizedBox(height: 2),
                    Text(habit.subtitle, style: AppText.bodyMuted),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: done
                    ? 'Mark ${habit.title} not done today'
                    : 'Mark ${habit.title} done today',
                child: Material(
                  color: done ? AppColors.flagGreen : AppColors.canvas,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onToggle,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.check_rounded,
                        color: done ? AppColors.surface : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.line,
              color: AppColors.flagGreen,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('$week of $target days this week', style: AppText.caption),
              const Spacer(),
              const Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: AppColors.flagAmber,
              ),
              const SizedBox(width: 4),
              Text(
                streak == 0 ? 'No streak yet' : '$streak-day streak',
                style: AppText.caption.copyWith(color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (isBreathing)
                TextButton.icon(
                  onPressed: () => context.push(AppRoutes.breathing),
                  icon: const Icon(Icons.air_rounded, size: 18),
                  label: const Text('Start session'),
                ),
              const Spacer(),
              TextButton(onPressed: onPause, child: const Text('Pause')),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreathingLinkCard extends StatelessWidget {
  const _BreathingLinkCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DarkPromoCard(
      badge: '1, 3 or 5 minutes',
      title: 'Guided breathing',
      body: 'Slow, even breaths with a simple expanding circle. Stop any '
          'time you like.',
      buttonLabel: 'Start breathing',
      onPressed: onTap,
    );
  }
}

/// Side-by-side look at the metric a habit relates to. Observational only.
class _ImpactCard extends ConsumerWidget {
  const _ImpactCard({required this.active});

  final List<Habit> active;

  static const _fallbackMetric = <HealthDomain, VitalMetric>{
    HealthDomain.heart: VitalMetric.restingHr,
    HealthDomain.sleep: VitalMetric.sleepDuration,
    HealthDomain.activity: VitalMetric.steps,
    HealthDomain.stressRecovery: VitalMetric.hrv,
    HealthDomain.respiratory: VitalMetric.respiratoryRate,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingsAsync = ref.watch(readingsProvider(ChartRange.all));
    final rules = ref.watch(rulesProvider).value ?? const [];

    // The most consistent active habit this week drives the card.
    final candidates = [...active]
      ..sort(
        (a, b) => b.completionsThisWeek().compareTo(a.completionsThisWeek()),
      );
    final habit = candidates.isEmpty ? null : candidates.first;

    return SoftSurface(
      color: AppColors.lavenderCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded),
              const SizedBox(width: 8),
              Text('Is it showing up in your data?', style: AppText.cardTitle),
            ],
          ),
          const SizedBox(height: 10),
          if (habit == null)
            Text(
              'Add a habit and keep it going for a week or two. We will put '
              'your related numbers side by side here.',
              style: AppText.body,
            )
          else
            readingsAsync.when(
              loading: () => const ShimmerLikeSkeleton(height: 60, radius: 16),
              error: (e, _) => Text(
                'We could not load your readings just now.',
                style: AppText.body,
              ),
              data: (readings) {
                VitalMetric? metric;
                for (final r in rules) {
                  if (r.id == habit.linkedRuleId) metric = r.primaryMetric;
                }
                metric ??= _fallbackMetric[habit.domain]!;
                return _impactBody(habit, metric, readings);
              },
            ),
        ],
      ),
    );
  }

  Widget _impactBody(
    Habit habit,
    VitalMetric metric,
    List<DailyReading> readings,
  ) {
    double? avg(List<DailyReading> slice) {
      final v = [
        for (final r in slice)
          if (r.valueOf(metric) != null) r.valueOf(metric)!,
      ];
      if (v.length < 3) return null;
      return v.reduce((a, b) => a + b) / v.length;
    }

    final n = readings.length;
    final recent = n >= 7 ? avg(readings.sublist(n - 7)) : null;
    final before = n >= 14 ? avg(readings.sublist(n - 14, n - 7)) : null;

    if (recent == null || before == null) {
      return Text(
        'Not enough ${metric.label} readings yet to compare two weeks. '
        'Keep wearing your device and check back soon.',
        style: AppText.body,
      );
    }
    final diff = recent - before;
    final steady = before == 0 || (diff / before).abs() < 0.02;
    final better = metric.higherIsBetter ? diff > 0 : diff < 0;
    final (icon, color, word) = steady
        ? (Icons.trending_flat_rounded, AppColors.muted, 'about the same')
        : better
            ? (
                diff > 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                AppColors.flagGreen,
                'moving the healthier way',
              )
            : (
                diff > 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                AppColors.flagAmber,
                'moving the other way',
              );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'While keeping up "${habit.title}", your ${metric.label.toLowerCase()} '
          'averaged ${MetricFormat.withUnit(metric, recent)} over the last 7 days, '
          'compared with ${MetricFormat.withUnit(metric, before)} the 7 days before.',
          style: AppText.body,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 6),
            Text(
              'That is $word.',
              style: AppText.label.copyWith(color: AppColors.ink),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'This is a side-by-side of your own numbers. Many things affect '
          'vitals, so it does not show the habit is the cause.',
          style: AppText.caption.copyWith(color: AppColors.ink),
        ),
      ],
    );
  }
}
