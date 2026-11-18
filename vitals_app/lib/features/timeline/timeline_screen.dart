import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide Baseline;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/metric_format.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/baseline.dart';
import '../../domain/models/daily_reading.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/life_event.dart';
import '../../providers/providers.dart';

const _maxMetrics = 3;

final _seriesColors = <Color>[
  AppColors.ink,
  Color.lerp(AppColors.accent, AppColors.ink, 0.45)!,
  Color.lerp(AppColors.lavenderCard, AppColors.ink, 0.55)!,
];

/// Multi-metric timeline with the person's usual range, life events and an
/// optional comparison with the previous period.
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  List<VitalMetric>? _selected;
  ChartRange _range = ChartRange.oneMonth;
  bool _compare = false;

  static const _ranges = ChartRange.values;

  List<VitalMetric> get _metrics =>
      _selected ?? [ref.read(currentPersonaProvider).heroMetric];

  void _toggleMetric(VitalMetric metric) {
    final current = List<VitalMetric>.of(_metrics);
    if (current.contains(metric)) {
      if (current.length == 1) {
        showSnack(context, 'Keep at least one metric selected.');
        return;
      }
      current.remove(metric);
    } else {
      if (current.length >= _maxMetrics) {
        showSnack(context, 'You can compare up to $_maxMetrics metrics at once.');
        return;
      }
      current.add(metric);
    }
    setState(() => _selected = current);
  }

  Future<void> _addEvent() async {
    final event = await showFormSheet<LifeEvent>(
      context,
      builder: (_) => const _AddEventSheet(),
    );
    if (event == null || !mounted) return;
    try {
      await ref.read(lifeEventsProvider.notifier).add(event);
      if (mounted) showSnack(context, 'Added "${event.title}" to your timeline.');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not save the event. Please try again.');
    }
  }

  Future<void> _removeEvent(LifeEvent event) async {
    try {
      await ref.read(lifeEventsProvider.notifier).remove(event.id);
      if (mounted) showSnack(context, 'Removed "${event.title}".');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not remove the event.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final readingsAsync = ref.watch(readingsProvider(ChartRange.all));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CenteredBody(
          child: readingsAsync.when(
            loading: () => const ListSkeleton(blocks: 3, blockHeight: 200),
            error: (e, _) => FeatureError(
              what: 'your timeline',
              onRetry: () => ref.invalidate(readingsProvider),
            ),
            data: _buildData,
          ),
        ),
      ),
    );
  }

  Widget _buildData(List<DailyReading> all) {
    final metrics = _metrics;
    final hasAnyData = all.any((r) => !r.isGap);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(readingsProvider);
        ref.invalidate(lifeEventsProvider);
        try {
          await ref.read(readingsProvider(ChartRange.all).future);
        } catch (_) {}
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Row(
            children: [
              Expanded(child: Text('Timeline', style: AppText.screenTitle)),
              PillButton(
                label: 'Add event',
                icon: Icons.add_rounded,
                expanded: false,
                height: 44,
                variant: PillButtonVariant.secondary,
                onPressed: _addEvent,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'See how your vitals move against your own usual range.',
            style: AppText.bodyMuted,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in VitalMetric.values)
                AppChip(
                  label: m.label,
                  selected: metrics.contains(m),
                  dotColor: metrics.contains(m)
                      ? _seriesColors[metrics.indexOf(m)]
                      : null,
                  onTap: () => _toggleMetric(m),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${metrics.length} of $_maxMetrics metrics selected',
            style: AppText.caption,
          ),
          const SizedBox(height: 16),
          if (!hasAnyData)
            const SoftSurface(
              child: EmptyState(
                title: 'No data yet',
                message:
                    'Once your wearable syncs a few days of readings, your '
                    'timeline will appear here.',
                icon: Icons.show_chart_rounded,
              ),
            )
          else
            _buildChartCard(all, metrics),
          const SizedBox(height: 20),
          _buildEvents(),
          const SizedBox(height: 16),
          const DisclaimerBanner(),
        ],
      ),
    );
  }

  Widget _buildChartCard(List<DailyReading> all, List<VitalMetric> metrics) {
    final days = _range.days.clamp(1, all.length);
    final window = all.sublist(all.length - days);
    final canCompare =
        _range != ChartRange.all && all.length >= days * 2 && days >= 7;
    final prior = canCompare
        ? all.sublist(all.length - days * 2, all.length - days)
        : const <DailyReading>[];
    final priorHasData = prior.where((r) => !r.isGap).length >= 3;
    final showCompare = _compare && canCompare && priorHasData;

    final baselines = <VitalMetric, Baseline?>{
      for (final m in metrics) m: ref.watch(baselineProvider(m)).value,
    };
    final events = ref.watch(lifeEventsProvider).value ?? const <LifeEvent>[];

    final multi = metrics.length > 1;
    final bars = <_Bar>[];
    final values = <double>[];

    for (var i = 0; i < metrics.length; i++) {
      final m = metrics[i];
      final base = baselines[m];
      final nonGap = [
        for (final r in window)
          if (r.valueOf(m) != null) r.valueOf(m)!,
      ];
      final ref0 = (base != null && base.hasData)
          ? base.mean
          : (nonGap.isEmpty
                ? 1.0
                : nonGap.reduce((a, b) => a + b) / nonGap.length);
      double scale(double v) => multi && ref0 != 0 ? v / ref0 * 100 : v;

      bars.add(_Bar.from(m, window, _seriesColors[i], scale, dashed: false));
      if (showCompare) {
        bars.add(_Bar.from(m, prior, _seriesColors[i].withValues(alpha: 0.45),
            scale,
            dashed: true));
      }
    }
    for (final b in bars) {
      for (final s in b.spots) {
        if (!s.isNull()) values.add(s.y);
      }
    }

    final primary = metrics.first;
    final primaryBase = baselines[primary];
    double? bandLow;
    double? bandHigh;
    if (primaryBase != null && primaryBase.hasData) {
      final double low;
      final double high;
      if (multi && primaryBase.mean != 0) {
        low = primaryBase.low / primaryBase.mean * 100;
        high = primaryBase.high / primaryBase.mean * 100;
      } else {
        low = primaryBase.low;
        high = primaryBase.high;
      }
      bandLow = low;
      bandHigh = high;
      values.addAll([low, high]);
    }

    final hasPlot = bars.any((b) => b.hasData);
    double minY = 0;
    double maxY = 1;
    if (values.isNotEmpty) {
      minY = values.reduce((a, b) => a < b ? a : b);
      maxY = values.reduce((a, b) => a > b ? a : b);
      final pad = (maxY - minY).abs() < 1e-6 ? 1.0 : (maxY - minY) * 0.12;
      minY -= pad;
      maxY += pad;
    }

    final windowStart = window.first.date;
    final markers = <(LifeEvent, double)>[
      for (final e in events)
        if (!AppDateUtils.dateOnly(e.startDate).isBefore(windowStart) &&
            !AppDateUtils.dateOnly(e.startDate).isAfter(window.last.date))
          (
            e,
            AppDateUtils.dateOnly(e.startDate)
                .difference(windowStart)
                .inDays
                .toDouble(),
          ),
    ];

    final interval = days <= 7 ? 1.0 : (days <= 30 ? 7.0 : (days <= 90 ? 15.0 : 30.0));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.skyCard,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  multi
                      ? 'Change from your usual (%)'
                      : '${primary.label} (${primary.unit})',
                  style: AppText.cardTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: !hasPlot
                ? const Center(
                    child: EmptyState(
                      title: 'No readings in this range',
                      message: 'Try a longer range or a different metric.',
                      icon: Icons.show_chart_rounded,
                    ),
                  )
                : Semantics(
                    label:
                        'Timeline chart of ${metrics.map((m) => m.label).join(', ')} '
                        'over the last $days days.',
                    child: LineChart(
                      LineChartData(
                        minY: minY,
                        maxY: maxY,
                        minX: 0,
                        maxX: (days - 1).toDouble().clamp(1, double.infinity),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: AppColors.surface.withValues(alpha: 0.7),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              getTitlesWidget: (v, meta) {
                                if (v == meta.min || v == meta.max) {
                                  return const SizedBox.shrink();
                                }
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    multi
                                        ? v.round().toString()
                                        : MetricFormat.value(primary, v),
                                    style: AppText.caption,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: interval,
                              getTitlesWidget: (v, meta) {
                                final i = v.round();
                                if (i < 0 || i >= window.length) {
                                  return const SizedBox.shrink();
                                }
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    AppDateUtils.dayMonth.format(window[i].date),
                                    style: AppText.caption,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        rangeAnnotations: RangeAnnotations(
                          horizontalRangeAnnotations: [
                            if (bandLow != null && bandHigh != null)
                              HorizontalRangeAnnotation(
                                y1: bandLow,
                                y2: bandHigh,
                                color: AppColors.surface.withValues(alpha: 0.65),
                              ),
                          ],
                        ),
                        extraLinesData: ExtraLinesData(
                          verticalLines: [
                            for (final (event, x) in markers)
                              VerticalLine(
                                x: x,
                                color: AppColors.flagAmber,
                                strokeWidth: 1.6,
                                dashArray: const [4, 4],
                                label: VerticalLineLabel(
                                  show: true,
                                  alignment: Alignment.topRight,
                                  labelResolver: (_) =>
                                      event.type.label.substring(0, 1),
                                  style: AppText.caption.copyWith(
                                    color: AppColors.flagAmber,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => AppColors.ink,
                            tooltipBorderRadius: BorderRadius.circular(14),
                            getTooltipItems: (spots) => [
                              for (final s in spots)
                                LineTooltipItem(
                                  bars[s.barIndex].tooltip(s.spotIndex),
                                  AppText.caption.copyWith(
                                    color: AppColors.surface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        lineBarsData: [
                          for (final b in bars)
                            LineChartBarData(
                              spots: b.spots,
                              color: b.color,
                              barWidth: b.dashed ? 2 : 2.6,
                              dashArray: b.dashed ? const [6, 5] : null,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: !b.dashed && days <= 14),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (var i = 0; i < metrics.length; i++)
                _LegendDot(color: _seriesColors[i], label: metrics[i].label),
              if (bandLow != null)
                _LegendDot(
                  color: AppColors.surface,
                  label: multi
                      ? 'Usual range (${primary.label})'
                      : 'Your usual range',
                  outlined: true,
                ),
              if (markers.isNotEmpty)
                const _LegendDot(
                  color: AppColors.flagAmber,
                  label: 'Life event',
                ),
              if (showCompare)
                const _LegendDot(
                  color: AppColors.muted,
                  label: 'Previous period (dashed)',
                ),
            ],
          ),
          if (multi) ...[
            const SizedBox(height: 6),
            Text(
              '100 = each metric\'s own usual level, so different units can share one chart.',
              style: AppText.caption,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              RangeChips(
                labels: [for (final r in _ranges) r.label],
                selectedIndex: _ranges.indexOf(_range),
                onSelected: (i) => setState(() => _range = _ranges[i]),
              ),
              const Spacer(),
              Text('Compare', style: AppText.caption.copyWith(color: AppColors.ink)),
              Switch(
                value: _compare,
                onChanged: (v) => setState(() => _compare = v),
              ),
            ],
          ),
          if (_compare && !showCompare)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      !canCompare
                          ? 'Not enough history to compare this range with an '
                              'earlier one yet. Try 1W, 1M or 3M.'
                          : 'The previous period has too few readings to compare.',
                      style: AppText.caption.copyWith(color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          for (var i = 0; i < metrics.length; i++)
            _MetricSummary(
              metric: metrics[i],
              color: _seriesColors[i],
              window: window,
              baseline: baselines[metrics[i]],
            ),
        ],
      ),
    );
  }

  Widget _buildEvents() {
    final eventsAsync = ref.watch(lifeEventsProvider);
    final days = _range.days;
    final today = AppDateUtils.dateOnly(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Life events',
          actionLabel: 'Add',
          onActionTap: _addEvent,
        ),
        const SizedBox(height: 4),
        Text(
          'Travel, illness or a stressful week can explain changes in your '
          'numbers.',
          style: AppText.bodyMuted,
        ),
        const SizedBox(height: 12),
        eventsAsync.when(
          loading: () => const ShimmerLikeSkeleton(height: 72, radius: 20),
          error: (e, _) => SoftSurface(
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Could not load life events.',
                    style: AppText.body,
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(lifeEventsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (events) {
            if (events.isEmpty) {
              return SoftSurface(
                child: EmptyState(
                  title: 'No life events yet',
                  message:
                      'Add events like a trip or a busy period to see them as '
                      'markers on the chart.',
                  icon: Icons.event_note_rounded,
                  actionLabel: 'Add event',
                  onAction: _addEvent,
                ),
              );
            }
            return Column(
              children: [
                for (final e in events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SoftSurface(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.creamCard,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(e.type.icon, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.title, style: AppText.cardTitle),
                                const SizedBox(height: 2),
                                Text(
                                  '${e.type.label} · ${AppDateUtils.dayMonth.format(e.startDate)}'
                                  '${e.endDate != null ? ' – ${AppDateUtils.dayMonth.format(e.endDate!)}' : ''}'
                                  '${today.difference(AppDateUtils.dateOnly(e.startDate)).inDays > days ? ' · outside this range' : ''}',
                                  style: AppText.caption,
                                ),
                                if (e.note != null && e.note!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(e.note!, style: AppText.bodyMuted),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove ${e.title}',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => _removeEvent(e),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Bar {
  _Bar({
    required this.metric,
    required this.spots,
    required this.actuals,
    required this.color,
    required this.dashed,
  });

  factory _Bar.from(
    VitalMetric metric,
    List<DailyReading> readings,
    Color color,
    double Function(double) scale, {
    required bool dashed,
  }) {
    final spots = <FlSpot>[];
    final actuals = <double?>[];
    for (var i = 0; i < readings.length; i++) {
      final v = readings[i].valueOf(metric);
      actuals.add(v);
      spots.add(v == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), scale(v)));
    }
    return _Bar(
      metric: metric,
      spots: spots,
      actuals: actuals,
      color: color,
      dashed: dashed,
    );
  }

  final VitalMetric metric;
  final List<FlSpot> spots;
  final List<double?> actuals;
  final Color color;
  final bool dashed;

  bool get hasData => spots.any((s) => !s.isNull());

  String tooltip(int index) {
    final v = index < actuals.length ? actuals[index] : null;
    final value = v == null ? 'No data' : MetricFormat.withUnit(metric, v);
    return '${metric.label}${dashed ? ' (before)' : ''}\n$value';
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.outlined = false,
  });

  final Color color;
  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: outlined ? Border.all(color: AppColors.muted) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppText.caption.copyWith(color: AppColors.ink)),
      ],
    );
  }
}

class _MetricSummary extends StatelessWidget {
  const _MetricSummary({
    required this.metric,
    required this.color,
    required this.window,
    required this.baseline,
  });

  final VitalMetric metric;
  final Color color;
  final List<DailyReading> window;
  final Baseline? baseline;

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final r in window)
        if (r.valueOf(metric) != null) r.valueOf(metric)!,
    ];
    final String text;
    if (values.isEmpty) {
      text = 'No data for ${metric.label} in this range.';
    } else {
      final avg = values.reduce((a, b) => a + b) / values.length;
      final usual = baseline != null && baseline!.hasData
          ? ' Your usual range is ${MetricFormat.range(metric, baseline!.low, baseline!.high)}.'
          : '';
      text =
          '${metric.label} averaged ${MetricFormat.withUnit(metric, avg)} across '
          '${values.length} days with data.$usual';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppText.caption.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddEventSheet extends StatefulWidget {
  const _AddEventSheet();

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  LifeEventType _type = LifeEventType.travel;
  DateTime _start = AppDateUtils.dateOnly(DateTime.now());
  DateTime? _end;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool end}) async {
    final today = AppDateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: end ? (_end ?? _start) : _start,
      firstDate: end ? _start : today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 30)),
    );
    if (picked == null) return;
    setState(() {
      if (end) {
        _end = picked;
      } else {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = null;
      }
    });
  }

  void _save() {
    final title = _title.text.trim().isEmpty ? _type.label : _title.text.trim();
    final note = _note.text.trim();
    Navigator.of(context).pop(
      LifeEvent(
        id: 'event_${DateTime.now().microsecondsSinceEpoch}',
        type: _type,
        title: title,
        startDate: _start,
        endDate: _end,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Add life event', style: AppText.sectionTitle),
        const SizedBox(height: 4),
        Text(
          'It will show as a marker on your timeline.',
          style: AppText.bodyMuted,
        ),
        const FieldLabel('Type'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in LifeEventType.values)
              AppChip(
                label: t.label,
                icon: t.icon,
                selected: _type == t,
                onTap: () => setState(() => _type = t),
              ),
          ],
        ),
        const FieldLabel('Title'),
        TextField(
          controller: _title,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(hintText: 'e.g. Trip to Pune'),
        ),
        const FieldLabel('Dates'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(end: false),
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text('From ${AppDateUtils.dayMonth.format(_start)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(end: true),
                icon: const Icon(Icons.event_available_rounded, size: 18),
                label: Text(
                  _end == null
                      ? 'To (optional)'
                      : 'To ${AppDateUtils.dayMonth.format(_end!)}',
                ),
              ),
            ),
          ],
        ),
        const FieldLabel('Note (optional)'),
        TextField(
          controller: _note,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Anything worth remembering'),
        ),
        const SizedBox(height: 20),
        PillButton(label: 'Save event', onPressed: _save),
      ],
    );
  }
}
