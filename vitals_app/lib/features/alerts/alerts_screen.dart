import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Baseline;

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/option_sheet.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/alert.dart';
import '../../domain/models/enums.dart';
import '../../providers/providers.dart';
import 'alerts_state.dart';

enum _AlertFilter { all, unread, snoozed }

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  _AlertFilter _filter = _AlertFilter.all;

  Future<void> _snooze(Alert alert) async {
    final duration = await showOptionSheet<Duration>(
      context,
      title: 'Snooze "${alert.title}"',
      options: const [
        SheetOption(Duration(hours: 1), 'For 1 hour', icon: Icons.timer_outlined),
        SheetOption(Duration(hours: 8), 'For 8 hours', icon: Icons.bedtime_outlined),
        SheetOption(Duration(days: 1), 'Until tomorrow', icon: Icons.today_rounded),
        SheetOption(Duration(days: 3), 'For 3 days', icon: Icons.date_range_rounded),
      ],
    );
    if (duration == null || !mounted) return;
    ref.read(snoozedAlertsProvider.notifier).snooze(alert.id, duration);
    showSnack(context, 'Snoozed. It will come back later.');
  }

  Future<void> _dismiss(Alert alert) async {
    if (alert.id.startsWith('demo_')) {
      ref.read(demoAlertsProvider.notifier).remove(alert.id);
      return;
    }
    try {
      await ref.read(alertsProvider.notifier).dismiss(alert.id);
      if (mounted) showSnack(context, 'Dismissed.');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not dismiss. Try again.');
    }
  }

  Future<void> _markRead(Alert alert) async {
    if (alert.isRead || alert.id.startsWith('demo_')) return;
    try {
      await ref.read(alertsProvider.notifier).markRead(alert.id);
    } catch (_) {}
  }

  void _open(Alert alert) {
    _markRead(alert);
    if (alert.tier == AlertTier.emergency) {
      context.push(AppRoutes.emergency);
    } else if (alert.flagId != null) {
      context.push(AppRoutes.flag(alert.flagId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(alertsProvider);
    final demo = ref.watch(demoAlertsProvider);
    final snoozed = ref.watch(snoozedAlertsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          IconButton(
            tooltip: 'Mark all read',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: async.hasValue
                ? () async {
                    try {
                      await ref.read(alertsProvider.notifier).markAllRead();
                    } catch (_) {
                      if (context.mounted) showSnack(context, 'Could not update alerts.');
                    }
                  }
                : null,
          ),
          IconButton(
            tooltip: 'Alert preferences',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push(AppRoutes.alertPreferences),
          ),
        ],
      ),
      body: SafeArea(
        child: CenteredBody(
          child: async.when(
            loading: () => const ListSkeleton(blocks: 4, blockHeight: 130),
            error: (e, _) => FeatureError(
              what: 'your alerts',
              onRetry: () => ref.invalidate(alertsProvider),
            ),
            data: (alerts) => _buildData([...demo, ...alerts], snoozed),
          ),
        ),
      ),
    );
  }

  Widget _buildData(List<Alert> all, Map<String, DateTime> snoozedMap) {
    final notifier = ref.read(snoozedAlertsProvider.notifier);
    final snoozedList = [for (final a in all) if (notifier.isSnoozed(a)) a];
    final active = [for (final a in all) if (!notifier.isSnoozed(a)) a];
    final unread = active.where((a) => !a.isRead).toList();

    final shown = switch (_filter) {
      _AlertFilter.all => active,
      _AlertFilter.unread => unread,
      _AlertFilter.snoozed => snoozedList,
    }..sort((a, b) {
        if ((a.tier == AlertTier.emergency) != (b.tier == AlertTier.emergency)) {
          return a.tier == AlertTier.emergency ? -1 : 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(alertsProvider);
        try {
          await ref.read(alertsProvider.future);
        } catch (_) {}
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                AppChip(
                  label: 'All ${active.length}',
                  selected: _filter == _AlertFilter.all,
                  onTap: () => setState(() => _filter = _AlertFilter.all),
                ),
                const SizedBox(width: 8),
                AppChip(
                  label: 'Unread ${unread.length}',
                  selected: _filter == _AlertFilter.unread,
                  onTap: () => setState(() => _filter = _AlertFilter.unread),
                ),
                const SizedBox(width: 8),
                AppChip(
                  label: 'Snoozed ${snoozedList.length}',
                  selected: _filter == _AlertFilter.snoozed,
                  onTap: () => setState(() => _filter = _AlertFilter.snoozed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: EmptyState(
                title: switch (_filter) {
                  _AlertFilter.all => 'No alerts',
                  _AlertFilter.unread => 'All caught up',
                  _AlertFilter.snoozed => 'Nothing snoozed',
                },
                message: switch (_filter) {
                  _AlertFilter.all => 'New alerts will show up here.',
                  _AlertFilter.unread => 'You have read everything.',
                  _AlertFilter.snoozed => 'Snoozed alerts wait here until their time is up.',
                },
                icon: Icons.notifications_none_rounded,
              ),
            )
          else
            for (final alert in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AlertCard(
                  alert: alert,
                  snoozedUntil: _filter == _AlertFilter.snoozed
                      ? snoozedMap[alert.id]
                      : null,
                  onOpen: () => _open(alert),
                  onSnooze: () => _snooze(alert),
                  onUnsnooze: () => notifier.unsnooze(alert.id),
                  onDismiss: () => _dismiss(alert),
                ),
              ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.alertPreferences),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Alert preferences'),
          ),
          const SizedBox(height: 8),
          const DisclaimerBanner(),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.onOpen,
    required this.onSnooze,
    required this.onUnsnooze,
    required this.onDismiss,
    this.snoozedUntil,
  });

  final Alert alert;
  final DateTime? snoozedUntil;
  final VoidCallback onOpen;
  final VoidCallback onSnooze;
  final VoidCallback onUnsnooze;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tier = alert.tier;
    final emergency = tier == AlertTier.emergency;
    final accent = switch (tier) {
      AlertTier.info => AppColors.ink,
      AlertTier.advise => AppColors.flagAmber,
      AlertTier.urgent => AppColors.flagRed,
      AlertTier.emergency => AppColors.flagRed,
    };
    final canOpen = emergency || alert.flagId != null;
    final openLabel = emergency
        ? 'Open emergency screen'
        : (alert.flagId != null ? 'View flag' : null);

    return Semantics(
      container: true,
      label: '${tier.label} alert: ${alert.title}'
          '${alert.isRead ? '' : ', unread'}',
      child: SoftSurface(
        color: tier.background,
        borderColor: emergency ? AppColors.flagRed : null,
        onTap: onOpen,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(tier.icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            tier.label.toUpperCase(),
                            style: AppText.caption.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!alert.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.flagRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                          const Spacer(),
                          Text(
                            AppDateUtils.relativeDay(alert.createdAt),
                            style: AppText.caption,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.title,
                        style: AppText.cardTitle.copyWith(
                          fontWeight: alert.isRead ? FontWeight.w600 : FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(alert.message, style: AppText.body),
            if (snoozedUntil != null) ...[
              const SizedBox(height: 8),
              Text(
                'Snoozed until ${AppDateUtils.dayMonth.format(snoozedUntil!)}, '
                '${TimeOfDay.fromDateTime(snoozedUntil!).format(context)}',
                style: AppText.caption.copyWith(color: AppColors.ink),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 0,
              children: [
                if (canOpen && openLabel != null)
                  TextButton(onPressed: onOpen, child: Text(openLabel)),
                if (snoozedUntil != null)
                  TextButton(onPressed: onUnsnooze, child: const Text('Unsnooze'))
                else if (!emergency)
                  TextButton(onPressed: onSnooze, child: const Text('Snooze')),
                TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
