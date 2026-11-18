import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide Baseline;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/settings.dart';
import '../../providers/providers.dart';
import 'alerts_state.dart';

/// Channels, frequency and quiet hours. Held in app state only (demo).
class AlertPreferencesScreen extends ConsumerWidget {
  const AlertPreferencesScreen({super.key});

  static TimeOfDay _time(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref, {
    required bool start,
  }) async {
    final prefs = ref.read(alertPrefsProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: _time(start ? prefs.quietStartMinutes : prefs.quietEndMinutes),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    ref.read(alertPrefsProvider.notifier).update(
      (p) => start
          ? p.copyWith(quietStartMinutes: minutes)
          : p.copyWith(quietEndMinutes: minutes),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(alertPrefsProvider);
    final notifier = ref.read(alertPrefsProvider.notifier);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Alert preferences')),
      body: SafeArea(
        child: CenteredBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                'Choose how and when VitalWatch gets your attention.',
                style: AppText.bodyMuted,
              ),
              const SizedBox(height: 16),
              settingsAsync.when(
                loading: () => const ShimmerLikeSkeleton(height: 64, radius: 24),
                error: (e, _) => SoftSurface(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Could not load notification settings.',
                          style: AppText.body,
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(settingsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (s) => SoftSurface(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SwitchListTile(
                    title: Text('Pattern notifications', style: AppText.cardTitle),
                    subtitle: Text(
                      'Master switch for all alerts below.',
                      style: AppText.caption,
                    ),
                    value: s.notificationsEnabled,
                    onChanged: (v) => ref
                        .read(settingsProvider.notifier)
                        .save(s.copyWith(notificationsEnabled: v)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Channels'),
              const SizedBox(height: 12),
              SoftSurface(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_rounded),
                      title: const Text('Push notifications'),
                      value: prefs.push,
                      onChanged: (v) => notifier.update((p) => p.copyWith(push: v)),
                    ),
                    const Divider(),
                    SwitchListTile(
                      secondary: const Icon(Icons.mail_outline_rounded),
                      title: const Text('Email'),
                      value: prefs.email,
                      onChanged: (v) => notifier.update((p) => p.copyWith(email: v)),
                    ),
                    const Divider(),
                    SwitchListTile(
                      secondary: const Icon(Icons.sms_outlined),
                      title: const Text('SMS'),
                      subtitle: Text(
                        'Reserved for the most important alerts.',
                        style: AppText.caption,
                      ),
                      value: prefs.sms,
                      onChanged: (v) => notifier.update((p) => p.copyWith(sms: v)),
                    ),
                  ],
                ),
              ),
              if (!prefs.push && !prefs.email && !prefs.sms) ...[
                const SizedBox(height: 8),
                Text(
                  'All channels are off. You will still see alerts inside the app.',
                  style: AppText.caption.copyWith(color: AppColors.flagAmber),
                ),
              ],
              const SizedBox(height: 24),
              const SectionHeader(title: 'How often'),
              const SizedBox(height: 12),
              SoftSurface(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: RadioGroup<AlertFrequency>(
                  groupValue: prefs.frequency,
                  onChanged: (v) {
                    if (v != null) notifier.update((p) => p.copyWith(frequency: v));
                  },
                  child: Column(
                    children: [
                      for (final f in AlertFrequency.values)
                        RadioListTile<AlertFrequency>(
                          value: f,
                          title: Text(f.label),
                          subtitle: Text(f.description, style: AppText.caption),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Sensitivity'),
              const SizedBox(height: 12),
              settingsAsync.maybeWhen(
                data: (s) => SoftSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final a in AlertSensitivity.values)
                            AppChip(
                              label: a.label,
                              selected: s.sensitivity == a,
                              onTap: () => ref
                                  .read(settingsProvider.notifier)
                                  .save(s.copyWith(sensitivity: a)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Relaxed surfaces only longer-lasting patterns. '
                        'Sensitive surfaces them sooner.',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Quiet hours'),
              const SizedBox(height: 12),
              SoftSurface(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.bedtime_outlined),
                      title: const Text('Pause non-urgent alerts'),
                      value: prefs.quietHoursEnabled,
                      onChanged: (v) =>
                          notifier.update((p) => p.copyWith(quietHoursEnabled: v)),
                    ),
                    if (prefs.quietHoursEnabled) ...[
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.nights_stay_outlined),
                        title: const Text('From'),
                        trailing: Text(
                          _time(prefs.quietStartMinutes).format(context),
                          style: AppText.cardTitle,
                        ),
                        onTap: () => _pickTime(context, ref, start: true),
                      ),
                      ListTile(
                        leading: const Icon(Icons.wb_sunny_outlined),
                        title: const Text('Until'),
                        trailing: Text(
                          _time(prefs.quietEndMinutes).format(context),
                          style: AppText.cardTitle,
                        ),
                        onTap: () => _pickTime(context, ref, start: false),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Emergency alerts always come through, even during quiet '
                'hours.',
                style: AppText.caption,
              ),
              const SizedBox(height: 24),
              PillButton(
                label: 'Reset to defaults',
                variant: PillButtonVariant.secondary,
                onPressed: () {
                  notifier.reset();
                  showSnack(context, 'Preferences reset.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
