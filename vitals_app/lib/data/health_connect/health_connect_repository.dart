import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';

import '../repositories/daily_repository.dart';

/// Health Connect read + daily aggregation for Firestore.
class HealthConnectRepository {
  HealthConnectRepository() : _health = Health();

  final Health _health;
  bool _isConfigured = false;

  static const List<HealthDataType> types = [
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.STEPS,
    HealthDataType.BLOOD_OXYGEN,
  ];

  static final List<HealthDataAccess> _permissions =
      List.filled(types.length, HealthDataAccess.READ);

  final _dayFmt = DateFormat('yyyy-MM-dd');

  Future<void> _ensureConfigured() async {
    if (!_isConfigured) {
      await _health.configure();
      _isConfigured = true;
    }
  }

  void _assertAndroid() {
    if (!Platform.isAndroid) {
      throw Exception('Health Connect is only available on Android.');
    }
  }

  Future<bool> hasAuthorization() async {
    if (!Platform.isAndroid) return false;
    await _ensureConfigured();
    try {
      return await _health.hasPermissions(types, permissions: _permissions) ??
          false;
    } catch (e) {
      if (kDebugMode) debugPrint('[HealthConnect] hasAuthorization: $e');
      return false;
    }
  }

  Future<bool> requestAuthorization() async {
    _assertAndroid();
    await _ensureConfigured();
    final status = await _health.getHealthConnectSdkStatus();
    if (kDebugMode) debugPrint('[HealthConnect] SDK status: $status');
    if (status != HealthConnectSdkStatus.sdkAvailable) {
      if (status ==
          HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        await _health.installHealthConnect();
      }
      throw Exception('Health Connect is not available on this device.');
    }
    return _health.requestAuthorization(types, permissions: _permissions);
  }

  /// Reads [from]→[to] in 7-day chunks, aggregates per local calendar day.
  /// Omits unavailable fields (never writes 0 for gaps). Days with no data
  /// produce no document.
  Future<List<DailyModel>> fetchDailyRange({
    required DateTime from,
    required DateTime to,
  }) async {
    _assertAndroid();
    await _ensureConfigured();

    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59);

    final byDay = <String, _DayAgg>{};

    var cursor = start;
    while (cursor.isBefore(end) || cursor.isAtSameMomentAs(start)) {
      final chunkEnd = cursor.add(const Duration(days: 7));
      final rangeEnd = chunkEnd.isAfter(end) ? end : chunkEnd;

      List<HealthDataPoint> points = const [];
      try {
        points = await _health.getHealthDataFromTypes(
          types: types,
          startTime: cursor,
          endTime: rangeEnd,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[HealthConnect] chunk read failed: $e');
      }

      for (final p in points) {
        _accumulate(byDay, p);
      }

      cursor = rangeEnd.add(const Duration(milliseconds: 1));
      if (cursor.isAfter(end)) break;
    }

    final days = <DailyModel>[];
    final keys = byDay.keys.toList()..sort();
    for (final key in keys) {
      final agg = byDay[key]!;
      final model = agg.toModel(key);
      if (!model.isGap) days.add(model);
    }
    return days;
  }

  void _accumulate(Map<String, _DayAgg> byDay, HealthDataPoint p) {
    // Sleep attributed to the day the session ends.
    final when = p.type == HealthDataType.SLEEP_ASLEEP ||
            p.type == HealthDataType.SLEEP_DEEP
        ? p.dateTo
        : p.dateFrom;
    final key = _dayFmt.format(when.toLocal());
    final agg = byDay.putIfAbsent(key, _DayAgg.new);

    final value = _num(p);
    if (value == null) return;

    switch (p.type) {
      case HealthDataType.RESTING_HEART_RATE:
        // Prefer lowest sustained resting sample for the day.
        agg.restingHr = agg.restingHr == null
            ? value
            : (value < agg.restingHr! ? value : agg.restingHr);
      case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
        agg.hrvSum += value;
        agg.hrvCount++;
      case HealthDataType.SLEEP_DEEP:
        agg.sleepDeepMin += _minutes(p);
      case HealthDataType.SLEEP_ASLEEP:
        agg.sleepTotalMin += _minutes(p);
      case HealthDataType.BLOOD_OXYGEN:
        // Health Connect often stores SpO2 as 0–1 fraction.
        final spo2 = value <= 1.0 ? value * 100.0 : value;
        agg.spo2Sum += spo2;
        agg.spo2Count++;
      case HealthDataType.STEPS:
        agg.stepsSum += value;
      default:
        break;
    }
  }

  double? _num(HealthDataPoint p) {
    final v = p.value;
    if (v is NumericHealthValue) return v.numericValue.toDouble();
    return null;
  }

  double _minutes(HealthDataPoint p) {
    final mins = p.dateTo.difference(p.dateFrom).inMinutes.toDouble();
    if (mins > 0) return mins;
    final v = _num(p);
    return v ?? 0;
  }
}

class _DayAgg {
  double? restingHr;
  double hrvSum = 0;
  int hrvCount = 0;
  double sleepDeepMin = 0;
  double sleepTotalMin = 0;
  double spo2Sum = 0;
  int spo2Count = 0;
  double stepsSum = 0;

  DailyModel toModel(String date) {
    return DailyModel(
      date: date,
      restingHr: restingHr,
      hrv: hrvCount > 0 ? hrvSum / hrvCount : null,
      sleepDeep: sleepDeepMin > 0 ? sleepDeepMin : null,
      sleepTotal: sleepTotalMin > 0 ? sleepTotalMin : null,
      spo2: spo2Count > 0 ? spo2Sum / spo2Count : null,
      steps: stepsSum > 0 ? stepsSum : null,
      source: 'health_connect',
    );
  }
}
