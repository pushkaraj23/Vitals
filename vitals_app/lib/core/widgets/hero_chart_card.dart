import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../../domain/models/enums.dart';

class HeroChartCard extends StatefulWidget {
  const HeroChartCard({
    super.key,
    required this.title,
    required this.valueLabel,
    required this.points,
    this.rangeLabels = const ['1W', '1M', '3M', '6M', 'ALL'],
    this.selectedRangeIndex = 0,
    this.onRangeSelected,
    this.semanticsSummary,
    this.background,
    this.status,
    this.subtitle,
    this.heroMetricLabel,
    this.heroMetricUnit,
    this.latestMetricValue,
  });

  final String title;
  final String valueLabel;
  final List<double> points;
  final List<String> rangeLabels;
  final int selectedRangeIndex;
  final ValueChanged<int>? onRangeSelected;
  final String? semanticsSummary;
  final Color? background;
  final FlagStatus? status;
  final String? subtitle;
  final String? heroMetricLabel;
  final String? heroMetricUnit;
  final double? latestMetricValue;

  @override
  State<HeroChartCard> createState() => _HeroChartCardState();
}

class _HeroChartCardState extends State<HeroChartCard> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < widget.points.length; i++)
        FlSpot(i.toDouble(), widget.points[i]),
    ];
    final minY = widget.points.isEmpty
        ? 0.0
        : widget.points.reduce((a, b) => a < b ? a : b) * 0.92;
    final maxY = widget.points.isEmpty
        ? 1.0
        : widget.points.reduce((a, b) => a > b ? a : b) * 1.08;

    return Semantics(
      label: widget.semanticsSummary ??
          '${widget.title} ${widget.valueLabel}. Chart with ${widget.points.length} points.',
      child: Container(
        decoration: BoxDecoration(
          gradient: widget.background != null
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE6F1FD),
                    Color(0xFFD8EBFC),
                    Color(0xFFC7E2FA),
                  ],
                ),
          color: widget.background,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B4D89).withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Category tag & Status pill
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_graph_rounded,
                        size: 13,
                        color: Color(0xFF1B4D89),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.title.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1B4D89),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (widget.status != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.status!.background,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: widget.status!.color.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.status!.icon,
                          size: 12,
                          color: widget.status!.color,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.status!.label,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: widget.status!.color,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Score and subheadline
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  widget.valueLabel,
                  style: GoogleFonts.manrope(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    height: 1.0,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '/100',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.subtitle!,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft.withValues(alpha: 0.78),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Metric tracking tag
            if (widget.heroMetricLabel != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timeline_rounded,
                      size: 13,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Wave: ${widget.heroMetricLabel}',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    if (widget.latestMetricValue != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: AppColors.muted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${Format.number(widget.latestMetricValue!, decimals: 0)} ${widget.heroMetricUnit ?? ''}',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Smooth curved trend chart
            SizedBox(
              height: 148,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: false,
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions ||
                          response?.lineBarSpots == null ||
                          response!.lineBarSpots!.isEmpty) {
                        setState(() => _touchedIndex = null);
                        return;
                      }
                      setState(() {
                        _touchedIndex = response.lineBarSpots!.first.spotIndex;
                      });
                    },
                    getTouchedSpotIndicator: (bar, indexes) => indexes
                        .map(
                          (index) => TouchedSpotIndicatorData(
                            const FlLine(
                              color: Color(0xFF1D4ED8),
                              strokeWidth: 1.5,
                            ),
                            FlDotData(
                              getDotPainter: (spot, percent, barData, i) =>
                                  FlDotCirclePainter(
                                radius: 6,
                                color: const Color(0xFF1D4ED8),
                                strokeWidth: 2.5,
                                strokeColor: AppColors.surface,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppColors.ink,
                      tooltipBorderRadius: BorderRadius.circular(12),
                      getTooltipItems: (spots) => spots
                          .map(
                            (spot) => LineTooltipItem(
                              Format.number(spot.y, decimals: 1),
                              GoogleFonts.manrope(
                                color: AppColors.surface,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  showingTooltipIndicators: _touchedIndex == null
                      ? const []
                      : [
                          ShowingTooltipIndicators([
                            LineBarSpot(
                              LineChartBarData(spots: spots),
                              0,
                              spots[_touchedIndex!],
                            ),
                          ]),
                        ],
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1D4ED8),
                          Color(0xFF2563EB),
                          Color(0xFF60A5FA),
                        ],
                      ),
                      barWidth: 3.2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF3B82F6).withValues(alpha: 0.32),
                            const Color(0xFF3B82F6).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Modern capsule range switcher
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < widget.rangeLabels.length; i++)
                        GestureDetector(
                          onTap: () => widget.onRangeSelected?.call(i),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: i == widget.selectedRangeIndex
                                  ? AppColors.surface
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: i == widget.selectedRangeIndex
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1.5),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              widget.rangeLabels[i],
                              style: GoogleFonts.manrope(
                                fontSize: 11.5,
                                fontWeight: i == widget.selectedRangeIndex
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: i == widget.selectedRangeIndex
                                    ? AppColors.ink
                                    : AppColors.muted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
