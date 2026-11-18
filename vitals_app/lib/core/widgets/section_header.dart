import 'package:material_ui/material_ui.dart';

import '../theme/app_text.dart';
import 'circular_icon_button.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onFilterTap,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final Widget? trailing;
  final VoidCallback? onFilterTap;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppText.sectionTitle)),
        if (actionLabel != null)
          TextButton(
            onPressed: onActionTap,
            child: Text(actionLabel!),
          ),
        ?trailing,
        if (onFilterTap != null)
          CircularIconButton(
            icon: Icons.tune_rounded,
            onPressed: onFilterTap,
            semanticLabel: 'Filter $title',
          ),
      ],
    );
  }
}
