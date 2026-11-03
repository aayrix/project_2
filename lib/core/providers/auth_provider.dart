import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';
import '../constants/app_constants.dart';
import 'repository_providers.dart';

/// Stream of auth state changes from Firebase Auth.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Fetches the profile of the currently signed-in user.
final currentUserProfileProvider = FutureProvider<UserModel?>((ref) async {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return null;

  final authRepo = ref.watch(authRepositoryProvider);
  return await authRepo.getUserProfile(authUser.uid);
});

/// Persisted user role ("parent" | "child" | null) stored in SharedPreferences.
final persistedRoleProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(AppConstants.prefUserRole);
});

/// Controller handling Google Sign-In and sign-out operations.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    return null;
  }

  Future<bool> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final user = await authRepo.signInParentWithGoogle();

      if (user == null) {
        // User cancelled sign in
        state = const AsyncValue.data(null);
        return false;
      }

      // Persist parent role
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefUserRole, AppConstants.roleParent);

      // Automatically create or fetch family for the parent
      final familyRepo = ref.read(familyRepositoryProvider);
      await familyRepo.getOrCreateFamily(user);

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.prefUserRole);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
