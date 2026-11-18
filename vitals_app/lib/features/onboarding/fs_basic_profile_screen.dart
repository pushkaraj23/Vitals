import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/pill_button.dart';
import '../../data/auth_service.dart';
import '../../providers/auth_provider.dart';
import 'onboarding_parts.dart';

class FsBasicProfileScreen extends ConsumerStatefulWidget {
  const FsBasicProfileScreen({super.key});

  @override
  ConsumerState<FsBasicProfileScreen> createState() =>
      _FsBasicProfileScreenState();
}

class _FsBasicProfileScreenState extends ConsumerState<FsBasicProfileScreen> {
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String? _sex;
  bool _loading = false;
  String? _error;

  static const _sexOptions = ['Male', 'Female', 'Other'];

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    final age = int.tryParse(_ageCtrl.text.trim());
    final height = double.tryParse(_heightCtrl.text.trim());
    final weight = double.tryParse(_weightCtrl.text.trim());

    if (age == null || age < 1 || age > 120) {
      setState(() => _error = 'Please enter a valid age.');
      return;
    }
    if (_sex == null) {
      setState(() => _error = 'Please select a biological sex.');
      return;
    }
    if (height == null || height < 50 || height > 300) {
      setState(() => _error = 'Please enter a valid height in cm.');
      return;
    }
    if (weight == null || weight < 10 || weight > 500) {
      setState(() => _error = 'Please enter a valid weight in kg.');
      return;
    }

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService().saveBasicProfile(
        uid,
        age: age,
        sex: _sex!,
        heightCm: height,
        weightKg: weight,
      );
      if (mounted) context.go('/onboard/medical-profile');
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Please try again.');
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
        title: const Text('Basic profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(kScreenPadding),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('About you', style: AppText.screenTitle),
              const SizedBox(height: 8),
              Text(
                'This helps VitalWatch calibrate your personal baseline.',
                style: AppText.bodyMuted,
              ),
              const SizedBox(height: 24),
              LabeledField(
                label: 'Age',
                controller: _ageCtrl,
                hint: 'e.g. 35',
                prefixIcon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Text('Biological sex', style: AppText.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in _sexOptions)
                    ChoiceChip(
                      label: Text(s),
                      selected: _sex == s,
                      onSelected: (_) => setState(() => _sex = s),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Height (cm)',
                controller: _heightCtrl,
                hint: 'e.g. 170',
                prefixIcon: Icons.height_rounded,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Weight (kg)',
                controller: _weightCtrl,
                hint: 'e.g. 70',
                prefixIcon: Icons.monitor_weight_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                errorText: _error,
              ),
              const SizedBox(height: 20),
              PillButton(
                label: _loading ? 'Saving…' : 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: _loading ? null : _proceed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
