import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/state_views.dart';
import '../../data/repositories/symptom_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../onboarding/onboarding_parts.dart';

class FsSymptomsScreen extends ConsumerStatefulWidget {
  const FsSymptomsScreen({super.key});

  @override
  ConsumerState<FsSymptomsScreen> createState() => _FsSymptomsScreenState();
}

class _FsSymptomsScreenState extends ConsumerState<FsSymptomsScreen> {
  final _textCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _addSymptom() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final id = 'sym_${now.millisecondsSinceEpoch}';

      final symptom = SymptomModel(
        id: id,
        symptom: text,
        date: dateStr,
      );

      await ref.read(symptomRepositoryProvider).addSymptom(uid, symptom);
      _textCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Symptom logged.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteSymptom(String id) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    await ref.read(symptomRepositoryProvider).deleteSymptom(uid, id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Symptom removed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final symptomsAsync = ref.watch(symptomsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        title: const Text('Symptoms Journal'),
      ),
      body: SafeArea(
        child: symptomsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ErrorState(
            message: 'Unable to load symptoms.',
            onRetry: () => ref.invalidate(symptomsProvider),
          ),
          data: (symptoms) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(kScreenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Log how you feel', style: AppText.screenTitle),
                  const SizedBox(height: 6),
                  Text(
                    'Track symptoms alongside your wearable patterns to share with your doctor.',
                    style: AppText.bodyMuted,
                  ),
                  const SizedBox(height: 20),

                  // Add symptom box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _textCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. Waking up unrefreshed, palpitations',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addSymptom(),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _addSymptom,
                            icon: const Icon(Icons.add),
                            label: Text(_saving ? 'Saving…' : 'Log symptom'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text('Recorded symptoms', style: AppText.cardTitle),
                  const SizedBox(height: 10),

                  if (symptoms.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'No symptoms logged yet.',
                          style: AppText.bodyMuted,
                        ),
                      ),
                    )
                  else
                    for (final s in symptoms)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(s.symptom, style: AppText.body),
                          subtitle: Text(
                            s.flagId != null
                                ? '${s.date} • Linked to flag'
                                : s.date,
                            style: AppText.caption,
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.muted,
                            ),
                            onPressed: () => _deleteSymptom(s.id),
                          ),
                        ),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
