import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/chart_scale.dart';
import '../../core/utils/metric_labels.dart';
import '../../core/widgets/fade_chart.dart';
import '../../core/widgets/ink_app_bar.dart';
import '../../core/widgets/metric_spark_card.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/soft_surface.dart';
import '../../core/widgets/state_views.dart';
import '../../data/health_connect/health_connect_auth_notifier.dart';
import '../../data/repositories/flag_repository.dart';
import '../../domain/models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chart_providers.dart';
import '../../providers/data_providers.dart';

class FsHomeScreen extends ConsumerStatefulWidget {
  const FsHomeScreen({super.key});

  @override
  ConsumerState<FsHomeScreen> createState() => _FsHomeScreenState();
}

class _FsHomeScreenState extends ConsumerState<FsHomeScreen> {
  bool _syncing = false;

  Future<void> _syncNow({required bool isDemo}) async {
    setState(() => _syncing = true);
    try {
      if (isDemo) {
        ref.invalidate(dailyProvider(null));
        ref.invalidate(flagsProvider);
        ref.invalidate(baselinesProvider);
        ref.invalidate(userProvider);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demo data refreshed from your cloud account.'),
            ),
          );
        }
        return;
      }

      final uid = ref.read(currentUidProvider);
      if (uid == null) return;
      final result = await ref.read(healthSyncServiceProvider).syncUser(uid);
      ref.invalidate(dailyProvider(null));
      ref.invalidate(flagsProvider);
      ref.invalidate(baselinesProvider);
      ref.invalidate(userProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Synced ${result.daysWritten} day(s) from Health Connect.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.flagRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);
    final flagsAsync = ref.watch(flagsProvider);
    final dailyAsync = ref.watch(dailyProvider(null));
    final seriesMap = ref.watch(homeMetricSeriesProvider);
    final heroMetric = ref.watch(homeHeroMetricProvider);

    final isDemo = userAsync.value?.isDemo ?? false;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        titleWidget: userAsync.when(
          loading: () => Text(
            'VitalWatch',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          error: (_, _) => Text(
            'VitalWatch',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          data: (user) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Hi, ${user?.firstName ?? 'Friend'}',
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('EEEE, MMM d').format(DateTime.now()),
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: _syncing ? 'Syncing…' : 'Sync now',
            onPressed: _syncing ? null : () => _syncNow(isDemo: isDemo),
            icon: _syncing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: 'Checkups',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => context.push(AppRoutes.alerts),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(
          message: 'Unable to load your profile.',
          onRetry: () => ref.invalidate(userProvider),
        ),
        data: (user) {
          return flagsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => ErrorState(
              message: 'Unable to load health flags.',
              onRetry: () => ref.invalidate(flagsProvider),
            ),
            data: (flags) {
              final daily = dailyAsync.value ?? [];
              final nonGapDays = daily.where((d) => !d.isGap).length;
              final worstLevel = flags.any((f) => f.level == 'red')
                  ? 'red'
                  : (flags.any((f) => f.level == 'amber') ? 'amber' : 'green');
              final overallStatus = MetricLabels.statusFromLevel(worstLevel);
              final hero = seriesMap[heroMetric];

              return RefreshIndicator(
                onRefresh: () => _syncNow(isDemo: isDemo),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  children: [
                    if (nonGapDays == 0 && flags.isEmpty) ...[
                      _EmptyWatchCard(
                        onConnect: () => context.push('/connect'),
                      ),
                    ] else ...[
                      _StatusHero(
                        status: overallStatus,
                        series: hero,
                        onOpenTimeline: () {
                          ref
                              .read(timelineSelectedMetricProvider.notifier)
                              .select(heroMetric);
                          context.go(AppRoutes.timeline);
                        },
                      ),
                      const SizedBox(height: 20),
                      Text('Today’s vitals', style: AppText.cardTitle),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 168,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final entry in [
                              ('restingHr', AppColors.peachCard),
                              ('hrv', AppColors.lavenderCard),
                              ('sleepDeep', AppColors.skyCard),
                              ('steps', AppColors.mintCard),
                              ('spo2', AppColors.creamCard),
                            ]) ...[
                              MetricSparkCard(
                                series: seriesMap[entry.$1]!,
                                background: entry.$2,
                                onTap: () {
                                  ref
                                      .read(timelineSelectedMetricProvider
                                          .notifier)
                                      .select(entry.$1);
                                  context.go(AppRoutes.timeline);
                                },
                              ),
                              const SizedBox(width: 10),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Text('Health Flags', style: AppText.cardTitle),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.flags),
                            child: const Text('View all'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (flags.isEmpty)
                        SoftSurface(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No concerning patterns right now.',
                            style: AppText.bodyMuted,
                          ),
                        )
                      else
                        for (final flag in flags.take(4)) ...[
                          _VisualFlagCard(
                            flag: flag,
                            spark: seriesMap[flag.metric],
                            onTap: () => context.push('/flags/${flag.id}'),
                          ),
                          const SizedBox(height: 10),
                        ],
                      const SizedBox(height: 10),
                      SoftSurface(
                        onTap: () => context.push(AppRoutes.symptoms),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.lavenderCard,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.edit_note_rounded),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Symptoms journal',
                                      style: AppText.cardTitle),
                                  Text(
                                    'Log how you feel alongside your patterns.',
                                    style: AppText.caption,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'VitalWatch provides wellness insights, not medical diagnoses.',
                      textAlign: TextAlign.center,
                      style: AppText.caption,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyWatchCard extends StatelessWidget {
  const _EmptyWatchCard({required this.onConnect});
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      color: AppColors.skyCard,
      radius: 28,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.watch_rounded, size: 48),
          const SizedBox(height: 12),
          Text(
            'Connect your watch to start building your baseline',
            textAlign: TextAlign.center,
            style: AppText.cardTitle,
          ),
          const SizedBox(height: 8),
          Text(
            'VitalWatch maps Health Connect vitals into charts and health flags.',
            textAlign: TextAlign.center,
            style: AppText.bodyMuted,
          ),
          const SizedBox(height: 16),
          PillButton(
            label: 'Connect Watch',
            icon: Icons.bluetooth_searching_rounded,
            onPressed: onConnect,
          ),
        ],
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({
    required this.status,
    required this.series,
    required this.onOpenTimeline,
  });

  final FlagStatus status;
  final MetricSeries? series;
  final VoidCallback onOpenTimeline;

  Color get _solidBg => switch (status) {
        FlagStatus.red => AppColors.peachCard,
        FlagStatus.amber => AppColors.creamCard,
        FlagStatus.green => AppColors.mintCard,
      };

  @override
  Widget build(BuildContext context) {
    final title = switch (status) {
      FlagStatus.red => 'Attention recommended',
      FlagStatus.amber => 'Pattern worth watching',
      FlagStatus.green => 'Patterns look stable',
    };
    final metric = series?.metric ?? 'restingHr';
    final latest = series?.latest;
    final valueLabel = latest == null
        ? '—'
        : '${latest >= 100 ? latest.toStringAsFixed(0) : latest.toStringAsFixed(1)} ${MetricLabels.unit(metric)}';

    final values = series?.values ?? const <double?>[];
    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++)
        values[i] == null
            ? FlSpot.nullSpot
            : FlSpot(i.toDouble(), values[i]!),
    ];
    final solid = series?.solidPoints ?? const <double>[];
    final yBounds = ChartScale.bounds(solid, metric: metric);
    final minY = yBounds.minY;
    final maxY = yBounds.maxY;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onOpenTimeline,
        child: Ink(
          decoration: BoxDecoration(
            color: _solidBg,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: status.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    MetricLabels.label(metric),
                    style: AppText.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: AppText.cardTitle.copyWith(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                'Recent ${MetricLabels.label(metric)}: $valueLabel',
                style: AppText.bodyMuted,
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 120,
                child: solid.length < 2
                    ? Center(
                        child: Text(
                          'Not enough points yet for a trend',
                          style: AppText.caption,
                        ),
                      )
                    : FadeChart(
                        child: LineChart(
                          LineChartData(
                            minY: minY,
                            maxY: maxY,
                            clipData: const FlClipData.all(),
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            extraLinesData: series?.baselineMean != null
                                ? ExtraLinesData(
                                    horizontalLines: [
                                      HorizontalLine(
                                        y: series!.baselineMean!,
                                        color: AppColors.muted
                                            .withValues(alpha: 0.45),
                                        strokeWidth: 1.2,
                                        dashArray: const [6, 4],
                                      ),
                                    ],
                                  )
                                : null,
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: status.color,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: status.color.withValues(alpha: 0.14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                'Baseline shown as dashed line · tap for timeline',
                style: AppText.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisualFlagCard extends StatelessWidget {
  const _VisualFlagCard({
    required this.flag,
    required this.spark,
    required this.onTap,
  });

  final FlagModel flag;
  final MetricSeries? spark;
  final VoidCallback onTap;

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

    return SoftSurface(
      onTap: onTap,
      color: _solidBg,
      radius: 24,
      padding: const EdgeInsets.all(14),
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
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${flag.durationDays}d · ${flag.confidence} confidence',
                  style: AppText.caption,
                ),
                const SizedBox(height: 4),
                Text(
                  flag.explanation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyMuted.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            height: 48,
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
                                  color:
                                      status.color.withValues(alpha: 0.12),
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
    );
  }
}
