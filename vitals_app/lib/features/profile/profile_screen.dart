import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Baseline;

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/profile.dart';
import '../../providers/providers.dart';
import 'profile_state.dart';

const _historySuggestions = [
  'Asthma',
  'Allergies',
  'High blood pressure',
  'Type 2 diabetes',
  'Thyroid condition',
  'Migraine',
  'Anxiety',
  'Previous surgery',
];

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CenteredBody(
          child: profileAsync.when(
            loading: () => const ListSkeleton(blocks: 3, blockHeight: 140),
            error: (e, _) => FeatureError(
              what: 'your profile',
              onRetry: () => ref.invalidate(profileProvider),
            ),
            data: (profile) => _ProfileBody(profile: profile),
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(medicalHistoryProvider);
    final family = ref.watch(familyTreeProvider);
    final reminders = ref.watch(screeningRemindersProvider);
    final devices = ref.watch(devicesProvider).value;

    final steps = <(String, bool)>[
      ('Basic details', true),
      ('Health goals', profile.goals.isNotEmpty),
      ('Medical history', history.isNotEmpty),
      ('Family history', family.values.any((s) => s.isNotEmpty)),
      ('Connected device', devices?.any((d) => d.connected) ?? false),
      ('Screening reminders', reminders.isNotEmpty),
    ];
    final done = steps.where((s) => s.$2).length;
    final pending = [for (final s in steps) if (!s.$2) s.$1];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Row(
          children: [
            Semantics(
              label: 'Profile ${(done / steps.length * 100).round()} percent complete',
              excludeSemantics: true,
              child: SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: CircularProgressIndicator(
                        value: done / steps.length,
                        strokeWidth: 6,
                        backgroundColor: AppColors.line,
                        color: AppColors.flagGreen,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.lavenderCard,
                      child: Text(profile.initials, style: AppText.sectionTitle),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.name, style: AppText.screenTitle.copyWith(fontSize: 24)),
                  Text(
                    '${profile.age} · ${profile.sex.label} · ${profile.occupation}',
                    style: AppText.bodyMuted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Profile ${(done / steps.length * 100).round()}% complete',
                    style: AppText.label,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Still to add: ${pending.join(', ')}', style: AppText.caption),
        ],
        const SizedBox(height: 24),
        const SectionHeader(title: 'Medical history'),
        const SizedBox(height: 4),
        Text(
          'Things you tell us about yourself. Only you can edit this.',
          style: AppText.bodyMuted,
        ),
        const SizedBox(height: 12),
        _HistoryChips(history: history),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Family history'),
        const SizedBox(height: 4),
        Text(
          'Tap a relative to add conditions that run in your family. It can '
          'make pattern checks a little more sensitive.',
          style: AppText.bodyMuted,
        ),
        const SizedBox(height: 12),
        _FamilyTree(profile: profile),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Screening reminders'),
        const SizedBox(height: 4),
        Text(
          'Gentle nudges. Ask a clinician what schedule suits you.',
          style: AppText.bodyMuted,
        ),
        const SizedBox(height: 12),
        SoftSurface(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              for (var i = 0; i < screeningReminders.length; i++) ...[
                if (i > 0) const Divider(),
                SwitchListTile(
                  title: Text(screeningReminders[i].title),
                  subtitle: Text(
                    screeningReminders[i].subtitle,
                    style: AppText.caption,
                  ),
                  value: reminders.contains(screeningReminders[i].id),
                  onChanged: (v) => ref
                      .read(screeningRemindersProvider.notifier)
                      .set(screeningReminders[i].id, on: v),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'More'),
        const SizedBox(height: 12),
        SoftSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _LinkTile(Icons.description_outlined, 'Reports', 'Doctor summary and weekly report', AppRoutes.reports),
              const Divider(),
              _LinkTile(Icons.medical_services_outlined, 'Doctor reviews', 'Sample reviews of your patterns', AppRoutes.doctors),
              const Divider(),
              _LinkTile(Icons.edit_note_rounded, 'Symptoms & check-in', 'Journal and daily check-in', AppRoutes.symptoms),
              const Divider(),
              _LinkTile(Icons.watch_rounded, 'Devices', 'Connections and data quality', AppRoutes.devices),
              const Divider(),
              _LinkTile(Icons.settings_rounded, 'Settings', 'Preferences, privacy and demo tools', AppRoutes.settings),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const DisclaimerBanner(),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile(this.icon, this.title, this.subtitle, this.route);

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: AppText.cardTitle),
      subtitle: Text(subtitle, style: AppText.caption),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      onTap: () => context.push(route),
    );
  }
}

class _HistoryChips extends ConsumerWidget {
  const _HistoryChips({required this.history});

  final List<String> history;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final item = await showFormSheet<String>(
      context,
      builder: (_) => _AddHistorySheet(existing: history),
    );
    if (item != null) ref.read(medicalHistoryProvider.notifier).add(item);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in history)
          InputChip(
            label: Text(item),
            onDeleted: () =>
                ref.read(medicalHistoryProvider.notifier).remove(item),
            deleteButtonTooltipMessage: 'Remove $item',
          ),
        ActionChip(
          avatar: const Icon(Icons.add_rounded, size: 18),
          label: Text(history.isEmpty ? 'Add medical history' : 'Add'),
          onPressed: () => _add(context, ref),
        ),
      ],
    );
  }
}

class _AddHistorySheet extends StatefulWidget {
  const _AddHistorySheet({required this.existing});

  final List<String> existing;

  @override
  State<_AddHistorySheet> createState() => _AddHistorySheetState();
}

class _AddHistorySheetState extends State<_AddHistorySheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      for (final s in _historySuggestions)
        if (!widget.existing.contains(s)) s,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Add medical history', style: AppText.sectionTitle),
        const SizedBox(height: 12),
        if (options.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in options)
                AppChip(
                  label: s,
                  selected: false,
                  onTap: () => Navigator.of(context).pop(s),
                ),
            ],
          ),
        const FieldLabel('Something else?'),
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.of(context).pop(v.trim());
          },
          decoration: const InputDecoration(hintText: 'Type it here'),
        ),
        const SizedBox(height: 16),
        PillButton(
          label: 'Add',
          onPressed: () {
            final v = _controller.text.trim();
            if (v.isEmpty) {
              showSnack(context, 'Pick one above or type your own.');
              return;
            }
            Navigator.of(context).pop(v);
          },
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ family tree

class _FamilyTree extends ConsumerWidget {
  const _FamilyTree({required this.profile});

  final Profile profile;

  Future<void> _edit(BuildContext context, WidgetRef ref, Relative r) async {
    final current = ref.read(familyTreeProvider)[r] ?? <String>{};
    final result = await showFormSheet<Set<String>>(
      context,
      builder: (_) => _EditRelativeSheet(relative: r, initial: current),
    );
    if (result == null) return;
    final notifier = ref.read(familyTreeProvider.notifier);
    notifier.set(r, result);

    // Keep the stored profile in step so pattern checks use it.
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            profile.copyWith(familyHistoryTags: notifier.allTags.toList()),
          );
      ref
        ..invalidate(profileProvider)
        ..invalidate(flagsProvider)
        ..invalidate(flagProvider)
        ..invalidate(homeSnapshotProvider);
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'Saved here, but we could not update your profile.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(familyTreeProvider);

    Widget node(Relative r) => _TreeNode(
      title: r.label,
      tags: tree[r] ?? const {},
      onTap: () => _edit(context, ref, r),
    );

    return SoftSurface(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: node(Relative.maternalGrandparents)),
              const SizedBox(width: 10),
              Expanded(child: node(Relative.paternalGrandparents)),
            ],
          ),
          const _Connector(parentsJoin: false),
          Row(
            children: [
              Expanded(child: node(Relative.mother)),
              const SizedBox(width: 10),
              Expanded(child: node(Relative.father)),
            ],
          ),
          const _Connector(parentsJoin: true),
          Row(
            children: [
              Expanded(
                child: _TreeNode(
                  title: 'You',
                  tags: const {},
                  highlighted: true,
                  subtitle: profile.firstName,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: node(Relative.siblings)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.parentsJoin});

  final bool parentsJoin;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      width: double.infinity,
      child: CustomPaint(painter: _ConnectorPainter(parentsJoin)),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter(this.join);

  final bool join;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.muted.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    final left = size.width * 0.25 - 5;
    final right = size.width * 0.75 + 5;
    final mid = size.height / 2;
    if (!join) {
      canvas.drawLine(Offset(left, 0), Offset(left, size.height), paint);
      canvas.drawLine(Offset(right, 0), Offset(right, size.height), paint);
    } else {
      canvas.drawLine(Offset(left, 0), Offset(left, mid), paint);
      canvas.drawLine(Offset(right, 0), Offset(right, mid), paint);
      canvas.drawLine(Offset(left, mid), Offset(right, mid), paint);
      canvas.drawLine(Offset(left, mid), Offset(left, size.height), paint);
      canvas.drawLine(Offset(right, mid), Offset(right, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) =>
      oldDelegate.join != join;
}

class _TreeNode extends StatelessWidget {
  const _TreeNode({
    required this.title,
    required this.tags,
    this.onTap,
    this.highlighted = false,
    this.subtitle,
  });

  final String title;
  final Set<String> tags;
  final VoidCallback? onTap;
  final bool highlighted;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? AppColors.surface : AppColors.ink;
    return Semantics(
      button: onTap != null,
      label: onTap == null
          ? title
          : '$title. ${tags.isEmpty ? 'No conditions added' : tags.map((t) => familyConditions[t] ?? t).join(', ')}. Tap to edit.',
      excludeSemantics: true,
      child: Material(
        color: highlighted ? AppColors.ink : AppColors.canvas,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppText.label.copyWith(color: fg),
                        ),
                      ),
                      if (onTap != null)
                        const Icon(Icons.edit_outlined, size: 14, color: AppColors.muted),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (subtitle != null)
                    Text(subtitle!, style: AppText.caption.copyWith(color: fg))
                  else if (tags.isEmpty)
                    Text('Tap to add', style: AppText.caption)
                  else
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final t in tags)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.lavenderCard,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              familyConditions[t] ?? t,
                              style: AppText.caption.copyWith(
                                color: AppColors.ink,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditRelativeSheet extends StatefulWidget {
  const _EditRelativeSheet({required this.relative, required this.initial});

  final Relative relative;
  final Set<String> initial;

  @override
  State<_EditRelativeSheet> createState() => _EditRelativeSheetState();
}

class _EditRelativeSheetState extends State<_EditRelativeSheet> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.relative.label, style: AppText.sectionTitle),
        const SizedBox(height: 4),
        Text(
          'Which of these run on this side of the family?',
          style: AppText.bodyMuted,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in familyConditions.entries)
              AppChip(
                label: e.value,
                selected: _selected.contains(e.key),
                icon: _selected.contains(e.key) ? Icons.check_rounded : null,
                onTap: () => setState(() {
                  if (!_selected.remove(e.key)) _selected.add(e.key);
                }),
              ),
          ],
        ),
        const SizedBox(height: 20),
        PillButton(
          label: 'Save',
          onPressed: () => Navigator.of(context).pop(_selected),
        ),
        const SizedBox(height: 8),
        PillButton(
          label: 'Clear',
          variant: PillButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(<String>{}),
        ),
      ],
    );
  }
}
