import 'package:material_ui/material_ui.dart';

import '../../domain/models/enums.dart';
import '../theme/app_text.dart';

class FlagChip extends StatelessWidget {
  const FlagChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  final FlagStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Flag status ${status.label}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: status.background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 16, color: status.color),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: AppText.caption.copyWith(
                color: status.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
