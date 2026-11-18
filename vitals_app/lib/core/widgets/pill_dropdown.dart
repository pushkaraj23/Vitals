import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class PillDropdown extends StatelessWidget {
  const PillDropdown({
    super.key,
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label filter',
      child: Material(
        color: AppColors.surface,
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.line),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppText.caption.copyWith(color: AppColors.ink)),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RangeChips extends StatelessWidget {
  const RangeChips({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: AppText.caption.copyWith(
                color: i == selectedIndex ? AppColors.ink : AppColors.muted,
                fontWeight: i == selectedIndex ? FontWeight.w800 : FontWeight.w500,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Text(labels[i]),
              ),
            ),
          ),
      ],
    );
  }
}
