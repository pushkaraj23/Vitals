import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Floating dark chrome bar — same margins / radius language as the bottom nav.
class InkAppBar extends StatelessWidget implements PreferredSizeWidget {
  const InkAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.titleWidget,
    this.leading,
    this.actions,
    this.barHeight = 80,
  }) : assert(title != null || titleWidget != null);

  /// Matches [AdaptiveShell] bottom nav horizontal inset.
  static const double horizontalMargin = 16;
  static const double topGap = 10;
  static const double bottomGap = 10;
  static const double radius = 28;
  static const double innerHorizontalLeft = 22;
  static const double innerHorizontalRight = 12;

  final String? title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final double barHeight;

  static double totalHeight(BuildContext context, {double barHeight = 72}) {
    return MediaQuery.paddingOf(context).top + topGap + barHeight + bottomGap;
  }

  @override
  Size get preferredSize {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final top = MediaQueryData.fromView(view).padding.top;
    return Size.fromHeight(top + topGap + barHeight + bottomGap);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalMargin,
          top + topGap,
          horizontalMargin,
          bottomGap,
        ),
        child: Material(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: barHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                innerHorizontalLeft,
                10,
                innerHorizontalRight,
                10,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    IconTheme(
                      data: const IconThemeData(color: Colors.white),
                      child: leading!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: titleWidget ??
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.15,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ],
                        ),
                  ),
                  if (actions != null)
                    IconTheme(
                      data: const IconThemeData(color: Colors.white),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actions!,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
