import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/pill_button.dart';
import '../../providers/session_provider.dart';
import 'onboarding_parts.dart';

class _Slide {
  const _Slide({
    required this.title,
    required this.body,
    required this.color,
    required this.icon,
    required this.accentIcons,
  });

  final String title;
  final String body;
  final Color color;
  final IconData icon;
  final List<IconData> accentIcons;
}

const _slides = <_Slide>[
  _Slide(
    title: 'Your history, not just today',
    body: 'We compare every reading with your own usual range, built from '
        'months of sleep, heart and activity data.',
    color: AppColors.skyCard,
    icon: Icons.show_chart_rounded,
    accentIcons: [Icons.bedtime_outlined, Icons.monitor_heart_outlined],
  ),
  _Slide(
    title: 'Flags that explain themselves',
    body: 'When something drifts, you see what changed, by how much, and '
        'why it matters, in plain language.',
    color: AppColors.creamCard,
    icon: Icons.flag_rounded,
    accentIcons: [Icons.lightbulb_outline_rounded, Icons.trending_up_rounded],
  ),
  _Slide(
    title: 'Doctors in the loop',
    body: 'Share a clear summary with your clinician only when you choose, '
        'and get their review back in the app.',
    color: AppColors.mintCard,
    icon: Icons.medical_services_rounded,
    accentIcons: [Icons.verified_user_outlined, Icons.chat_bubble_outline],
  ),
];

class OnboardingCarouselScreen extends ConsumerStatefulWidget {
  const OnboardingCarouselScreen({super.key});

  @override
  ConsumerState<OnboardingCarouselScreen> createState() =>
      _OnboardingCarouselScreenState();
}

class _OnboardingCarouselScreenState
    extends ConsumerState<OnboardingCarouselScreen> {
  final _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(sessionProvider.notifier).completeOnboarding();
    context.go('/sign-in');
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kScreenPadding,
                12,
                kScreenPadding,
                0,
              ),
              child: Row(
                children: [
                  const LogoTile(size: 40),
                  const SizedBox(width: 10),
                  Text('VitalWatch', style: AppText.cardTitle),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _isLast ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: _isLast,
                      child: SoftPill(label: 'Skip', onPressed: _finish),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kScreenPadding,
                8,
                kScreenPadding,
                24,
              ),
              child: Row(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _index ? 26 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index ? AppColors.ink : AppColors.line,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  PillButton(
                    label: _isLast ? 'Get started' : 'Next',
                    icon: _isLast
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    expanded: false,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: slide.color,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 28,
                    top: 28,
                    child: _FloatingIcon(icon: slide.accentIcons[0]),
                  ),
                  Positioned(
                    right: 28,
                    bottom: 28,
                    child: _FloatingIcon(icon: slide.accentIcons[1]),
                  ),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      color: AppColors.ink,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(slide.icon, size: 56, color: AppColors.surface),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(slide.title, style: AppText.screenTitle),
          const SizedBox(height: 10),
          Text(slide.body, style: AppText.bodyMuted.copyWith(fontSize: 15)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: AppColors.ink),
    );
  }
}
