import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/option_sheet.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/flag.dart';
import '../../providers/providers.dart';
import 'flag_tile.dart';

/// All flags, grouped by status, with status/domain filters and search.
class FlagsScreen extends ConsumerStatefulWidget {
  const FlagsScreen({super.key});

  @override
  ConsumerState<FlagsScreen> createState() => _FlagsScreenState();
}

class _FlagsScreenState extends ConsumerState<FlagsScreen> {
  final _searchController = TextEditingController();
  FlagStatus? _status;
  HealthDomain? _domain;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(flagsProvider);
    try {
      await ref.read(flagsProvider.future);
    } catch (_) {
      // The error state is rendered from the provider itself.
    }
  }

  Future<void> _pickDomain() async {
    const all = 'all';
    final result = await showOptionSheet<Object>(
      context,
      title: 'Filter by area',
      selected: _domain ?? all,
      options: [
        const SheetOption<Object>(all, 'All areas'),
        for (final d in HealthDomain.values)
          SheetOption<Object>(d, d.label, icon: d.icon),
      ],
    );
    // `null` means the sheet was dismissed without a choice.
    if (!mounted || result == null) return;
    setState(() => _domain = result is HealthDomain ? result : null);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _status = null;
      _domain = null;
      _query = '';
    });
  }

  List<Flag> _applyFilters(List<Flag> all) {
    final q = _query.trim().toLowerCase();
    return all.where((f) {
      if (_status != null && f.status != _status) return false;
      if (_domain != null && f.domain != _domain) return false;
      if (q.isEmpty) return true;
      return f.title.toLowerCase().contains(q) ||
          f.summary.toLowerCase().contains(q) ||
          f.metric.label.toLowerCase().contains(q) ||
          f.domain.label.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final flagsAsync = ref.watch(flagsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: flagsAsync.when(
              loading: () => const _FlagsSkeleton(),
              error: (error, _) => ErrorState(
                message: 'We could not load your flags. Check your connection and try again.',
                onRetry: () => ref.invalidate(flagsProvider),
              ),
              data: _buildData,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildData(List<Flag> all) {
    final filtered = _applyFilters(all);
    final counts = <FlagStatus, int>{
      for (final s in FlagStatus.values)
        s: all.where((f) => f.status == s).length,
    };
    final hasFilters = _status != null || _domain != null || _query.isNotEmpty;

    final groups = <FlagStatus>[
      FlagStatus.red,
      FlagStatus.amber,
      FlagStatus.green,
    ];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text('Flags', style: AppText.screenTitle),
          const SizedBox(height: 4),
          Text(
            all.isEmpty
                ? 'Patterns in your data will appear here.'
                : '${counts[FlagStatus.red]! + counts[FlagStatus.amber]!} to keep an eye on · ${counts[FlagStatus.green]} in your usual range',
            style: AppText.bodyMuted,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search flags',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusChip(
                  label: 'All ${all.length}',
                  selected: _status == null,
                  onTap: () => setState(() => _status = null),
                ),
                const SizedBox(width: 8),
                for (final s in [
                  FlagStatus.red,
                  FlagStatus.amber,
                  FlagStatus.green,
                ]) ...[
                  _StatusChip(
                    label: '${_shortLabel(s)} ${counts[s]}',
                    selected: _status == s,
                    dotColor: s.color,
                    onTap: () => setState(() => _status = s),
                  ),
                  const SizedBox(width: 8),
                ],
                PillDropdown(
                  label: _domain?.label ?? 'All areas',
                  onTap: _pickDomain,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (all.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: EmptyState(
                title: 'No flags yet',
                message:
                    'Once your wearable has a few days of data, patterns that '
                    'differ from your usual range will show up here.',
                icon: Icons.flag_outlined,
              ),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: EmptyState(
                title: 'No flags match',
                message: hasFilters
                    ? 'Try a different filter or search term.'
                    : 'Nothing to show right now.',
                icon: Icons.filter_alt_off_rounded,
                actionLabel: hasFilters ? 'Clear filters' : null,
                onAction: hasFilters ? _clearFilters : null,
              ),
            )
          else
            for (final status in groups) ..._buildGroup(status, filtered),
        ],
      ),
    );
  }

  List<Widget> _buildGroup(FlagStatus status, List<Flag> filtered) {
    final items = filtered.where((f) => f.status == status).toList()
      ..sort((a, b) {
        final bySeverity = b.severity.index.compareTo(a.severity.index);
        if (bySeverity != 0) return bySeverity;
        return b.streakDays.compareTo(a.streakDays);
      });
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Row(
          children: [
            Icon(status.icon, size: 18, color: status.color),
            const SizedBox(width: 8),
            Text('${status.label} · ${items.length}', style: AppText.cardTitle),
          ],
        ),
      ),
      for (final flag in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FlagTile(flag: flag),
        ),
      const SizedBox(height: 8),
    ];
  }

  static String _shortLabel(FlagStatus s) => switch (s) {
    FlagStatus.red => 'Red',
    FlagStatus.amber => 'Amber',
    FlagStatus.green => 'Green',
  };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dotColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label filter',
      child: Material(
        color: selected ? AppColors.ink : AppColors.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? AppColors.ink : AppColors.line),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: AppText.caption.copyWith(
                    color: selected ? AppColors.surface : AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlagsSkeleton extends StatelessWidget {
  const _FlagsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: const [
        ShimmerLikeSkeleton(height: 32, width: 120),
        SizedBox(height: 16),
        ShimmerLikeSkeleton(height: 52, radius: 16),
        SizedBox(height: 12),
        ShimmerLikeSkeleton(height: 40, radius: 20),
        SizedBox(height: 24),
        ShimmerLikeSkeleton(height: 120, radius: 24),
        SizedBox(height: 12),
        ShimmerLikeSkeleton(height: 120, radius: 24),
        SizedBox(height: 12),
        ShimmerLikeSkeleton(height: 120, radius: 24),
      ],
    );
  }
}
