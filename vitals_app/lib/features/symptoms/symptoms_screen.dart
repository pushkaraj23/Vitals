import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide Baseline;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/widgets.dart';
import '../../data/mock/personas.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/symptom.dart';
import '../../providers/providers.dart';

/// One day's self-reported mood, energy and stress (each 1–5).
class CheckIn {
  const CheckIn({
    required this.date,
    required this.mood,
    required this.energy,
    required this.stress,
  });

  final DateTime date;
  final int mood;
  final int energy;
  final int stress;
}

/// Daily check-ins (local sample data; resets when the persona changes).
class CheckInsNotifier extends Notifier<List<CheckIn>> {
  @override
  List<CheckIn> build() {
    final persona = ref.watch(personaIdProvider);
    final today = AppDateUtils.dateOnly(DateTime.now());
    final (mood, energy, stress) = persona == PersonaId.rahul
        ? (
            [3, 3, 2, 3, 2, 2],
            [3, 2, 2, 2, 2, 2],
            [3, 4, 4, 4, 5, 4],
          )
        : (
            [4, 4, 5, 4, 4, 4],
            [4, 3, 4, 4, 4, 5],
            [2, 2, 1, 2, 2, 2],
          );
    return [
      for (var i = 0; i < 6; i++)
        CheckIn(
          date: today.subtract(Duration(days: 6 - i)),
          mood: mood[i],
          energy: energy[i],
          stress: stress[i],
        ),
    ];
  }

  void save(CheckIn checkIn) {
    final day = AppDateUtils.dateOnly(checkIn.date);
    state = [
      for (final c in state)
        if (AppDateUtils.dateOnly(c.date) != day) c,
      checkIn,
    ]..sort((a, b) => a.date.compareTo(b.date));
  }
}

final checkInsProvider = NotifierProvider<CheckInsNotifier, List<CheckIn>>(
  CheckInsNotifier.new,
);

class SymptomsScreen extends ConsumerWidget {
  const SymptomsScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final symptom = await showFormSheet<Symptom>(
      context,
      builder: (_) => const _AddSymptomSheet(),
    );
    if (symptom == null || !context.mounted) return;
    try {
      await ref.read(symptomsProvider.notifier).add(symptom);
      if (context.mounted) showSnack(context, 'Added "${symptom.label}" to your journal.');
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not save. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(symptomsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Symptoms & check-in')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.surface,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add symptom'),
      ),
      body: SafeArea(
        child: CenteredBody(
          child: async.when(
            loading: () => const ListSkeleton(blocks: 3, blockHeight: 150),
            error: (e, _) => FeatureError(
              what: 'your symptom journal',
              onRetry: () => ref.invalidate(symptomsProvider),
            ),
            data: (symptoms) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(symptomsProvider);
                try {
                  await ref.read(symptomsProvider.future);
                } catch (_) {}
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                children: [
                  Text(
                    'Notes about how you feel can add context to your vitals.',
                    style: AppText.bodyMuted,
                  ),
                  const SizedBox(height: 16),
                  const _CheckInCard(),
                  const SizedBox(height: 16),
                  const _TrendCard(),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Journal'),
                  const SizedBox(height: 12),
                  if (symptoms.isEmpty)
                    SoftSurface(
                      child: EmptyState(
                        title: 'Nothing logged yet',
                        message:
                            'Add anything you notice, like a headache or a '
                            'restless night.',
                        icon: Icons.edit_note_rounded,
                        actionLabel: 'Add symptom',
                        onAction: () => _add(context, ref),
                      ),
                    )
                  else
                    ..._journal(context, ref, symptoms),
                  const SizedBox(height: 12),
                  Text(
                    'If something feels sudden or severe, contact a clinician '
                    'or local emergency services.',
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 12),
                  const DisclaimerBanner(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _journal(BuildContext context, WidgetRef ref, List<Symptom> all) {
    final groups = <DateTime, List<Symptom>>{};
    for (final s in all) {
      groups.putIfAbsent(AppDateUtils.dateOnly(s.date), () => []).add(s);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final day in days) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            '${AppDateUtils.relativeDay(day)} · ${AppDateUtils.dayMonthYear.format(day)}',
            style: AppText.label.copyWith(color: AppColors.muted),
          ),
        ),
        for (final s in groups[day]!)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftSurface(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _severityColor(s.severity),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.label, style: AppText.cardTitle),
                        Text(_severityLabel(s.severity), style: AppText.caption),
                        if (s.note != null && s.note!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(s.note!, style: AppText.bodyMuted),
                        ],
                        if (s.linkedFlagId != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.link_rounded, size: 14, color: AppColors.muted),
                              const SizedBox(width: 4),
                              Text('Related to a flag', style: AppText.caption),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove ${s.label}',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      try {
                        await ref.read(symptomsProvider.notifier).remove(s.id);
                      } catch (_) {
                        if (context.mounted) showSnack(context, 'Could not remove entry.');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    ];
  }
}

String _severityLabel(Severity s) => switch (s) {
  Severity.low => 'Mild',
  Severity.medium => 'Moderate',
  Severity.high => 'Strong',
};

Color _severityColor(Severity s) => switch (s) {
  Severity.low => AppColors.flagGreen,
  Severity.medium => AppColors.flagAmber,
  Severity.high => AppColors.flagRed,
};

class _CheckInCard extends ConsumerStatefulWidget {
  const _CheckInCard();

  @override
  ConsumerState<_CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends ConsumerState<_CheckInCard> {
  int? _mood;
  int? _energy;
  int? _stress;

  @override
  Widget build(BuildContext context) {
    final today = AppDateUtils.dateOnly(DateTime.now());
    final saved = ref
        .watch(checkInsProvider)
        .where((c) => AppDateUtils.dateOnly(c.date) == today)
        .firstOrNull;
    final mood = _mood ?? saved?.mood;
    final energy = _energy ?? saved?.energy;
    final stress = _stress ?? saved?.stress;
    final complete = mood != null && energy != null && stress != null;

    return SoftSurface(
      color: AppColors.creamCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Daily check-in', style: AppText.cardTitle)),
              if (saved != null)
                Text('Saved today', style: AppText.caption.copyWith(color: AppColors.flagGreen)),
            ],
          ),
          const SizedBox(height: 4),
          Text('How are you today? Takes ten seconds.', style: AppText.bodyMuted),
          const SizedBox(height: 12),
          _ScaleRow(
            label: 'Mood',
            low: 'Low',
            high: 'Great',
            value: mood,
            onChanged: (v) => setState(() => _mood = v),
          ),
          _ScaleRow(
            label: 'Energy',
            low: 'Drained',
            high: 'Energised',
            value: energy,
            onChanged: (v) => setState(() => _energy = v),
          ),
          _ScaleRow(
            label: 'Stress',
            low: 'Calm',
            high: 'Stressed',
            value: stress,
            onChanged: (v) => setState(() => _stress = v),
          ),
          const SizedBox(height: 12),
          PillButton(
            label: saved == null ? 'Save check-in' : 'Update check-in',
            onPressed: complete
                ? () {
                    ref.read(checkInsProvider.notifier).save(
                      CheckIn(
                        date: today,
                        mood: mood,
                        energy: energy,
                        stress: stress,
                      ),
                    );
                    setState(() {
                      _mood = null;
                      _energy = null;
                      _stress = null;
                    });
                    showSnack(context, 'Check-in saved.');
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _ScaleRow extends StatelessWidget {
  const _ScaleRow({
    required this.label,
    required this.low,
    required this.high,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String low;
  final String high;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 1; i <= 5; i++) ...[
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: value == i,
                    label: '$label $i of 5',
                    excludeSemantics: true,
                    child: Material(
                      color: value == i ? AppColors.ink : AppColors.surface,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => onChanged(i),
                        child: SizedBox(
                          height: 44,
                          child: Center(
                            child: Text(
                              '$i',
                              style: AppText.label.copyWith(
                                color: value == i ? AppColors.surface : AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (i < 5) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(low, style: AppText.caption),
              Text(high, style: AppText.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends ConsumerWidget {
  const _TrendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(checkInsProvider);
    final recent = all.length > 7 ? all.sublist(all.length - 7) : all;

    final series = <(String, Color, int Function(CheckIn))>[
      ('Mood', AppColors.flagGreen, (c) => c.mood),
      ('Energy', AppColors.flagAmber, (c) => c.energy),
      ('Stress', AppColors.flagRed, (c) => c.stress),
    ];

    return SoftSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent check-ins', style: AppText.cardTitle),
          const SizedBox(height: 12),
          if (recent.length < 2)
            const EmptyState(
              title: 'Not enough check-ins yet',
              message: 'Check in on a few days to see a trend.',
              icon: Icons.show_chart_rounded,
            )
          else ...[
            SizedBox(
              height: 160,
              child: Semantics(
                label: 'Line chart of mood, energy and stress over the last '
                    '${recent.length} check-ins.',
                child: LineChart(
                  LineChartData(
                    minY: 1,
                    maxY: 5,
                    minX: 0,
                    maxX: (recent.length - 1).toDouble(),
                    gridData: const FlGridData(drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          reservedSize: 24,
                          getTitlesWidget: (v, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text('${v.round()}', style: AppText.caption),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          reservedSize: 26,
                          getTitlesWidget: (v, meta) {
                            final i = v.round();
                            if (i < 0 || i >= recent.length) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                AppDateUtils.weekdayShort.format(recent[i].date),
                                style: AppText.caption,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      for (final (_, color, pick) in series)
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < recent.length; i++)
                              FlSpot(i.toDouble(), pick(recent[i]).toDouble()),
                          ],
                          color: color,
                          barWidth: 2.6,
                          isCurved: true,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              children: [
                for (final (name, color, _) in series)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(name, style: AppText.caption.copyWith(color: AppColors.ink)),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AddSymptomSheet extends ConsumerStatefulWidget {
  const _AddSymptomSheet();

  @override
  ConsumerState<_AddSymptomSheet> createState() => _AddSymptomSheetState();
}

class _AddSymptomSheetState extends ConsumerState<_AddSymptomSheet> {
  final _label = TextEditingController();
  final _note = TextEditingController();
  Severity _severity = Severity.low;
  DateTime _date = AppDateUtils.dateOnly(DateTime.now());

  @override
  void dispose() {
    _label.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = AppDateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today,
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final label = _label.text.trim();
    if (label.isEmpty) {
      showSnack(context, 'Choose or type what you noticed.');
      return;
    }
    final note = _note.text.trim();
    Navigator.of(context).pop(
      Symptom(
        id: 'symptom_${DateTime.now().microsecondsSinceEpoch}',
        label: label,
        date: _date,
        severity: _severity,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggested = ref.watch(suggestedSymptomsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Add symptom', style: AppText.sectionTitle),
        const SizedBox(height: 4),
        Text('What have you noticed?', style: AppText.bodyMuted),
        const SizedBox(height: 12),
        suggested.when(
          loading: () => const ShimmerLikeSkeleton(height: 40, radius: 20),
          error: (e, _) => Text(
            'Suggestions are unavailable. You can still type your own.',
            style: AppText.caption,
          ),
          data: (items) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in items.take(8))
                AppChip(
                  label: s,
                  selected: _label.text == s,
                  onTap: () => setState(() => _label.text = s),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _label,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'Or describe it'),
        ),
        const FieldLabel('How strong?'),
        Wrap(
          spacing: 8,
          children: [
            for (final s in Severity.values)
              AppChip(
                label: _severityLabel(s),
                dotColor: _severityColor(s),
                selected: _severity == s,
                onTap: () => setState(() => _severity = s),
              ),
          ],
        ),
        if (_severity == Severity.high) ...[
          const SizedBox(height: 8),
          Text(
            'If this feels severe or sudden, please contact a clinician or '
            'local emergency services.',
            style: AppText.caption.copyWith(color: AppColors.flagRed),
          ),
        ],
        const FieldLabel('When?'),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.event_rounded, size: 18),
          label: Text(
            '${AppDateUtils.relativeDay(_date)} · ${AppDateUtils.dayMonth.format(_date)}',
          ),
        ),
        const FieldLabel('Note (optional)'),
        TextField(
          controller: _note,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Anything else worth remembering'),
        ),
        const SizedBox(height: 20),
        PillButton(label: 'Save to journal', onPressed: _save),
      ],
    );
  }
}
