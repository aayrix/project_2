import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_usage_model.dart';

class UsageDayModel {
  final String dateKey; // e.g. "2026-11-04"
  final int totalMs;
  final DateTime updatedAt;
  final Map<String, AppUsageModel> apps;

  UsageDayModel({
    required this.dateKey,
    required this.totalMs,
    required this.updatedAt,
    required this.apps,
  });

  /// Returns apps sorted by usage time in descending order.
  List<AppUsageModel> get sortedApps {
    final list = apps.values.toList();
    list.sort((a, b) => b.ms.compareTo(a.ms));
    return list;
  }

  factory UsageDayModel.fromMap(Map<String, dynamic> map, String dateKey) {
    DateTime parsedUpdated;
    if (map['updatedAt'] is Timestamp) {
      parsedUpdated = (map['updatedAt'] as Timestamp).toDate();
    } else if (map['updatedAt'] is String) {
      parsedUpdated = DateTime.tryParse(map['updatedAt']) ?? DateTime.now();
    } else {
      parsedUpdated = DateTime.now();
    }

    final rawApps = map['apps'] as Map<String, dynamic>? ?? {};
    final appsMap = <String, AppUsageModel>{};

    rawApps.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        appsMap[key] = AppUsageModel.fromMap(key, val);
      }
    });

    return UsageDayModel(
      dateKey: dateKey,
      totalMs: (map['totalMs'] as num?)?.toInt() ?? 0,
      updatedAt: parsedUpdated,
      apps: appsMap,
    );
  }

  Map<String, dynamic> toMap() {
    final rawApps = <String, dynamic>{};
    apps.forEach((key, val) {
      rawApps[key] = val.toMap();
    });

    return {
      'totalMs': totalMs,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'apps': rawApps,
    };
  }
}
