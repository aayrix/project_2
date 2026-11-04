import 'package:cloud_firestore/cloud_firestore.dart';

/// Screen-time limits and blocks for a child, stored in
/// families/{familyId}/children/{childId}/rules/main.
///
/// The parent writes all fields except `extraTimeUntil`, which is also
/// parent-only (written via "Give 15 more minutes" from the parent app).
/// The child device reads rules/main but never writes PIN-related data.
class RuleModel {
  /// Total phone screen time allowed per day in ms, or null for unlimited.
  final int? dailyLimitMs;

  /// Per-app daily limits in ms: packageName -> ms.
  final Map<String, int> appLimits;

  /// Apps blocked until a given Timestamp: packageName -> Timestamp.
  /// "Block for today" = end of today in the device's local time.
  final Map<String, DateTime> blockedApps;

  /// Blocks everything except the always-allowed list, until this Timestamp.
  /// null means phone-wide block is off.
  final DateTime? allBlockedUntil;

  /// Extra time granted by parent ("Give 15 more minutes"), stored in
  /// rules/main by the parent app. The child reads this for offline fallback
  /// when the local PIN unlock has expired.
  final DateTime? extraTimeUntil;

  final DateTime? updatedAt;

  RuleModel({
    this.dailyLimitMs,
    this.appLimits = const {},
    this.blockedApps = const {},
    this.allBlockedUntil,
    this.extraTimeUntil,
    this.updatedAt,
  });

  factory RuleModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseNullable(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return RuleModel(
      dailyLimitMs: (map['dailyLimitMs'] as num?)?.toInt(),
      appLimits: (map['appLimits'] as Map<String, dynamic>?)
          ?.map((key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0)) ??
          {},
      blockedApps: (map['blockedApps'] as Map<String, dynamic>?)
          ?.map((key, value) {
        final dt = parseNullable(value);
        return MapEntry(key, dt ?? DateTime.now());
      }) ?? {},
      allBlockedUntil: parseNullable(map['allBlockedUntil']),
      extraTimeUntil: parseNullable(map['extraTimeUntil']),
      updatedAt: parseNullable(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dailyLimitMs': dailyLimitMs,
      'appLimits': appLimits,
      'blockedApps': blockedApps.map((key, value) =>
          MapEntry(key, Timestamp.fromDate(value))),
      'allBlockedUntil':
          allBlockedUntil != null ? Timestamp.fromDate(allBlockedUntil!) : null,
      'extraTimeUntil':
          extraTimeUntil != null ? Timestamp.fromDate(extraTimeUntil!) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  RuleModel copyWith({
    int? dailyLimitMs,
    Map<String, int>? appLimits,
    Map<String, DateTime>? blockedApps,
    DateTime? allBlockedUntil,
    DateTime? extraTimeUntil,
  }) {
    return RuleModel(
      dailyLimitMs: dailyLimitMs ?? this.dailyLimitMs,
      appLimits: appLimits ?? this.appLimits,
      blockedApps: blockedApps ?? this.blockedApps,
      allBlockedUntil: allBlockedUntil ?? this.allBlockedUntil,
      extraTimeUntil: extraTimeUntil ?? this.extraTimeUntil,
    );
  }
}
