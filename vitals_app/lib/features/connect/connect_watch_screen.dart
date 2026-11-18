import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/soft_surface.dart';
import '../../data/health_connect/health_connect_auth_notifier.dart';
import '../../providers/session_provider.dart';
import '../onboarding/onboarding_parts.dart';

const int kBackfillDays = 180;

const _permissions = <(IconData, String, String)>[
  (
    Icons.favorite_border_rounded,
    'Read vitals',
    'Heart rate, HRV, SpO\u2082 and skin temperature.',
  ),
  (
    Icons.bedtime_outlined,
    'Read sleep & activity',
    'Sleep stages, steps and active minutes.',
  ),
  (
    Icons.history_rounded,
    'Read history',
    'Up to 180 days of past data to build your baseline.',
  ),
];

const _metrics = <String>[
  'Resting heart rate',
  'Heart rate variability',
  'Blood oxygen (SpO\u2082)',
  'Sleep duration & stages',
  'Steps',
  'Respiratory rate',
  'Skin temperature',
  'Active minutes',
];

class ConnectWatchScreen extends ConsumerStatefulWidget {
  const ConnectWatchScreen({super.key});

  @override
  ConsumerState<ConnectWatchScreen> createState() =>
      _ConnectWatchScreenState();
}

class _ConnectWatchScreenState extends ConsumerState<ConnectWatchScreen> {
  bool _connecting = false;

  Future<void> _connect() async {
    setState(() => _connecting = true);

    // Request real Health Connect permissions (shows the system dialog).
    await ref
        .read(hcAuthProvider.notifier)
        .requestPermissions();

    if (!mounted) return;
    setState(() => _connecting = false);

    final authAsync = ref.read(hcAuthProvider);
    if (authAsync.hasError) {
      final err = authAsync.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err.toString().replaceAll('Exception: ', ''),
          ),
          backgroundColor: AppColors.flagRed,
        ),
      );
      return;
    }

    if (authAsync.value != HcAuthState.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Health Connect permissions were not granted. '
            'Please tap "Allow all" in the dialog and try again.',
          ),
        ),
      );
      return;
    }

    final finished = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => const _BackfillSheet(),
    );

    if (finished == true && mounted) {
      ref.read(sessionProvider.notifier).connectDevice();
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(kScreenPadding),
                children: [
                  const SizedBox(height: 8),
                  _Hero(),
                  const SizedBox(height: 24),
                  Text('Connect your watch', style: AppText.screenTitle),
                  const SizedBox(height: 8),
                  Text(
                    'VitalWatch reads your data through Health Connect, the '
                    'Android hub your watch already syncs to. You stay in '
                    'control of every permission.',
                    style: AppText.bodyMuted.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 24),
                  Text('Permissions we will ask for', style: AppText.cardTitle),
                  const SizedBox(height: 10),
                  SoftSurface(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < _permissions.length; i++) ...[
                          if (i > 0) const Divider(),
                          _PermissionRow(
                            icon: _permissions[i].$1,
                            title: _permissions[i].$2,
                            body: _permissions[i].$3,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Metrics we support', style: AppText.cardTitle),
                  const SizedBox(height: 10),
                  SoftSurface(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final m in _metrics)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: AppColors.flagGreenBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: AppColors.flagGreen,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(m, style: AppText.body)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _DemoNote(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kScreenPadding,
                8,
                kScreenPadding,
                20,
              ),
              child: PillButton(
                label: _connecting ? 'Connecting...' : 'Connect Health Connect',
                icon: Icons.link_rounded,
                loading: _connecting,
                onPressed: _connect,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.skyCard,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _HeroTile(icon: Icons.watch_outlined, color: AppColors.surface),
          const SizedBox(width: 12),
          const Icon(Icons.sync_alt_rounded, color: AppColors.ink),
          const SizedBox(width: 12),
          _HeroTile(
            icon: Icons.health_and_safety_outlined,
            color: AppColors.mintCard,
          ),
          const SizedBox(width: 12),
          const Icon(Icons.sync_alt_rounded, color: AppColors.ink),
          const SizedBox(width: 12),
          const LogoTile(size: 64),
        ],
      ),
    );
  }
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, size: 30, color: AppColors.ink),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.cardTitle),
                const SizedBox(height: 2),
                Text(body, style: AppText.bodyMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoNote extends StatelessWidget {
  const _DemoNote();

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      color: AppColors.creamCard,
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined, size: 18, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your data is read directly from Health Connect on this device. '
              'No data leaves your phone unless you explicitly share a report.',
              style: AppText.body.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackfillSheet extends StatefulWidget {
  const _BackfillSheet();

  @override
  State<_BackfillSheet> createState() => _BackfillSheetState();
}

class _BackfillSheetState extends State<_BackfillSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            kScreenPadding,
            12,
            kScreenPadding,
            kScreenPadding,
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_controller.value);
              final days = (t * kBackfillDays).round();
              final done = _controller.isCompleted;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: done
                              ? AppColors.flagGreenBg
                              : AppColors.skyCard,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          done
                              ? Icons.check_rounded
                              : Icons.cloud_download_outlined,
                          color: done ? AppColors.flagGreen : AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          done ? 'History imported' : 'Connected to Health Connect',
                          style: AppText.sectionTitle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Importing your history: $days of $kBackfillDays days',
                    style: AppText.cardTitle,
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: days / kBackfillDays,
                      minHeight: 10,
                      backgroundColor: AppColors.line,
                      color: done ? AppColors.flagGreen : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    done
                        ? 'Your baseline is ready.'
                        : 'Building your personal baseline. This only takes a moment.',
                    style: AppText.bodyMuted,
                  ),
                  const SizedBox(height: 20),
                  PillButton(
                    label: 'Open my dashboard',
                    icon: Icons.arrow_forward_rounded,
                    onPressed:
                        done ? () => Navigator.of(context).pop(true) : null,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
