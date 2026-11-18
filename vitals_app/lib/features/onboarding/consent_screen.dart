import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/soft_surface.dart';
import '../../providers/session_provider.dart';
import 'onboarding_parts.dart';

const String kConsentVersion = 'v1.0';

class _ConsentItem {
  const _ConsentItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.required,
    required this.initial,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool required;
  final bool initial;
}

const _items = <_ConsentItem>[
  _ConsentItem(
    id: 'read_health',
    title: 'Read my health data',
    description: 'Sleep, heart and activity readings from Health Connect, '
        'used to learn your usual range.',
    icon: Icons.monitor_heart_outlined,
    required: true,
    initial: true,
  ),
  _ConsentItem(
    id: 'store_server',
    title: 'Store data on server',
    description: 'Keeps your history securely backed up so trends and flags '
        'work across devices.',
    icon: Icons.cloud_outlined,
    required: true,
    initial: true,
  ),
  _ConsentItem(
    id: 'share_doctors',
    title: 'Share with doctors',
    description: 'Summaries are shared with a clinician only when you request '
        'a review.',
    icon: Icons.medical_services_outlined,
    required: true,
    initial: true,
  ),
  _ConsentItem(
    id: 'analytics',
    title: 'Help improve VitalWatch',
    description: 'Anonymous usage analytics. Optional and off by default.',
    icon: Icons.insights_outlined,
    required: false,
    initial: false,
  ),
];

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  late final Map<String, bool> _granted = {
    for (final i in _items) i.id: i.initial,
  };

  bool get _requiredOk =>
      _items.where((i) => i.required).every((i) => _granted[i.id] == true);

  void _continue() {
    // No dedicated onboarding consent notifier exists (the settings
    // ConsentsNotifier uses different ids), so persist to the session only.
    ref.read(sessionProvider.notifier).acceptConsents();
    context.go('/intake');
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
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.lavenderCard,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Your data, your call', style: AppText.screenTitle),
                  const SizedBox(height: 8),
                  Text(
                    'Choose what VitalWatch can do. You can change optional '
                    'items any time in Settings.',
                    style: AppText.bodyMuted.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  for (final item in _items) ...[
                    _ConsentTile(
                      item: item,
                      value: _granted[item.id]!,
                      onChanged: (v) => setState(() => _granted[item.id] = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Consent text $kConsentVersion',
                      style: AppText.caption,
                    ),
                  ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_requiredOk) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.flagAmber,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Turn on all required items to continue.',
                            style: AppText.caption.copyWith(
                              color: AppColors.flagAmber,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  PillButton(
                    label: 'Agree and continue',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _requiredOk ? _continue : null,
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

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.item,
    required this.value,
    required this.onChanged,
  });

  final _ConsentItem item;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final needsAttention = item.required && !value;
    return Semantics(
      container: true,
      label: '${item.title}, ${item.required ? 'required' : 'optional'}',
      child: SoftSurface(
        borderColor: needsAttention ? AppColors.flagAmber : null,
        onTap: () => onChanged(!value),
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
              child: Icon(item.icon, size: 20, color: AppColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(item.title, style: AppText.cardTitle),
                      ),
                      const SizedBox(width: 8),
                      _Tag(required: item.required),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.description, style: AppText.bodyMuted),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.surface,
              activeTrackColor: AppColors.ink,
              inactiveThumbColor: AppColors.surface,
              inactiveTrackColor: AppColors.line,
              trackOutlineColor: WidgetStatePropertyAll(
                value ? AppColors.ink : AppColors.line,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.required});

  final bool required;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: required ? AppColors.peachCard : AppColors.skyCard,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        required ? 'Required' : 'Optional',
        style: AppText.caption.copyWith(
          color: AppColors.ink,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
