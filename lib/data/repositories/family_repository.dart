import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../models/child_model.dart';
import '../models/user_model.dart';

class LinkCodeResult {
  final String familyId;
  final ChildModel child;

  LinkCodeResult({required this.familyId, required this.child});
}

class FamilyRepository {
  final FirebaseFirestore _firestore;

  FamilyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Ensures a family exists for the parent. If none exists, creates one and links it to the user.
  Future<String> getOrCreateFamily(UserModel parentUser) async {
    // 1. If user already has familyId recorded, check if document exists
    if (parentUser.familyId != null && parentUser.familyId!.isNotEmpty) {
      final existingDoc = await _firestore
          .collection(AppConstants.colFamilies)
          .doc(parentUser.familyId)
          .get();
      if (existingDoc.exists) {
        return parentUser.familyId!;
      }
    }

    // 2. Query families by parentUid in case user doc didn't store it
    final query = await _firestore
        .collection(AppConstants.colFamilies)
        .where('parentUid', isEqualTo: parentUser.uid)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final familyId = query.docs.first.id;
      // Update user document
      await _firestore
          .collection(AppConstants.colUsers)
          .doc(parentUser.uid)
          .update({'familyId': familyId});
      return familyId;
    }

    // 3. Otherwise, create a new family document
    final newFamilyRef = _firestore.collection(AppConstants.colFamilies).doc();
    await newFamilyRef.set({
      'parentUid': parentUser.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Link familyId to parent's user doc
    await _firestore
        .collection(AppConstants.colUsers)
        .doc(parentUser.uid)
        .set({'familyId': newFamilyRef.id}, SetOptions(merge: true));

    return newFamilyRef.id;
  }

  /// Generates a random 6-digit code string.
  String generateSixDigitCode() {
    final random = Random();
    final number = 100000 + random.nextInt(900000);
    return number.toString();
  }

  /// Adds a new child profile to the parent's family with an initial 24h 6-digit link code.
  Future<ChildModel> addChild({
    required String familyId,
    required String name,
    required int age,
  }) async {
    final linkCode = generateSixDigitCode();
    final expiresAt = DateTime.now().add(AppConstants.linkCodeValidity);

    final childRef = _firestore
        .collection(AppConstants.colFamilies)
        .doc(familyId)
        .collection(AppConstants.colChildren)
        .doc();

    final child = ChildModel(
      id: childRef.id,
      name: name.trim(),
      age: age,
      linkCode: linkCode,
      linkCodeExpiresAt: expiresAt,
      deviceUid: null,
      deviceName: null,
      linkedAt: null,
      lastSeen: null,
    );

    await childRef.set(child.toMap());
    return child;
  }

  /// Regenerates an expired or lost 6-digit link code for a child.
  Future<String> regenerateLinkCode({
    required String familyId,
    required String childId,
  }) async {
    final newCode = generateSixDigitCode();
    final newExpires = DateTime.now().add(AppConstants.linkCodeValidity);

    await _firestore
        .collection(AppConstants.colFamilies)
        .doc(familyId)
        .collection(AppConstants.colChildren)
        .doc(childId)
        .update({
      'linkCode': newCode,
      'linkCodeExpiresAt': Timestamp.fromDate(newExpires),
    });

    return newCode;
  }

  /// Streams the list of children for a given family in real time.
  Stream<List<ChildModel>> streamChildren(String familyId) {
    return _firestore
        .collection(AppConstants.colFamilies)
        .doc(familyId)
        .collection(AppConstants.colChildren)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ChildModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Streams a single child's profile in real time.
  Stream<ChildModel?> streamChild(String familyId, String childId) {
    return _firestore
        .collection(AppConstants.colFamilies)
        .doc(familyId)
        .collection(AppConstants.colChildren)
        .doc(childId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ChildModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// Finds a child profile by link code across all family trees using collectionGroup query.
  Future<LinkCodeResult?> findChildByLinkCode(String code) async {
    final trimmed = code.trim();
    final snapshot = await _firestore
        .collectionGroup(AppConstants.colChildren)
        .where('linkCode', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final doc = snapshot.docs.first;
    final child = ChildModel.fromMap(doc.data(), doc.id);

    // Extract familyId from doc.reference.parent.parent (families/{familyId})
    final familyRef = doc.reference.parent.parent;
    if (familyRef == null) {
      return null;
    }

    return LinkCodeResult(
      familyId: familyRef.id,
      child: child,
    );
  }

  /// Links a child's device UID and device name to the child profile.
  Future<void> linkChildDevice({
    required String familyId,
    required String childId,
    required String childName,
    required String deviceUid,
    required String deviceName,
  }) async {
    final now = DateTime.now();

    // 1. Update child document
    await _firestore
        .collection(AppConstants.colFamilies)
        .doc(familyId)
        .collection(AppConstants.colChildren)
        .doc(childId)
        .update({
      'deviceUid': deviceUid,
      'deviceName': deviceName,
      'linkedAt': Timestamp.fromDate(now),
      'lastSeen': Timestamp.fromDate(now),
    });

    // 2. Create/update child user record in users/{uid}
    final childUser = UserModel(
      uid: deviceUid,
      name: childName,
      email: null,
      role: AppConstants.roleChild,
      familyId: familyId,
      createdAt: now,
    );

    await _firestore
        .collection(AppConstants.colUsers)
        .doc(deviceUid)
        .set(childUser.toMap(), SetOptions(merge: true));
  }

  /// Updates the lastSeen timestamp when child device checks in.
  Future<void> updateLastSeen({
    required String familyId,
    required String childId,
  }) async {
    await _firestore
        .collection(AppConstants.colFamilies)
        .doc(familyId)
        .collection(AppConstants.colChildren)
        .doc(childId)
        .update({
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
}
