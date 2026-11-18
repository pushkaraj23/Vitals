import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/metric_labels.dart';
import '../../core/widgets/ink_app_bar.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/flag_repository.dart';
import '../../data/repositories/rule_repository.dart';
import '../../domain/models/enums.dart';
import '../../providers/data_providers.dart';

/// Checkups derived from pattern flags (Info / Advise / Urgent).
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  Future<void> _showDoctorSummary(
    BuildContext context,
    FlagModel flag,
    RuleModel? rule,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Doctor-ready summary',
              style: AppText.cardTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 12),
            SoftSurface(
              color: AppColors.lavenderCard,
              radius: 22,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flag.title,
                    style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(flag.explanation, style: AppText.bodyMuted),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SoftSurface(
              radius: 22,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Metric: ${MetricLabels.label(flag.metric)} · '
                    'Duration: ${flag.durationDays} days · '
                    'Confidence: ${flag.confidence}',
                    style: AppText.caption,
                  ),
                  if (flag.baselineValue != null ||
                      flag.currentValue != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Baseline ${flag.baselineValue?.toStringAsFixed(1) ?? '—'} → '
                      'Recent ${flag.currentValue?.toStringAsFixed(1) ?? '—'} '
                      '${MetricLabels.unit(flag.metric)}',
                      style: AppText.caption.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if ((rule?.specialist ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Specialist: ${rule!.specialist}',
                      style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'VitalWatch provides wellness insights, not medical diagnoses. '
              'This summary is for discussion with a clinician.',
              style: AppText.caption,
            ),
          ],
        ),
      ),
    );
  }

  Color _cardColor(AlertTier tier) => switch (tier) {
        AlertTier.urgent || AlertTier.emergency => AppColors.peachCard,
        AlertTier.advise => AppColors.creamCard,
        AlertTier.info => AppColors.skyCard,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagsAsync = ref.watch(flagsProvider);
    final rulesAsync = ref.watch(rulesProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        title: 'Checkups',
        subtitle: 'Insights worth a closer look',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Alert preferences',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push(AppRoutes.alertPreferences),
          ),
        ],
      ),
      body: flagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Could not load checkups.',
          onRetry: () => ref.invalidate(flagsProvider),
        ),
        data: (flags) {
          final actionable =
              flags.where((f) => f.level != 'green').toList(growable: false);

          if (actionable.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                SoftSurface(
                  color: AppColors.mintCard,
                  radius: 28,
                  padding: const EdgeInsets.fromLTRB(22, 32, 22, 32),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 32,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No checkups right now',
                        style: AppText.cardTitle.copyWith(fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Connect your watch to start building your baseline. Stable patterns show here as wellness insights.',
                        style: AppText.bodyMuted,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          final rules = {
            for (final r in rulesAsync.value ?? <RuleModel>[]) r.id: r,
          };

          final urgent = actionable
              .where((f) {
                final t = MetricLabels.checkupTier(f.level, f.severity);
                return t == AlertTier.urgent || t == AlertTier.emergency;
              })
              .length;
          final advise = actionable
              .where(
                (f) =>
                    MetricLabels.checkupTier(f.level, f.severity) ==
                    AlertTier.advise,
              )
              .length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(flagsProvider);
              await ref.read(flagsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SoftSurface(
                        color: AppColors.peachCard,
                        radius: 22,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$urgent',
                              style: GoogleFonts.manrope(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text('Urgent', style: AppText.caption),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SoftSurface(
                        color: AppColors.creamCard,
                        radius: 22,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$advise',
                              style: GoogleFonts.manrope(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text('Advise', style: AppText.caption),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SoftSurface(
                        color: AppColors.skyCard,
                        radius: 22,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${actionable.length}',
                              style: GoogleFonts.manrope(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text('Total', style: AppText.caption),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Needs attention', style: AppText.cardTitle),
                const SizedBox(height: 10),
                for (final flag in actionable) ...[
                  Builder(
                    builder: (context) {
                      final tier =
                          MetricLabels.checkupTier(flag.level, flag.severity);
                      final rule = rules[flag.ruleId];
                      return SoftSurface(
                        color: _cardColor(tier),
                        radius: 28,
                        padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
                        onTap: () => context.push(AppRoutes.flag(flag.id)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(tier.icon, size: 15),
                                      const SizedBox(width: 6),
                                      Text(
                                        tier.label,
                                        style: AppText.caption.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                FlagChip(
                                  status:
                                      MetricLabels.statusFromLevel(flag.level),
                                  compact: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              flag.title,
                              style: AppText.cardTitle.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              flag.explanation,
                              style: AppText.bodyMuted,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if ((rule?.specialist ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Specialist: ${rule!.specialist}',
                                style: AppText.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Material(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(999),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: () => _showDoctorSummary(
                                    context,
                                    flag,
                                    rule,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Doctor-ready summary',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
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
