// lib/features/onboarding/fs_medical_profile_screen.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/pill_button.dart';
import '../../data/auth_service.dart';
import '../../providers/auth_provider.dart';
import 'onboarding_parts.dart';

class FsMedicalProfileScreen extends ConsumerStatefulWidget {
  const FsMedicalProfileScreen({super.key});

  @override
  ConsumerState<FsMedicalProfileScreen> createState() =>
      _FsMedicalProfileScreenState();
}

class _FsMedicalProfileScreenState extends ConsumerState<FsMedicalProfileScreen> {
  final _conditionCtrl = TextEditingController();
  final _medicationCtrl = TextEditingController();
  final _allergyCtrl = TextEditingController();
  final _surgeryCtrl = TextEditingController();

  final List<String> _conditions = [];
  final List<String> _medications = [];
  final List<String> _allergies = [];
  final List<String> _surgeries = [];
  bool _loading = false;

  @override
  void dispose() {
    _conditionCtrl.dispose();
    _medicationCtrl.dispose();
    _allergyCtrl.dispose();
    _surgeryCtrl.dispose();
    super.dispose();
  }

  void _addItem(TextEditingController ctrl, List<String> target) {
    final text = ctrl.text.trim();
    if (text.isNotEmpty && !target.contains(text)) {
      setState(() {
        target.add(text);
        ctrl.clear();
      });
    }
  }

  Future<void> _saveAndContinue() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _loading = true);
    try {
      await AuthService().saveMedicalProfile(
        uid,
        conditions: _conditions,
        medications: _medications,
        allergies: _allergies,
        surgeries: _surgeries,
      );
      if (mounted) context.go('/onboard/family-history');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save medical profile.')),
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
        title: const Text('Medical background'),
        actions: [
          TextButton(
            onPressed: () => context.go('/onboard/family-history'),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(kScreenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Medical profile', style: AppText.screenTitle),
              const SizedBox(height: 8),
              Text(
                'Optional. Helps contextualize your wellness insights with your doctor.',
                style: AppText.bodyMuted,
              ),
              const SizedBox(height: 20),
              _TagSection(
                title: 'Known conditions',
                controller: _conditionCtrl,
                hint: 'e.g. Asthma, Thyroid',
                items: _conditions,
                onAdd: () => _addItem(_conditionCtrl, _conditions),
                onRemove: (idx) => setState(() => _conditions.removeAt(idx)),
              ),
              const SizedBox(height: 16),
              _TagSection(
                title: 'Current medications',
                controller: _medicationCtrl,
                hint: 'e.g. Metformin, Amlodipine',
                items: _medications,
                onAdd: () => _addItem(_medicationCtrl, _medications),
                onRemove: (idx) => setState(() => _medications.removeAt(idx)),
              ),
              const SizedBox(height: 16),
              _TagSection(
                title: 'Allergies',
                controller: _allergyCtrl,
                hint: 'e.g. Penicillin, Peanuts',
                items: _allergies,
                onAdd: () => _addItem(_allergyCtrl, _allergies),
                onRemove: (idx) => setState(() => _allergies.removeAt(idx)),
              ),
              const SizedBox(height: 16),
              _TagSection(
                title: 'Past surgeries',
                controller: _surgeryCtrl,
                hint: 'e.g. Appendectomy',
                items: _surgeries,
                onAdd: () => _addItem(_surgeryCtrl, _surgeries),
                onRemove: (idx) => setState(() => _surgeries.removeAt(idx)),
              ),
              const SizedBox(height: 28),
              PillButton(
                label: _loading ? 'Saving…' : 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: _loading ? null : _saveAndContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({
    required this.title,
    required this.controller,
    required this.hint,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final TextEditingController controller;
  final String hint;
  final List<String> items;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.label),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.add),
              onPressed: onAdd,
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < items.length; i++)
                Chip(
                  label: Text(items[i]),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => onRemove(i),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
