import 'package:flutter/foundation.dart';

import '../repositories/daily_repository.dart';
import '../repositories/user_repository.dart';
import 'health_connect_repository.dart';

class HealthSyncResult {
  const HealthSyncResult({
    required this.daysWritten,
    required this.from,
    required this.to,
  });

  final int daysWritten;
  final DateTime from;
  final DateTime to;
}

/// Orchestrates Health Connect → Firestore daily upserts.
/// Demo users must never call this.
class HealthSyncService {
  HealthSyncService({
    required this._health,
    required this._daily,
    required this._users,
  });

  final HealthConnectRepository _health;
  final DailyRepository _daily;
  final UserRepository _users;

  Future<HealthSyncResult> syncUser(String uid, {bool backfill = false}) async {
    final profile = await _users.getUser(uid);
    if (profile == null) {
      throw Exception('User profile not found.');
    }
    if (profile.isDemo) {
      throw Exception('Demo accounts do not sync Health Connect data.');
    }

    final authorized = await _health.hasAuthorization();
    if (!authorized) {
      final granted = await _health.requestAuthorization();
      if (!granted) {
        throw Exception(
          'Health Connect permissions were not granted. Open settings to allow access.',
        );
      }
    }

    final now = DateTime.now();
    final DateTime from;
    if (backfill || profile.lastSyncedAt == null) {
      from = now.subtract(const Duration(days: 180));
    } else {
      from = profile.lastSyncedAt!.subtract(const Duration(days: 2));
    }

    if (kDebugMode) {
      debugPrint(
        '[HealthSync] uid=$uid from=${from.toIso8601String()} to=${now.toIso8601String()}',
      );
    }

    final days = await _health.fetchDailyRange(from: from, to: now);
    if (days.isNotEmpty) {
      await _daily.upsertBatch(uid, days);
    }
    await _users.updateLastSynced(uid, now);

    return HealthSyncResult(daysWritten: days.length, from: from, to: now);
  }
}
