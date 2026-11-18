import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide Baseline;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/daily_reading.dart';
import '../../domain/models/device.dart';
import '../../domain/models/enums.dart';
import '../../providers/providers.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(devicesProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Devices')),
      body: SafeArea(
        child: CenteredBody(
          child: async.when(
            loading: () => const ListSkeleton(blocks: 3, blockHeight: 150),
            error: (e, _) => FeatureError(
              what: 'your devices',
              onRetry: () => ref.invalidate(devicesProvider),
            ),
            data: (devices) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(devicesProvider);
                try {
                  await ref.read(devicesProvider.future);
                } catch (_) {}
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text(
                    'Where your health data comes from.',
                    style: AppText.bodyMuted,
                  ),
                  const SizedBox(height: 16),
                  if (devices.isEmpty)
                    const SoftSurface(
                      child: EmptyState(
                        title: 'No devices yet',
                        message: 'Connect a watch, ring or Health Connect to '
                            'start building your usual range.',
                        icon: Icons.watch_outlined,
                      ),
                    )
                  else
                    for (final d in devices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DeviceCard(device: d),
                      ),
                  const SizedBox(height: 12),
                  const SectionHeader(title: 'Metrics availability'),
                  const SizedBox(height: 12),
                  _MetricsAvailability(devices: devices),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Data quality'),
                  const SizedBox(height: 12),
                  const _DataQuality(),
                  const SizedBox(height: 16),
                  const DisclaimerBanner(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(DeviceKind kind) => switch (kind) {
  DeviceKind.phone => Icons.smartphone_rounded,
  DeviceKind.watch => Icons.watch_rounded,
  DeviceKind.ring => Icons.radio_button_unchecked_rounded,
  DeviceKind.band => Icons.fitness_center_rounded,
};

class _DeviceCard extends ConsumerStatefulWidget {
  const _DeviceCard({required this.device});

  final Device device;

  @override
  ConsumerState<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<_DeviceCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showSnack(context, success);
    } catch (_) {
      if (mounted) showSnack(context, 'That did not work. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final notifier = ref.read(devicesProvider.notifier);
    final synced = d.lastSyncedAt;

    return SoftSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: d.connected ? AppColors.mintCard : AppColors.canvas,
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconFor(d.kind)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, style: AppText.cardTitle),
                    Text(d.kind.label, style: AppText.caption),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: d.connected ? AppColors.flagGreenBg : AppColors.canvas,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  d.connected ? 'Connected' : 'Not connected',
                  style: AppText.caption.copyWith(
                    color: d.connected ? AppColors.flagGreen : AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _Fact(
                Icons.sync_rounded,
                synced == null
                    ? 'Never synced'
                    : 'Synced ${AppDateUtils.relativeDay(synced)}, ${TimeOfDay.fromDateTime(synced).format(context)}',
              ),
              if (d.batteryPercent != null)
                _Fact(Icons.battery_5_bar_rounded, '${d.batteryPercent}% battery'),
            ],
          ),
          if (d.metrics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in d.metrics)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      m.label,
                      style: AppText.caption.copyWith(color: AppColors.ink),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (d.connected) ...[
                Expanded(
                  child: PillButton(
                    label: 'Sync now',
                    icon: Icons.sync_rounded,
                    height: 44,
                    loading: _busy,
                    onPressed: () =>
                        _run(() => notifier.sync(d.id), 'Synced ${d.name}.'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PillButton(
                    label: 'Disconnect',
                    height: 44,
                    variant: PillButtonVariant.secondary,
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => notifier.setConnected(d.id, connected: false),
                            'Disconnected ${d.name}.',
                          ),
                  ),
                ),
              ] else
                Expanded(
                  child: PillButton(
                    label: 'Connect',
                    icon: Icons.link_rounded,
                    height: 44,
                    loading: _busy,
                    onPressed: () => _run(
                      () => notifier.setConnected(d.id, connected: true),
                      'Connected ${d.name}.',
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 6),
        Text(text, style: AppText.caption),
      ],
    );
  }
}

class _MetricsAvailability extends StatelessWidget {
  const _MetricsAvailability({required this.devices});

  final List<Device> devices;

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < VitalMetric.values.length; i++) ...[
            if (i > 0) const Divider(),
            _metricRow(VitalMetric.values[i]),
          ],
        ],
      ),
    );
  }

  Widget _metricRow(VitalMetric m) {
    final providers = [for (final d in devices) if (d.metrics.contains(m)) d];
    final live = providers.where((d) => d.connected).toList();
    final (label, color, icon) = live.isNotEmpty
        ? ('From ${live.first.name}', AppColors.flagGreen, Icons.check_circle_rounded)
        : providers.isNotEmpty
            ? ('Connect ${providers.first.name}', AppColors.flagAmber, Icons.link_off_rounded)
            : ('No device provides this', AppColors.muted, Icons.remove_circle_outline_rounded);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(m.label, style: AppText.body)),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.end,
              style: AppText.caption.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataQuality extends ConsumerWidget {
  const _DataQuality();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(readingsProvider(ChartRange.all));
    return async.when(
      loading: () => const ShimmerLikeSkeleton(height: 140, radius: 24),
      error: (e, _) => SoftSurface(
        child: Row(
          children: [
            Expanded(
              child: Text('Could not check data quality.', style: AppText.body),
            ),
            TextButton(
              onPressed: () => ref.invalidate(readingsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (readings) => _quality(readings),
    );
  }

  Widget _quality(List<DailyReading> readings) {
    if (readings.isEmpty) {
      return const SoftSurface(
        child: EmptyState(
          title: 'No data yet',
          message: 'Quality shows up once readings start arriving.',
          icon: Icons.insights_outlined,
        ),
      );
    }
    final window = readings.length > 30
        ? readings.sublist(readings.length - 30)
        : readings;
    final withData = window.where((r) => !r.isGap).length;
    final share = withData / window.length;
    final (label, color) = share >= 0.9
        ? ('Good', AppColors.flagGreen)
        : share >= 0.7
            ? ('Fair', AppColors.flagAmber)
            : ('Needs attention', AppColors.flagRed);

    var missed = 0;
    for (var i = window.length - 1; i >= 0 && window[i].isGap; i--) {
      missed++;
    }

    return SoftSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$withData of ${window.length} days have data',
                  style: AppText.cardTitle,
                ),
              ),
              Text(label, style: AppText.label.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 8,
              backgroundColor: AppColors.line,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            missed > 0
                ? 'No data for the last $missed ${missed == 1 ? 'day' : 'days'}. '
                    'Check that your device is charged and syncing.'
                : 'Steady wear helps your usual range stay accurate. Missing '
                    'days are left blank, never counted as zero.',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}
