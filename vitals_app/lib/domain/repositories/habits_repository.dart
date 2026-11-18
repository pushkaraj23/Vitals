import '../models/habit.dart';

// Later: backed by Health Connect + FastAPI.
abstract class HabitsRepository {
  Future<List<Habit>> getHabits();

  /// Marks the habit done (or not done) for [date]. Returns the updated habit.
  Future<Habit> toggleHabit(String id, DateTime date);

  Future<List<Habit>> addHabit(Habit habit);

  Future<List<Habit>> removeHabit(String id);
}
