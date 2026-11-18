import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/enums.dart';

/// Internal gallery of shared signature components.
class DesignPreviewScreen extends StatelessWidget {
  const DesignPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Design preview')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Signature components', style: AppText.screenTitle),
          const SizedBox(height: 20),
          AvatarHeader(
            greeting: 'Good morning, Rahul',
            name: 'Rahul',
            hasUnread: true,
            onSearch: () {},
            onBell: () {},
            onProfile: () {},
          ),
          const SizedBox(height: 20),
          HeroChartCard(
            title: 'Wellness score',
            valueLabel: '78',
            points: const [62, 64, 63, 68, 70, 72, 75, 74, 78, 76, 79, 78],
            selectedRangeIndex: 1,
            onRangeSelected: (_) {},
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                PastelStatCard(
                  title: 'Heart',
                  value: '72',
                  subtitle: 'Slightly elevated',
                  background: AppColors.lavenderCard,
                  icon: Icons.favorite_rounded,
                  status: FlagStatus.amber,
                ),
                SizedBox(width: 12),
                PastelStatCard(
                  title: 'Sleep',
                  value: '64',
                  subtitle: 'Deep sleep shrinking',
                  background: AppColors.mintCard,
                  icon: Icons.bedtime_rounded,
                  status: FlagStatus.amber,
                ),
                SizedBox(width: 12),
                PastelStatCard(
                  title: 'Activity',
                  value: '88',
                  subtitle: 'Steady steps',
                  background: AppColors.creamCard,
                  icon: Icons.directions_walk_rounded,
                  status: FlagStatus.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FlagChip(status: FlagStatus.green),
              FlagChip(status: FlagStatus.amber),
              FlagChip(status: FlagStatus.red),
              DoctorBadge(state: DoctorBadgeState.verified),
              DoctorBadge(state: DoctorBadgeState.underReview),
              DoctorBadge(state: DoctorBadgeState.notReviewed),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              PillDropdown(label: '24h'),
              SizedBox(width: 8),
              PillDropdown(label: 'Most urgent'),
            ],
          ),
          const SizedBox(height: 20),
          DarkPromoCard(
            badge: 'Advise',
            title: 'Consider a checkup',
            body:
                'Your resting heart rate pattern is worth discussing with a doctor.',
            buttonLabel: 'View details',
            onPressed: () {},
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Section header'),
          const SizedBox(height: 12),
          const DisclaimerBanner(),
          const SizedBox(height: 12),
          const SimulatedReviewLabel(),
          const SizedBox(height: 20),
          const ShimmerLikeSkeleton(height: 72, width: double.infinity),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
