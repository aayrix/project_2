import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream of Firebase Auth user changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently logged in Firebase User (or null if signed out).
  User? get currentUser => _auth.currentUser;

  /// Signs up a parent with email and password, and initializes their user profile in Firestore.
  Future<UserModel> signUpParent({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'USER_NULL',
        message: 'Registration succeeded but no user was returned.',
      );
    }

    // Update display name
    await user.updateDisplayName(name.trim());

    // Create user document in users/{uid}
    final userModel = UserModel(
      uid: user.uid,
      name: name.trim(),
      email: email.trim(),
      role: AppConstants.roleParent,
      familyId: null,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.colUsers)
        .doc(user.uid)
        .set(userModel.toMap());

    return userModel;
  }

  /// Logs in a parent with email and password.
  Future<UserModel> signInParent({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'USER_NULL',
        message: 'Sign in succeeded but no user was returned.',
      );
    }

    final userDoc = await getUserProfile(user.uid);
    if (userDoc == null) {
      // Create profile fallback if missing
      final newProfile = UserModel(
        uid: user.uid,
        name: user.displayName ?? 'Parent',
        email: user.email,
        role: AppConstants.roleParent,
        familyId: null,
        createdAt: DateTime.now(),
      );
      await saveUserProfile(newProfile);
      return newProfile;
    }

    return userDoc;
  }

  /// Signs in anonymously for a child device.
  Future<User> signInChildDevice() async {
    if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
      return _auth.currentUser!;
    }
    final credential = await _auth.signInAnonymously();
    return credential.user!;
  }

  /// Fetches user profile document from Firestore.
  Future<UserModel?> getUserProfile(String uid) async {
    final doc =
        await _firestore.collection(AppConstants.colUsers).doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  /// Saves or updates user profile in Firestore.
  Future<void> saveUserProfile(UserModel userModel) async {
    await _firestore
        .collection(AppConstants.colUsers)
        .doc(userModel.uid)
        .set(userModel.toMap(), SetOptions(merge: true));
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
