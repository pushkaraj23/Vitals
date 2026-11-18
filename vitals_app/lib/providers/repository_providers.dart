import 'package:cloud_firestore/cloud_firestore.dart';
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

final firestoreInstanceProvider = Provider<FirebaseFirestore>((ref) {
  final db = FirebaseFirestore.instance;
  db.settings = const Settings(persistenceEnabled: true);
  return db;
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(firestoreInstanceProvider));
});

final dailyRepositoryProvider = Provider<DailyRepository>((ref) {
  return DailyRepository(ref.watch(firestoreInstanceProvider));
});

final baselineRepositoryProvider = Provider<BaselineRepository>((ref) {
  return BaselineRepository(ref.watch(firestoreInstanceProvider));
});

final flagRepositoryProvider = Provider<FlagRepository>((ref) {
  return FlagRepository(ref.watch(firestoreInstanceProvider));
});

final ruleRepositoryProvider = Provider<RuleRepository>((ref) {
  return RuleRepository(ref.watch(firestoreInstanceProvider));
});

final symptomRepositoryProvider = Provider<SymptomRepository>((ref) {
  return SymptomRepository(ref.watch(firestoreInstanceProvider));
});

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository(ref.watch(firestoreInstanceProvider));
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(firestoreInstanceProvider));
});

final doctorRepositoryProvider = Provider<DoctorRepository>((ref) {
  return DoctorRepository(ref.watch(firestoreInstanceProvider));
});

final habitTemplateRepositoryProvider = Provider<HabitTemplateRepository>((ref) {
  return HabitTemplateRepository(ref.watch(firestoreInstanceProvider));
});
