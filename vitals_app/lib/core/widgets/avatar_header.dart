import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'circular_icon_button.dart';

class AvatarHeader extends StatelessWidget {
  const AvatarHeader({
    super.key,
    required this.greeting,
    required this.name,
    this.onSearch,
    this.onBell,
    this.onProfile,
    this.hasUnread = false,
    this.initials,
  });

  final String greeting;
  final String name;
  final VoidCallback? onSearch;
  final VoidCallback? onBell;
  final VoidCallback? onProfile;
  final bool hasUnread;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    final letters = initials ??
        name
            .split(' ')
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0])
            .join()
            .toUpperCase();

    return Row(
      children: [
        Expanded(
          child: Text(
            greeting,
            style: AppText.screenTitle.copyWith(fontSize: 24),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        CircularIconButton(
          icon: Icons.search_rounded,
          onPressed: onSearch,
          semanticLabel: 'Search',
        ),
        const SizedBox(width: 8),
        CircularIconButton(
          icon: Icons.notifications_none_rounded,
          onPressed: onBell,
          semanticLabel: 'Alerts',
          showBadge: hasUnread,
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Profile $name',
          child: Material(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onProfile,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.lavenderCard,
                      child: Text(
                        letters,
                        style: AppText.caption.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 72),
                      child: Text(
                        name,
                        style: AppText.caption.copyWith(color: AppColors.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
