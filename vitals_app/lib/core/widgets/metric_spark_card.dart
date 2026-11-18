import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/chart_scale.dart';
import '../utils/metric_labels.dart';
import '../../domain/models/enums.dart';
import '../../providers/chart_providers.dart';
import 'fade_chart.dart';

/// Solid pastel metric tile with a soft-faded sparkline.
class MetricSparkCard extends StatelessWidget {
  const MetricSparkCard({
    super.key,
    required this.series,
    required this.background,
    this.onTap,
    this.width = 156,
  });

  final MetricSeries series;
  final Color background;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final status = series.status;
    final label = MetricLabels.label(series.metric);
    final unit = MetricLabels.unit(series.metric);
    final valueText = series.latest == null
        ? '—'
        : series.latest! >= 100
            ? series.latest!.toStringAsFixed(0)
            : series.latest!.toStringAsFixed(1);

    final spots = <FlSpot>[
      for (var i = 0; i < series.values.length; i++)
        series.values[i] == null
            ? FlSpot.nullSpot
            : FlSpot(i.toDouble(), series.values[i]!),
    ];
    final solid = series.solidPoints;
    final yBounds = ChartScale.bounds(solid, metric: series.metric);
    final minY = solid.isEmpty ? null : yBounds.minY;
    final maxY = solid.isEmpty ? null : yBounds.maxY;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          width: width,
          height: 168,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(MetricLabels.icon(series.metric),
                        size: 18, color: status.color),
                    const Spacer(),
                    _MiniStatus(status: status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      valueText,
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(unit, style: AppText.caption),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  height: 40,
                  child: solid.length < 2
                      ? const SizedBox.shrink()
                      : FadeChart(
                          fadeFraction: 0.12,
                          child: LineChart(
                            LineChartData(
                              minY: minY,
                              maxY: maxY,
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
                                    color:
                                        status.color.withValues(alpha: 0.12),
                                  ),
                                ),
                              ],
                            ),
                          ),
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

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({required this.status});
  final FlagStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: status.color,
        ),
      ),
    );
  }
}
