import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models/rule.dart';

/// Loads the educational rules library from `assets/rules/rules.json`.
class RulesLoader {
  const RulesLoader({this.bundle, this.assetPath = defaultAssetPath});

  static const defaultAssetPath = 'assets/rules/rules.json';

  /// Defaults to [rootBundle].
  final AssetBundle? bundle;
  final String assetPath;

  Future<List<Rule>> load() async {
    final source = await (bundle ?? rootBundle).loadString(assetPath);
    return parse(source);
  }

  /// Parses rules JSON. Throws [FormatException] on malformed input.
  static List<Rule> parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('rules.json is not valid JSON: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('rules.json must be a JSON object');
    }
    final list = decoded['rules'];
    if (list is! List<dynamic>) {
      throw const FormatException('rules.json is missing a "rules" array');
    }
    final rules = list
        .map((e) => Rule.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final ids = <String>{};
    for (final rule in rules) {
      if (!ids.add(rule.id)) {
        throw FormatException('Duplicate rule id "${rule.id}"');
      }
    }
    return rules;
  }
}
