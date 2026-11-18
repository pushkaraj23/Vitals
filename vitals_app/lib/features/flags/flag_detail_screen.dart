import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/chart_scale.dart';
import '../../core/utils/metric_labels.dart';
import '../../core/widgets/ink_app_bar.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/daily_repository.dart';
import '../../data/repositories/flag_repository.dart';
import '../../data/repositories/symptom_repository.dart';
import '../../domain/models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';

class FlagDetailScreen extends ConsumerWidget {
  const FlagDetailScreen({super.key, required this.flagId});

  final String flagId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagAsync = ref.watch(flagProvider(flagId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        title: 'Health Flag',
        subtitle: flagAsync.value?.title,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: flagAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Could not load this flag.',
          onRetry: () => ref.invalidate(flagProvider(flagId)),
        ),
        data: (flag) {
          if (flag == null) {
            return const EmptyState(
              icon: Icons.flag_outlined,
              title: 'Flag not found',
              message: 'This health flag may have been removed.',
            );
          }
          return _FlagDetailBody(flag: flag);
        },
      ),
    );
  }
}

class _FlagDetailBody extends ConsumerWidget {
  const _FlagDetailBody({required this.flag});

  final FlagModel flag;

  Color get _heroBg => switch (flag.level) {
        'red' => AppColors.peachCard,
        'amber' => AppColors.creamCard,
        _ => AppColors.mintCard,
      };

  Future<void> _logSymptom(
    BuildContext context,
    WidgetRef ref,
    String symptom,
  ) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final id = const Uuid().v4();
    await ref.read(symptomRepositoryProvider).addSymptom(
          uid,
          SymptomModel(
            id: id,
            symptom: symptom,
            date: today,
            flagId: flag.id,
          ),
        );
    if (context.mounted) {
      showSnack(context, 'Logged "$symptom".');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ruleAsync = ref.watch(ruleProvider(flag.ruleId));
    final dailyAsync = ref.watch(dailyProvider(null));
    final baselineAsync = ref.watch(baselineProvider(flag.metric));
    final reviewAsync = ref.watch(reviewForFlagProvider(flag.id));
    final symptomsAsync = ref.watch(symptomsProvider);
    final status = MetricLabels.statusFromLevel(flag.level);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        SoftSurface(
          color: _heroBg,
          radius: 28,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(status.icon, size: 14, color: status.color),
                    const SizedBox(width: 6),
                    Text(
                      status.label,
                      style: AppText.caption.copyWith(
                        color: status.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                flag.title,
                style: AppText.screenTitle.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                flag.aiExplanation ?? flag.explanation,
                style: AppText.body,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(
                    icon: MetricLabels.icon(flag.metric),
                    label: MetricLabels.label(flag.metric),
                  ),
                  _Pill(
                    icon: Icons.timelapse_rounded,
                    label: '${flag.durationDays} days',
                  ),
                  _Pill(
                    icon: Icons.insights_rounded,
                    label: 'Confidence: ${flag.confidence}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Why was this flagged?', style: AppText.cardTitle),
        const SizedBox(height: 8),
        SoftSurface(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ruleAsync.value?.explanation ?? flag.explanation,
                style: AppText.bodyMuted,
              ),
              const SizedBox(height: 12),
              if (flag.baselineValue != null || flag.currentValue != null)
                Text(
                  'Baseline: ${flag.baselineValue?.toStringAsFixed(1) ?? '—'}  ·  '
                  'Recent: ${flag.currentValue?.toStringAsFixed(1) ?? '—'} '
                  '${MetricLabels.unit(flag.metric)}',
                  style: AppText.caption,
                ),
              if (flag.dataUsed.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Data used: ${flag.dataUsed.map(MetricLabels.label).join(', ')}',
                  style: AppText.caption,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Trend', style: AppText.cardTitle),
        const SizedBox(height: 8),
        SoftSurface(
          color: _heroBg,
          radius: 28,
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          child: dailyAsync.when(
            loading: () => const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const SizedBox(
              height: 120,
              child: Center(child: Text('Could not load chart.')),
            ),
            data: (days) => _MetricTrendChart(
              days: days,
              metric: flag.metric,
              mean: baselineAsync.value?.mean,
              std: baselineAsync.value?.std,
              lineColor: status.color,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text('Related sensations', style: AppText.cardTitle),
        const SizedBox(height: 4),
        Text(
          'Tap if you are experiencing this — worth discussing with a doctor if it persists.',
          style: AppText.caption,
        ),
        const SizedBox(height: 8),
        ...(ruleAsync.value?.symptoms ?? const <String>[]).map((s) {
          final logged = (symptomsAsync.value ?? [])
              .any((x) => x.flagId == flag.id && x.symptom == s);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftSurface(
              radius: 20,
              color: logged ? AppColors.mintCard : AppColors.surface,
              onTap: logged ? null : () => _logSymptom(context, ref, s),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    logged
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline,
                    color: logged ? AppColors.flagGreen : AppColors.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s, style: AppText.body)),
                  Text(
                    logged ? 'Logged' : "I'm experiencing this",
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
          );
        }),
        if ((ruleAsync.value?.symptoms ?? const []).isEmpty)
          Text(
            'No linked sensations for this rule.',
            style: AppText.bodyMuted,
          ),
        const SizedBox(height: 16),
        if ((ruleAsync.value?.impacts ?? const []).isNotEmpty) ...[
          Text('If this continues', style: AppText.cardTitle),
          const SizedBox(height: 8),
          SoftSurface(
            radius: 24,
            color: AppColors.lavenderCard,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final impact in ruleAsync.value!.impacts) ...[
                  Text(impact.timeframe, style: AppText.label),
                  const SizedBox(height: 4),
                  Text(impact.text, style: AppText.bodyMuted),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if ((ruleAsync.value?.specialist ?? '').isNotEmpty) ...[
          SoftSurface(
            radius: 24,
            color: AppColors.skyCard,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.medical_services_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Specialist to consider: ${ruleAsync.value!.specialist}',
                    style: AppText.body,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text('Doctor review', style: AppText.cardTitle),
        const SizedBox(height: 8),
        SoftSurface(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: reviewAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const Text('Could not load review status.'),
            data: (review) {
              if (review == null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Not yet reviewed', style: AppText.body),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        final uid = ref.read(currentUidProvider);
                        if (uid == null) return;
                        await ref
                            .read(reviewRepositoryProvider)
                            .requestReview(uid, flag.id);
                        if (context.mounted) {
                          showSnack(
                            context,
                            'Doctor review is not available yet in this prototype.',
                          );
                        }
                      },
                      child: const Text('Request review'),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (review.simulated)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: SimulatedReviewLabel(),
                    ),
                  if (!review.isPending)
                    DoctorBadge(
                      state: review.verdict == 'Confirmed'
                          ? DoctorBadgeState.verified
                          : review.verdict == 'Needs consultation'
                              ? DoctorBadgeState.needsConsultation
                              : DoctorBadgeState.verified,
                    ),
                  if (review.isPending)
                    const DoctorBadge(state: DoctorBadgeState.underReview),
                  const SizedBox(height: 8),
                  Text(review.verdict, style: AppText.cardTitle),
                  const SizedBox(height: 4),
                  Text(review.note, style: AppText.bodyMuted),
                  const SizedBox(height: 4),
                  Text(
                    '${review.reviewerName} · ${review.reviewedAt}',
                    style: AppText.caption,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'VitalWatch provides wellness insights, not medical diagnoses.',
          style: AppText.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 6),
          Text(label, style: AppText.caption),
        ],
      ),
    );
  }
}

class _MetricTrendChart extends StatelessWidget {
  const _MetricTrendChart({
    required this.days,
    required this.metric,
    required this.lineColor,
    this.mean,
    this.std,
  });

  final List<DailyModel> days;
  final String metric;
  final Color lineColor;
  final double? mean;
  final double? std;

  double? _value(DailyModel d) => switch (metric) {
        'restingHr' => d.restingHr,
        'hrv' => d.hrv,
        'sleepDeep' => d.sleepDeep,
        'sleepTotal' => d.sleepTotal,
        'spo2' => d.spo2,
        'steps' => d.steps,
        _ => null,
      };

  String _formatY(double v) {
    if (v.abs() >= 100) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  String _xLabel(List<({int i, double? v})> series, int index) {
    if (index < 0 || index >= series.length) return '';
    final raw = days[series[index].i].date;
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return DateFormat('MM/dd').format(parsed);
    if (raw.length >= 10) return raw.substring(5).replaceAll('-', '/');
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final withIndex = <({int i, double? v})>[];
    for (var i = 0; i < days.length; i++) {
      withIndex.add((i: i, v: _value(days[i])));
    }
    if (withIndex.every((e) => e.v == null)) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text('Connect your watch to start building your baseline'),
        ),
      );
    }

    var series = withIndex;
    if (series.length > 120) {
      final step = (series.length / 120).ceil();
      series = [
        for (var i = 0; i < series.length; i += step) series[i],
      ];
    }

    // Break gaps into separate segments (never plot missing as zero).
    final segments = <List<FlSpot>>[];
    var current = <FlSpot>[];
    for (var i = 0; i < series.length; i++) {
      final v = series[i].v;
      if (v == null) {
        if (current.isNotEmpty) {
          segments.add(current);
          current = [];
        }
      } else {
        current.add(FlSpot(i.toDouble(), v));
      }
    }
    if (current.isNotEmpty) segments.add(current);

    final vals = series.map((e) => e.v).whereType<double>().toList();
    final yBounds = ChartScale.bounds(vals, metric: metric);
    final minY = yBounds.minY;
    final maxY = yBounds.maxY;
    final maxX = (series.length - 1).toDouble().clamp(1.0, 9999.0).toDouble();
    final xInterval =
        (series.length / 5).ceilToDouble().clamp(1.0, 9999.0).toDouble();
    final yInterval = ChartScale.yInterval(minY, maxY);
    final unit = MetricLabels.unit(metric);
    final axisStyle = AppText.caption.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: AppColors.inkSoft,
    );

    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(right: 4, top: 4),
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            minX: 0,
            maxX: maxX,
            clipData: const FlClipData.all(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: yInterval,
              verticalInterval: xInterval,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.ink.withValues(alpha: 0.08),
                strokeWidth: 1,
              ),
              getDrawingVerticalLine: (_) => FlLine(
                color: AppColors.ink.withValues(alpha: 0.06),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                left: BorderSide(color: AppColors.ink.withValues(alpha: 0.18)),
                bottom:
                    BorderSide(color: AppColors.ink.withValues(alpha: 0.18)),
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: yInterval,
                  getTitlesWidget: (value, meta) {
                    if (value < minY - 0.01 || value > maxY + 0.01) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      space: 4,
                      child: Text(
                        _formatY(value),
                        style: axisStyle,
                        textAlign: TextAlign.right,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: xInterval,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if ((value - i).abs() > 0.01) {
                      return const SizedBox.shrink();
                    }
                    if (i < 0 || i >= series.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      space: 4,
                      child: Text(_xLabel(series, i), style: axisStyle),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.ink,
                getTooltipItems: (touched) => touched.map((s) {
                  final i = s.x.round().clamp(0, series.length - 1);
                  return LineTooltipItem(
                    '${_xLabel(series, i)}\n${_formatY(s.y)} $unit',
                    AppText.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
            extraLinesData: mean != null
                ? ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: mean!,
                        color: AppColors.muted.withValues(alpha: 0.55),
                        strokeWidth: 1.2,
                        dashArray: const [6, 4],
                      ),
                      if (std != null) ...[
                        HorizontalLine(
                          y: mean! + std!,
                          color: AppColors.ink.withValues(alpha: 0.18),
                          strokeWidth: 1,
                          dashArray: const [4, 4],
                        ),
                        HorizontalLine(
                          y: mean! - std!,
                          color: AppColors.ink.withValues(alpha: 0.18),
                          strokeWidth: 1,
                          dashArray: const [4, 4],
                        ),
                      ],
                    ],
                  )
                : null,
            lineBarsData: [
              for (final seg in segments)
                LineChartBarData(
                  spots: seg,
                  isCurved: true,
                  color: lineColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, _) => series.length <= 21,
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: lineColor,
                      strokeWidth: 1.5,
                      strokeColor: AppColors.surface,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: lineColor.withValues(alpha: 0.12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
