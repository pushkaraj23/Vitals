import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/alert.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/flag.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/home_snapshot.dart';
import '../../providers/providers.dart';
import '../flags/flag_tile.dart';

/// Illustrative 0-100 score for a domain, derived from its flag status.
int domainScore(FlagStatus status) => switch (status) {
  FlagStatus.green => 88,
  FlagStatus.amber => 64,
  FlagStatus.red => 42,
};

Color _domainCardColor(FlagStatus status) => switch (status) {
  FlagStatus.green => const Color(0xFFEDF8F1),
  FlagStatus.amber => const Color(0xFFFEF8E8),
  FlagStatus.red => const Color(0xFFFDECEB),
};

String _greeting(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

String _syncedLabel(DateTime time) {
  final day = AppDateUtils.relativeDay(time);
  return '$day, ${DateFormat('h:mm a').format(time)}';
}

/// Home dashboard: wellness overview, domain scores, flags, habits and wins.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _rangeIndex = 1;

  Future<void> _refresh() async {
    ref.invalidate(homeSnapshotProvider);
    try {
      await ref.read(homeSnapshotProvider.future);
    } catch (_) {
      // The error state is rendered from the provider itself.
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(homeSnapshotProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: snapshotAsync.when(
        skipLoadingOnReload: true,
        loading: () => const _HomeSkeleton(),
        error: (error, _) => ErrorState(
          message: 'We could not load your overview. Please try again.',
          onRetry: () => ref.invalidate(homeSnapshotProvider),
        ),
        data: _buildData,
      ),
    );
  }

  Widget _buildData(HomeSnapshot snapshot) {
    final alerts = ref.watch(alertsProvider).value;
    final habits = ref.watch(habitsProvider).value;
    final unread = alerts == null
        ? snapshot.unreadAlertCount
        : ref.watch(unreadAlertCountProvider);

    final statuses = snapshot.domainStatuses;
    final scores = [for (final s in statuses.values) domainScore(s)];
    final wellness = scores.isEmpty
        ? domainScore(snapshot.overallStatus)
        : (scores.reduce((a, b) => a + b) / scores.length).round();

    // Hero chart points: recent readings of the hero metric (gaps skipped).
    final window = _rangeIndex == 0 ? 7 : 30;
    final readings = snapshot.recentReadings.length > window
        ? snapshot.recentReadings.sublist(
            snapshot.recentReadings.length - window,
          )
        : snapshot.recentReadings;
    final points = <double>[
      for (final r in readings)
        if (r.valueOf(snapshot.heroMetric) != null)
          r.valueOf(snapshot.heroMetric)!,
    ];

    final activeFlags = snapshot.activeFlags;
    final topAlert = _highestAlert(alerts);
    final topInset = MediaQuery.paddingOf(context).top;

    Widget pad(Widget child, {double bottom = 0}) =>
        Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, bottom), child: child);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: topInset + 84, bottom: 128),
            children: [
              pad(_buildHero(snapshot, wellness, points), bottom: 28),
              pad(const SectionHeader(title: 'Your areas'), bottom: 12),
              if (statuses.isNotEmpty)
                SizedBox(
                  height: 184,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: statuses.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, i) {
                      final entry = statuses.entries.elementAt(i);
                      return PastelStatCard(
                        title: entry.key.label,
                        value: '${domainScore(entry.value)}',
                        background: _domainCardColor(entry.value),
                        icon: entry.key.icon,
                        status: entry.value,
                        width: 164,
                        onTap: () => context.go('/flags'),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 28),
              pad(
                SectionHeader(
                  title: 'Active flags',
                  actionLabel: 'See all',
                  onActionTap: () => context.go('/flags'),
                ),
                bottom: 12,
              ),
              pad(_buildActiveFlags(snapshot, activeFlags), bottom: 28),
              if (topAlert != null) pad(_buildPromo(topAlert), bottom: 28),
              if (habits != null && habits.isNotEmpty)
                pad(_buildHabits(habits), bottom: 20),
              pad(_buildSyncRow(snapshot)),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: topInset + 8,
          child: _FloatingHomeBar(
            greeting:
                '${_greeting(DateTime.now())}, ${snapshot.profile.firstName}',
            name: snapshot.profile.firstName,
            initials: snapshot.profile.initials,
            hasUnread: unread > 0,
            onBell: () => context.push('/alerts'),
            onProfile: () => context.go('/profile'),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------- hero

  Widget _buildHero(HomeSnapshot snapshot, int wellness, List<double> points) {
    if (points.length < 2) {
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE6F1FD),
              Color(0xFFD8EBFC),
              Color(0xFFC7E2FA),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B4D89).withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_graph_rounded,
                        size: 13,
                        color: Color(0xFF1B4D89),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'WELLNESS SCORE',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1B4D89),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.flagGreenBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.flagGreen.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: AppColors.flagGreen,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Calibrating',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.flagGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$wellness',
                  style: GoogleFonts.manrope(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    height: 1.0,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '/100',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 1.2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0EFFE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.sync_rounded,
                      size: 20,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calibrating your baseline',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'VitalWatch is tracking your ${snapshot.heroMetric.label.toLowerCase()} from Health Connect. Your trend line will graph here as daily data continues to record.',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return HeroChartCard(
      title: 'Wellness',
      valueLabel: '$wellness',
      points: points,
      rangeLabels: const ['1W', '1M'],
      selectedRangeIndex: _rangeIndex,
      onRangeSelected: (i) => setState(() => _rangeIndex = i),
      status: snapshot.overallStatus,
      subtitle: snapshot.headline,
      heroMetricLabel: snapshot.heroMetric.label,
      heroMetricUnit: snapshot.heroMetric.unit,
      latestMetricValue: snapshot.latestReading?.valueOf(snapshot.heroMetric),
      semanticsSummary:
          'Wellness score $wellness out of 100. Chart of ${snapshot.heroMetric.label} over the last ${_rangeIndex == 0 ? 7 : 30} days.',
    );
  }

  Widget _buildActiveFlags(HomeSnapshot snapshot, List<Flag> flags) {
    if (flags.isEmpty) {
      final hasActive = snapshot.activeFlags.isNotEmpty;
      return SoftSurface(
        color: hasActive ? AppColors.surface : AppColors.mintCard,
        child: Row(
          children: [
            Icon(
              hasActive
                  ? Icons.filter_alt_off_rounded
                  : Icons.check_circle_rounded,
              color: hasActive ? AppColors.muted : AppColors.flagGreen,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasActive
                    ? 'Nothing in this view.'
                    : 'No active flags.',
                style: AppText.body,
              ),
            ),
          ],
        ),
      );
    }
    final shown = flags.take(3).toList();
    return Column(
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          FlagTile(flag: shown[i]),
        ],
      ],
    );
  }

  // ------------------------------------------------------------------ promo

  Alert? _highestAlert(List<Alert>? alerts) {
    if (alerts == null || alerts.isEmpty) return null;
    final sorted = [...alerts]
      ..sort((a, b) {
        final byTier = b.tier.index.compareTo(a.tier.index);
        if (byTier != 0) return byTier;
        return b.createdAt.compareTo(a.createdAt);
      });
    return sorted.first;
  }

  Widget _buildPromo(Alert alert) {
    return DarkPromoCard(
      badge: alert.tier.label,
      title: alert.title,
      body: alert.message,
      buttonLabel: alert.actionLabel ?? 'View details',
      onPressed: () {
        ref.read(alertsProvider.notifier).markRead(alert.id).catchError((_) {});
        if (alert.flagId != null) {
          context.push('/flags/${alert.flagId}');
        } else {
          context.push('/alerts');
        }
      },
    );
  }

  // ----------------------------------------------------------------- habits

  Widget _buildHabits(List<Habit> habits) {
    final today = DateTime.now();
    final doneCount = habits.where((h) => h.isDoneOn(today)).length;
    final shown = habits.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Habits',
          actionLabel: '$doneCount/${habits.length}',
          onActionTap: () => context.go('/habits'),
        ),
        const SizedBox(height: 12),
        SoftSurface(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            children: [
              for (final habit in shown)
                _HabitRow(habit: habit, onToggle: () => _toggleHabit(habit)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggleHabit(Habit habit) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(habitsProvider.notifier).toggle(habit.id);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not update that habit. Try again.'),
        ),
      );
    }
  }

  // ------------------------------------------------------------------- sync

  Widget _buildSyncRow(HomeSnapshot snapshot) {
    return SoftSurface(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.sync_rounded, size: 20, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Last synced ${_syncedLabel(snapshot.lastSyncedAt)}',
              style: AppText.caption.copyWith(color: AppColors.ink),
            ),
          ),
          TextButton(onPressed: _openSyncSheet, child: const Text('Sync now')),
        ],
      ),
    );
  }

  void _openSyncSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const _SyncSheet(),
    );
  }
}

// ----------------------------------------------------------------- widgets

class _HabitRow extends StatelessWidget {
  const _HabitRow({required this.habit, required this.onToggle});

  final Habit habit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final done = habit.isDoneOn(DateTime.now());
    final streak = habit.currentStreak();
    return Semantics(
      container: true,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: Semantics(
          button: true,
          checked: done,
          label: done
              ? 'Mark ${habit.title} as not done'
              : 'Mark ${habit.title} as done',
          child: InkResponse(
            radius: 24,
            onTap: onToggle,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: done ? AppColors.flagGreen : AppColors.canvas,
                shape: BoxShape.circle,
              ),
              child: Icon(
                done ? Icons.check_rounded : habit.domain.icon,
                size: 20,
                color: done ? AppColors.surface : AppColors.ink,
              ),
            ),
          ),
        ),
        title: Text(habit.title, style: AppText.cardTitle),
        subtitle: Text(
          '${habit.completionsThisWeek()}/${habit.targetDaysPerWeek} this week'
          '${streak > 1 ? ' · $streak-day streak' : ''}',
          style: AppText.caption,
        ),
        onTap: onToggle,
      ),
    );
  }
}

class _SyncSheet extends ConsumerWidget {
  const _SyncSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncProvider);
    final lastSynced = ref.watch(homeSnapshotProvider).value?.lastSyncedAt;
    final justSynced = sync.value;

    final String message;
    if (sync.hasError && !sync.isLoading) {
      message = 'Sync did not finish. Your last data is still available.';
    } else if (sync.isLoading) {
      message = 'Syncing your wearable…';
    } else if (justSynced != null) {
      message = 'All caught up. Synced ${_syncedLabel(justSynced)}.';
    } else if (lastSynced != null) {
      message = 'Last synced ${_syncedLabel(lastSynced)}.';
    } else {
      message = 'Pull in the latest data from your connected wearable.';
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sync your data', style: AppText.sectionTitle),
            const SizedBox(height: 8),
            Text(message, style: AppText.bodyMuted),
            const SizedBox(height: 20),
            PillButton(
              label: sync.hasError && !sync.isLoading
                  ? 'Try again'
                  : 'Sync now',
              icon: Icons.sync_rounded,
              loading: sync.isLoading,
              onPressed: () => ref.read(syncProvider.notifier).sync(),
            ),
            const SizedBox(height: 8),
            PillButton(
              label: 'Close',
              variant: PillButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingHomeBar extends StatelessWidget {
  const _FloatingHomeBar({
    required this.greeting,
    required this.name,
    required this.onBell,
    required this.onProfile,
    this.hasUnread = false,
    this.initials,
  });

  final String greeting;
  final String name;
  final VoidCallback onBell;
  final VoidCallback onProfile;
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

    return Material(
      color: AppColors.ink,
      elevation: 10,
      shadowColor: AppColors.ink.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.cardTitle.copyWith(color: AppColors.surface),
              ),
            ),
            IconButton(
              tooltip: 'Alerts',
              onPressed: onBell,
              icon: Badge(
                isLabelVisible: hasUnread,
                smallSize: 8,
                backgroundColor: AppColors.flagRed,
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.surface,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Profile $name',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onProfile,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.creamLogo,
                  child: Text(
                    letters,
                    style: AppText.caption.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: const [
        ShimmerLikeSkeleton(height: 44, radius: 22),
        SizedBox(height: 24),
        ShimmerLikeSkeleton(height: 24, width: 220),
        SizedBox(height: 16),
        ShimmerLikeSkeleton(height: 260, radius: 28),
        SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: ShimmerLikeSkeleton(height: 180, radius: 24)),
            SizedBox(width: 12),
            Expanded(child: ShimmerLikeSkeleton(height: 180, radius: 24)),
          ],
        ),
        SizedBox(height: 24),
        ShimmerLikeSkeleton(height: 110, radius: 24),
        SizedBox(height: 12),
        ShimmerLikeSkeleton(height: 110, radius: 24),
      ],
    );
  }
}
