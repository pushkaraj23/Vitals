import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Baseline;

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/metric_format.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/doctor_review.dart';
import '../../domain/models/flag.dart';
import '../../providers/providers.dart';
import 'doctor_reviews_screen.dart';

class DoctorReviewDetailScreen extends ConsumerWidget {
  const DoctorReviewDetailScreen({super.key, required this.reviewId});

  final String reviewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(doctorReviewsProvider);
    final flags = ref.watch(flagsProvider).value ?? const <Flag>[];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Review')),
      body: SafeArea(
        child: CenteredBody(
          child: reviewsAsync.when(
            loading: () => const ListSkeleton(blocks: 3, blockHeight: 140),
            error: (e, _) => FeatureError(
              what: 'this review',
              onRetry: () => ref.invalidate(doctorReviewsProvider),
            ),
            data: (reviews) {
              DoctorReview? review;
              for (final r in reviews) {
                if (r.id == reviewId) review = r;
              }
              if (review == null) {
                return EmptyState(
                  title: 'Review not found',
                  message: 'It may have been removed.',
                  icon: Icons.search_off_rounded,
                  actionLabel: 'Back to reviews',
                  onAction: () => context.go(AppRoutes.doctors),
                );
              }
              Flag? flag;
              for (final f in flags) {
                if (f.id == review.flagId) flag = f;
              }
              return _Body(review: review, flag: flag, reviews: reviews, flags: flags);
            },
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.review,
    required this.flag,
    required this.reviews,
    required this.flags,
  });

  final DoctorReview review;
  final Flag? flag;
  final List<DoctorReview> reviews;
  final List<Flag> flags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requested = ref.watch(secondOpinionsProvider).contains(review.id);
    final title = flag?.title ?? 'Pattern review';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(title, style: AppText.screenTitle.copyWith(fontSize: 24)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DoctorBadge(state: review.badge),
            const SimulatedReviewLabel(),
          ],
        ),
        const SizedBox(height: 16),
        SoftSurface(
          color: AppColors.lavenderCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(review.verdict.label, style: AppText.sectionTitle),
              const SizedBox(height: 6),
              Text(verdictExplanation(review.verdict), style: AppText.body),
              if (review.note != null && review.note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Reviewer note', style: AppText.label),
                const SizedBox(height: 4),
                Text(review.note!, style: AppText.body),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SoftSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reviewer', style: AppText.label),
              const SizedBox(height: 4),
              Text(review.doctorName, style: AppText.cardTitle),
              Text(review.credentials, style: AppText.caption),
              const Divider(height: 24),
              _TimelineRow(
                icon: Icons.send_rounded,
                label: 'Requested',
                value: AppDateUtils.dayMonthYear.format(review.requestedAt),
              ),
              const SizedBox(height: 10),
              _TimelineRow(
                icon: review.reviewedAt == null
                    ? Icons.hourglass_top_rounded
                    : Icons.check_circle_rounded,
                label: review.reviewedAt == null ? 'Waiting for review' : 'Reviewed',
                value: review.reviewedAt == null
                    ? 'In progress'
                    : AppDateUtils.dayMonthYear.format(review.reviewedAt!),
              ),
            ],
          ),
        ),
        if (flag != null) ...[
          const SizedBox(height: 16),
          SoftSurface(
            onTap: () => context.push(AppRoutes.flag(flag!.id)),
            child: Row(
              children: [
                Icon(flag!.status.icon, color: flag!.status.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What was reviewed', style: AppText.label),
                      const SizedBox(height: 2),
                      Text(flag!.summary, style: AppText.bodyMuted),
                      if (flag!.currentValue != null &&
                          flag!.baselineLow != null &&
                          flag!.baselineHigh != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${flag!.metric.label}: ${MetricFormat.withUnit(flag!.metric, flag!.currentValue!)} '
                          '(usual ${MetricFormat.range(flag!.metric, flag!.baselineLow!, flag!.baselineHigh!)})',
                          style: AppText.caption.copyWith(color: AppColors.ink),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        PillButton(
          label: requested ? 'Second opinion requested' : 'Request second opinion',
          icon: Icons.groups_2_outlined,
          variant: PillButtonVariant.secondary,
          onPressed: requested
              ? null
              : () => showSecondOpinionSheet(
                  context,
                  reviews: reviews,
                  flags: flags,
                  initialReviewId: review.id,
                ),
        ),
        const SizedBox(height: 16),
        const DisclaimerBanner(),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppText.body)),
        Text(value, style: AppText.caption.copyWith(color: AppColors.ink)),
      ],
    );
  }
}
