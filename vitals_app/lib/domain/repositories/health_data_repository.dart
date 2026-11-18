import '../models/baseline.dart';
import '../models/daily_reading.dart';
import '../models/enums.dart';
import '../models/home_snapshot.dart';

// Later: backed by Health Connect + FastAPI.
abstract class HealthDataRepository {
  /// Daily readings, oldest first, for the given [range].
  Future<List<DailyReading>> getReadings({ChartRange range = ChartRange.all});

  /// Most recent day that has data (gaps skipped).
  Future<DailyReading?> getLatestReading();

  /// Personal usual range (with rolling band series) for [metric].
  Future<Baseline> getBaseline(VitalMetric metric);

  Future<HomeSnapshot> getHomeSnapshot();

  /// Pulls fresh data from connected sources. Returns the sync time.
  Future<DateTime> syncNow();
}
