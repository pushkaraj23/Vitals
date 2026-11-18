import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

enum PillButtonVariant { primary, secondary, ghost, accent }

/// Full-width (by default) stadium button with optional leading icon and a
/// loading state.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PillButtonVariant.primary,
    this.icon,
    this.expanded = true,
    this.loading = false,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillButtonVariant variant;
  final IconData? icon;
  final bool expanded;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      PillButtonVariant.primary => (AppColors.ink, AppColors.surface, null),
      PillButtonVariant.accent => (AppColors.accent, AppColors.ink, null),
      PillButtonVariant.secondary =>
        (AppColors.surface, AppColors.ink, AppColors.line),
      PillButtonVariant.ghost => (Colors.transparent, AppColors.ink, null),
    };
    final enabled = onPressed != null && !loading;
    final effectiveBg = enabled || loading ? bg : AppColors.line;
    final effectiveFg = enabled || loading ? fg : AppColors.muted;

    final content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: effectiveFg,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 20, color: effectiveFg),
        if (loading || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label.copyWith(
              color: effectiveFg,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: effectiveBg,
        shape: StadiumBorder(
          side: border == null
              ? BorderSide.none
              : BorderSide(color: border, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: height,
              minWidth: expanded ? double.infinity : 0,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Center(widthFactor: expanded ? null : 1, child: content),
            ),
          ),
        ),
      ),
    );
  }
}
