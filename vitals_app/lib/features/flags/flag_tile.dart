import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/flag.dart';

/// Row used for a flag on Home and in the Flags list. Opens the detail screen.
class FlagTile extends StatelessWidget {
  const FlagTile({super.key, required this.flag});

  final Flag flag;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${flag.status.label}. ${flag.title}',
      child: SoftSurface(
        onTap: () => context.push('/flags/${flag.id}'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: flag.status.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    flag.domain.icon,
                    size: 20,
                    color: flag.status.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        flag.title,
                        style: AppText.cardTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        flag.summary,
                        style: AppText.bodyMuted,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FlagChip(status: flag.status, compact: true),
                _MetaPill(
                  icon: flag.metric.domain.icon,
                  label: flag.metric.label,
                ),
                if (flag.status != FlagStatus.green)
                  _MetaPill(
                    icon: Icons.timelapse_rounded,
                    label: Format.durationDays(flag.streakDays),
                  ),
                if (flag.doctorBadge != DoctorBadgeState.notReviewed)
                  DoctorBadge(state: flag.doctorBadge, compact: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 6),
          Text(label, style: AppText.caption.copyWith(color: AppColors.ink)),
        ],
      ),
    );
  }
}
