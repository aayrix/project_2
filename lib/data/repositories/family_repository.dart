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

  /// Generates a random 6-digit code string (from 100000 to 999999).
  String generateSixDigitCode() {
    final random = Random();
    final number = 100000 + random.nextInt(900000);
    return number.toString();
  }

  /// Adds a new child profile to the parent's family with an initial 24h 6-digit link code.
  /// Also registers the code in the top-level linkCodes/{code} collection for secure single-doc lookup.
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

    // 1. Create child document in families/{familyId}/children/{childId}
    await childRef.set(child.toMap());

    // 2. Create index document in linkCodes/{code}
    await _firestore.collection(AppConstants.colLinkCodes).doc(linkCode).set({
      'familyId': familyId,
      'childId': childRef.id,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return child;
  }

  /// Regenerates an expired or lost 6-digit link code for a child.
  Future<String> regenerateLinkCode({
    required String familyId,
    required String childId,
    String? oldCode,
  }) async {
    final newCode = generateSixDigitCode();
    final newExpires = DateTime.now().add(AppConstants.linkCodeValidity);

    // Clean up old code index if present
    if (oldCode != null && oldCode.isNotEmpty) {
      try {
        await _firestore.collection(AppConstants.colLinkCodes).doc(oldCode).delete();
      } catch (_) {}
    }

    // Update child document
    await _firestore
        .collection(AppConstants.colFamilies)
        .doc(familyId)
        .collection(AppConstants.colChildren)
        .doc(childId)
        .update({
      'linkCode': newCode,
      'linkCodeExpiresAt': Timestamp.fromDate(newExpires),
    });

    // Create new code index in linkCodes/{newCode}
    await _firestore.collection(AppConstants.colLinkCodes).doc(newCode).set({
      'familyId': familyId,
      'childId': childId,
      'expiresAt': Timestamp.fromDate(newExpires),
      'createdAt': FieldValue.serverTimestamp(),
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

  /// Reads linkCodes/{code} (get only). Returns the code document data or null.
  /// Does NOT read the child document — the rules only allow the child device to
  /// read it after deviceUid is set to its own uid.
  Future<Map<String, dynamic>?> getLinkCodeData(String code) async {
    final trimmedCode = code.trim();
    if (trimmedCode.length != 6) return null;

    final codeDoc = await _firestore
        .collection(AppConstants.colLinkCodes)
        .doc(trimmedCode)
        .get();

    if (!codeDoc.exists || codeDoc.data() == null) {
      return null;
    }

    return codeDoc.data()!;
  }

  /// Links a child's device UID and device name to the child profile.
  /// Performs the child-document update and linkCodes/{code} delete in ONE
  /// atomic WriteBatch, then writes users/{deviceUid} as a child record.
  /// The child-document update changes only: deviceUid, deviceName, linkedAt, lastSeen.
  Future<void> linkChildDevice({
    required String familyId,
    required String childId,
    required String childName,
    required String linkCode,
    required String deviceUid,
    required String deviceName,
  }) async {
    final now = DateTime.now();
    final batch = _firestore.batch();

    // 1. Update child document — only these four fields.
    final childRef = _firestore
        .collection(AppConstants.colFamilies)
        .doc(familyId)
        .collection(AppConstants.colChildren)
        .doc(childId);

    batch.update(childRef, {
      'deviceUid': deviceUid,
      'deviceName': deviceName,
      'linkedAt': Timestamp.fromDate(now),
      'lastSeen': Timestamp.fromDate(now),
    });

    // 2. Delete consumed linkCodes/{code} in the same batch.
    batch.delete(_firestore.collection(AppConstants.colLinkCodes).doc(linkCode.trim()));

    await batch.commit();

    // 3. Write child user record in users/{uid} (after the batch succeeds).
    final childUser = UserModel(
      uid: deviceUid,
      name: childName,
      email: null,
      photoUrl: null,
      role: AppConstants.roleChild,
      familyId: familyId,
      createdAt: now,
    );

    await _firestore
        .collection(AppConstants.colUsers)
        .doc(deviceUid)
        .set(childUser.toMap(), SetOptions(merge: true));
  }

  /// Reads the child's name from the child document AFTER linking succeeds.
  /// The rules allow this read once deviceUid == request.auth.uid.
  Future<String?> getChildName(String familyId, String childId) async {
    final childDoc = await _firestore
        .collection(AppConstants.colFamilies)
        .doc(familyId)
        .collection(AppConstants.colChildren)
        .doc(childId)
        .get();

    if (!childDoc.exists || childDoc.data() == null) {
      return null;
    }

    return childDoc.data()!['name'] as String?;
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
