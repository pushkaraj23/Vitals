import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import 'onboarding_parts.dart';

/// Brand splash: logo fades in, holds briefly, fades out, then [onFinished].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _run();
  }

  Future<void> _run() async {
    try {
      await _controller.forward().orCancel;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      await _controller
          .animateBack(
            0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeIn,
          )
          .orCancel;
      if (mounted) widget.onFinished();
    } on TickerCanceled {
      // Disposed mid-animation; nothing to do.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LogoTile(size: 104),
                  const SizedBox(height: 24),
                  Text('VitalWatch', style: AppText.screenTitle),
                  const SizedBox(height: 6),
                  Text(
                    'Know your normal. Notice what changes.',
                    style: AppText.bodyMuted,
                    textAlign: TextAlign.center,
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
