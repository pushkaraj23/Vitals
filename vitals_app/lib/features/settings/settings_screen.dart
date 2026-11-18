import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Baseline;

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/widgets.dart';
import '../../data/mock/personas.dart';
import '../../domain/models/consent.dart';
import '../../domain/models/settings.dart';
import '../../providers/providers.dart';
import '../alerts/alerts_state.dart';
import '../doctor/doctor_reviews_screen.dart';
import '../habits/habits_screen.dart';
import '../profile/profile_state.dart';
import '../symptoms/symptoms_screen.dart';

const appVersion = '0.1.0 (build 1)';

enum AppLanguage {
  en('English', 'EN'),
  hi('हिन्दी', 'HI'),
  mr('मराठी', 'MR');

  const AppLanguage(this.nativeName, this.code);

  final String nativeName;
  final String code;
}

/// Selected language. Only English is fully translated in this build.
class LanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => AppLanguage.en;

  void select(AppLanguage language) => state = language;
}

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(
  LanguageNotifier.new,
);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: CenteredBody(
          child: settingsAsync.when(
            loading: () => const ListSkeleton(blocks: 4, blockHeight: 120),
            error: (e, _) => FeatureError(
              what: 'your settings',
              onRetry: () => ref.invalidate(settingsProvider),
            ),
            data: (settings) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _Preferences(settings: settings),
                const SizedBox(height: 24),
                const _PrivacyDashboard(),
                const SizedBox(height: 24),
                _DemoTools(settings: settings),
                const SizedBox(height: 24),
                const _About(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _saveSettings(
  BuildContext context,
  WidgetRef ref,
  AppSettings next,
) async {
  try {
    await ref.read(settingsProvider.notifier).save(next);
  } catch (_) {
    if (context.mounted) showSnack(context, 'Could not save that setting.');
  }
}

// ------------------------------------------------------------ preferences

class _Preferences extends ConsumerWidget {
  const _Preferences({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Preferences'),
        const SizedBox(height: 12),
        SoftSurface(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.spa_outlined),
                title: const Text('Gentle mode'),
                subtitle: Text(
                  'Softer wording when showing possible effects of a pattern.',
                  style: AppText.caption,
                ),
                value: settings.gentleMode,
                onChanged: (v) =>
                    _saveSettings(context, ref, settings.copyWith(gentleMode: v)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.straighten_rounded),
                title: const Text('Units'),
                trailing: SegmentedButton<UnitSystem>(
                  showSelectedIcon: false,
                  segments: [
                    for (final u in UnitSystem.values)
                      ButtonSegment(value: u, label: Text(u.label)),
                  ],
                  selected: {settings.unitSystem},
                  onSelectionChanged: (s) => _saveSettings(
                    context,
                    ref,
                    settings.copyWith(unitSystem: s.first),
                  ),
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.language_rounded),
                        const SizedBox(width: 16),
                        Text('Language', style: AppText.body),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final l in AppLanguage.values)
                          AppChip(
                            label: '${l.code} · ${l.nativeName}',
                            selected: language == l,
                            onTap: () {
                              ref.read(languageProvider.notifier).select(l);
                              if (l != AppLanguage.en) {
                                showSnack(
                                  context,
                                  '${l.nativeName} translations are coming '
                                  'soon. The app stays in English for now.',
                                );
                              }
                            },
                          ),
                      ],
                    ),
                    if (language != AppLanguage.en) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Only English is complete in this build.',
                        style: AppText.caption.copyWith(color: AppColors.flagAmber),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.notifications_none_rounded),
                title: const Text('Notifications'),
                subtitle: Text(
                  settings.notificationsEnabled ? 'On' : 'Off',
                  style: AppText.caption,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(AppRoutes.alertPreferences),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- privacy

class _PrivacyDashboard extends ConsumerWidget {
  const _PrivacyDashboard();

  static String _stamp(BuildContext context, DateTime t) =>
      '${AppDateUtils.dayMonthYear.format(t)}, ${TimeOfDay.fromDateTime(t).format(context)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consentsAsync = ref.watch(consentsProvider);
    final now = DateTime.now();
    final log = <(IconData, String, DateTime)>[
      (Icons.sync_rounded, 'Data synced from your devices', now.subtract(const Duration(hours: 3))),
      (Icons.visibility_outlined, 'You viewed your doctor summary', now.subtract(const Duration(days: 1, hours: 2))),
      (Icons.medical_services_outlined, 'Sample reviewer opened a shared summary (simulated)', now.subtract(const Duration(days: 3))),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Privacy dashboard'),
        const SizedBox(height: 4),
        Text(
          'You decide what VitalWatch can use. Change your mind any time.',
          style: AppText.bodyMuted,
        ),
        const SizedBox(height: 12),
        consentsAsync.when(
          loading: () => const ShimmerLikeSkeleton(height: 200, radius: 24),
          error: (e, _) => SoftSurface(
            child: Row(
              children: [
                Expanded(child: Text('Could not load consents.', style: AppText.body)),
                TextButton(
                  onPressed: () => ref.invalidate(consentsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (consents) => SoftSurface(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                for (var i = 0; i < consents.length; i++) ...[
                  if (i > 0) const Divider(),
                  _consentTile(context, ref, consents[i]),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Access log', style: AppText.cardTitle),
        const SizedBox(height: 2),
        Text('Sample entries for the demo.', style: AppText.caption),
        const SizedBox(height: 8),
        SoftSurface(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              for (var i = 0; i < log.length; i++) ...[
                if (i > 0) const Divider(),
                ListTile(
                  leading: Icon(log[i].$1),
                  title: Text(log[i].$2, style: AppText.body),
                  subtitle: Text(_stamp(context, log[i].$3), style: AppText.caption),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PillButton(
                label: 'Export my data',
                icon: Icons.download_rounded,
                variant: PillButtonVariant.secondary,
                onPressed: () => _confirmExport(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PillButton(
                label: 'Delete my data',
                icon: Icons.delete_outline_rounded,
                variant: PillButtonVariant.secondary,
                onPressed: () => _confirmDelete(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _consentTile(BuildContext context, WidgetRef ref, Consent c) {
    final when = c.updatedAt;
    final stamp = when == null
        ? 'Set during sign-up (sample)'
        : '${c.granted ? 'Granted' : 'Withdrawn'} ${_stamp(context, when)}';
    return SwitchListTile(
      title: Text(c.title),
      subtitle: Text(
        '${c.description}\n$stamp${c.isRequired ? ' · Required' : ''}',
        style: AppText.caption,
      ),
      isThreeLine: true,
      value: c.granted,
      onChanged: c.isRequired
          ? null
          : (v) async {
              try {
                await ref
                    .read(consentsProvider.notifier)
                    .setGranted(c.id, granted: v);
              } catch (_) {
                if (context.mounted) showSnack(context, 'Could not update consent.');
              }
            },
    );
  }

  Future<void> _confirmExport(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Export your data?'),
        content: Text(
          'We would prepare a file with your readings, symptoms, notes and '
          'settings.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Request export'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      showSnack(context, 'Data export is coming later.');
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteDialog(),
    );
    if (ok == true && context.mounted) {
      showSnack(context, 'Demo only: nothing was deleted.');
    }
  }
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog();

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.text.trim().toUpperCase() == 'DELETE';
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: AppColors.flagRed),
      title: const Text('Delete all your data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This would remove your readings, symptoms, notes and reports. '
            'It could not be undone.',
            style: AppText.body,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Type DELETE to confirm'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.flagRed),
          onPressed: ready ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- demo tools

class _DemoTools extends ConsumerWidget {
  const _DemoTools({required this.settings});

  final AppSettings settings;

  void _reset(BuildContext context, WidgetRef ref) {
    ref.read(personaIdProvider.notifier).select(Personas.defaultId);
    ref
      // Regenerates sample data, settings, consents and devices.
      ..invalidate(mockSessionProvider)
      ..invalidate(mockStoreProvider)
      // Screen-level demo state.
      ..invalidate(languageProvider)
      ..invalidate(alertPrefsProvider)
      ..invalidate(demoAlertsProvider)
      ..invalidate(snoozedAlertsProvider)
      ..invalidate(checkInsProvider)
      ..invalidate(medicalHistoryProvider)
      ..invalidate(familyTreeProvider)
      ..invalidate(screeningRemindersProvider)
      ..invalidate(secondOpinionsProvider)
      ..invalidate(activeHabitIdsProvider);
    showSnack(context, 'Demo reset to Rahul with fresh sample data.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(personaIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Demo tools'),
        const SizedBox(height: 4),
        Text('For presentations. Not part of the real app.', style: AppText.bodyMuted),
        const SizedBox(height: 12),
        SoftSurface(
          color: AppColors.lavenderCard,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sample person', style: AppText.label),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<PersonaId>(
                        showSelectedIcon: false,
                        segments: [
                          for (final p in PersonaId.values)
                            ButtonSegment(
                              value: p,
                              label: Text(p.label),
                            ),
                        ],
                        selected: {persona},
                        onSelectionChanged: (s) {
                          ref.read(personaIdProvider.notifier).select(s.first);
                          showSnack(
                            context,
                            'Switched to ${s.first.label} (${s.first.storyLabel}).',
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(persona.storyLabel, style: AppText.caption.copyWith(color: AppColors.ink)),
                  ],
                ),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Force errors'),
                subtitle: Text('Data screens show their error state.', style: AppText.caption),
                value: settings.forceError,
                onChanged: (v) async {
                  try {
                    await ref.read(settingsProvider.notifier).setForceError(v);
                  } catch (_) {}
                },
              ),
              SwitchListTile(
                title: const Text('Slow sync'),
                subtitle: Text('Adds a few seconds of loading.', style: AppText.caption),
                value: settings.slowSync,
                onChanged: (v) async {
                  try {
                    await ref.read(settingsProvider.notifier).setSlowSync(v);
                  } catch (_) {}
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.emergency_rounded, color: AppColors.flagRed),
                title: const Text('Trigger emergency'),
                subtitle: Text('Opens the emergency screen.', style: AppText.caption),
                onTap: () {
                  ref.read(demoAlertsProvider.notifier).triggerEmergency();
                  context.push(AppRoutes.emergency);
                },
              ),
              ListTile(
                leading: const Icon(Icons.restart_alt_rounded),
                title: const Text('Reset demo'),
                subtitle: Text('Back to Rahul with fresh sample data.', style: AppText.caption),
                onTap: () => _reset(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Design preview'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(AppRoutes.designPreview),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ about

class _About extends StatelessWidget {
  const _About();

  static const _disclaimer =
      'VitalWatch shows how your recent wearable data compares with your own '
      'usual range. It gives wellness insights, not a medical diagnosis, and '
      'it cannot tell you whether you have a condition. If you feel unwell or '
      'are worried, speak to a qualified clinician. In an emergency, contact '
      'your local emergency services.';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'About'),
        const SizedBox(height: 12),
        SoftSurface(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('VitalWatch'),
                subtitle: Text('Version $appVersion', style: AppText.caption),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.gavel_rounded),
                title: const Text('Disclaimer'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Disclaimer'),
                    content: Text(_disclaimer, style: AppText.body),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const DisclaimerBanner(),
      ],
    );
  }
}
