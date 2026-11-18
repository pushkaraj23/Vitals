import 'baseline.dart';
import 'daily_reading.dart';
import 'enums.dart';
import 'flag.dart';
import 'profile.dart';
import 'win_item.dart';

/// Everything the Home screen needs in one object.
class HomeSnapshot {
  const HomeSnapshot({
    required this.profile,
    required this.overallStatus,
    required this.headline,
    required this.subheadline,
    required this.flags,
    required this.domainStatuses,
    required this.latestReading,
    required this.recentReadings,
    required this.heroMetric,
    required this.heroBaseline,
    required this.wins,
    required this.unreadAlertCount,
    required this.lastSyncedAt,
    required this.generatedAt,
  });

  final Profile profile;
  final FlagStatus overallStatus;
  final String headline;
  final String subheadline;

  /// All evaluated flags (including green ones), worst first.
  final List<Flag> flags;
  final Map<HealthDomain, FlagStatus> domainStatuses;
  final DailyReading? latestReading;

  /// Last ~30 days, oldest first.
  final List<DailyReading> recentReadings;
  final VitalMetric heroMetric;
  final Baseline heroBaseline;
  final List<WinItem> wins;
  final int unreadAlertCount;
  final DateTime lastSyncedAt;
  final DateTime generatedAt;

  /// Flags that are amber or red.
  List<Flag> get activeFlags => flags.where((f) => f.isActive).toList();
}
