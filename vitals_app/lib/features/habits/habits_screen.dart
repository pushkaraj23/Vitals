import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/metric_labels.dart';
import '../../core/widgets/ink_app_bar.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/habit_repository.dart';
import '../../data/repositories/habit_template_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  static const _cardColors = [
    AppColors.peachCard,
    AppColors.lavenderCard,
    AppColors.skyCard,
    AppColors.mintCard,
    AppColors.creamCard,
  ];

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _toggle(
    WidgetRef ref,
    BuildContext context,
    HabitModel habit,
  ) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final today = _today;
    final progress = [...habit.progress];
    final idx = progress.indexWhere((p) => p.date == today);
    if (idx >= 0) {
      progress[idx] = HabitProgressItem(date: today, done: !progress[idx].done);
    } else {
      progress.add(HabitProgressItem(date: today, done: true));
    }
    try {
      await ref
          .read(habitRepositoryProvider)
          .updateProgress(uid, habit.id, progress);
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'Could not update "${habit.title}". Try again.');
      }
    }
  }

  Future<void> _pickTemplate(BuildContext context, WidgetRef ref) async {
    final templatesAsync = ref.read(habitTemplatesProvider);
    final templates = templatesAsync.value ?? [];
    if (templates.isEmpty) {
      showSnack(context, 'No habit templates available yet.');
      return;
    }

    final selected = await showModalBottomSheet<HabitTemplateModel>(
      context: context,
      backgroundColor: AppColors.canvas,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Choose a habit', style: AppText.cardTitle.copyWith(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                'Small daily practices linked to your wellness patterns.',
                style: AppText.bodyMuted,
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: templates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final t = templates[i];
                    final color = _cardColors[i % _cardColors.length];
                    return SoftSurface(
                      color: color,
                      radius: 22,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      onTap: () => Navigator.pop(ctx, t),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _iconForTitle(t.title),
                              color: AppColors.ink,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  style: AppText.cardTitle.copyWith(fontSize: 16),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${t.durationDays} days · ${t.targetPerDay}/day',
                                  style: AppText.caption,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.add_rounded,
                            color: AppColors.inkSoft,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !context.mounted) return;

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final habit = HabitModel(
      id: const Uuid().v4(),
      templateId: selected.id,
      title: selected.title,
      startDate: _today,
      durationDays: selected.durationDays,
      progress: const [],
    );
    try {
      await ref.read(habitRepositoryProvider).createHabit(uid, habit);
      if (context.mounted) showSnack(context, 'Added "${selected.title}".');
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'Could not add the habit. Try again.');
      }
    }
  }

  static IconData _iconForTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('breath') || t.contains('air')) return Icons.air_rounded;
    if (t.contains('walk') || t.contains('step')) return Icons.directions_walk_rounded;
    if (t.contains('water') || t.contains('hydrat')) return Icons.water_drop_rounded;
    if (t.contains('sleep') || t.contains('wind')) return Icons.bedtime_rounded;
    if (t.contains('stretch') || t.contains('yoga')) {
      return Icons.self_improvement_rounded;
    }
    return Icons.favorite_outline_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        title: 'Habits',
        subtitle: 'Small practices, steady gains',
        actions: [
          IconButton(
            tooltip: 'Add habit',
            onPressed: () => _pickTemplate(context, ref),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Could not load habits.',
          onRetry: () => ref.invalidate(habitsProvider),
        ),
        data: (habits) {
          final doneToday = habits
              .where((h) => h.progress.any((p) => p.date == _today && p.done))
              .length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(habitsProvider);
              await ref.read(habitsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                SoftSurface(
                  color: AppColors.skyCard,
                  radius: 28,
                  padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
                  onTap: () => context.push(AppRoutes.breathing),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.air_rounded,
                          color: AppColors.ink,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Breathing break',
                              style: AppText.cardTitle.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '4s in · 6s out — follow the circle',
                              style: AppText.caption,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.inkSoft,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (habits.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SoftSurface(
                          color: AppColors.mintCard,
                          radius: 22,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${habits.length}',
                                style: GoogleFonts.manrope(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text('Active', style: AppText.caption),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SoftSurface(
                          color: AppColors.creamCard,
                          radius: 22,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$doneToday/${habits.length}',
                                style: GoogleFonts.manrope(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text('Done today', style: AppText.caption),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Your habits', style: AppText.cardTitle),
                  const SizedBox(height: 10),
                  for (var i = 0; i < habits.length; i++) ...[
                    _HabitCard(
                      habit: habits[i],
                      color: _cardColors[i % _cardColors.length],
                      todayDone: habits[i]
                          .progress
                          .any((p) => p.date == _today && p.done),
                      onToggle: () => _toggle(ref, context, habits[i]),
                    ),
                    const SizedBox(height: 12),
                  ],
                ] else ...[
                  SoftSurface(
                    color: AppColors.lavenderCard,
                    radius: 28,
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.self_improvement_rounded,
                            size: 32,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No habits yet',
                          style: AppText.cardTitle.copyWith(fontSize: 20),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pick a template to build a small daily practice linked to your wellness insights.',
                          style: AppText.bodyMuted,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        Material(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            onTap: () => _pickTemplate(context, ref),
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              child: Text(
                                'Add a habit',
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.surface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'VitalWatch provides wellness insights, not medical diagnoses.',
                  style: AppText.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.color,
    required this.todayDone,
    required this.onToggle,
  });

  final HabitModel habit;
  final Color color;
  final bool todayDone;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final progress = habit.durationDays == 0
        ? 0.0
        : (habit.completedCount / habit.durationDays).clamp(0.0, 1.0);

    return SoftSurface(
      color: color,
      radius: 28,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
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
                    Text(
                      habit.title,
                      style: AppText.cardTitle.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Day ${habit.completedCount} of ${habit.durationDays}',
                      style: AppText.caption.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: todayDone ? AppColors.ink : AppColors.surface,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onToggle,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      todayDone
                          ? Icons.check_rounded
                          : Icons.circle_outlined,
                      color: todayDone ? AppColors.surface : AppColors.inkSoft,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (habit.metric != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${MetricLabels.label(habit.metric!)}  '
                '${habit.metricBefore?.toStringAsFixed(1) ?? '—'} → '
                '${habit.metricAfter?.toStringAsFixed(1) ?? '—'}',
                style: AppText.caption.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surface.withValues(alpha: 0.55),
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            todayDone ? 'Done for today' : 'Tap the check when finished',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}
