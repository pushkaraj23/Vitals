import '../models/flag.dart';
import '../models/rule.dart';

// Later: backed by Health Connect + FastAPI.
abstract class FlagsRepository {
  /// All evaluated flags (green, amber and red), worst first.
  Future<List<Flag>> getFlags();

  Future<Flag?> getFlag(String id);

  Future<Flag> acknowledgeFlag(String id);

  /// The educational rules behind the flags.
  Future<List<Rule>> getRules();

  Future<Rule?> getRule(String id);
}
