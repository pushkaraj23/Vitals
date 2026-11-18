import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/enums.dart';
import '../../providers/data_providers.dart';

class DoctorReviewDetailScreen extends ConsumerWidget {
  const DoctorReviewDetailScreen({super.key, required this.reviewId});

  final String reviewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(reviewForFlagProvider(reviewId));
    final flagAsync = ref.watch(flagProvider(reviewId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Review detail')),
      body: reviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Could not load this review.',
          onRetry: () => ref.invalidate(reviewForFlagProvider(reviewId)),
        ),
        data: (review) {
          if (review == null) {
            return const EmptyState(
              icon: Icons.medical_services_outlined,
              title: 'Review not found',
              message: 'This review may still be pending or was removed.',
            );
          }
          final flag = flagAsync.value;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (review.simulated)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SimulatedReviewLabel(),
                ),
              SoftSurface(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flag?.title ?? 'Pattern flag',
                      style: AppText.cardTitle,
                    ),
                    const SizedBox(height: 12),
                    Text(review.verdict, style: AppText.screenTitle.copyWith(fontSize: 22)),
                    const SizedBox(height: 8),
                    Text(review.note, style: AppText.bodyMuted),
                    const SizedBox(height: 12),
                    Text(
                      '${review.reviewerName} · ${review.reviewedAt}',
                      style: AppText.caption,
                    ),
                    if (review.isPending) ...[
                      const SizedBox(height: 12),
                      const DoctorBadge(state: DoctorBadgeState.underReview),
                    ] else ...[
                      const SizedBox(height: 12),
                      const DoctorBadge(state: DoctorBadgeState.verified),
                    ],
                  ],
                ),
              ),
              if (flag != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.push(AppRoutes.flag(flag.id)),
                  child: const Text('Open linked flag'),
                ),
              ],
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
