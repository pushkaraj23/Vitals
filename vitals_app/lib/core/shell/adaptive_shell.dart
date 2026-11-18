import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class AdaptiveShell extends ConsumerWidget {
  const AdaptiveShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _NavItem('Home', Icons.grid_view_rounded, '/home'),
    _NavItem('Flags', Icons.flag_rounded, '/flags'),
    _NavItem('Timeline', Icons.show_chart_rounded, '/timeline'),
    _NavItem('Habits', Icons.spa_rounded, '/habits'),
    _NavItem('Profile', Icons.person_rounded, '/profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    if (wide) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _WideRail(
                  index: navigationShell.currentIndex,
                  onSelect: navigationShell.goBranch,
                  onLogout: () => context.go('/sign-in'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: navigationShell,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          12 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                for (var i = 0; i < _destinations.length; i++)
                  Expanded(
                    child: _BottomNavButton(
                      item: _destinations[i],
                      selected: navigationShell.currentIndex == i,
                      onTap: () => navigationShell.goBranch(
                        i,
                        initialLocation: i == navigationShell.currentIndex,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.inkSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                color: selected ? AppColors.surface : const Color(0xFFB7BDC6),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: AppText.caption.copyWith(
                  color: selected ? AppColors.surface : const Color(0xFFB7BDC6),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WideRail extends StatelessWidget {
  const _WideRail({
    required this.index,
    required this.onSelect,
    required this.onLogout,
  });

  final int index;
  final void Function(int index, {bool initialLocation}) onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.creamLogo,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.favorite_rounded, color: AppColors.ink),
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < AdaptiveShell._destinations.length; i++) ...[
            _RailIcon(
              icon: AdaptiveShell._destinations[i].icon,
              label: AdaptiveShell._destinations[i].label,
              selected: index == i,
              onTap: () => onSelect(i, initialLocation: index == i),
            ),
            const SizedBox(height: 8),
          ],
          const Spacer(),
          _RailIcon(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            selected: false,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 56,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (selected)
                Positioned(
                  left: 0,
                  child: Container(
                    width: 3,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              Icon(
                icon,
                color: selected ? AppColors.surface : AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
