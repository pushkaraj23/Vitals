import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/pill_button.dart';
import '../../data/auth_service.dart';
import '../../data/repositories/user_repository.dart';
import '../../providers/auth_provider.dart';
import 'onboarding_parts.dart';

class FsFamilyHistoryScreen extends ConsumerStatefulWidget {
  const FsFamilyHistoryScreen({super.key});

  @override
  ConsumerState<FsFamilyHistoryScreen> createState() =>
      _FsFamilyHistoryScreenState();
}

class _FsFamilyHistoryScreenState
    extends ConsumerState<FsFamilyHistoryScreen> {
  final List<FamilyHistoryItem> _items = [];
  final _relationCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _relationCtrl.dispose();
    _conditionCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  void _addEntry() {
    final rel = _relationCtrl.text.trim();
    final cond = _conditionCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text.trim());
    if (rel.isNotEmpty && cond.isNotEmpty) {
      setState(() {
        _items.add(FamilyHistoryItem(
          relation: rel,
          condition: cond,
          ageAtOnset: age,
        ));
        _relationCtrl.clear();
        _conditionCtrl.clear();
        _ageCtrl.clear();
      });
    }
  }

  Future<void> _finish() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _loading = true);
    try {
      final svc = AuthService();
      await svc.saveFamilyHistory(uid, _items);
      await svc.completeOnboarding(uid);
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not complete setup.')),
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
        title: const Text('Family history'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _finish,
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
              Text('Family health patterns', style: AppText.screenTitle),
              const SizedBox(height: 8),
              Text(
                'Optional. Having family history of heart conditions or diabetes helps the app calibrate sensitivities for wellness alerts.',
                style: AppText.bodyMuted,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _relationCtrl,
                      decoration: InputDecoration(
                        labelText: 'Relation',
                        hintText: 'e.g. Father, Mother',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _conditionCtrl,
                      decoration: InputDecoration(
                        labelText: 'Condition',
                        hintText: 'e.g. Hypertension',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ageCtrl,
                      decoration: InputDecoration(
                        labelText: 'Age at onset (optional)',
                        hintText: 'e.g. 52',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _addEntry,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_items.isNotEmpty) ...[
                Text('Recorded entries', style: AppText.label),
                const SizedBox(height: 8),
                for (var i = 0; i < _items.length; i++)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        '${_items[i].relation}: ${_items[i].condition}',
                        style: AppText.body,
                      ),
                      subtitle: _items[i].ageAtOnset != null
                          ? Text('Onset around age ${_items[i].ageAtOnset}')
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => setState(() => _items.removeAt(i)),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 28),
              PillButton(
                label: _loading ? 'Completing setup…' : 'Complete setup',
                icon: Icons.check_circle_rounded,
                onPressed: _loading ? null : _finish,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
