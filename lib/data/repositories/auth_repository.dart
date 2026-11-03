import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  bool _isGoogleSignInInitialized = false;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream of Firebase Auth user changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently logged in Firebase User (or null if signed out).
  User? get currentUser => _auth.currentUser;

  /// Initializes GoogleSignIn plugin (required in google_sign_in 7.x).
  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await GoogleSignIn.instance.initialize();
      _isGoogleSignInInitialized = true;
    }
  }

  /// Signs in a parent using Google Sign-In and creates their profile in users/{uid} on first sign-in.
  Future<UserModel?> signInParentWithGoogle() async {
    await _ensureGoogleSignInInitialized();

    try {
      final GoogleSignInAccount googleAccount =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth = googleAccount.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final User? user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'USER_NULL',
          message: 'Google Sign-In completed but no Firebase user was returned.',
        );
      }

      // Check if user record exists in users/{uid}
      final existingProfile = await getUserProfile(user.uid);
      if (existingProfile != null) {
        return existingProfile;
      }

      // First time sign-in: create user profile
      final newProfile = UserModel(
        uid: user.uid,
        name: user.displayName ?? googleAccount.displayName ?? 'Parent',
        email: user.email,
        photoUrl: user.photoURL ?? googleAccount.photoUrl,
        role: AppConstants.roleParent,
        familyId: null,
        createdAt: DateTime.now(),
      );

      await saveUserProfile(newProfile);
      return newProfile;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // User deliberately dismissed the Google account picker
        return null;
      }
      rethrow;
    }
  }

  /// Signs in anonymously for a child device.
  Future<User> signInChildDevice() async {
    if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
      return _auth.currentUser!;
    }
    final credential = await _auth.signInAnonymously();
    return credential.user!;
  }

  /// Fetches user profile document from users/{uid}.
  Future<UserModel?> getUserProfile(String uid) async {
    final doc =
        await _firestore.collection(AppConstants.colUsers).doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  /// Saves or updates user profile in users/{uid}.
  Future<void> saveUserProfile(UserModel userModel) async {
    await _firestore
        .collection(AppConstants.colUsers)
        .doc(userModel.uid)
        .set(userModel.toMap(), SetOptions(merge: true));
  }

  /// Signs out both Google and Firebase sessions.
  Future<void> signOut() async {
    try {
      await _ensureGoogleSignInInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Ignore if not initialized
    }
    await _auth.signOut();
  }
}
