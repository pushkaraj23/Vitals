import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';

/// Self-reported medical history (e.g. "Asthma"). Local demo state that
/// resets when the persona changes.
class MedicalHistoryNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    ref.watch(personaIdProvider);
    return const [];
  }

  void add(String item) {
    final clean = item.trim();
    if (clean.isEmpty) return;
    if (state.any((e) => e.toLowerCase() == clean.toLowerCase())) return;
    state = [...state, clean];
  }

  void remove(String item) => state = [
    for (final e in state)
      if (e != item) e,
  ];
}

final medicalHistoryProvider =
    NotifierProvider<MedicalHistoryNotifier, List<String>>(
      MedicalHistoryNotifier.new,
    );

enum Relative {
  maternalGrandparents('Maternal grandparents'),
  paternalGrandparents('Paternal grandparents'),
  mother('Mother'),
  father('Father'),
  siblings('Siblings');

  const Relative(this.label);

  final String label;
}

/// Family conditions we can use (they match the tags in the rules library).
const familyConditions = <String, String>{
  'cardiovascular': 'Heart & circulation',
  'sleep_disorders': 'Sleep conditions',
  'respiratory': 'Lung & breathing',
  'metabolic': 'Blood sugar & metabolism',
};

/// Who in the family has which condition. Seeded (as sample data) from the
/// persona's family-history tags; resets when the persona changes.
class FamilyTreeNotifier extends Notifier<Map<Relative, Set<String>>> {
  @override
  Map<Relative, Set<String>> build() {
    final persona = ref.watch(currentPersonaProvider);
    return {
      for (final r in Relative.values) r: <String>{},
      if (persona.profile.familyHistoryTags.isNotEmpty)
        Relative.father: persona.profile.familyHistoryTags.toSet(),
    };
  }

  void set(Relative relative, Set<String> tags) {
    state = {...state, relative: tags};
  }

  /// Every condition mentioned by anyone in the tree.
  Set<String> get allTags => {for (final s in state.values) ...s};
}

final familyTreeProvider =
    NotifierProvider<FamilyTreeNotifier, Map<Relative, Set<String>>>(
      FamilyTreeNotifier.new,
    );

class ScreeningReminder {
  const ScreeningReminder(this.id, this.title, this.subtitle);

  final String id;
  final String title;
  final String subtitle;
}

const screeningReminders = <ScreeningReminder>[
  ScreeningReminder('checkup', 'General health check-up', 'A yearly visit to talk things through'),
  ScreeningReminder('blood_pressure', 'Blood pressure check', 'Easy to do at a pharmacy or clinic'),
  ScreeningReminder('blood_sugar', 'Blood sugar check', 'Ask a clinician how often suits you'),
  ScreeningReminder('eyes', 'Eye check', 'Good to review every year or two'),
  ScreeningReminder('dental', 'Dental check-up', 'Usually every six months'),
];

class ScreeningRemindersNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(personaIdProvider);
    return const {'checkup'};
  }

  void set(String id, {required bool on}) {
    final next = {...state};
    on ? next.add(id) : next.remove(id);
    state = next;
  }
}

final screeningRemindersProvider =
    NotifierProvider<ScreeningRemindersNotifier, Set<String>>(
      ScreeningRemindersNotifier.new,
    );
