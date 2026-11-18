import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide Baseline;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/format.dart';
import '../../core/utils/metric_format.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/baseline.dart';
import '../../domain/models/daily_reading.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/home_snapshot.dart';
import '../../domain/models/life_event.dart';
import '../../domain/models/symptom.dart';
import '../../providers/providers.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _tab = 0;

  void _retry() {
    ref
      ..invalidate(homeSnapshotProvider)
      ..invalidate(readingsProvider)
      ..invalidate(baselineProvider)
      ..invalidate(symptomsProvider)
      ..invalidate(lifeEventsProvider)
      ..invalidate(habitsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeSnapshotProvider);
    final readings = ref.watch(readingsProvider(ChartRange.all));
    final symptoms = ref.watch(symptomsProvider);
    final events = ref.watch(lifeEventsProvider);
    final habits = ref.watch(habitsProvider);
    final baselines = {
      for (final m in VitalMetric.values) m: ref.watch(baselineProvider(m)),
    };

    final all = <AsyncValue<Object?>>[
      home,
      readings,
      symptoms,
      events,
      habits,
      ...baselines.values,
    ];

    Widget body;
    if (all.any((a) => a.hasError && !a.hasValue)) {
      body = FeatureError(what: 'your reports', onRetry: _retry);
    } else if (all.any((a) => !a.hasValue)) {
      body = const ListSkeleton(blocks: 2, blockHeight: 260);
    } else {
      final data = _ReportData(
        home: home.requireValue,
        readings: readings.requireValue,
        symptoms: symptoms.requireValue,
        events: events.requireValue,
        habits: habits.requireValue,
        baselines: {
          for (final e in baselines.entries) e.key: e.value.requireValue,
        },
      );
      body = _buildData(data);
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Reports')),
      body: SafeArea(child: CenteredBody(child: body)),
    );
  }

  Widget _buildData(_ReportData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            AppChip(
              label: 'Doctor summary',
              icon: Icons.description_outlined,
              selected: _tab == 0,
              onTap: () => setState(() => _tab = 0),
            ),
            const SizedBox(width: 8),
            AppChip(
              label: 'Weekly report',
              icon: Icons.calendar_view_week_rounded,
              selected: _tab == 1,
              onTap: () => setState(() => _tab = 1),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!data.hasData)
          const SoftSurface(
            child: EmptyState(
              title: 'Not enough data for a report',
              message: 'Reports are built from your wearable readings. They '
                  'will be ready after a few days of data.',
              icon: Icons.description_outlined,
            ),
          )
        else if (_tab == 0)
          _DoctorSummaryPaper(data: data)
        else
          _WeeklyReport(data: data),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PillButton(
                label: 'Share',
                icon: Icons.ios_share_rounded,
                onPressed: !data.hasData ? null : () => showSnack(context, 'PDF sharing is coming later.'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PillButton(
                label: 'Download',
                icon: Icons.download_rounded,
                variant: PillButtonVariant.secondary,
                onPressed: !data.hasData ? null : () => showSnack(context, 'PDF download is coming later.'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const DisclaimerBanner(),
      ],
    );
  }
}

class _ReportData {
  const _ReportData({
    required this.home,
    required this.readings,
    required this.symptoms,
    required this.events,
    required this.habits,
    required this.baselines,
  });

  final HomeSnapshot home;
  final List<DailyReading> readings;
  final List<Symptom> symptoms;
  final List<LifeEvent> events;
  final List<Habit> habits;
  final Map<VitalMetric, Baseline> baselines;

  bool get hasData => readings.any((r) => !r.isGap);

  List<DailyReading> lastDays(int n, {int skip = 0}) {
    final end = readings.length - skip;
    if (end <= 0) return const [];
    final start = (end - n).clamp(0, end);
    return readings.sublist(start, end);
  }

  static double? average(List<DailyReading> slice, VitalMetric m) {
    final v = [
      for (final r in slice)
        if (r.valueOf(m) != null) r.valueOf(m)!,
    ];
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b) / v.length;
  }
}

class _Paper extends StatelessWidget {
  const _Paper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PaperSection extends StatelessWidget {
  const _PaperSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppText.caption.copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const Divider(height: 12),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _DoctorSummaryPaper extends StatelessWidget {
  const _DoctorSummaryPaper({required this.data});

  final _ReportData data;

  @override
  Widget build(BuildContext context) {
    final p = data.home.profile;
    final window = data.lastDays(30);
    final since = window.isEmpty ? null : window.first.date;
    final daysWithData = window.where((r) => !r.isGap).length;
    final flags = data.home.activeFlags;
    final recentSymptoms = [
      for (final s in data.symptoms)
        if (since != null && !s.date.isBefore(since)) s,
    ];
    final recentEvents = [
      for (final e in data.events)
        if (since != null &&
            (e.endDate ?? e.startDate).isAfter(since.subtract(const Duration(days: 1))))
          e,
    ];

    final vitalRows = <Widget>[];
    for (final m in VitalMetric.values) {
      final avg = _ReportData.average(window, m);
      final base = data.baselines[m];
      if (avg == null) continue;
      vitalRows.add(
        _Row(
          m.label,
          MetricFormat.withUnit(m, avg),
          trailing: base != null && base.hasData
              ? 'usual ${MetricFormat.range(m, base.low, base.high)}'
              : null,
        ),
      );
    }

    return _Paper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded, size: 18),
              const SizedBox(width: 8),
              Text('VitalWatch', style: AppText.label),
              const Spacer(),
              Text(
                AppDateUtils.dayMonthYear.format(data.home.generatedAt),
                style: AppText.caption,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Wellness summary for a clinician', style: AppText.sectionTitle),
          const SizedBox(height: 4),
          Text(
            'Prepared from wearable data the person chose to share.',
            style: AppText.caption,
          ),
          _PaperSection(
            title: 'Person',
            children: [
              _Row('Name', p.name),
              _Row('Age / sex', '${p.age} · ${p.sex.label}'),
              _Row('Height / weight', '${p.heightCm.round()} cm · ${p.weightKg.round()} kg'),
              _Row('Occupation', p.occupation),
            ],
          ),
          _PaperSection(
            title: 'Period covered',
            children: [
              _Row(
                'Last ${window.length} days',
                '$daysWithData days with data',
              ),
            ],
          ),
          _PaperSection(
            title: 'Patterns outside the usual range',
            children: [
              if (flags.isEmpty)
                Text(
                  'None. Recent values are within this person\'s own usual '
                  'range.',
                  style: AppText.body,
                )
              else
                for (final f in flags)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.title, style: AppText.cardTitle),
                        Text(
                          '${f.metric.label}'
                          '${f.currentValue != null ? ' recently ${MetricFormat.withUnit(f.metric, f.currentValue!)}' : ''}'
                          '${f.baselineLow != null && f.baselineHigh != null ? ', usual ${MetricFormat.range(f.metric, f.baselineLow!, f.baselineHigh!)}' : ''}'
                          ' · ${Format.durationDays(f.streakDays)}',
                          style: AppText.body,
                        ),
                      ],
                    ),
                  ),
            ],
          ),
          if (vitalRows.isNotEmpty)
            _PaperSection(
              title: '30-day averages',
              children: vitalRows,
            ),
          _PaperSection(
            title: 'Symptoms noted by the person',
            children: [
              if (recentSymptoms.isEmpty)
                Text('None logged in this period.', style: AppText.body)
              else
                for (final s in recentSymptoms.take(8))
                  _Row(
                    s.label,
                    AppDateUtils.dayMonth.format(s.date),
                    trailing: switch (s.severity) {
                      Severity.low => 'mild',
                      Severity.medium => 'moderate',
                      Severity.high => 'strong',
                    },
                  ),
            ],
          ),
          _PaperSection(
            title: 'Life events',
            children: [
              if (recentEvents.isEmpty)
                Text('None logged in this period.', style: AppText.body)
              else
                for (final e in recentEvents)
                  _Row(
                    e.title,
                    '${e.type.label} · ${AppDateUtils.dayMonth.format(e.startDate)}',
                  ),
            ],
          ),
          if (p.familyHistoryTags.isNotEmpty)
            _PaperSection(
              title: 'Family history noted',
              children: [
                Text(
                  p.familyHistoryTags
                      .map((t) => t.replaceAll('_', ' '))
                      .join(', '),
                  style: AppText.body,
                ),
              ],
            ),
          const SizedBox(height: 20),
          Text(
            'This summary compares recent wearable data with the person\'s own '
            'usual range. It is not a diagnosis and does not estimate the '
            'chance of any condition.',
            style: AppText.caption.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.trailing});

  final String label;
  final String value;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Text(label, style: AppText.bodyMuted)),
          Expanded(
            flex: 5,
            child: Text(
              trailing == null ? value : '$value · $trailing',
              style: AppText.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReport extends StatelessWidget {
  const _WeeklyReport({required this.data});

  final _ReportData data;

  @override
  Widget build(BuildContext context) {
    final week = data.lastDays(7);
    final prev = data.lastDays(7, skip: 7);
    final start = week.first.date;
    final end = week.last.date;

    final rows = <_WeekRow>[];
    for (final m in VitalMetric.values) {
      final avg = _ReportData.average(week, m);
      if (avg == null) continue;
      rows.add(
        _WeekRow(
          metric: m,
          average: avg,
          previous: _ReportData.average(prev, m),
          baseline: data.baselines[m],
        ),
      );
    }
    final within = rows.where((r) => r.status == _Status.within).length;
    final measurable = rows.where((r) => r.status != _Status.unknown).length;
    final symptomsThisWeek = data.symptoms
        .where((s) => !s.date.isBefore(start))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftSurface(
          color: AppColors.mintCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppDateUtils.dayMonth.format(start)} – ${AppDateUtils.dayMonth.format(end)}',
                style: AppText.caption.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: 6),
              Text(
                measurable == 0
                    ? 'Your week at a glance'
                    : '$within of $measurable measures sat in your usual range',
                style: AppText.sectionTitle,
              ),
              const SizedBox(height: 6),
              Text(
                '${data.home.activeFlags.length} patterns to watch · '
                '$symptomsThisWeek symptoms logged',
                style: AppText.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Vitals this week'),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const SoftSurface(
            child: EmptyState(
              title: 'No readings this week',
              message: 'Wear your device to fill in this report.',
              icon: Icons.watch_off_outlined,
            ),
          )
        else
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: r.build(),
            ),
        const SizedBox(height: 12),
        const SectionHeader(title: 'Habits this week'),
        const SizedBox(height: 12),
        if (data.habits.isEmpty)
          const SoftSurface(
            child: EmptyState(
              title: 'No habits yet',
              message: 'Add a habit to see how your week went.',
              icon: Icons.spa_outlined,
            ),
          )
        else
          SoftSurface(
            child: Column(
              children: [
                for (final h in data.habits)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(h.title, style: AppText.body)),
                        Text(
                          '${h.completionsThisWeek()}/${h.targetDaysPerWeek} days',
                          style: AppText.label,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

enum _Status { within, above, below, unknown }

class _WeekRow {
  _WeekRow({
    required this.metric,
    required this.average,
    required this.previous,
    required this.baseline,
  });

  final VitalMetric metric;
  final double average;
  final double? previous;
  final Baseline? baseline;

  _Status get status {
    final b = baseline;
    if (b == null || !b.hasData) return _Status.unknown;
    if (average > b.high) return _Status.above;
    if (average < b.low) return _Status.below;
    return _Status.within;
  }

  Widget build() {
    final (label, color, icon) = switch (status) {
      _Status.within => ('In your usual range', AppColors.flagGreen, Icons.check_circle_rounded),
      _Status.above => ('Above your usual range', AppColors.flagAmber, Icons.arrow_upward_rounded),
      _Status.below => ('Below your usual range', AppColors.flagAmber, Icons.arrow_downward_rounded),
      _Status.unknown => ('Usual range still forming', AppColors.muted, Icons.hourglass_empty_rounded),
    };
    String? change;
    if (previous != null) {
      final diff = average - previous!;
      final d = MetricFormat.value(metric, diff.abs());
      change = diff.abs() < 1e-9 || d == '0' || d == '0.0'
          ? 'Same as last week'
          : '${diff > 0 ? 'Up' : 'Down'} $d ${metric.unit} from last week';
    }
    return SoftSurface(
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metric.label, style: AppText.cardTitle),
                Text(label, style: AppText.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
                if (change != null) Text(change, style: AppText.caption),
              ],
            ),
          ),
          Text(MetricFormat.withUnit(metric, average), style: AppText.label),
        ],
      ),
    );
  }
}
