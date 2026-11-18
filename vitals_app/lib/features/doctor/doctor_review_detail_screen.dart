import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/review_repository.dart';
import '../../domain/models/enums.dart';
import '../../providers/data_providers.dart';

class DoctorReviewDetailScreen extends ConsumerWidget {
  const DoctorReviewDetailScreen({super.key, required this.reviewId});

  final String reviewId;

  DoctorBadgeState _badgeFor(ReviewModel review) {
    if (review.isPending) return DoctorBadgeState.underReview;
    if (review.verdict == 'Needs consultation') {
      return DoctorBadgeState.needsConsultation;
    }
    if (review.isReviewed) return DoctorBadgeState.verified;
    return DoctorBadgeState.notReviewed;
  }

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
                color: AppColors.skyCard,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DoctorBadge(state: _badgeFor(review)),
                    const SizedBox(height: 12),
                    Text(
                      flag?.title ?? 'Pattern flag',
                      style: AppText.cardTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(review.statusLabel, style: AppText.body),
                    if (flag?.explanation != null &&
                        flag!.explanation.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(flag.explanation, style: AppText.bodyMuted),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SoftSurface(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Doctor update', style: AppText.cardTitle),
                    const SizedBox(height: 10),
                    if (review.isPending) ...[
                      Text(
                        review.isInReview
                            ? 'A doctor has opened your request and is reviewing it.'
                            : 'Your request is in the doctor portal queue. This page updates when they reply.',
                        style: AppText.bodyMuted,
                      ),
                    ] else ...[
                      if (review.verdict.isNotEmpty)
                        Text(
                          review.verdict,
                          style: AppText.screenTitle.copyWith(fontSize: 22),
                        ),
                      if (review.note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(review.note, style: AppText.bodyMuted),
                      ],
                    ],
                    if (review.note.isNotEmpty && review.isPending) ...[
                      const SizedBox(height: 8),
                      Text(review.note, style: AppText.bodyMuted),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      review.isPending
                          ? 'Requested · ${review.reviewedAt}'
                          : '${review.reviewerName} · ${review.reviewedAt}',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              if (flag != null) ...[
                const SizedBox(height: 16),
                SoftSurface(
                  onTap: () => context.push(AppRoutes.flag(flag.id)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Open linked health flag',
                          style: AppText.body,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.push(AppRoutes.doctors),
                child: const Text('Back to all reviews'),
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
