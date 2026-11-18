import 'package:flutter_test/flutter_test.dart';
import 'package:vitals/data/mock/rules_loader.dart';
import 'package:vitals/domain/models/enums.dart';
import 'package:vitals/domain/models/rule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RulesLoader (asset)', () {
    late List<Rule> rules;

    setUpAll(() async {
      rules = await const RulesLoader().load();
    });

    test('loads the 8 expected rules', () {
      expect(rules.map((r) => r.id).toList(), [
        'resting_hr_drift',
        'hrv_decline',
        'sleep_fragmentation',
        'low_deep_sleep',
        'spo2_dips',
        'low_activity',
        'elevated_respiratory_rate',
        'irregular_sleep_schedule',
      ]);
    });

    test('every rule is fully populated', () {
      for (final rule in rules) {
        expect(rule.name, isNotEmpty, reason: rule.id);
        expect(rule.summary, isNotEmpty, reason: rule.id);
        expect(rule.metrics, isNotEmpty, reason: rule.id);
        expect(rule.minDurationDays, greaterThan(0), reason: rule.id);
        expect(rule.symptoms, isNotEmpty, reason: rule.id);
        expect(rule.impactsPhysical, isNotEmpty, reason: rule.id);
        expect(rule.impactsMental, isNotEmpty, reason: rule.id);
        expect(rule.remedies, isNotEmpty, reason: rule.id);
        expect(rule.specialist, isNotEmpty, reason: rule.id);
        expect(rule.sources, isNotEmpty, reason: rule.id);
        expect(rule.thresholds.sigma, greaterThan(0), reason: rule.id);
        expect(rule.thresholds.redDays, greaterThanOrEqualTo(rule.minDurationDays));
      }
    });

    test('ids are unique and metrics map to known vitals', () {
      expect(rules.map((r) => r.id).toSet().length, rules.length);
      final primary = {for (final r in rules) r.id: r.primaryMetric};
      expect(primary['resting_hr_drift'], VitalMetric.restingHr);
      expect(primary['hrv_decline'], VitalMetric.hrv);
      expect(primary['sleep_fragmentation'], VitalMetric.sleepFragmentation);
      expect(primary['low_deep_sleep'], VitalMetric.deepSleep);
      expect(primary['spo2_dips'], VitalMetric.spo2);
      expect(primary['low_activity'], VitalMetric.steps);
      expect(primary['elevated_respiratory_rate'], VitalMetric.respiratoryRate);
      expect(
        primary['irregular_sleep_schedule'],
        VitalMetric.bedtimeVariability,
      );
    });

    test('sources are generic names with no URLs', () {
      for (final rule in rules) {
        for (final source in rule.sources) {
          expect(source.toLowerCase(), isNot(contains('http')));
          expect(source.toLowerCase(), isNot(contains('www.')));
          expect(source, isNot(contains('.com')));
          expect(source, isNot(contains('.org')));
        }
      }
    });

    test('content never diagnoses or quotes probabilities', () {
      for (final rule in rules) {
        final text = [
          rule.summary,
          ...rule.symptoms,
          ...rule.impactsPhysical,
          ...rule.impactsMental,
          ...rule.remedies,
          for (final m in rule.hereditaryModifiers) m.note,
        ].join(' ').toLowerCase();
        expect(text, isNot(contains('you have ')), reason: rule.id);
        expect(text, isNot(contains('diagnosed with')), reason: rule.id);
        expect(text, isNot(contains('%')), reason: rule.id);
        expect(text, isNot(contains('probab')), reason: rule.id);
        expect(text, isNot(contains('chance of')), reason: rule.id);
      }
    });

    test('hereditary modifiers parse', () {
      final hr = rules.firstWhere((r) => r.id == 'resting_hr_drift');
      expect(hr.hereditaryModifiers, isNotEmpty);
      expect(hr.hereditaryModifiers.first.tag, 'cardiovascular');
      expect(hr.hereditaryModifiers.first.sigmaDelta, lessThan(0));
    });
  });

  group('RulesLoader.parse', () {
    test('rejects invalid JSON', () {
      expect(() => RulesLoader.parse('not json'), throwsFormatException);
    });

    test('rejects a missing rules array', () {
      expect(() => RulesLoader.parse('{"version":1}'), throwsFormatException);
    });

    test('rejects unknown metrics', () {
      const source = '''
{"rules":[{"id":"x","name":"X","summary":"s","metrics":["notAMetric"],
"minDurationDays":3,
"thresholds":{"sigma":2,"redSigma":3,"redDays":7,"minDelta":1},
"specialist":"GP"}]}''';
      expect(() => RulesLoader.parse(source), throwsFormatException);
    });

    test('rejects duplicate ids', () {
      const rule = '''
{"id":"x","name":"X","summary":"s","metrics":["hrv"],"minDurationDays":3,
"thresholds":{"sigma":2,"redSigma":3,"redDays":7,"minDelta":1},
"specialist":"GP"}''';
      expect(
        () => RulesLoader.parse('{"rules":[$rule,$rule]}'),
        throwsFormatException,
      );
    });

    test('optional lists default to empty', () {
      const source = '''
{"rules":[{"id":"x","name":"X","summary":"s","metrics":["hrv"],
"minDurationDays":3,
"thresholds":{"sigma":2,"redSigma":3,"redDays":7,"minDelta":1},
"specialist":"GP"}]}''';
      final rule = RulesLoader.parse(source).single;
      expect(rule.symptoms, isEmpty);
      expect(rule.remedies, isEmpty);
      expect(rule.hereditaryModifiers, isEmpty);
    });
  });
}
