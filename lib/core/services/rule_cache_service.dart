import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/rule_model.dart';

/// Caches the latest rules/main document locally so the child device can
/// enforce limits even when offline.
class RuleCacheService {
  static const String _keyPrefix = 'orbit_rules_';

  static String _key(String familyId, String childId) =>
      '$_keyPrefix${familyId}_${childId}';

  /// Writes the rules to SharedPreferences as JSON.
  static Future<void> saveRules({
    required String familyId,
    required String childId,
    required RuleModel rules,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final json = _rulesToJson(rules);
    await prefs.setString(_key(familyId, childId), json);
    debugPrint('RuleCacheService: saved rules for $childId');
  }

  /// Reads the cached rules from SharedPreferences. Returns null if none.
  static Future<RuleModel?> loadRules({
    required String familyId,
    required String childId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key(familyId, childId));
    if (json == null || json.isEmpty) return null;
    return _rulesFromJson(json);
  }

  static String _rulesToJson(RuleModel rules) {
    final blockedApps = <String, String>{};
    rules.blockedApps.forEach((k, v) => blockedApps[k] = v.toIso8601String());

    return jsonEncode({
      'dailyLimitMs': rules.dailyLimitMs,
      'appLimits': rules.appLimits,
      'blockedApps': blockedApps,
      'allBlockedUntil': rules.allBlockedUntil?.toIso8601String(),
      'parentPinHash': rules.parentPinHash,
      'parentPinSalt': rules.parentPinSalt,
      'parentUnlockUntil': rules.parentUnlockUntil?.toIso8601String(),
      'updatedAt': rules.updatedAt?.toIso8601String(),
    });
  }

  static RuleModel _rulesFromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    DateTime? parseNullable(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final blockedApps = <String, DateTime>{};
    final rawBlocked = map['blockedApps'];
    if (rawBlocked is Map) {
      rawBlocked.forEach((k, v) {
        final dt = parseNullable(v);
        if (dt != null) blockedApps[k as String] = dt;
      });
    }

    final appLimits = <String, int>{};
    final rawApps = map['appLimits'];
    if (rawApps is Map) {
      rawApps.forEach((k, v) {
        appLimits[k as String] = (v as num).toInt();
      });
    }

    return RuleModel(
      dailyLimitMs: (map['dailyLimitMs'] as num?)?.toInt(),
      appLimits: appLimits,
      blockedApps: blockedApps,
      allBlockedUntil: parseNullable(map['allBlockedUntil']),
      parentPinHash: map['parentPinHash'] as String?,
      parentPinSalt: map['parentPinSalt'] as String?,
      parentUnlockUntil: parseNullable(map['parentUnlockUntil']),
      updatedAt: parseNullable(map['updatedAt']),
    );
  }
}
