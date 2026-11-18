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

class DoctorReviewsScreen extends ConsumerWidget {
  const DoctorReviewsScreen({super.key});

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
    final reviewsAsync = ref.watch(reviewsProvider);
    final flagsAsync = ref.watch(flagsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('My reviews')),
      body: reviewsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Could not load reviews.',
          onRetry: () => ref.invalidate(reviewsProvider),
        ),
        data: (reviews) {
          if (reviews.isEmpty) {
            return EmptyState(
              icon: Icons.medical_services_outlined,
              title: 'No reviews yet',
              message:
                  'Request a review from any health flag. When a doctor replies in the portal, the update shows here live.',
              actionLabel: 'Browse flags',
              onAction: () => context.go(AppRoutes.flags),
            );
          }

          final flagTitles = {
            for (final f in flagsAsync.value ?? []) f.id: f.title,
          };

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(reviewsProvider);
              await ref.read(reviewsProvider.future);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: reviews.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Live updates from the doctor portal. Pending requests stay at the top.',
                      style: AppText.bodyMuted,
                    ),
                  );
                }
                final review = reviews[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SoftSurface(
                    onTap: () =>
                        context.push(AppRoutes.doctorReview(review.flagId)),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            DoctorBadge(
                              state: _badgeFor(review),
                              compact: true,
                            ),
                            const Spacer(),
                            Text(review.statusLabel, style: AppText.caption),
                          ],
                        ),
                        if (review.simulated)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: SimulatedReviewLabel(),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          flagTitles[review.flagId] ?? 'Pattern flag',
                          style: AppText.cardTitle,
                        ),
                        if (review.verdict.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(review.verdict, style: AppText.body),
                        ],
                        if (review.note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            review.note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyMuted,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          review.isPending
                              ? 'Requested · ${review.reviewedAt}'
                              : '${review.reviewerName} · ${review.reviewedAt}',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
