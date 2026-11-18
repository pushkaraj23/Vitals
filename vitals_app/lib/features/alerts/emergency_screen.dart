import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Baseline;

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/metric_format.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/home_snapshot.dart';
import '../../providers/providers.dart';

/// Full-screen red escalation. It never dials by itself: "Call emergency"
/// only opens a confirmation dialog in this demo build.
class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});

  static const emergencyNumber = '112';

  // A darker red than the flag colour so white text stays easy to read.
  static final _background = Color.lerp(AppColors.flagRed, AppColors.ink, 0.28)!;

  Future<void> _confirmCall(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.call_rounded, color: AppColors.flagRed),
        title: const Text('Call emergency services?'),
        content: Text(
          'This would call $emergencyNumber. Nothing is dialled in this '
          'demo.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.flagRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Call'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      showSnack(context, 'Demo only: no call was placed.');
    }
  }

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const white = AppColors.surface;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: CenteredBody(
          maxWidth: 560,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _close(context),
                  style: TextButton.styleFrom(foregroundColor: white),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Column(
                  children: [
                    const Icon(Icons.emergency_rounded, size: 72, color: white),
                    const SizedBox(height: 16),
                    Text(
                      'Seek medical care now',
                      textAlign: TextAlign.center,
                      style: AppText.screenTitle.copyWith(
                        color: white,
                        fontSize: 32,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'If you feel unwell, or you are worried, get help from a '
                'medical professional straight away. Do not wait for an app.',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: white, fontSize: 17),
              ),
              const SizedBox(height: 32),
              PillButton(
                label: 'Call emergency ($emergencyNumber)',
                icon: Icons.call_rounded,
                variant: PillButtonVariant.secondary,
                onPressed: () => _confirmCall(context),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showSummary(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: white,
                  side: const BorderSide(color: white, width: 1.6),
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Show summary'),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'VitalWatch gives wellness insights, not a medical '
                  'diagnosis. The summary shows your recent numbers to help '
                  'a clinician; it does not say what is wrong.',
                  style: AppText.caption.copyWith(color: white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSummary(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const _SummarySheet(),
    );
  }
}

class _SummarySheet extends ConsumerWidget {
  const _SummarySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeSnapshotProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShimmerLikeSkeleton(height: 28, width: 180),
                SizedBox(height: 16),
                ShimmerLikeSkeleton(height: 120, radius: 20),
              ],
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: FeatureError(
              what: 'your summary',
              onRetry: () => ref.invalidate(homeSnapshotProvider),
            ),
          ),
          data: (s) => _content(s),
        ),
      ),
    );
  }

  Widget _content(HomeSnapshot s) {
    final p = s.profile;
    final reading = s.latestReading;
    final flags = s.activeFlags;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      shrinkWrap: true,
      children: [
        Text('Summary for the medical team', style: AppText.sectionTitle),
        const SizedBox(height: 4),
        Text(
          '${p.name} · ${p.age} · ${p.sex.label}',
          style: AppText.bodyMuted,
        ),
        const FieldLabel('Patterns noticed in wearable data'),
        if (flags.isEmpty)
          Text('No active patterns right now.', style: AppText.body)
        else
          for (final f in flags)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• ${f.title}: ${f.metric.label} outside usual range for '
                '${f.streakDays} days',
                style: AppText.body,
              ),
            ),
        if (reading != null) ...[
          const FieldLabel('Latest readings'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in VitalMetric.values)
                if (reading.valueOf(m) != null)
                  Chip(
                    label: Text(
                      '${m.label} ${MetricFormat.withUnit(m, reading.valueOf(m)!)}',
                    ),
                  ),
            ],
          ),
        ],
        if (p.familyHistoryTags.isNotEmpty) ...[
          const FieldLabel('Family history noted'),
          Text(
            p.familyHistoryTags.map((t) => t.replaceAll('_', ' ')).join(', '),
            style: AppText.body,
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Generated from your own wearable data. Not a diagnosis.',
          style: AppText.caption,
        ),
      ],
    );
  }

}
