import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../../data/mock/flag_engine.dart';
import '../../domain/models/baseline.dart';
import '../../domain/models/daily_reading.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/flag.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/home_snapshot.dart';
import '../../domain/models/rule.dart';
import '../../domain/models/win_item.dart';
import '../../domain/repositories/alerts_repository.dart';
import '../../domain/repositories/flags_repository.dart';
import '../../domain/repositories/habits_repository.dart';
import '../../domain/repositories/health_data_repository.dart';
import '../../domain/repositories/profile_repository.dart';

/// A real [HealthDataRepository] backed by Google Health Connect (Android).
class HealthConnectRepository implements HealthDataRepository {
  HealthConnectRepository({
    required this.loadRules,
    required this.profileRepository,
    this.habitsRepository,
    this.alertsRepository,
  }) : _health = Health();

  final Future<List<Rule>> Function() loadRules;
  final ProfileRepository profileRepository;
  final HabitsRepository? habitsRepository;
  final AlertsRepository? alertsRepository;
  final Health _health;
  final FlagEngine _flagEngine = const FlagEngine();

  bool _isConfigured = false;
  DateTime _lastSyncedAt = DateTime.now();

  // ── Types & Permissions ───────────────────────────────────────────────────

  /// ONLY types that are natively supported by Google Health Connect on Android.
  static const List<HealthDataType> _types = [
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.STEPS,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BODY_TEMPERATURE,
  ];

  static final List<HealthDataAccess> _permissions =
      List.filled(_types.length, HealthDataAccess.READ);

  Future<void> _ensureConfigured() async {
    if (!_isConfigured) {
      await _health.configure();
      _isConfigured = true;
    }
  }

  // ── Authorisation ─────────────────────────────────────────────────────────

  /// Request read-only access from Health Connect.
  Future<bool> requestAuthorization() async {
    _assertAndroid();
    await _ensureConfigured();

    final status = await _health.getHealthConnectSdkStatus();
    debugPrint('[HealthConnectRepository] SDK status: $status');

    if (status != HealthConnectSdkStatus.sdkAvailable) {
      if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        await _health.installHealthConnect();
        throw Exception(
          'Health Connect needs to be updated. Opening Google Play Store...',
        );
      } else {
        await _health.installHealthConnect();
        throw Exception(
          'Health Connect is not installed or unavailable. Opening Google Play Store...',
        );
      }
    }

    final granted = await _health.requestAuthorization(
      _types,
      permissions: _permissions,
    );
    debugPrint('[HealthConnectRepository] requestAuthorization result: $granted');
    return granted;
  }

  /// Check whether we already hold all permissions (no dialog shown).
  Future<bool> hasAuthorization() async {
    if (!Platform.isAndroid) return false;
    try {
      await _ensureConfigured();
      final result = await _health.hasPermissions(
        _types,
        permissions: _permissions,
      );
      return result ?? false;
    } catch (e) {
      debugPrint('[HealthConnectRepository] hasAuthorization error: $e');
      return false;
    }
  }

  // ── HealthDataRepository ──────────────────────────────────────────────────

  @override
  Future<List<DailyReading>> getReadings({
    ChartRange range = ChartRange.all,
  }) async {
    _assertAndroid();
    await _ensureConfigured();

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: range.days));
    final end = now;

    final raw = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: start,
      endTime: end,
    );

    return _aggregate(_health.removeDuplicates(raw), start, end);
  }

  @override
  Future<DailyReading?> getLatestReading() async {
    final readings = await getReadings(range: ChartRange.oneWeek);
    for (final r in readings.reversed) {
      if (!r.isGap) return r;
    }
    return null;
  }

  @override
  Future<Baseline> getBaseline(VitalMetric metric) async {
    final readings = await getReadings(range: ChartRange.all);
    final baseline = _flagEngine.computeBaseline(readings, metric);
    if (baseline.hasData) return baseline;

    // Fallback if the user has fewer than 60 days of historical data:
    final values = [
      for (final r in readings)
        if (r.valueOf(metric) != null) r.valueOf(metric)!,
    ];
    if (values.length < 3) {
      return Baseline.insufficient(metric);
    }

    final mean = values.reduce((a, b) => a + b) / values.length;
    var sqSum = 0.0;
    for (final v in values) {
      sqSum += (v - mean) * (v - mean);
    }
    final stdDev = math.sqrt(sqSum / (values.length - 1));
    const sigma = 2.0;
    final low = mean - sigma * stdDev;
    final high = mean + sigma * stdDev;

    final series = [
      for (final r in readings)
        if (r.valueOf(metric) != null)
          BaselinePoint(
            date: r.date,
            mean: mean,
            stdDev: stdDev,
            low: low,
            high: high,
          ),
    ];

    return Baseline(
      metric: metric,
      mean: mean,
      stdDev: stdDev,
      low: low,
      high: high,
      sampleCount: values.length,
      sigma: sigma,
      series: series,
    );
  }

  @override
  Future<HomeSnapshot> getHomeSnapshot() async {
    _assertAndroid();
    await _ensureConfigured();

    final readings = await getReadings(range: ChartRange.all);
    final rules = await loadRules();
    final profile = await profileRepository.getProfile();
    final alerts = await alertsRepository?.getAlerts() ?? const [];
    final habits = await habitsRepository?.getHabits() ?? const [];

    final allFlags = _flagEngine.evaluateAll(
      readings,
      rules,
      hereditaryTags: profile.familyHistoryTags.toSet(),
      now: DateTime.now(),
    );

    final reds = allFlags.where((f) => f.status == FlagStatus.red).length;
    final ambers = allFlags.where((f) => f.status == FlagStatus.amber).length;

    FlagStatus overall = FlagStatus.green;
    String headline = 'Your vitals look steady';
    String sub = 'Everything is within your own usual range right now.';
    if (reds > 0) {
      overall = FlagStatus.red;
      headline = reds == 1
          ? 'One pattern needs your attention'
          : '$reds patterns need your attention';
      sub = ambers > 0
          ? 'Plus $ambers more worth watching. These compare recent days with your own usual range.'
          : 'This compares recent days with your own usual range.';
    } else if (ambers > 0) {
      overall = FlagStatus.amber;
      headline = ambers == 1
          ? 'One thing is worth watching'
          : '$ambers things are worth watching';
      sub = 'These compare recent days with your own usual range.';
    }

    final domainStatuses = <HealthDomain, FlagStatus>{
      for (final domain in HealthDomain.values) domain: FlagStatus.green,
    };
    for (final flag in allFlags) {
      final current = domainStatuses[flag.domain]!;
      if (flag.status.index > current.index) {
        domainStatuses[flag.domain] = flag.status;
      }
    }

    final recentStart = math.max(0, readings.length - 30);
    final recentReadings = readings.sublist(recentStart);
    final latest = await getLatestReading();
    const heroMetric = VitalMetric.restingHr;
    final heroBase = await getBaseline(heroMetric);

    final wins = _buildWins(allFlags, readings, habits);

    return HomeSnapshot(
      profile: profile,
      overallStatus: overall,
      headline: headline,
      subheadline: sub,
      flags: allFlags,
      domainStatuses: domainStatuses,
      latestReading: latest,
      recentReadings: recentReadings,
      heroMetric: heroMetric,
      heroBaseline: heroBase,
      wins: wins,
      unreadAlertCount: alerts.where((a) => !a.isRead).length,
      lastSyncedAt: _lastSyncedAt,
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<DateTime> syncNow() async {
    _lastSyncedAt = DateTime.now();
    return _lastSyncedAt;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _assertAndroid() {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'HealthConnectRepository is only supported on Android.',
      );
    }
  }

  List<WinItem> _buildWins(
    List<Flag> allFlags,
    List<DailyReading> readings,
    List<Habit> habits,
  ) {
    final now = DateTime.now();
    final improvements = <WinItem>[];
    final steady = <WinItem>[];
    final habitWins = <WinItem>[];
    final recent = readings.length >= 14
        ? readings.sublist(readings.length - 14)
        : readings;

    for (final flag in allFlags) {
      if (flag.status != FlagStatus.green) continue;
      final metric = flag.metric;
      final base = _flagEngine.computeBaseline(readings, metric);
      if (!base.hasData) continue;
      final values = [
        for (final r in recent)
          if (r.valueOf(metric) != null) r.valueOf(metric)!,
      ];
      if (values.length < 7) continue;
      final mean = values.reduce((a, b) => a + b) / values.length;
      final gain = metric.higherIsBetter ? mean - base.mean : base.mean - mean;
      if (gain > 0.75 * base.stdDev) {
        improvements.add(
          WinItem(
            id: 'win_better_${metric.name}',
            title: '${metric.label} is trending better',
            description:
                'The last two weeks sit on the healthier side of your usual range.',
            domain: metric.domain,
            achievedOn: now,
          ),
        );
      } else if (values.every((v) => base.contains(v))) {
        steady.add(
          WinItem(
            id: 'win_steady_${metric.name}',
            title: '${metric.label} is steady',
            description: 'Within your usual range for the past two weeks.',
            domain: metric.domain,
            achievedOn: now,
          ),
        );
      }
    }

    for (final habit in habits) {
      final streak = habit.currentStreak(now: now);
      if (streak >= 3) {
        habitWins.add(
          WinItem(
            id: 'win_habit_${habit.id}',
            title: '$streak-day streak',
            description: habit.title,
            domain: habit.domain,
            achievedOn: now,
          ),
        );
      }
    }
    habitWins.sort((a, b) => b.title.compareTo(a.title));

    var tracked = 0;
    for (var i = readings.length - 1; i >= 0 && !readings[i].isGap; i--) {
      tracked++;
    }
    final tracking = tracked >= 5
        ? [
            WinItem(
              id: 'win_tracking',
              title: '$tracked days of data in a row',
              description: 'Steady wear makes your usual range more reliable.',
              domain: HealthDomain.heart,
              achievedOn: now,
            ),
          ]
        : <WinItem>[];

    return [...improvements, ...habitWins, ...steady, ...tracking].take(4).toList();
  }

  List<DailyReading> _aggregate(
    List<HealthDataPoint> points,
    DateTime start,
    DateTime end,
  ) {
    final byDay = SplayTreeMap<DateTime, Map<VitalMetric, List<double>>>();

    for (final p in points) {
      final day = DateTime(
        p.dateFrom.year,
        p.dateFrom.month,
        p.dateFrom.day,
      );
      byDay.putIfAbsent(day, () => {});

      final metric = _typeToMetric(p.type);
      if (metric == null) continue;

      final num? rawValue = switch (p.value) {
        final NumericHealthValue v => v.numericValue,
        _ => null,
      };
      if (rawValue == null) continue;

      byDay[day]!.putIfAbsent(metric, () => []).add(rawValue.toDouble());
    }

    final readings = <DailyReading>[];
    var cursor = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);

    while (!cursor.isAfter(endDay)) {
      final dayData = byDay[cursor];
      if (dayData == null) {
        readings.add(DailyReading.gap(cursor));
      } else {
        final values = <VitalMetric, double>{};
        for (final entry in dayData.entries) {
          values[entry.key] = _aggregate1(entry.key, entry.value);
        }
        readings.add(DailyReading.fromValues(cursor, values));
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return readings;
  }

  double _aggregate1(VitalMetric metric, List<double> values) {
    if (values.isEmpty) return 0;
    if (metric == VitalMetric.steps) {
      return values.reduce((a, b) => a + b);
    }
    if (metric == VitalMetric.sleepDuration || metric == VitalMetric.deepSleep) {
      final totalMinutes = values.reduce((a, b) => a + b);
      return totalMinutes / 60.0;
    }
    return values.reduce((a, b) => a + b) / values.length;
  }

  VitalMetric? _typeToMetric(HealthDataType type) {
    return switch (type) {
      HealthDataType.RESTING_HEART_RATE => VitalMetric.restingHr,
      HealthDataType.HEART_RATE_VARIABILITY_RMSSD => VitalMetric.hrv,
      HealthDataType.SLEEP_ASLEEP => VitalMetric.sleepDuration,
      HealthDataType.SLEEP_DEEP => VitalMetric.deepSleep,
      HealthDataType.STEPS => VitalMetric.steps,
      HealthDataType.RESPIRATORY_RATE => VitalMetric.respiratoryRate,
      HealthDataType.BLOOD_OXYGEN => VitalMetric.spo2,
      HealthDataType.BODY_TEMPERATURE => VitalMetric.skinTemp,
      _ => null,
    };
  }
}

/// A [FlagsRepository] implementation that evaluates the clinical/trend rules
/// against real Health Connect data.
class HealthConnectFlagsRepository implements FlagsRepository {
  HealthConnectFlagsRepository({
    required this.healthRepo,
    required this.loadRules,
    required this.profileRepo,
  });

  final HealthConnectRepository healthRepo;
  final Future<List<Rule>> Function() loadRules;
  final ProfileRepository profileRepo;
  final FlagEngine _flagEngine = const FlagEngine();
  final Set<String> _acknowledged = {};

  @override
  Future<List<Flag>> getFlags() async {
    final readings = await healthRepo.getReadings(range: ChartRange.all);
    final rules = await loadRules();
    final profile = await profileRepo.getProfile();
    final flags = _flagEngine.evaluateAll(
      readings,
      rules,
      hereditaryTags: profile.familyHistoryTags.toSet(),
      now: DateTime.now(),
    );
    return [
      for (final f in flags)
        f.copyWith(acknowledged: _acknowledged.contains(f.id)),
    ];
  }

  @override
  Future<Flag?> getFlag(String id) async {
    final flags = await getFlags();
    for (final f in flags) {
      if (f.id == id) return f;
    }
    return null;
  }

  @override
  Future<Flag> acknowledgeFlag(String id) async {
    _acknowledged.add(id);
    final flag = await getFlag(id);
    if (flag != null) return flag;
    throw ArgumentError('Flag $id not found');
  }

  @override
  Future<List<Rule>> getRules() => loadRules();

  @override
  Future<Rule?> getRule(String id) async {
    final rules = await loadRules();
    for (final r in rules) {
      if (r.id == id) return r;
    }
    return null;
  }
}
