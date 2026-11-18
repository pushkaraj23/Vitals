import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock/personas.dart';

/// Which sample persona is active. Changing it regenerates all mock data
/// (every repository and data provider rebuilds).
class PersonaNotifier extends Notifier<PersonaId> {
  @override
  PersonaId build() => Personas.defaultId;

  void select(PersonaId id) {
    if (id != state) state = id;
  }
}

final personaIdProvider = NotifierProvider<PersonaNotifier, PersonaId>(
  PersonaNotifier.new,
);

/// The active [Persona] definition.
final currentPersonaProvider = Provider<Persona>(
  (ref) => Personas.byId(ref.watch(personaIdProvider)),
);
