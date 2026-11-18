import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/ink_app_bar.dart';
import '../../core/widgets/widgets.dart';
import '../../data/auth_service.dart';
import '../../engine/vitalwatch_engine.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';

class FsSettingsScreen extends ConsumerStatefulWidget {
  const FsSettingsScreen({super.key});

  @override
  ConsumerState<FsSettingsScreen> createState() => _FsSettingsScreenState();
}

class _FsSettingsScreenState extends ConsumerState<FsSettingsScreen> {
  bool _recomputing = false;
  bool _deleting = false;

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Sign out', style: AppText.cardTitle),
        content: Text(
          'Are you sure you want to sign out of VitalWatch?',
          style: AppText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sign out',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService().signOut();
      if (mounted) context.go('/sign-in');
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete my data', style: AppText.cardTitle),
        content: Text(
          'This will permanently delete all your health data, baselines, pattern flags, symptoms, habits, and your user account. This cannot be undone.',
          style: AppText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete everything',
              style: TextStyle(
                color: AppColors.flagRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final uid = ref.read(currentUidProvider);
      if (uid == null) return;
      setState(() => _deleting = true);
      try {
        await AuthService().deleteAccount(uid);
        if (mounted) context.go('/sign-in');
      } catch (e) {
        if (mounted) {
          showSnack(context, 'Error deleting account: $e');
        }
      } finally {
        if (mounted) setState(() => _deleting = false);
      }
    }
  }

  Future<void> _recomputeFlags() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _recomputing = true);
    try {
      final user = await ref.read(userRepositoryProvider).getUser(uid);
      final daily = await ref.read(dailyRepositoryProvider).getAll(uid);
      final rules = await ref.read(ruleRepositoryProvider).getAll();

      if (user != null) {
        const engine = VitalWatchEngine();
        final output = engine.evaluate(
          daily: daily,
          rules: rules,
          user: user,
          now: DateTime.now(),
        );

        await ref
            .read(baselineRepositoryProvider)
            .setBatch(uid, output.baselines);

        await ref.read(flagRepositoryProvider).setFlagBatch(uid, output.flags);

        final activeIds = output.flags.map((f) => f.id).toSet();
        await ref
            .read(flagRepositoryProvider)
            .pruneEngineFlags(uid, activeIds);

        ref.invalidate(flagsProvider);
        ref.invalidate(baselinesProvider);

        if (mounted) {
          showSnack(
            context,
            'Engine recomputed: ${output.flags.length} flag(s)'
            '${output.isCalibrating ? ' (calibrating)' : ''}.',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _recomputing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).value;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        title: 'Settings',
        subtitle: 'Account & preferences',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          SoftSurface(
            color: AppColors.lavenderCard,
            radius: 28,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.surface,
                  child: Text(
                    user?.name?.isNotEmpty == true
                        ? user!.name![0].toUpperCase()
                        : '?',
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'VitalWatch Member',
                        style: AppText.cardTitle.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(user?.email ?? '', style: AppText.bodyMuted),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Shortcuts', style: AppText.cardTitle),
          const SizedBox(height: 10),
          _SettingsTile(
            color: AppColors.peachCard,
            icon: Icons.person_outline_rounded,
            title: 'Edit profile & family history',
            subtitle: 'Name, vitals, medical context',
            onTap: () => context.push(AppRoutes.profile),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            color: AppColors.skyCard,
            icon: Icons.watch_outlined,
            title: 'Connected devices',
            subtitle: 'Health Connect sync status',
            onTap: () => context.push(AppRoutes.devices),
          ),
          const SizedBox(height: 20),

          Text('Sync & storage', style: AppText.cardTitle),
          const SizedBox(height: 10),
          SoftSurface(
            color: AppColors.mintCard,
            radius: 28,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.cloud_done_outlined,
                  title: 'Cloud backup',
                  subtitle: 'Encrypted in asia-south1 Firestore',
                ),
                _InfoRow(
                  icon: Icons.offline_bolt_outlined,
                  title: 'Offline persistence',
                  subtitle: 'Cached locally on device',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Developer tools', style: AppText.cardTitle),
          const SizedBox(height: 10),
          SoftSurface(
            color: AppColors.creamCard,
            radius: 28,
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            onTap: _recomputing ? null : _recomputeFlags,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.refresh_rounded, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recompute flags',
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Runs the engine on your stored data',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                if (_recomputing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: 24),

          PillButton(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            variant: PillButtonVariant.secondary,
            onPressed: _signOut,
          ),
          const SizedBox(height: 12),
          SoftSurface(
            color: AppColors.flagRedBg,
            radius: 999,
            padding: EdgeInsets.zero,
            onTap: _deleting ? null : _deleteAccount,
            child: SizedBox(
              height: 52,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_forever_rounded,
                      size: 20,
                      color: AppColors.flagRed,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _deleting ? 'Deleting data…' : 'Delete my data',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.flagRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'VitalWatch provides wellness insights, not medical diagnoses.',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      color: color,
      radius: 28,
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
