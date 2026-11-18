import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/metric_labels.dart';
import '../../core/widgets/widgets.dart';
import '../../providers/data_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    final flagsAsync = ref.watch(flagsProvider);
    final dailyAsync = ref.watch(dailyProvider(null));
    final status = ref.watch(overallStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Summary')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Could not load summary.',
          onRetry: () => ref.invalidate(userProvider),
        ),
        data: (user) {
          final days = dailyAsync.value ?? [];
          final nonGap = days.where((d) => !d.isGap).length;
          final flags = flagsAsync.value ?? [];

          if (nonGap == 0) {
            return const EmptyState(
              icon: Icons.watch_outlined,
              title: 'No data yet',
              message: 'Connect your watch to start building your baseline',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SoftSurface(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'Your summary',
                      style: AppText.cardTitle,
                    ),
                    const SizedBox(height: 8),
                    FlagChip(status: MetricLabels.statusFromLevel(status)),
                    const SizedBox(height: 12),
                    Text('$nonGap days of vitals stored', style: AppText.body),
                    Text('${flags.length} pattern flags', style: AppText.bodyMuted),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SoftSurface(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('By level', style: AppText.cardTitle),
                    const SizedBox(height: 8),
                    Text(
                      'Red: ${flags.where((f) => f.level == 'red').length}  ·  '
                      'Amber: ${flags.where((f) => f.level == 'amber').length}  ·  '
                      'Green: ${flags.where((f) => f.level == 'green').length}',
                      style: AppText.bodyMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'VitalWatch provides wellness insights, not medical diagnoses.',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}
