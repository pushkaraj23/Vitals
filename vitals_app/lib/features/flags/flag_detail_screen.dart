import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Baseline;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/baseline.dart';
import '../../domain/models/daily_reading.dart';
import '../../domain/models/doctor_review.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/flag.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/rule.dart';
import '../../domain/models/symptom.dart';
import '../../providers/providers.dart';

String _cap(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

String _fmtValue(VitalMetric metric, double value) =>
    Format.number(value, decimals: metric == VitalMetric.steps ? 0 : 1);

/// Detail view for one flag: trend, facts, context, symptoms and next steps.
class FlagDetailScreen extends ConsumerStatefulWidget {
  const FlagDetailScreen({super.key, required this.flagId});

  final String flagId;

  @override
  ConsumerState<FlagDetailScreen> createState() => _FlagDetailScreenState();
}

class _FlagDetailScreenState extends ConsumerState<FlagDetailScreen> {
  static const _ranges = [
    ChartRange.oneWeek,
    ChartRange.oneMonth,
    ChartRange.threeMonths,
  ];

  int _rangeIndex = 1;
  bool _showMental = false;
  bool _impactsRevealed = false;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/flags');
    }
  }

  @override
  Widget build(BuildContext context) {
    final flagAsync = ref.watch(flagProvider(widget.flagId));
    final flag = flagAsync.value;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _back,
        ),
        title: flag == null
            ? const Text('Flag')
            : Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FlagChip(status: flag.status, compact: true),
                      const SizedBox(width: 8),
                      DoctorBadge(state: flag.doctorBadge, compact: true),
                    ],
                  ),
                ),
              ),
      ),
      body: SafeArea(
        child: flagAsync.when(
          skipLoadingOnReload: true,
          loading: () => const _DetailSkeleton(),
          error: (error, _) => ErrorState(
            message: 'We could not load this flag. Please try again.',
            onRetry: () => ref.invalidate(flagProvider(widget.flagId)),
          ),
          data: (flag) {
            if (flag == null) {
              return EmptyState(
                title: 'Flag not found',
                message: 'This flag may have been resolved or removed.',
                icon: Icons.flag_outlined,
                actionLabel: 'Back to flags',
                onAction: _back,
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: _buildBody(flag),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(Flag flag) {
    final ruleAsync = ref.watch(ruleProvider(flag.ruleId));
    final rule = ruleAsync.value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        // --- Plain statement
        Text(flag.title, style: AppText.screenTitle.copyWith(fontSize: 26)),
        const SizedBox(height: 8),
        Text(flag.summary, style: AppText.body),
        const SizedBox(height: 16),
        SoftSurface(
          color: AppColors.creamCard,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('A gentle next step', style: AppText.label),
                    const SizedBox(height: 4),
                    Text(flag.nextStep, style: AppText.body),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // --- Chart
        _buildChartSection(flag),
        const SizedBox(height: 24),

        // --- Facts
        _buildFacts(flag),
        const SizedBox(height: 24),

        // --- Rule-driven sections
        if (ruleAsync.isLoading && rule == null) ...[
          const ShimmerLikeSkeleton(height: 72, radius: 24),
          const SizedBox(height: 12),
          const ShimmerLikeSkeleton(height: 160, radius: 24),
          const SizedBox(height: 24),
        ] else if (rule != null) ...[
          _buildWhy(flag, rule),
          const SizedBox(height: 24),
          if (rule.symptoms.isNotEmpty) ...[
            _buildSymptoms(flag, rule),
            const SizedBox(height: 24),
          ],
          if (rule.impactsPhysical.isNotEmpty ||
              rule.impactsMental.isNotEmpty) ...[
            _buildImpacts(rule),
            const SizedBox(height: 24),
          ],
          _buildCheckup(flag, rule),
          const SizedBox(height: 24),
          if (rule.remedies.isNotEmpty) ...[
            _buildHabits(flag, rule),
            const SizedBox(height: 24),
          ],
        ] else ...[
          // Rule unavailable: keep the page useful with the checkup card.
          _buildCheckup(flag, null),
          const SizedBox(height: 24),
        ],

        // --- Doctor verification
        _buildDoctor(flag),
        const SizedBox(height: 24),
        const DisclaimerBanner(),
      ],
    );
  }

  // ------------------------------------------------------------------ chart

  Widget _buildChartSection(Flag flag) {
    final range = _ranges[_rangeIndex];
    final readingsAsync = ref.watch(readingsProvider(range));
    final baselineAsync = ref.watch(baselineProvider(flag.metric));

    return SoftSurface(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${flag.metric.label} (${flag.metric.unit})',
                  style: AppText.cardTitle,
                ),
              ),
              RangeChips(
                labels: [for (final r in _ranges) r.label],
                selectedIndex: _rangeIndex,
                onSelected: (i) => setState(() => _rangeIndex = i),
              ),
            ],
          ),
          const SizedBox(height: 12),
          readingsAsync.when(
            skipLoadingOnReload: true,
            loading: () => const ShimmerLikeSkeleton(height: 220, radius: 16),
            error: (error, _) => SizedBox(
              height: 220,
              child: ErrorState(
                message: 'The trend could not be loaded.',
                onRetry: () => ref.invalidate(readingsProvider(range)),
              ),
            ),
            data: (readings) => _TrendChart(
              flag: flag,
              readings: readings,
              baseline: baselineAsync.value,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ facts

  Widget _buildFacts(Flag flag) {
    final severityColor = switch (flag.severity) {
      Severity.low => AppColors.mintCard,
      Severity.medium => AppColors.creamCard,
      Severity.high => AppColors.peachCard,
    };

    final hasUsual = flag.baselineLow != null && flag.baselineHigh != null;
    final unit = flag.metric.unit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'The facts'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _FactTile(
                label: 'Duration',
                value: Format.durationDays(flag.streakDays),
                icon: Icons.timelapse_rounded,
                color: AppColors.skyCard,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FactTile(
                label: 'Severity',
                value: _cap(flag.severity.name),
                icon: Icons.speed_rounded,
                color: severityColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FactTile(
                label: 'Confidence',
                value: _cap(flag.confidence.name),
                icon: Icons.insights_rounded,
                color: AppColors.lavenderCard,
              ),
            ),
          ],
        ),
        if (flag.currentValue != null || hasUsual) ...[
          const SizedBox(height: 12),
          SoftSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (flag.currentValue != null)
                  _FactLine(
                    label: 'Recent',
                    value:
                        '${_fmtValue(flag.metric, flag.currentValue!)} $unit',
                  ),
                if (hasUsual) ...[
                  if (flag.currentValue != null) const SizedBox(height: 8),
                  _FactLine(
                    label: 'Your usual range',
                    value:
                        '${_fmtValue(flag.metric, flag.baselineLow!)}–${_fmtValue(flag.metric, flag.baselineHigh!)} $unit',
                  ),
                ],
                if (flag.startedOn != null) ...[
                  const SizedBox(height: 8),
                  _FactLine(
                    label: 'First noticed',
                    value: AppDateUtils.dayMonthYear.format(flag.startedOn!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------------- why

  Widget _buildWhy(Flag flag, Rule rule) {
    final unit = flag.metric.unit;
    final lines = <String>[
      'Your ${flag.metric.label.toLowerCase()} has been outside your own usual range for ${Format.durationDays(flag.streakDays)}.',
      if (flag.currentValue != null &&
          flag.baselineLow != null &&
          flag.baselineHigh != null)
        'Recently it was ${_fmtValue(flag.metric, flag.currentValue!)} $unit, compared with your usual ${_fmtValue(flag.metric, flag.baselineLow!)}–${_fmtValue(flag.metric, flag.baselineHigh!)} $unit.',
      rule.summary,
      'We only show this kind of pattern once it has lasted at least ${Format.durationDays(rule.minDurationDays)}, so one-off days do not trigger it.',
    ];

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text('Why am I seeing this?', style: AppText.cardTitle),
          children: [
            for (final line in lines) ...[
              Text(line, style: AppText.body),
              const SizedBox(height: 10),
            ],
            if (flag.contextNote != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.skyCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(flag.contextNote!, style: AppText.body),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (rule.sources.isNotEmpty)
              Text(
                'Further reading: ${rule.sources.join(', ')}',
                style: AppText.caption,
              ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- symptoms

  Widget _buildSymptoms(Flag flag, Rule rule) {
    final logged = ref.watch(symptomsProvider).value ?? const <Symptom>[];

    bool isLogged(String label) =>
        logged.any((s) => s.linkedFlagId == flag.id && s.label == label);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'What you might notice'),
        const SizedBox(height: 4),
        Text(
          'Some people notice these alongside this pattern. Only you can tell whether they apply.',
          style: AppText.bodyMuted,
        ),
        const SizedBox(height: 12),
        SoftSurface(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              for (var i = 0; i < rule.symptoms.length; i++) ...[
                if (i > 0) const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(rule.symptoms[i], style: AppText.body),
                      ),
                      const SizedBox(width: 12),
                      _SymptomButton(
                        logged: isLogged(rule.symptoms[i]),
                        onPressed: () => _logSymptom(flag, rule.symptoms[i]),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _logSymptom(Flag flag, String label) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(symptomsProvider.notifier)
          .add(
            Symptom(
              id: 'sym_${DateTime.now().microsecondsSinceEpoch}',
              label: label,
              date: DateTime.now(),
              linkedFlagId: flag.id,
            ),
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Noted. It is saved to your timeline.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save that. Please try again.')),
      );
    }
  }

  // ---------------------------------------------------------------- impacts

  Widget _buildImpacts(Rule rule) {
    final gentle = ref.watch(settingsProvider).value?.gentleMode ?? false;
    final gated = gentle && !_impactsRevealed;
    final items = _showMental ? rule.impactsMental : rule.impactsPhysical;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'If this continues'),
        const SizedBox(height: 4),
        Text(
          'General, non-personal notes on what a long-running pattern like this can affect. They are not predictions for you.',
          style: AppText.bodyMuted,
        ),
        const SizedBox(height: 12),
        if (gated)
          SoftSurface(
            color: AppColors.lavenderCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.spa_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Gentle mode is on',
                        style: AppText.cardTitle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'We have tucked these notes away. Read them when you feel ready. You can change gentle mode in Settings.',
                  style: AppText.body,
                ),
                const SizedBox(height: 16),
                PillButton(
                  label: 'Show notes',
                  variant: PillButtonVariant.secondary,
                  expanded: false,
                  onPressed: () => setState(() => _impactsRevealed = true),
                ),
              ],
            ),
          )
        else
          SoftSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ToggleChip(
                      label: 'Physical',
                      selected: !_showMental,
                      onTap: () => setState(() => _showMental = false),
                    ),
                    const SizedBox(width: 8),
                    _ToggleChip(
                      label: 'Mental',
                      selected: _showMental,
                      onTap: () => setState(() => _showMental = true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  Text('Nothing specific to note here.', style: AppText.body)
                else
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.ink,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(item, style: AppText.body)),
                        ],
                      ),
                    ),
                if (gentle) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => setState(() => _impactsRevealed = false),
                    child: const Text('Hide notes again'),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------- checkup

  Widget _buildCheckup(Flag flag, Rule? rule) {
    final who = rule == null ? 'a clinician' : 'a ${rule.specialist}';
    final urgent = flag.status == FlagStatus.red;
    return DarkPromoCard(
      badge: urgent ? 'Worth discussing soon' : 'Optional',
      title: 'Talk it through at a check-up',
      body:
          'Bringing this trend to $who can help you make sense of it in the context of your whole health picture.',
      buttonLabel: 'Prepare for a check-up',
      onPressed: () => _openCheckupSheet(flag, rule),
    );
  }

  void _openCheckupSheet(Flag flag, Rule? rule) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        final points = [
          'This trend: ${flag.title}',
          'How long it has lasted: ${Format.durationDays(flag.streakDays)}',
          'Anything that changed lately: sleep, stress, medicines, travel, illness',
          if (rule != null && rule.symptoms.isNotEmpty)
            'Anything you noticed, such as: ${rule.symptoms.take(2).join('; ')}',
        ];
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prepare for a check-up', style: AppText.sectionTitle),
                const SizedBox(height: 8),
                Text(
                  'A few things worth bringing so the conversation is easy.',
                  style: AppText.bodyMuted,
                ),
                const SizedBox(height: 16),
                for (final point in points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 20,
                          color: AppColors.flagGreen,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(point, style: AppText.body)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'This app does not book appointments or give medical advice.',
                  style: AppText.caption,
                ),
                const SizedBox(height: 16),
                PillButton(
                  label: 'Got it',
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------------- habits

  Widget _buildHabits(Flag flag, Rule rule) {
    final habits = ref.watch(habitsProvider).value ?? const <Habit>[];

    String habitId(int index) => 'habit_${rule.id}_$index';
    bool started(int index) => habits.any(
      (h) =>
          h.id == habitId(index) ||
          (h.linkedRuleId == rule.id && h.title == rule.remedies[index]),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Small habits that may help'),
        const SizedBox(height: 4),
        Text(
          'Lifestyle ideas only. Start one plan and see how it feels.',
          style: AppText.bodyMuted,
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < rule.remedies.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          SoftSurface(
            color: AppColors.mintCard,
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(child: Text(rule.remedies[i], style: AppText.body)),
                const SizedBox(width: 12),
                PillButton(
                  label: started(i) ? 'Started' : 'Start plan',
                  icon: started(i) ? Icons.check_rounded : null,
                  expanded: false,
                  height: 40,
                  variant: started(i)
                      ? PillButtonVariant.secondary
                      : PillButtonVariant.primary,
                  onPressed: started(i)
                      ? null
                      : () => _startPlan(flag, rule, i, habitId(i)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _startPlan(Flag flag, Rule rule, int index, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref
          .read(habitsRepositoryProvider)
          .addHabit(
            Habit(
              id: id,
              title: rule.remedies[index],
              subtitle: 'From: ${flag.title}',
              domain: flag.domain,
              targetDaysPerWeek: 5,
              linkedRuleId: rule.id,
            ),
          );
      ref.invalidate(habitsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Plan started. You can track it in Habits.'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => router.go('/habits'),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not start that plan. Try again.')),
      );
    }
  }

  // ----------------------------------------------------------------- doctor

  Widget _buildDoctor(Flag flag) {
    final reviewAsync = ref.watch(doctorReviewForFlagProvider(flag.id));
    final action = ref.watch(doctorReviewActionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Doctor verification'),
        const SizedBox(height: 12),
        SoftSurface(
          child: reviewAsync.when(
            skipLoadingOnReload: true,
            loading: () => const Column(
              children: [
                ShimmerLikeSkeleton(height: 20),
                SizedBox(height: 12),
                ShimmerLikeSkeleton(height: 20, width: 180),
              ],
            ),
            error: (error, _) => ErrorState(
              message: 'Review status could not be loaded.',
              onRetry: () =>
                  ref.invalidate(doctorReviewForFlagProvider(flag.id)),
            ),
            data: (review) => review == null
                ? _buildNoReview(flag, action)
                : _buildReview(review),
          ),
        ),
      ],
    );
  }

  Widget _buildNoReview(Flag flag, AsyncValue<void> action) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DoctorBadge(state: flag.doctorBadge),
        const SizedBox(height: 12),
        Text(
          'You can ask a clinician to look at this trend summary. They review the pattern, not you as a person.',
          style: AppText.body,
        ),
        if (action.hasError && !action.isLoading) ...[
          const SizedBox(height: 8),
          Text(
            'The request did not go through. Please try again.',
            style: AppText.caption.copyWith(color: AppColors.flagRed),
          ),
        ],
        const SizedBox(height: 16),
        PillButton(
          label: 'Request a review',
          icon: Icons.verified_user_outlined,
          loading: action.isLoading,
          onPressed: () =>
              ref.read(doctorReviewActionsProvider.notifier).request(flag.id),
        ),
        const SizedBox(height: 12),
        const SimulatedReviewLabel(),
      ],
    );
  }

  Widget _buildReview(DoctorReview review) {
    final date = review.reviewedAt ?? review.requestedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DoctorBadge(state: review.badge),
        const SizedBox(height: 14),
        Text(review.doctorName, style: AppText.cardTitle),
        const SizedBox(height: 2),
        Text(review.credentials, style: AppText.caption),
        const SizedBox(height: 12),
        _FactLine(label: 'Outcome', value: review.verdict.label),
        const SizedBox(height: 6),
        _FactLine(
          label: review.isPending ? 'Requested' : 'Reviewed',
          value: AppDateUtils.dayMonthYear.format(date),
        ),
        if (review.note != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(review.note!, style: AppText.body),
          ),
        ],
        const SizedBox(height: 12),
        const SimulatedReviewLabel(),
      ],
    );
  }
}

// ------------------------------------------------------------------- chart

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.flag,
    required this.readings,
    required this.baseline,
  });

  final Flag flag;
  final List<DailyReading> readings;
  final Baseline? baseline;

  @override
  Widget build(BuildContext context) {
    final metric = flag.metric;
    final values = [for (final r in readings) r.valueOf(metric)];
    final hasData = values.whereType<double>().length >= 2;
    if (!hasData) {
      return const SizedBox(
        height: 220,
        child: EmptyState(
          title: 'Not enough data yet',
          message: 'The trend appears once a few days are synced.',
          icon: Icons.show_chart_rounded,
        ),
      );
    }

    // Contiguous runs of real values; a gap ends the current run so the line
    // visibly breaks instead of dropping to zero.
    final segments = <List<FlSpot>>[];
    var current = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) {
        if (current.isNotEmpty) segments.add(current);
        current = <FlSpot>[];
      } else {
        current.add(FlSpot(i.toDouble(), v));
      }
    }
    if (current.isNotEmpty) segments.add(current);
    final hasGaps = values.any((v) => v == null);

    // Usual range band (rolling series if available, else the flag's range).
    final lowSpots = <FlSpot>[];
    final highSpots = <FlSpot>[];
    final series = baseline?.series ?? const <BaselinePoint>[];
    if (series.isNotEmpty) {
      final byDay = {for (final p in series) AppDateUtils.dateOnly(p.date): p};
      for (var i = 0; i < readings.length; i++) {
        final p = byDay[AppDateUtils.dateOnly(readings[i].date)];
        if (p == null) continue;
        lowSpots.add(FlSpot(i.toDouble(), p.low));
        highSpots.add(FlSpot(i.toDouble(), p.high));
      }
    }
    if (lowSpots.length < 2) {
      lowSpots.clear();
      highSpots.clear();
      final low =
          flag.baselineLow ??
          (baseline?.hasData == true ? baseline!.low : null);
      final high =
          flag.baselineHigh ??
          (baseline?.hasData == true ? baseline!.high : null);
      if (low != null && high != null) {
        final last = (readings.length - 1).toDouble();
        lowSpots
          ..add(FlSpot(0, low))
          ..add(FlSpot(last, low));
        highSpots
          ..add(FlSpot(0, high))
          ..add(FlSpot(last, high));
      }
    }
    final hasBand = lowSpots.length >= 2;

    var minY = double.infinity;
    var maxY = -double.infinity;
    for (final v in values.whereType<double>()) {
      if (v < minY) minY = v;
      if (v > maxY) maxY = v;
    }
    if (hasBand) {
      for (final s in lowSpots) {
        if (s.y < minY) minY = s.y;
      }
      for (final s in highSpots) {
        if (s.y > maxY) maxY = s.y;
      }
    }
    final span = (maxY - minY).abs() < 0.001 ? 1.0 : maxY - minY;
    minY -= span * 0.12;
    maxY += span * 0.12;

    final lineColor = flag.status.color;
    final bandCount = hasBand ? 2 : 0;
    final xInterval = (readings.length / 4)
        .floorToDouble()
        .clamp(1, 1000)
        .toDouble();

    final bars = <LineChartBarData>[
      if (hasBand) ...[
        LineChartBarData(
          spots: lowSpots,
          color: Colors.transparent,
          barWidth: 0,
          dotData: const FlDotData(show: false),
        ),
        LineChartBarData(
          spots: highSpots,
          color: Colors.transparent,
          barWidth: 0,
          dotData: const FlDotData(show: false),
        ),
      ],
      for (final segment in segments)
        LineChartBarData(
          spots: segment,
          isCurved: segment.length > 2,
          curveSmoothness: 0.2,
          preventCurveOverShooting: true,
          color: AppColors.ink,
          barWidth: 2.4,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: segment.length == 1,
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 3.5,
              color: AppColors.ink,
              strokeWidth: 0,
            ),
          ),
        ),
    ];

    final summary = StringBuffer(
      '${metric.label} over the last ${readings.length} days.',
    );
    if (hasBand) summary.write(' Shaded area shows your usual range.');
    if (hasGaps) summary.write(' Breaks in the line are days without data.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: summary.toString(),
          child: SizedBox(
            height: 220,
            child: ExcludeSemantics(
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (readings.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: AppColors.line, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.min || value == meta.max) {
                            return const SizedBox.shrink();
                          }
                          return Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                _fmtValue(metric, value),
                                style: AppText.caption,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: xInterval,
                        getTitlesWidget: (value, meta) {
                          final i = value.round();
                          if (i < 0 || i >= readings.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              AppDateUtils.dayMonth.format(readings[i].date),
                              style: AppText.caption,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppColors.ink,
                      tooltipBorderRadius: BorderRadius.circular(12),
                      getTooltipItems: (touched) => [
                        for (final spot in touched)
                          if (spot.barIndex < bandCount)
                            null
                          else
                            LineTooltipItem(
                              '${_fmtValue(metric, spot.y)} ${metric.unit}\n'
                              '${AppDateUtils.dayMonth.format(readings[spot.x.round().clamp(0, readings.length - 1)].date)}',
                              AppText.caption.copyWith(
                                color: AppColors.surface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                      ],
                    ),
                  ),
                  betweenBarsData: [
                    if (hasBand)
                      BetweenBarsData(
                        fromIndex: 0,
                        toIndex: 1,
                        color: lineColor.withValues(alpha: 0.14),
                      ),
                  ],
                  lineBarsData: bars,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            if (hasBand)
              _LegendItem(
                swatch: Container(
                  width: 14,
                  height: 10,
                  decoration: BoxDecoration(
                    color: lineColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                label: 'Your usual range',
              ),
            if (hasGaps)
              const _LegendItem(
                swatch: Icon(
                  Icons.more_horiz_rounded,
                  size: 16,
                  color: AppColors.muted,
                ),
                label: 'Break = no data that day',
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.swatch, required this.label});

  final Widget swatch;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 6),
        Text(label, style: AppText.caption),
      ],
    );
  }
}

// ----------------------------------------------------------------- widgets

class _FactTile extends StatelessWidget {
  const _FactTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label $value',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 10),
            Text(label, style: AppText.caption),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppText.cardTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: AppText.bodyMuted)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppText.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _SymptomButton extends StatelessWidget {
  const _SymptomButton({required this.logged, required this.onPressed});

  final bool logged;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !logged,
      label: logged ? 'Logged' : "I'm experiencing this",
      child: Material(
        color: logged ? AppColors.mintCard : AppColors.canvas,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: logged ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (logged) ...[
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.flagGreen,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  logged ? 'Logged' : "I'm experiencing this",
                  style: AppText.caption.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.ink : AppColors.canvas,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(
              label,
              style: AppText.label.copyWith(
                color: selected ? AppColors.surface : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: const [
        ShimmerLikeSkeleton(height: 32),
        SizedBox(height: 12),
        ShimmerLikeSkeleton(height: 18),
        SizedBox(height: 24),
        ShimmerLikeSkeleton(height: 280, radius: 24),
        SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: ShimmerLikeSkeleton(height: 96, radius: 22)),
            SizedBox(width: 10),
            Expanded(child: ShimmerLikeSkeleton(height: 96, radius: 22)),
            SizedBox(width: 10),
            Expanded(child: ShimmerLikeSkeleton(height: 96, radius: 22)),
          ],
        ),
      ],
    );
  }
}
