import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../models/app_usage_model.dart';
import '../models/usage_day_model.dart';

class UsageRepository {
  final FirebaseFirestore _firestore;

  UsageRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Uploads or merges usage stats for a specific day.
  Future<void> saveUsageDay({
    required String familyId,
    required String childId,
    required String dateKey,
    required int totalMs,
    required Map<String, AppUsageModel> apps,
  }) async {
    final rawApps = <String, dynamic>{};
    apps.forEach((key, val) {
      rawApps[key] = val.toMap();
    });

    final usageDocRef = _firestore
        .collection(AppConstants.colFamilies)
        .doc(familyId)
        .collection(AppConstants.colChildren)
        .doc(childId)
        .collection(AppConstants.colUsageDays)
        .doc(dateKey);

    await usageDocRef.set({
      'totalMs': totalMs,
      'updatedAt': FieldValue.serverTimestamp(),
      'apps': rawApps,
    }, SetOptions(merge: true));

    // Also update lastSeen on the child profile document
    await _firestore
        .collection(AppConstants.colFamilies)
        .doc(familyId)
        .collection(AppConstants.colChildren)
        .doc(childId)
        .update({
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Streams real-time usage stats for today.
  Stream<UsageDayModel?> streamTodayUsage({
    required String familyId,
    required String childId,
  }) {
    final todayKey = AppDateUtils.formatDateKey(DateTime.now());
    return _firestore
        .collection(AppConstants.colFamilies)
        .doc(familyId)
        .collection(AppConstants.colChildren)
        .doc(childId)
        .collection(AppConstants.colUsageDays)
        .doc(todayKey)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UsageDayModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// One-time fetch of today's usage stats.
  Future<UsageDayModel?> getTodayUsage({
    required String familyId,
    required String childId,
  }) async {
    final todayKey = AppDateUtils.formatDateKey(DateTime.now());
    final doc = await _firestore
        .collection(AppConstants.colFamilies)
        .doc(familyId)
        .collection(AppConstants.colChildren)
        .doc(childId)
        .collection(AppConstants.colUsageDays)
        .doc(todayKey)
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return UsageDayModel.fromMap(doc.data()!, doc.id);
  }
}
