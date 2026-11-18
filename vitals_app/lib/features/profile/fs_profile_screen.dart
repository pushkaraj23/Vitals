import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/ink_app_bar.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/user_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';

class FsProfileScreen extends ConsumerStatefulWidget {
  const FsProfileScreen({super.key});

  @override
  ConsumerState<FsProfileScreen> createState() => _FsProfileScreenState();
}

class _FsProfileScreenState extends ConsumerState<FsProfileScreen> {
  bool _editing = false;
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  bool _saving = false;
  bool _fieldsSeeded = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _initFields(UserModel user) {
    _nameCtrl.text = user.name ?? '';
    _ageCtrl.text = user.age?.toString() ?? '';
    _heightCtrl.text = user.heightCm?.toString() ?? '';
    _weightCtrl.text = user.weightKg?.toString() ?? '';
    _fieldsSeeded = true;
  }

  Future<void> _saveProfile(UserModel current) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      final updated = current.copyWith(
        name: _nameCtrl.text.trim(),
        age: int.tryParse(_ageCtrl.text.trim()),
        heightCm: double.tryParse(_heightCtrl.text.trim()),
        weightKg: double.tryParse(_weightCtrl.text.trim()),
      );
      await ref.read(userRepositoryProvider).setUser(uid, updated);
      setState(() => _editing = false);
      if (mounted) showSnack(context, 'Profile updated.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showAddFamilyDialog(UserModel current) async {
    final relCtrl = TextEditingController();
    final condCtrl = TextEditingController();
    final ageCtrl = TextEditingController();

    final added = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.canvas,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final inset = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + inset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add family history',
                style: AppText.cardTitle.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(
                'Heart conditions or diabetes help calibrate drift sensitivity.',
                style: AppText.bodyMuted,
              ),
              const SizedBox(height: 16),
              SoftSurface(
                radius: 22,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Column(
                  children: [
                    TextField(
                      controller: relCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Relation',
                        hintText: 'e.g. Father, Mother',
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(height: 1),
                    TextField(
                      controller: condCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Condition',
                        hintText: 'e.g. Hypertension',
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(height: 1),
                    TextField(
                      controller: ageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Age at onset (optional)',
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: 'Cancel',
                      variant: PillButtonVariant.secondary,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PillButton(
                      label: 'Add',
                      onPressed: () async {
                        final rel = relCtrl.text.trim();
                        final cond = condCtrl.text.trim();
                        final age = int.tryParse(ageCtrl.text.trim());
                        if (rel.isEmpty || cond.isEmpty) return;
                        final uid = ref.read(currentUidProvider);
                        if (uid == null) return;
                        final list =
                            List<FamilyHistoryItem>.from(current.familyHistory)
                              ..add(
                                FamilyHistoryItem(
                                  relation: rel,
                                  condition: cond,
                                  ageAtOnset: age,
                                ),
                              );
                        await ref.read(userRepositoryProvider).setUser(
                              uid,
                              current.copyWith(familyHistory: list),
                            );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    relCtrl.dispose();
    condCtrl.dispose();
    ageCtrl.dispose();
    if (added == true && mounted) {
      showSnack(context, 'Family history added.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        title: 'Profile',
        subtitle: 'You & your health context',
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(
          message: 'Unable to load profile.',
          onRetry: () => ref.invalidate(userProvider),
        ),
        data: (user) {
          if (user == null) {
            return const EmptyState(
              icon: Icons.person_outline_rounded,
              title: 'No profile found',
              message: 'Sign in again to load your VitalWatch profile.',
            );
          }

          if (!_fieldsSeeded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_fieldsSeeded) {
                setState(() => _initFields(user));
              }
            });
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userProvider);
              await ref.read(userProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                SoftSurface(
                  color: AppColors.lavenderCard,
                  radius: 28,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: AppColors.surface,
                        child: Text(
                          user.name?.isNotEmpty == true
                              ? user.name![0].toUpperCase()
                              : '?',
                          style: GoogleFonts.manrope(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name ?? 'VitalWatch Member',
                              style: AppText.cardTitle.copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: 2),
                            Text(user.email ?? '', style: AppText.bodyMuted),
                            if (user.isDemo) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.creamCard,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Demo · ${user.scenario ?? 'synthetic'}',
                                  style: AppText.caption.copyWith(
                                    color: AppColors.flagAmber,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                SoftSurface(
                  color: AppColors.peachCard,
                  radius: 28,
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Basic details',
                              style: AppText.cardTitle.copyWith(fontSize: 18),
                            ),
                          ),
                          Material(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: _saving
                                  ? null
                                  : () {
                                      if (_editing) {
                                        _saveProfile(user);
                                      } else {
                                        _initFields(user);
                                        setState(() => _editing = true);
                                      }
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                child: Text(
                                  _editing
                                      ? (_saving ? 'Saving…' : 'Save')
                                      : 'Edit',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_editing) ...[
                            const SizedBox(width: 6),
                            Material(
                              color: AppColors.surface.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(999),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () {
                                  _initFields(user);
                                  setState(() => _editing = false);
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.close_rounded, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_editing) ...[
                        SoftSurface(
                          radius: 20,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: SoftSurface(
                                radius: 20,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: TextField(
                                  controller: _ageCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Age',
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SoftSurface(
                                radius: 20,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: TextField(
                                  controller: _heightCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Height cm',
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SoftSurface(
                                radius: 20,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: TextField(
                                  controller: _weightCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Weight kg',
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else
                        Row(
                          children: [
                            Expanded(
                              child: _StatChip(
                                label: 'Age',
                                value: '${user.age ?? '—'}',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatChip(
                                label: 'Sex',
                                value: user.sex ?? '—',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatChip(
                                label: 'Height',
                                value: user.heightCm == null
                                    ? '—'
                                    : '${user.heightCm!.round()}',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatChip(
                                label: 'Weight',
                                value: user.weightKg == null
                                    ? '—'
                                    : '${user.weightKg!.round()}',
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                SoftSurface(
                  color: AppColors.mintCard,
                  radius: 28,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medical profile',
                        style: AppText.cardTitle.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 12),
                      _TagSection(title: 'Conditions', items: user.conditions),
                      const SizedBox(height: 10),
                      _TagSection(title: 'Medications', items: user.medications),
                      const SizedBox(height: 10),
                      _TagSection(title: 'Allergies', items: user.allergies),
                      const SizedBox(height: 10),
                      _TagSection(title: 'Surgeries', items: user.surgeries),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                SoftSurface(
                  color: AppColors.creamCard,
                  radius: 28,
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Family history',
                              style: AppText.cardTitle.copyWith(fontSize: 18),
                            ),
                          ),
                          Material(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => _showAddFamilyDialog(user),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_rounded, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Add',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (user.familyHistory.isEmpty)
                        Text(
                          'No family history yet. Adding heart conditions or diabetes helps calibrate drift sensitivities.',
                          style: AppText.bodyMuted,
                        )
                      else
                        for (var i = 0; i < user.familyHistory.length; i++) ...[
                          SoftSurface(
                            radius: 18,
                            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${user.familyHistory[i].relation}: ${user.familyHistory[i].condition}',
                                        style: AppText.body.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (user.familyHistory[i].ageAtOnset !=
                                          null)
                                        Text(
                                          'Onset around age ${user.familyHistory[i].ageAtOnset}',
                                          style: AppText.caption,
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    final uid = ref.read(currentUidProvider);
                                    if (uid == null) return;
                                    final list =
                                        List<FamilyHistoryItem>.from(
                                      user.familyHistory,
                                    )..removeAt(i);
                                    await ref
                                        .read(userRepositoryProvider)
                                        .setUser(
                                          uid,
                                          user.copyWith(familyHistory: list),
                                        );
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (i < user.familyHistory.length - 1)
                            const SizedBox(height: 8),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                SoftSurface(
                  color: AppColors.mintCard,
                  radius: 28,
                  padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
                  onTap: () => context.push(AppRoutes.doctors),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.medical_services_outlined,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My reviews',
                              style: AppText.cardTitle.copyWith(fontSize: 17),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Track doctor replies to your requests',
                              style: AppText.caption,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.inkSoft,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SoftSurface(
                  color: AppColors.skyCard,
                  radius: 28,
                  padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
                  onTap: () => context.push(AppRoutes.devices),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.watch_outlined,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connected devices',
                              style: AppText.cardTitle.copyWith(fontSize: 17),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Health Connect sync status',
                              style: AppText.caption,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.inkSoft,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'VitalWatch provides wellness insights, not medical diagnoses.',
                  style: AppText.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppText.caption.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Text('None', style: AppText.caption)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in items)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item,
                    style: AppText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
