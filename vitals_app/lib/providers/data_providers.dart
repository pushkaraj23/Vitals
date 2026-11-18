import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/baseline_repository.dart';
import '../data/repositories/daily_repository.dart';
import '../data/repositories/doctor_repository.dart';
import '../data/repositories/flag_repository.dart';
import '../data/repositories/habit_repository.dart';
import '../data/repositories/habit_template_repository.dart';
import '../data/repositories/review_repository.dart';
import '../data/repositories/rule_repository.dart';
import '../data/repositories/symptom_repository.dart';
import '../data/repositories/user_repository.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

/// Stream of the current user's profile document from Firestore.
final userProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUser(uid);
});

/// Stream of all rules from the rules collection (read-only).
final rulesProvider = StreamProvider<List<RuleModel>>((ref) {
  return ref.watch(ruleRepositoryProvider).watchAll();
});

/// Single rule by ID.
final ruleProvider = StreamProvider.family<RuleModel?, String>((ref, ruleId) {
  return ref.watch(ruleRepositoryProvider).watchAll().map(
    (rules) {
      for (final r in rules) {
        if (r.id == ruleId) return r;
      }
      return null;
    },
  );
});

/// Stream of all daily readings for the current user.
final dailyProvider = StreamProvider.family<List<DailyModel>, String?>(
  (ref, range) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return Stream.value([]);
    return ref.watch(dailyRepositoryProvider).watchAll(uid);
  },
);

/// Stream of all baselines for the current user.
final baselinesProvider = StreamProvider<Map<String, BaselineModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value({});
  return ref.watch(baselineRepositoryProvider).watchAll(uid);
});

/// Single baseline by metric name.
final baselineProvider =
    StreamProvider.family<BaselineModel?, String>((ref, metric) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(baselineRepositoryProvider).watchAll(uid).map((map) => map[metric]);
});

/// Stream of all flags for the current user, sorted client-side:
/// red > amber > green, then by durationDays desc.
final flagsProvider = StreamProvider<List<FlagModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(flagRepositoryProvider).watchAll(uid).map((flags) {
    flags.sort((a, b) {
      final lvl = _levelRank(b.level) - _levelRank(a.level);
      if (lvl != 0) return lvl;
      return b.durationDays.compareTo(a.durationDays);
    });
    return flags;
  });
});

/// Single flag by flagId.
final flagProvider = StreamProvider.family<FlagModel?, String>((ref, flagId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(flagRepositoryProvider).watchOne(uid, flagId);
});

/// Stream of symptoms for the current user, newest first.
final symptomsProvider = StreamProvider<List<SymptomModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(symptomRepositoryProvider).watchAll(uid);
});

/// Stream of habits for the current user.
final habitsProvider = StreamProvider<List<HabitModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(habitRepositoryProvider).watchAll(uid);
});

/// Active doctors available for patient review assignment.
final doctorsProvider = StreamProvider<List<DoctorModel>>((ref) {
  return ref.watch(doctorRepositoryProvider).watchActive();
});

/// Stream of doctor reviews for the current user.
final reviewsProvider = StreamProvider<List<ReviewModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(reviewRepositoryProvider).watchAll(uid);
});

/// Doctor review for a specific flag.
final reviewForFlagProvider =
    StreamProvider.family<ReviewModel?, String>((ref, flagId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(reviewRepositoryProvider).watchForFlag(uid, flagId);
});

/// Habit templates from global habitTemplates collection (read-only).
final habitTemplatesProvider = StreamProvider<List<HabitTemplateModel>>((ref) {
  return ref.watch(habitTemplateRepositoryProvider).watchAll();
});

// ── Computed helpers ─────────────────────────────────────────────────────────

/// Overall health status string: 'green' | 'amber' | 'red'.
final overallStatusProvider = Provider<String>((ref) {
  final flags = ref.watch(flagsProvider).value ?? [];
  if (flags.any((f) => f.level == 'red')) return 'red';
  if (flags.any((f) => f.level == 'amber')) return 'amber';
  return 'green';
});

/// Count of valid daily entries.
final dataDaysCountProvider = Provider<int>((ref) {
  final daily = ref.watch(dailyProvider(null)).value ?? [];
  return daily.where((d) => !d.isGap).length;
});

int _levelRank(String level) => switch (level) {
  'red' => 2,
  'amber' => 1,
  _ => 0,
};