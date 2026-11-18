import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/pill_button.dart';
import '../../data/auth_service.dart';
import '../../providers/auth_provider.dart';
import 'onboarding_parts.dart';

class FsConsentScreen extends ConsumerStatefulWidget {
  const FsConsentScreen({super.key});

  @override
  ConsumerState<FsConsentScreen> createState() => _FsConsentScreenState();
}

class _FsConsentScreenState extends ConsumerState<FsConsentScreen> {
  bool _agreed = false;
  bool _loading = false;

  Future<void> _proceed() async {
    if (!_agreed) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      await AuthService().saveConsent(uid);
      if (mounted) context.go('/onboard/basic-profile');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save consent. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        title: const Text('Your health data'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(kScreenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How VitalWatch uses your data',
                style: AppText.screenTitle,
              ),
              const SizedBox(height: 16),
              const _ConsentCard(
                icon: Icons.health_and_safety_outlined,
                title: 'Personal baseline',
                body:
                    'VitalWatch reads your heart rate, sleep and activity from your wearable to build a baseline of your usual patterns. This data is stored securely in your personal account.',
              ),
              const SizedBox(height: 12),
              const _ConsentCard(
                icon: Icons.bar_chart_rounded,
                title: 'Pattern detection only',
                body:
                    'The app compares recent readings with your own baseline and flags sustained changes worth discussing with a doctor. VitalWatch provides wellness insights — not medical diagnoses.',
              ),
              const SizedBox(height: 12),
              const _ConsentCard(
                icon: Icons.lock_outline_rounded,
                title: 'Your data, your control',
                body:
                    'Your data is never sold or shared without your consent. You can delete your account and all data at any time from Settings.',
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _agreed = !_agreed),
                      child: Text(
                        'I understand that VitalWatch stores and processes my health data to provide wellness insights. I can withdraw consent at any time.',
                        style: AppText.body,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Read Privacy Policy →'),
                ),
              ),
              const SizedBox(height: 24),
              PillButton(
                label: _loading ? 'Saving…' : 'I agree — continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: (_agreed && !_loading) ? _proceed : null,
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'You must agree to continue. You can withdraw consent in Settings.',
                  textAlign: TextAlign.center,
                  style: AppText.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.skyCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.ink, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.cardTitle),
                const SizedBox(height: 4),
                Text(body, style: AppText.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
