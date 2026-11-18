import 'dart:math' as math;

import '../../core/utils/date_utils.dart';
import '../../domain/models/alert.dart';
import '../../domain/models/baseline.dart';
import '../../domain/models/daily_reading.dart';
import '../../domain/models/doctor_review.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/flag.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/home_snapshot.dart';
import '../../domain/models/life_event.dart';
import '../../domain/models/profile.dart';
import '../../domain/models/rule.dart';
import '../../domain/models/symptom.dart';
import '../../domain/models/win_item.dart';
import 'flag_engine.dart';
import 'mock_data_generator.dart';
import 'personas.dart';

/// All mutable sample data for one persona. Regenerated when the persona
/// changes. Repositories read and write through this object.
class MockStore {
  MockStore._({
    required this.persona,
    required this.now,
    required this.rules,
    required this.readings,
    required this.engine,
    required this.profile,
    required this.lifeEvents,
    required this.symptoms,
    required this.habits,
    required this.reviews,
    required this.lastSyncedAt,
  }) {
    _recomputeFlags();
    alerts = _buildAlerts();
  }

  /// Builds a fully populated store. Deterministic for a given [now].
  factory MockStore.create({
    required Persona persona,
    required List<Rule> rules,
    DateTime? now,
    MockDataGenerator generator = const MockDataGenerator(),
    FlagEngine engine = const FlagEngine(),
  }) {
    final today = AppDateUtils.dateOnly(now ?? DateTime.now());
    final readings = generator.generate(persona, end: today);
    final rng = math.Random(persona.seed + 7);

    DateTime ago(int days) =>
        DateTime(today.year, today.month, today.day - days);

    final lifeEvents = [
      for (final spec in persona.lifeEvents)
        LifeEvent(
          id: spec.id,
          type: spec.type,
          title: spec.title,
          startDate: ago(spec.startDaysAgo),
          endDate: _lifeEventEnd(spec, ago),
          note: spec.note,
        ),
    ]..sort((a, b) => b.startDate.compareTo(a.startDate));

    final symptoms = [
      for (final spec in persona.symptoms)
        Symptom(
          id: spec.id,
          label: spec.label,
          date: ago(spec.daysAgo),
          severity: spec.severity,
          note: spec.note,
          linkedFlagId:
              spec.linkedRuleId == null ? null : 'flag_${spec.linkedRuleId}',
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    final habits = [
      for (final spec in persona.habits)
        Habit(
          id: spec.id,
          title: spec.title,
          subtitle: spec.subtitle,
          domain: spec.domain,
          targetDaysPerWeek: spec.targetDaysPerWeek,
          linkedRuleId: spec.linkedRuleId,
          completedDates: [
            for (var d = 60; d >= 1; d--)
              if (d <= spec.recentStreak
                  ? true
                  : (d == spec.recentStreak + 1
                        ? false
                        : rng.nextDouble() < spec.completionRate))
                ago(d),
          ],
        ),
    ];

    final reviews = [
      for (final spec in persona.reviews)
        DoctorReview(
          id: 'review_${spec.ruleId}',
          flagId: 'flag_${spec.ruleId}',
          doctorName: 'Dr. Ananya Mehta',
          credentials: 'General physician (sample reviewer)',
          verdict: spec.verdict,
          requestedAt: ago(spec.requestedDaysAgo),
          reviewedAt:
              spec.reviewedDaysAgo == null ? null : ago(spec.reviewedDaysAgo!),
          note: spec.note,
        ),
    ];

    return MockStore._(
      persona: persona,
      now: today,
      rules: rules,
      readings: readings,
      engine: engine,
      profile: persona.profile,
      lifeEvents: lifeEvents,
      symptoms: symptoms,
      habits: habits,
      reviews: reviews,
      lastSyncedAt: DateTime(today.year, today.month, today.day, 7, 45),
    );
  }

  static DateTime? _lifeEventEnd(LifeEventSpec spec, DateTime Function(int) ago) {
    final duration = spec.durationDays;
    if (duration == null) return null;
    return ago(spec.startDaysAgo - duration + 1);
  }

  final Persona persona;

  /// "Today" (date-only) for this dataset.
  final DateTime now;
  final List<Rule> rules;
  final List<DailyReading> readings;
  final FlagEngine engine;

  Profile profile;
  List<LifeEvent> lifeEvents;
  List<Symptom> symptoms;
  List<Habit> habits;
  List<DoctorReview> reviews;
  late List<Alert> alerts;
  DateTime lastSyncedAt;

  final Set<String> _acknowledged = {};
  final Map<VitalMetric, Baseline> _baselines = {};
  List<Flag> _engineFlags = const [];

  // ---------------------------------------------------------------- flags

  void _recomputeFlags() {
    _engineFlags = engine.evaluateAll(
      readings,
      rules,
      hereditaryTags: profile.familyHistoryTags.toSet(),
      now: now,
    );
  }

  /// Call after the profile (family history) changes.
  void refreshFlags() => _recomputeFlags();

  /// Flags with the latest doctor-review badge and acknowledgement applied.
  List<Flag> get flags => [
    for (final flag in _engineFlags)
      flag.copyWith(
        doctorBadge: _badgeFor(flag),
        acknowledged: _acknowledged.contains(flag.id),
      ),
  ];

  void acknowledge(String flagId) => _acknowledged.add(flagId);

  DoctorBadgeState _badgeFor(Flag flag) {
    final review = reviewFor(flag.id);
    return review?.badge ?? DoctorBadgeState.notReviewed;
  }

  DoctorReview? reviewFor(String flagId) {
    for (final review in reviews) {
      if (review.flagId == flagId) return review;
    }
    return null;
  }

  Baseline baseline(VitalMetric metric) {
    return _baselines.putIfAbsent(
      metric,
      () => engine.computeBaseline(readings, metric),
    );
  }

  DailyReading? get latestReading {
    for (var i = readings.length - 1; i >= 0; i--) {
      if (!readings[i].isGap) return readings[i];
    }
    return null;
  }

  // --------------------------------------------------------------- alerts

  List<Alert> _buildAlerts() {
    final result = <Alert>[];
    final active = _engineFlags.where((f) => f.isActive).toList();
    for (var i = 0; i < active.length; i++) {
      final flag = active[i];
      final red = flag.status == FlagStatus.red;
      result.add(
        Alert(
          id: 'alert_${flag.id}',
          tier: red ? AlertTier.urgent : AlertTier.advise,
          title: flag.title,
          message: '${flag.summary} ${flag.nextStep}',
          createdAt: DateTime(now.year, now.month, now.day - i, 7, 50),
          flagId: flag.id,
          actionLabel: red ? 'Review pattern' : 'See details',
        ),
      );
    }
    result.add(
      Alert(
        id: 'alert_sync_ok',
        tier: AlertTier.info,
        title: 'Data synced',
        message: 'Your latest sleep and heart data was added this morning.',
        createdAt: DateTime(now.year, now.month, now.day, 7, 45),
        isRead: true,
      ),
    );
    result.add(
      Alert(
        id: 'alert_baseline_updated',
        tier: AlertTier.info,
        title: 'Your usual range was refreshed',
        message:
            'VitalWatch compares each day with your own recent history, not '
            'with population averages.',
        createdAt: DateTime(now.year, now.month, now.day - 4, 9),
        isRead: true,
      ),
    );
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  // ----------------------------------------------------------------- home

  HomeSnapshot buildHomeSnapshot() {
    final all = flags;
    final reds = all.where((f) => f.status == FlagStatus.red).length;
    final ambers = all.where((f) => f.status == FlagStatus.amber).length;

    FlagStatus overall = FlagStatus.green;
    String headline = 'Your vitals look steady';
    String sub = 'Everything is within your own usual range right now.';
    if (reds > 0) {
      overall = FlagStatus.red;
      headline = reds == 1
          ? 'One pattern needs your attention'
          : '$reds patterns need your attention';
      sub = ambers > 0
          ? 'Plus $ambers more worth watching. These compare recent days '
                'with your own usual range.'
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
    for (final flag in all) {
      final current = domainStatuses[flag.domain]!;
      if (flag.status.index > current.index) {
        domainStatuses[flag.domain] = flag.status;
      }
    }

    final recentStart = math.max(0, readings.length - 30);
    return HomeSnapshot(
      profile: profile,
      overallStatus: overall,
      headline: headline,
      subheadline: sub,
      flags: all,
      domainStatuses: domainStatuses,
      latestReading: latestReading,
      recentReadings: readings.sublist(recentStart),
      heroMetric: persona.heroMetric,
      heroBaseline: baseline(persona.heroMetric),
      wins: _buildWins(all),
      unreadAlertCount: alerts.where((a) => !a.isRead).length,
      lastSyncedAt: lastSyncedAt,
      generatedAt: now,
    );
  }

  // ----------------------------------------------------------------- wins

  List<WinItem> _buildWins(List<Flag> allFlags) {
    final improvements = <WinItem>[];
    final steady = <WinItem>[];
    final habitWins = <WinItem>[];
    final recent = readings.length >= 14
        ? readings.sublist(readings.length - 14)
        : readings;

    for (final flag in allFlags) {
      if (flag.status != FlagStatus.green) continue;
      final metric = flag.metric;
      final base = baseline(metric);
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
                'The last two weeks sit on the healthier side of your usual '
                'range.',
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
              description:
                  'Steady wear makes your usual range more reliable.',
              domain: HealthDomain.heart,
              achievedOn: now,
            ),
          ]
        : <WinItem>[];

    return [...improvements, ...habitWins, ...steady, ...tracking].take(4).toList();
  }
}

