import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

class CircularIconButton extends StatelessWidget {
  const CircularIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.semanticLabel,
    this.background = AppColors.canvas,
    this.foreground = AppColors.ink,
    this.size = 44,
    this.showBadge = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final Color background;
  final Color foreground;
  final double size;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: foreground, size: 20),
                if (showBadge)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.flagRed,
                        shape: BoxShape.circle,
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
