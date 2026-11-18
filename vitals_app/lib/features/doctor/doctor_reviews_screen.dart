import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Baseline;

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/doctor_review.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/flag.dart';
import '../../providers/providers.dart';

/// Review ids for which a second opinion was requested (demo state).
class SecondOpinionsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(personaIdProvider);
    return const {};
  }

  void request(String reviewId) => state = {...state, reviewId};
}

final secondOpinionsProvider =
    NotifierProvider<SecondOpinionsNotifier, Set<String>>(
      SecondOpinionsNotifier.new,
    );

/// Title of the flag a review is about (falls back to a generic label).
String flagTitleFor(List<Flag> flags, String flagId) {
  for (final f in flags) {
    if (f.id == flagId) return f.title;
  }
  return 'Pattern review';
}

/// Short, neutral explanation of what a verdict means.
String verdictExplanation(DoctorVerdict verdict) => switch (verdict) {
  DoctorVerdict.confirmed =>
    'The sample reviewer agreed the pattern in your data is real and worth '
        'keeping an eye on.',
  DoctorVerdict.notConcerning =>
    'The sample reviewer felt this pattern is not concerning for now. '
        'Keep tracking and note how you feel.',
  DoctorVerdict.needsConsultation =>
    'The sample reviewer suggested talking this through with a clinician in '
        'person.',
  DoctorVerdict.pending =>
    'A reviewer has not looked at this yet. You will see their note here.',
};

Future<void> showSecondOpinionSheet(
  BuildContext context, {
  required List<DoctorReview> reviews,
  required List<Flag> flags,
  String? initialReviewId,
}) async {
  await showFormSheet<void>(
    context,
    builder: (_) => _SecondOpinionSheet(
      reviews: reviews,
      flags: flags,
      initialReviewId: initialReviewId,
    ),
  );
}

class DoctorReviewsScreen extends ConsumerWidget {
  const DoctorReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(doctorReviewsProvider);
    final flagsAsync = ref.watch(flagsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Doctor reviews')),
      body: SafeArea(
        child: CenteredBody(
          child: reviewsAsync.when(
            loading: () => const ListSkeleton(blocks: 3, blockHeight: 140),
            error: (e, _) => FeatureError(
              what: 'your reviews',
              onRetry: () {
                ref.invalidate(doctorReviewsProvider);
                ref.invalidate(flagsProvider);
              },
            ),
            data: (reviews) {
              final flags = flagsAsync.value ?? const <Flag>[];
              return _buildData(context, ref, reviews, flags);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildData(
    BuildContext context,
    WidgetRef ref,
    List<DoctorReview> reviews,
    List<Flag> flags,
  ) {
    final reviewedFlagIds = reviews.map((r) => r.flagId).toSet();
    final unreviewed = [
      for (final f in flags)
        if (f.isActive && !reviewedFlagIds.contains(f.id)) f,
    ];
    final secondOpinions = ref.watch(secondOpinionsProvider);
    final actions = ref.watch(doctorReviewActionsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(doctorReviewsProvider);
        try {
          await ref.read(doctorReviewsProvider.future);
        } catch (_) {}
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const _SimulatedBanner(),
          const SizedBox(height: 16),
          if (reviews.isEmpty)
            const SoftSurface(
              child: EmptyState(
                title: 'No reviews yet',
                message:
                    'When you ask for a review of a pattern, it will appear '
                    'here.',
                icon: Icons.medical_services_outlined,
              ),
            )
          else ...[
            for (final r in reviews)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReviewCard(
                  review: r,
                  title: flagTitleFor(flags, r.flagId),
                  secondOpinion: secondOpinions.contains(r.id),
                  onTap: () => context.push(AppRoutes.doctorReview(r.id)),
                ),
              ),
            const SizedBox(height: 4),
            PillButton(
              label: 'Request second opinion',
              icon: Icons.groups_2_outlined,
              variant: PillButtonVariant.secondary,
              onPressed: () => showSecondOpinionSheet(
                context,
                reviews: reviews,
                flags: flags,
              ),
            ),
          ],
          if (unreviewed.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader(title: 'Ask for a review'),
            const SizedBox(height: 4),
            Text(
              'Patterns that have not been reviewed yet.',
              style: AppText.bodyMuted,
            ),
            const SizedBox(height: 12),
            for (final f in unreviewed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftSurface(
                  child: Row(
                    children: [
                      Icon(f.status.icon, color: f.status.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(f.title, style: AppText.cardTitle),
                      ),
                      const SizedBox(width: 8),
                      PillButton(
                        label: 'Request',
                        expanded: false,
                        height: 40,
                        loading: actions.isLoading,
                        onPressed: () async {
                          await ref
                              .read(doctorReviewActionsProvider.notifier)
                              .request(f.id);
                          if (!context.mounted) return;
                          final failed =
                              ref.read(doctorReviewActionsProvider).hasError;
                          showSnack(
                            context,
                            failed
                                ? 'Could not send the request. Try again.'
                                : 'Review requested (simulated).',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          const DisclaimerBanner(),
        ],
      ),
    );
  }
}

class _SimulatedBanner extends StatelessWidget {
  const _SimulatedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lavenderCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SimulatedReviewLabel(),
                SizedBox(height: 4),
                _BannerText(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerText extends StatelessWidget {
  const _BannerText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'These reviews are sample content for the demo. No real clinician has '
      'looked at your data.',
      style: AppText.caption.copyWith(color: AppColors.ink),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.title,
    required this.secondOpinion,
    required this.onTap,
  });

  final DoctorReview review;
  final String title;
  final bool secondOpinion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = review.reviewedAt ?? review.requestedAt;
    return SoftSurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppText.cardTitle)),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DoctorBadge(state: review.badge, compact: true),
              Text(
                review.verdict.label,
                style: AppText.caption.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${review.doctorName} · ${review.credentials}',
            style: AppText.caption,
          ),
          const SizedBox(height: 2),
          Text(
            '${review.isPending ? 'Requested' : 'Reviewed'} ${AppDateUtils.dayMonth.format(date)}',
            style: AppText.caption,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SimulatedReviewLabel(),
              if (secondOpinion) ...[
                const SizedBox(width: 12),
                Text(
                  'Second opinion requested',
                  style: AppText.caption.copyWith(
                    color: AppColors.flagAmber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SecondOpinionSheet extends ConsumerStatefulWidget {
  const _SecondOpinionSheet({
    required this.reviews,
    required this.flags,
    this.initialReviewId,
  });

  final List<DoctorReview> reviews;
  final List<Flag> flags;
  final String? initialReviewId;

  @override
  ConsumerState<_SecondOpinionSheet> createState() =>
      _SecondOpinionSheetState();
}

class _SecondOpinionSheetState extends ConsumerState<_SecondOpinionSheet> {
  static const _reasons = [
    'I would like another view',
    'My symptoms have changed',
    'I am not sure what to do next',
    'The numbers have changed since',
  ];

  late String? _reviewId =
      widget.initialReviewId ??
      (widget.reviews.isEmpty ? null : widget.reviews.first.id);
  final _note = TextEditingController();
  final _selectedReasons = <String>{};

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final already = ref.watch(secondOpinionsProvider);
    final id = _reviewId;
    final alreadyRequested = id != null && already.contains(id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Request a second opinion', style: AppText.sectionTitle),
        const SizedBox(height: 4),
        const SimulatedReviewLabel(),
        const SizedBox(height: 4),
        Text(
          'A different sample reviewer would look at the same summary.',
          style: AppText.bodyMuted,
        ),
        if (widget.reviews.length > 1) ...[
          const FieldLabel('Which review?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in widget.reviews)
                AppChip(
                  label: flagTitleFor(widget.flags, r.flagId),
                  selected: _reviewId == r.id,
                  onTap: () => setState(() => _reviewId = r.id),
                ),
            ],
          ),
        ],
        const FieldLabel('Why?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final reason in _reasons)
              AppChip(
                label: reason,
                selected: _selectedReasons.contains(reason),
                onTap: () => setState(() {
                  if (!_selectedReasons.remove(reason)) {
                    _selectedReasons.add(reason);
                  }
                }),
              ),
          ],
        ),
        const FieldLabel('Anything to add? (optional)'),
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Add a short note'),
        ),
        const SizedBox(height: 16),
        Text(
          'Only a summary is shared, never your raw data.',
          style: AppText.caption,
        ),
        const SizedBox(height: 16),
        PillButton(
          label: alreadyRequested ? 'Already requested' : 'Send request',
          onPressed: id == null || alreadyRequested
              ? null
              : () {
                  ref.read(secondOpinionsProvider.notifier).request(id);
                  Navigator.of(context).pop();
                  showSnack(context, 'Second opinion requested (simulated).');
                },
        ),
      ],
    );
  }
}
