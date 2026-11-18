import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/chart_scale.dart';
import '../../core/utils/metric_labels.dart';
import '../../core/widgets/ink_app_bar.dart';
import '../../core/widgets/soft_surface.dart';
import '../../core/widgets/state_views.dart';
import '../../data/repositories/daily_repository.dart';
import '../../providers/chart_providers.dart';
import '../../providers/data_providers.dart';

enum _ChartPeriod { daily, weekly, monthly }

class _BucketPoint {
  const _BucketPoint({
    required this.label,
    required this.detailLabel,
    required this.value,
  });

  final String label;
  final String detailLabel;
  final double? value;
}

class FsTimelineScreen extends ConsumerStatefulWidget {
  const FsTimelineScreen({super.key});

  @override
  ConsumerState<FsTimelineScreen> createState() => _FsTimelineScreenState();
}

class _FsTimelineScreenState extends ConsumerState<FsTimelineScreen> {
  _ChartPeriod _period = _ChartPeriod.daily;

  static const _metrics = [
    ('restingHr', 'Resting HR', 'bpm', AppColors.peachCard),
    ('hrv', 'HRV', 'ms', AppColors.lavenderCard),
    ('sleepDeep', 'Deep sleep', 'min', AppColors.skyCard),
    ('spo2', 'SpO₂', '%', AppColors.creamCard),
    ('steps', 'Steps', 'steps', AppColors.mintCard),
  ];

  static const _validMetrics = {
    'restingHr',
    'hrv',
    'sleepDeep',
    'spo2',
    'steps',
  };

  String get _selectedMetric {
    final m = ref.watch(timelineSelectedMetricProvider);
    return _validMetrics.contains(m) ? m : 'restingHr';
  }

  void _selectMetric(String metric) {
    ref.read(timelineSelectedMetricProvider.notifier).select(metric);
  }

  double? _extractMetric(DailyModel day, String metric) {
    if (day.isGap) return null;
    return switch (metric) {
      'restingHr' => day.restingHr,
      'hrv' => day.hrv,
      'sleepDeep' => day.sleepDeep,
      'sleepTotal' => day.sleepTotal,
      'spo2' => day.spo2,
      'steps' => day.steps,
      _ => null,
    };
  }

  DateTime? _parseDate(String raw) => DateTime.tryParse(raw);

  /// Monday-start week key for stable weekly buckets.
  String _weekKey(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - DateTime.monday));
    final y = monday.year.toString().padLeft(4, '0');
    final m = monday.month.toString().padLeft(2, '0');
    final day = monday.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _monthKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  List<_BucketPoint> _buildBuckets(List<DailyModel> daily) {
    switch (_period) {
      case _ChartPeriod.daily:
        return [
          for (final day in daily)
            _BucketPoint(
              label: () {
                final parsed = _parseDate(day.date);
                if (parsed != null) return DateFormat('MM/dd').format(parsed);
                if (day.date.length >= 10) {
                  return day.date.substring(5).replaceAll('-', '/');
                }
                return day.date;
              }(),
              detailLabel: day.date,
              value: _extractMetric(day, _selectedMetric),
            ),
        ];
      case _ChartPeriod.weekly:
        return _aggregate(
          daily,
          keyOf: (d) {
            final parsed = _parseDate(d.date);
            if (parsed == null) return d.date;
            return _weekKey(parsed);
          },
          labelOf: (key) {
            final monday = DateTime.tryParse(key);
            if (monday == null) return key;
            final sunday = monday.add(const Duration(days: 6));
            final fmt = DateFormat('MM/dd');
            return '${fmt.format(monday)}–${fmt.format(sunday)}';
          },
          detailOf: (key) {
            final monday = DateTime.tryParse(key);
            if (monday == null) return 'Week of $key';
            return 'Week of ${DateFormat('MMM d, yyyy').format(monday)}';
          },
        );
      case _ChartPeriod.monthly:
        return _aggregate(
          daily,
          keyOf: (d) {
            final parsed = _parseDate(d.date);
            if (parsed == null) {
              return d.date.length >= 7 ? d.date.substring(0, 7) : d.date;
            }
            return _monthKey(parsed);
          },
          labelOf: (key) {
            final parsed = DateTime.tryParse('$key-01');
            if (parsed == null) return key;
            return DateFormat('MMM yy').format(parsed);
          },
          detailOf: (key) {
            final parsed = DateTime.tryParse('$key-01');
            if (parsed == null) return key;
            return DateFormat('MMMM yyyy').format(parsed);
          },
        );
    }
  }

  List<_BucketPoint> _aggregate(
    List<DailyModel> daily, {
    required String Function(DailyModel) keyOf,
    required String Function(String key) labelOf,
    required String Function(String key) detailOf,
  }) {
    final order = <String>[];
    final sums = <String, double>{};
    final counts = <String, int>{};

    for (final day in daily) {
      final key = keyOf(day);
      final val = _extractMetric(day, _selectedMetric);
      if (!sums.containsKey(key)) {
        order.add(key);
        sums[key] = 0;
        counts[key] = 0;
      }
      if (val != null) {
        sums[key] = sums[key]! + val;
        counts[key] = counts[key]! + 1;
      }
    }

    return [
      for (final key in order)
        _BucketPoint(
          label: labelOf(key),
          detailLabel: detailOf(key),
          value: counts[key]! == 0 ? null : sums[key]! / counts[key]!,
        ),
    ];
  }

  String get _periodListTitle => switch (_period) {
        _ChartPeriod.daily => 'Recorded days',
        _ChartPeriod.weekly => 'Weekly averages',
        _ChartPeriod.monthly => 'Monthly averages',
      };

  @override
  Widget build(BuildContext context) {
    final dailyAsync = ref.watch(dailyProvider(null));
    final baselinesAsync = ref.watch(baselinesProvider);
    final seriesMap = ref.watch(homeMetricSeriesProvider);

    final current = _metrics.firstWhere((m) => m.$1 == _selectedMetric);
    final status = seriesMap[_selectedMetric]?.status ??
        MetricLabels.statusFromLevel('green');

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const InkAppBar(
        title: 'Timeline',
        subtitle: 'Full history by metric',
      ),
      body: dailyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(
          message: 'Unable to load readings.',
          onRetry: () => ref.invalidate(dailyProvider(null)),
        ),
        data: (daily) {
          if (daily.isEmpty) {
            return const EmptyState(
              icon: Icons.show_chart_rounded,
              title: 'No timeline data yet',
              message: 'Connect your watch to start building your baseline',
            );
          }

          final baseline = baselinesAsync.value?[_selectedMetric];
          final buckets = _buildBuckets(daily);

          final segments = <List<FlSpot>>[];
          var currentSegment = <FlSpot>[];
          for (var i = 0; i < buckets.length; i++) {
            final val = buckets[i].value;
            if (val == null) {
              if (currentSegment.isNotEmpty) {
                segments.add(currentSegment);
                currentSegment = [];
              }
            } else {
              currentSegment.add(FlSpot(i.toDouble(), val));
            }
          }
          if (currentSegment.isNotEmpty) segments.add(currentSegment);

          final allValues =
              buckets.map((b) => b.value).whereType<double>().toList();
          final yBounds = ChartScale.bounds(allValues, metric: _selectedMetric);
          final latest = allValues.isEmpty ? null : allValues.last;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dailyProvider(null));
              ref.invalidate(baselinesProvider);
              await ref.read(dailyProvider(null).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final m in _metrics) ...[
                        _MetricPill(
                          label: m.$2,
                          selected: _selectedMetric == m.$1,
                          selectedBg: m.$4,
                          selectedFg: AppColors.ink,
                          onTap: () => _selectMetric(m.$1),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SoftSurface(
                  color: current.$4,
                  radius: 28,
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  MetricLabels.icon(_selectedMetric),
                                  size: 14,
                                  color: status.color,
                                ),
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
                          const Spacer(),
                          _PeriodDropdown(
                            value: _period,
                            onChanged: (p) => setState(() => _period = p),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        current.$2,
                        style: AppText.cardTitle.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        latest == null
                            ? 'No recent value'
                            : '${_period == _ChartPeriod.daily ? 'Latest' : 'Latest avg'}: ${latest >= 100 ? latest.toStringAsFixed(0) : latest.toStringAsFixed(1)} ${current.$3}',
                        style: AppText.bodyMuted,
                      ),
                      if (baseline != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Baseline ${baseline.mean.toStringAsFixed(1)} ± ${baseline.std.toStringAsFixed(1)} ${current.$3}',
                          style: AppText.caption.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 260,
                        width: double.infinity,
                        child: segments.isEmpty
                            ? Center(
                                child: Text(
                                  'No data points for this metric.',
                                  style: AppText.caption,
                                ),
                              )
                            : _DetailedMetricChart(
                                buckets: buckets,
                                segments: segments,
                                minY: yBounds.minY,
                                maxY: yBounds.maxY,
                                lineColor: status.color,
                                unit: current.$3,
                                baselineMean: baseline?.mean,
                                baselineStd: baseline?.std,
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(_periodListTitle, style: AppText.cardTitle),
                const SizedBox(height: 10),
                for (final bucket in buckets.reversed.take(15)) ...[
                  SoftSurface(
                    radius: 20,
                    color: bucket.value == null
                        ? AppColors.creamCard
                        : AppColors.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            bucket.detailLabel,
                            style: AppText.body,
                          ),
                        ),
                        if (bucket.value == null)
                          Text(
                            'No data',
                            style: AppText.caption.copyWith(
                              color: AppColors.flagAmber,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else
                          Text(
                            '${bucket.value! >= 100 ? bucket.value!.toStringAsFixed(0) : bucket.value!.toStringAsFixed(1)} ${current.$3}',
                            style: AppText.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
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

class _PeriodDropdown extends StatelessWidget {
  const _PeriodDropdown({
    required this.value,
    required this.onChanged,
  });

  final _ChartPeriod value;
  final ValueChanged<_ChartPeriod> onChanged;

  String _label(_ChartPeriod p) => switch (p) {
        _ChartPeriod.daily => 'Daily',
        _ChartPeriod.weekly => 'Weekly',
        _ChartPeriod.monthly => 'Monthly',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_ChartPeriod>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          items: _ChartPeriod.values
              .map(
                (p) => DropdownMenuItem(
                  value: p,
                  child: Text(_label(p)),
                ),
              )
              .toList(),
          onChanged: (p) {
            if (p != null) onChanged(p);
          },
        ),
      ),
    );
  }
}

class _DetailedMetricChart extends StatelessWidget {
  const _DetailedMetricChart({
    required this.buckets,
    required this.segments,
    required this.minY,
    required this.maxY,
    required this.lineColor,
    required this.unit,
    this.baselineMean,
    this.baselineStd,
  });

  final List<_BucketPoint> buckets;
  final List<List<FlSpot>> segments;
  final double minY;
  final double maxY;
  final Color lineColor;
  final String unit;
  final double? baselineMean;
  final double? baselineStd;

  String _formatY(double v) {
    if (v.abs() >= 100) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final maxX = (buckets.length - 1).toDouble().clamp(1.0, 9999.0).toDouble();
    final xInterval =
        (buckets.length / 5).ceilToDouble().clamp(1.0, 9999.0).toDouble();

    final yInterval = ChartScale.yInterval(minY, maxY);

    final axisStyle = GoogleFonts.manrope(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: AppColors.inkSoft,
    );

    return Padding(
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
              bottom: BorderSide(color: AppColors.ink.withValues(alpha: 0.18)),
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
                  if ((value - i).abs() > 0.01) return const SizedBox.shrink();
                  if (i < 0 || i >= buckets.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: Text(buckets[i].label, style: axisStyle),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.ink,
              getTooltipItems: (spots) => spots
                  .map(
                    (s) {
                      final i = s.x.round().clamp(0, buckets.length - 1);
                      return LineTooltipItem(
                        '${buckets[i].detailLabel}\n${_formatY(s.y)} $unit',
                        GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      );
                    },
                  )
                  .toList(),
            ),
          ),
          extraLinesData: baselineMean != null
              ? ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: baselineMean!,
                      color: AppColors.muted.withValues(alpha: 0.55),
                      strokeWidth: 1.2,
                      dashArray: const [6, 4],
                    ),
                    if (baselineStd != null) ...[
                      HorizontalLine(
                        y: baselineMean! + baselineStd!,
                        color: AppColors.ink.withValues(alpha: 0.18),
                        strokeWidth: 1,
                        dashArray: const [4, 4],
                      ),
                      HorizontalLine(
                        y: baselineMean! - baselineStd!,
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
                  checkToShowDot: (spot, _) => buckets.length <= 21,
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
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedBg,
    required this.selectedFg,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedBg;
  final Color selectedFg;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedBg : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? selectedFg : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}
