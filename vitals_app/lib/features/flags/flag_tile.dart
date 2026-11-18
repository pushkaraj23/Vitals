import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/chart_scale.dart';
import '../../core/utils/metric_labels.dart';
import '../../core/widgets/fade_chart.dart';
import '../../core/widgets/soft_surface.dart';
import '../../data/repositories/flag_repository.dart';
import '../../providers/chart_providers.dart';

/// Solid pastel flag row matching Home “Health Flags” cards.
class FlagTile extends StatelessWidget {
  const FlagTile({super.key, required this.flag, this.spark});

  final FlagModel flag;
  final MetricSeries? spark;

  Color get _solidBg => switch (flag.level) {
        'red' => AppColors.peachCard,
        'amber' => AppColors.creamCard,
        _ => AppColors.mintCard,
      };

  @override
  Widget build(BuildContext context) {
    final status = MetricLabels.statusFromLevel(flag.level);
    final values = spark?.values ?? const <double?>[];
    final solid = spark?.solidPoints ?? const <double>[];
    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++)
        values[i] == null
            ? FlSpot.nullSpot
            : FlSpot(i.toDouble(), values[i]!),
    ];

    return Semantics(
      container: true,
      label: '${status.label}. ${flag.title}',
      child: SoftSurface(
        onTap: () => context.push('/flags/${flag.id}'),
        color: _solidBg,
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: status.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          flag.title,
                          style: AppText.cardTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    flag.explanation,
                    style: AppText.bodyMuted,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MetaPill(
                        icon: status.icon,
                        label: status.label,
                        color: status.color,
                        bg: AppColors.surface,
                      ),
                      _MetaPill(
                        icon: MetricLabels.icon(flag.metric),
                        label: MetricLabels.label(flag.metric),
                      ),
                      if (flag.level != 'green')
                        _MetaPill(
                          icon: Icons.timelapse_rounded,
                          label: '${flag.durationDays}d',
                        ),
                      _MetaPill(
                        icon: Icons.insights_rounded,
                        label: flag.confidence,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 72,
              height: 52,
              child: solid.length < 2
                  ? Icon(MetricLabels.icon(flag.metric), color: status.color)
                  : Builder(
                      builder: (_) {
                        final y = ChartScale.bounds(
                          solid,
                          metric: flag.metric,
                        );
                        return FadeChart(
                          fadeFraction: 0.14,
                          child: LineChart(
                            LineChartData(
                              minY: y.minY,
                              maxY: y.maxY,
                              gridData: const FlGridData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              lineTouchData:
                                  const LineTouchData(enabled: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  color: status.color,
                                  barWidth: 2,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: status.color
                                        .withValues(alpha: 0.12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    this.color,
    this.bg,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppColors.muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppText.caption.copyWith(
              color: color ?? AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
