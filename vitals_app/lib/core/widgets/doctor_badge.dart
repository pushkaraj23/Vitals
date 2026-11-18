import 'package:material_ui/material_ui.dart';

import '../../domain/models/enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class DoctorBadge extends StatelessWidget {
  const DoctorBadge({
    super.key,
    required this.state,
    this.compact = false,
  });

  final DoctorBadgeState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: state.label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(state.icon, size: 16, color: state.color),
            const SizedBox(width: 6),
            Text(
              state.label,
              style: AppText.caption.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
