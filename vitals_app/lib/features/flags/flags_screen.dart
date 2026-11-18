import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/metric_labels.dart';
import '../../core/widgets/ink_app_bar.dart';
import '../../core/widgets/option_sheet.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/flag_repository.dart';
import '../../domain/models/enums.dart';
import '../../providers/chart_providers.dart';
import '../../providers/data_providers.dart';
import 'flag_tile.dart';

/// All health flags with status/metric filters and search.
class FlagsScreen extends ConsumerStatefulWidget {
  const FlagsScreen({super.key});

  @override
  ConsumerState<FlagsScreen> createState() => _FlagsScreenState();
}

class _FlagsScreenState extends ConsumerState<FlagsScreen> {
  final _searchController = TextEditingController();
  FlagStatus? _status;
  String? _metric;
  String _query = '';

  static const _metrics = [
    'restingHr',
    'hrv',
    'sleepDeep',
    'spo2',
    'steps',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickMetric() async {
    const all = 'all';
    final result = await showOptionSheet<Object>(
      context,
      title: 'Filter by metric',
      selected: _metric ?? all,
      options: [
        const SheetOption<Object>(all, 'All metrics'),
        for (final m in _metrics)
          SheetOption<Object>(
            m,
            MetricLabels.label(m),
            icon: MetricLabels.icon(m),
          ),
      ],
    );
    if (!mounted || result == null) return;
    setState(() => _metric = result is String && result != all ? result : null);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _status = null;
      _metric = null;
      _query = '';
    });
  }

  List<FlagModel> _applyFilters(List<FlagModel> all) {
    final q = _query.trim().toLowerCase();
    return all.where((f) {
      if (_status != null &&
          MetricLabels.statusFromLevel(f.level) != _status) {
        return false;
      }
      if (_metric != null && f.metric != _metric) return false;
      if (q.isEmpty) return true;
      return f.title.toLowerCase().contains(q) ||
          f.explanation.toLowerCase().contains(q) ||
          MetricLabels.label(f.metric).toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final flagsAsync = ref.watch(flagsProvider);
    final seriesMap = ref.watch(homeMetricSeriesProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        title: 'Health Flags',
        subtitle: 'From your personal baseline',
      ),
      body: flagsAsync.when(
        loading: () => const _FlagsSkeleton(),
        error: (error, _) => ErrorState(
          message:
              'We could not load your flags. Check your connection and try again.',
          onRetry: () => ref.invalidate(flagsProvider),
        ),
        data: (all) => _buildData(all, seriesMap),
      ),
    );
  }

  Widget _buildData(
    List<FlagModel> all,
    Map<String, MetricSeries> seriesMap,
  ) {
    final filtered = _applyFilters(all);
    final hasFilters =
        _status != null || _metric != null || _query.trim().isNotEmpty;

    if (all.isEmpty) {
      return const EmptyState(
        icon: Icons.watch_outlined,
        title: 'No health flags yet',
        message: 'Connect your watch to start building your baseline',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(flagsProvider);
        await ref.read(flagsProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          SoftSurface(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search flags',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in FlagStatus.values) ...[
                  _FilterPill(
                    label: s.label,
                    selected: _status == s,
                    selectedColor: s.color,
                    selectedBg: s.background,
                    onTap: () => setState(
                      () => _status = _status == s ? null : s,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _FilterPill(
                  label: _metric == null
                      ? 'Metric'
                      : MetricLabels.label(_metric!),
                  selected: _metric != null,
                  icon: Icons.tune_rounded,
                  onTap: _pickMetric,
                ),
                if (hasFilters) ...[
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'Clear',
                    selected: false,
                    onTap: _clearFilters,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: EmptyState(
                icon: Icons.filter_alt_off_rounded,
                title: 'No matches',
                message: 'Try clearing filters or search.',
              ),
            )
          else
            for (final f in filtered) ...[
              FlagTile(flag: f, spark: seriesMap[f.metric]),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 8),
          Text(
            'VitalWatch provides wellness insights, not medical diagnoses.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.selectedColor,
    this.selectedBg,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? selectedColor;
  final Color? selectedBg;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (selectedBg ?? AppColors.ink)
        : AppColors.surface;
    final fg = selected
        ? (selectedColor ?? Colors.white)
        : AppColors.inkSoft;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
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
      padding: const EdgeInsets.all(20),
      children: const [
        SizedBox(height: 12),
        ListSkeleton(blocks: 4),
      ],
    );
  }
}
