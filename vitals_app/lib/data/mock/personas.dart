import '../../domain/models/enums.dart';
import '../../domain/models/profile.dart';

enum PersonaId {
  rahul('Rahul', 'Red-flag story'),
  meera('Meera', 'Green story');

  const PersonaId(this.label, this.storyLabel);

  final String label;
  final String storyLabel;
}

/// Typical level and day-to-day spread of one metric for a persona.
class MetricSpec {
  const MetricSpec(this.mean, this.sd);

  final double mean;
  final double sd;
}

/// A gradual shift away from the persona's usual level that begins
/// [startDaysAgo] days before the last day and ramps over [rampDays].
class DriftSpec {
  const DriftSpec({
    required this.metric,
    required this.startDaysAgo,
    required this.rampDays,
    required this.totalShift,
  });

  final VitalMetric metric;
  final int startDaysAgo;
  final int rampDays;

  /// Signed change in the metric's unit once fully ramped.
  final double totalShift;

  double shiftAt(int daysAgo) {
    if (daysAgo > startDaysAgo) return 0;
    final progress = (startDaysAgo - daysAgo) / rampDays;
    return totalShift * progress.clamp(0.0, 1.0);
  }
}

/// A short temporary change (too short to count as a pattern).
class BlipSpec {
  const BlipSpec({
    required this.metric,
    required this.startDaysAgo,
    required this.lengthDays,
    required this.shift,
  });

  final VitalMetric metric;
  final int startDaysAgo;
  final int lengthDays;
  final double shift;

  double shiftAt(int daysAgo) {
    final endDaysAgo = startDaysAgo - lengthDays + 1;
    return daysAgo <= startDaysAgo && daysAgo >= endDaysAgo ? shift : 0;
  }
}

class LifeEventSpec {
  const LifeEventSpec({
    required this.id,
    required this.type,
    required this.title,
    required this.startDaysAgo,
    this.durationDays,
    this.note,
  });

  final String id;
  final LifeEventType type;
  final String title;
  final int startDaysAgo;

  /// `null` means ongoing.
  final int? durationDays;
  final String? note;
}

class SymptomSpec {
  const SymptomSpec({
    required this.id,
    required this.label,
    required this.daysAgo,
    required this.severity,
    this.note,
    this.linkedRuleId,
  });

  final String id;
  final String label;
  final int daysAgo;
  final Severity severity;
  final String? note;
  final String? linkedRuleId;
}

class HabitSpec {
  const HabitSpec({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.domain,
    required this.targetDaysPerWeek,
    required this.completionRate,
    required this.recentStreak,
    this.linkedRuleId,
  });

  final String id;
  final String title;
  final String subtitle;
  final HealthDomain domain;
  final int targetDaysPerWeek;

  /// Share of the past 60 days that were completed (0..1).
  final double completionRate;

  /// Days completed in a row ending yesterday.
  final int recentStreak;
  final String? linkedRuleId;
}

/// A pre-seeded clinician review (sample data).
class ReviewSpec {
  const ReviewSpec({
    required this.ruleId,
    required this.verdict,
    required this.requestedDaysAgo,
    this.reviewedDaysAgo,
    this.note,
  });

  final String ruleId;
  final DoctorVerdict verdict;
  final int requestedDaysAgo;
  final int? reviewedDaysAgo;
  final String? note;
}

/// A scripted sample person used to drive the UI-only build.
class Persona {
  const Persona({
    required this.id,
    required this.seed,
    required this.profile,
    required this.metrics,
    required this.heroMetric,
    this.drifts = const [],
    this.blips = const [],
    this.lifeEvents = const [],
    this.symptoms = const [],
    this.habits = const [],
    this.reviews = const [],
  });

  final PersonaId id;
  final int seed;
  final Profile profile;
  final Map<VitalMetric, MetricSpec> metrics;
  final VitalMetric heroMetric;
  final List<DriftSpec> drifts;
  final List<BlipSpec> blips;
  final List<LifeEventSpec> lifeEvents;
  final List<SymptomSpec> symptoms;
  final List<HabitSpec> habits;
  final List<ReviewSpec> reviews;
}

abstract final class Personas {
  static const PersonaId defaultId = PersonaId.rahul;

  static Persona byId(PersonaId id) {
    switch (id) {
      case PersonaId.rahul:
        return rahul;
      case PersonaId.meera:
        return meera;
    }
  }

  /// Rahul, 34 — a stretch of long working days; resting HR is creeping up
  /// and HRV is sliding, with sleep and activity following. (Red-flag story.)
  static final Persona rahul = Persona(
    id: PersonaId.rahul,
    seed: 3417,
    profile: Profile(
      id: 'rahul',
      name: 'Rahul Verma',
      age: 34,
      sex: BiologicalSex.male,
      heightCm: 176,
      weightKg: 79,
      occupation: 'Product manager',
      memberSince: DateTime(2026, 1, 12),
      familyHistoryTags: const ['cardiovascular'],
      goals: const ['Sleep more consistently', 'Walk more during the workday'],
    ),
    metrics: const {
      VitalMetric.restingHr: MetricSpec(62, 1.6),
      VitalMetric.hrv: MetricSpec(52, 4.0),
      VitalMetric.sleepDuration: MetricSpec(7.0, 0.45),
      VitalMetric.deepSleep: MetricSpec(1.5, 0.22),
      VitalMetric.sleepFragmentation: MetricSpec(11, 2.2),
      VitalMetric.spo2: MetricSpec(96.5, 0.6),
      VitalMetric.steps: MetricSpec(7200, 1000),
      VitalMetric.respiratoryRate: MetricSpec(14.5, 0.5),
      VitalMetric.skinTemp: MetricSpec(33.6, 0.25),
      VitalMetric.bedtimeVariability: MetricSpec(18, 7),
    },
    heroMetric: VitalMetric.restingHr,
    drifts: const [
      DriftSpec(
        metric: VitalMetric.restingHr,
        startDaysAgo: 30,
        rampDays: 10,
        totalShift: 9,
      ),
      DriftSpec(
        metric: VitalMetric.hrv,
        startDaysAgo: 26,
        rampDays: 8,
        totalShift: -18,
      ),
      DriftSpec(
        metric: VitalMetric.sleepFragmentation,
        startDaysAgo: 20,
        rampDays: 4,
        totalShift: 8,
      ),
      DriftSpec(
        metric: VitalMetric.deepSleep,
        startDaysAgo: 20,
        rampDays: 4,
        totalShift: -0.5,
      ),
      DriftSpec(
        metric: VitalMetric.steps,
        startDaysAgo: 24,
        rampDays: 5,
        totalShift: -3200,
      ),
    ],
    lifeEvents: const [
      LifeEventSpec(
        id: 'rahul_event_deadline',
        type: LifeEventType.stress,
        title: 'Product launch crunch',
        startDaysAgo: 34,
        durationDays: 21,
        note: 'Long days and late dinners while shipping a release.',
      ),
    ],
    symptoms: const [
      SymptomSpec(
        id: 'rahul_sym_1',
        label: 'Feeling more tired than usual',
        daysAgo: 4,
        severity: Severity.medium,
        linkedRuleId: 'hrv_decline',
      ),
      SymptomSpec(
        id: 'rahul_sym_2',
        label: 'Restless sleep',
        daysAgo: 9,
        severity: Severity.low,
        linkedRuleId: 'sleep_fragmentation',
      ),
      SymptomSpec(
        id: 'rahul_sym_3',
        label: 'Noticing my heartbeat more often',
        daysAgo: 13,
        severity: Severity.low,
        note: 'Mostly when sitting quietly in the evening.',
        linkedRuleId: 'resting_hr_drift',
      ),
    ],
    habits: const [
      HabitSpec(
        id: 'walk_after_lunch',
        title: '10-minute walk after lunch',
        subtitle: 'Gentle movement to break up long sitting stretches',
        domain: HealthDomain.activity,
        targetDaysPerWeek: 5,
        completionRate: 0.3,
        recentStreak: 0,
        linkedRuleId: 'low_activity',
      ),
      HabitSpec(
        id: 'consistent_bedtime',
        title: 'Lights out by 11 pm',
        subtitle: 'A steadier bedtime helps your body clock',
        domain: HealthDomain.sleep,
        targetDaysPerWeek: 6,
        completionRate: 0.35,
        recentStreak: 2,
        linkedRuleId: 'irregular_sleep_schedule',
      ),
      HabitSpec(
        id: 'screen_wind_down',
        title: 'Screens off 45 minutes before bed',
        subtitle: 'A calmer wind-down can ease restless nights',
        domain: HealthDomain.sleep,
        targetDaysPerWeek: 5,
        completionRate: 0.25,
        recentStreak: 0,
        linkedRuleId: 'sleep_fragmentation',
      ),
      HabitSpec(
        id: 'breathing_break',
        title: '5-minute breathing break',
        subtitle: 'Slow breathing once or twice a day',
        domain: HealthDomain.stressRecovery,
        targetDaysPerWeek: 5,
        completionRate: 0.2,
        recentStreak: 1,
        linkedRuleId: 'hrv_decline',
      ),
    ],
    reviews: const [
      ReviewSpec(
        ruleId: 'resting_hr_drift',
        verdict: DoctorVerdict.pending,
        requestedDaysAgo: 3,
        note: 'A clinician will look at your shared trend summary.',
      ),
    ],
  );

  /// Meera, 28 — steady routines, good sleep and plenty of movement.
  /// (Green story.) A brief dip in steps never lasts long enough to flag.
  static final Persona meera = Persona(
    id: PersonaId.meera,
    seed: 2811,
    profile: Profile(
      id: 'meera',
      name: 'Meera Iyer',
      age: 28,
      sex: BiologicalSex.female,
      heightCm: 163,
      weightKg: 56,
      occupation: 'UX designer',
      memberSince: DateTime(2026, 2, 3),
      goals: const ['Keep my routines steady', 'Run a 10K this spring'],
    ),
    metrics: const {
      VitalMetric.restingHr: MetricSpec(58, 1.4),
      VitalMetric.hrv: MetricSpec(64, 4.5),
      VitalMetric.sleepDuration: MetricSpec(7.7, 0.4),
      VitalMetric.deepSleep: MetricSpec(1.8, 0.2),
      VitalMetric.sleepFragmentation: MetricSpec(8, 1.8),
      VitalMetric.spo2: MetricSpec(97.2, 0.5),
      VitalMetric.steps: MetricSpec(9800, 1200),
      VitalMetric.respiratoryRate: MetricSpec(14.0, 0.4),
      VitalMetric.skinTemp: MetricSpec(33.8, 0.22),
      VitalMetric.bedtimeVariability: MetricSpec(12, 5),
    },
    heroMetric: VitalMetric.hrv,
    drifts: const [
      // A gentle improvement over the last month.
      DriftSpec(
        metric: VitalMetric.hrv,
        startDaysAgo: 30,
        rampDays: 30,
        totalShift: 5,
      ),
      DriftSpec(
        metric: VitalMetric.restingHr,
        startDaysAgo: 30,
        rampDays: 30,
        totalShift: -1.5,
      ),
    ],
    blips: const [
      BlipSpec(
        metric: VitalMetric.steps,
        startDaysAgo: 3,
        lengthDays: 3,
        shift: -3200,
      ),
    ],
    lifeEvents: const [
      LifeEventSpec(
        id: 'meera_event_trip',
        type: LifeEventType.travel,
        title: 'Weekend trip',
        startDaysAgo: 3,
        durationDays: 3,
        note: 'Lots of sightseeing by car, fewer steps than usual.',
      ),
    ],
    symptoms: const [
      SymptomSpec(
        id: 'meera_sym_1',
        label: 'Slightly stiff after long drive',
        daysAgo: 2,
        severity: Severity.low,
      ),
    ],
    habits: const [
      HabitSpec(
        id: 'morning_stretch',
        title: 'Morning stretch or yoga',
        subtitle: 'Start the day with 10 easy minutes',
        domain: HealthDomain.activity,
        targetDaysPerWeek: 5,
        completionRate: 0.82,
        recentStreak: 9,
      ),
      HabitSpec(
        id: 'consistent_bedtime',
        title: 'Lights out by 10:30 pm',
        subtitle: 'Keeps your body clock steady',
        domain: HealthDomain.sleep,
        targetDaysPerWeek: 6,
        completionRate: 0.78,
        recentStreak: 5,
        linkedRuleId: 'irregular_sleep_schedule',
      ),
      HabitSpec(
        id: 'evening_walk',
        title: 'Evening walk',
        subtitle: 'A relaxed 20 minutes after dinner',
        domain: HealthDomain.activity,
        targetDaysPerWeek: 5,
        completionRate: 0.7,
        recentStreak: 4,
        linkedRuleId: 'low_activity',
      ),
      HabitSpec(
        id: 'daylight_break',
        title: 'Daylight break',
        subtitle: 'Step outside for 10 minutes of daylight',
        domain: HealthDomain.stressRecovery,
        targetDaysPerWeek: 5,
        completionRate: 0.65,
        recentStreak: 3,
      ),
    ],
  );
}
