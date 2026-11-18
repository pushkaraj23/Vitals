import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../providers/data_providers.dart';

class DoctorReviewsScreen extends ConsumerWidget {
  const DoctorReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(reviewsProvider);
    final flagsAsync = ref.watch(flagsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Doctor reviews')),
      body: reviewsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Could not load reviews.',
          onRetry: () => ref.invalidate(reviewsProvider),
        ),
        data: (reviews) {
          if (reviews.isEmpty) {
            return const EmptyState(
              icon: Icons.medical_services_outlined,
              title: 'No reviews yet',
              message:
                  'When a clinician reviews a pattern flag, the verdict appears here.',
            );
          }

          final flagTitles = {
            for (final f in flagsAsync.value ?? []) f.id: f.title,
          };

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: reviews.length + 1,
            itemBuilder: (context, index) {
              if (index == reviews.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'VitalWatch provides wellness insights, not medical diagnoses.',
                    style: AppText.caption,
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final review = reviews[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SoftSurface(
                  onTap: () =>
                      context.push(AppRoutes.doctorReview(review.flagId)),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (review.simulated)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: SimulatedReviewLabel(),
                        ),
                      Text(
                        flagTitles[review.flagId] ?? 'Pattern flag',
                        style: AppText.cardTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(review.verdict, style: AppText.body),
                      const SizedBox(height: 4),
                      Text(
                        '${review.reviewerName} · ${review.reviewedAt}',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
