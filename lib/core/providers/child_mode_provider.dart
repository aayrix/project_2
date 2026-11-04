import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/rule_cache_service.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/rule_model.dart';
import 'repository_providers.dart';
import 'family_provider.dart';

class ChildDeviceState {
  final bool isLinked;
  final String? familyId;
  final String? childId;
  final String? childName;
  final bool hasUsagePermission;
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final String? errorMessage;
  final RuleModel? currentRules;

  const ChildDeviceState({
    this.isLinked = false,
    this.familyId,
    this.childId,
    this.childName,
    this.hasUsagePermission = false,
    this.isSyncing = false,
    this.lastSyncTime,
    this.errorMessage,
    this.currentRules,
  });

  ChildDeviceState copyWith({
    bool? isLinked,
    String? familyId,
    String? childId,
    String? childName,
    bool? hasUsagePermission,
    bool? isSyncing,
    DateTime? lastSyncTime,
    String? errorMessage,
    RuleModel? currentRules,
  }) {
    return ChildDeviceState(
      isLinked: isLinked ?? this.isLinked,
      familyId: familyId ?? this.familyId,
      childId: childId ?? this.childId,
      childName: childName ?? this.childName,
      hasUsagePermission: hasUsagePermission ?? this.hasUsagePermission,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage,
      currentRules: currentRules ?? this.currentRules,
    );
  }
}

class ChildModeNotifier extends Notifier<ChildDeviceState> {
  @override
  ChildDeviceState build() {
    // Schedule asynchronous initialization after initial build
    Future.microtask(() => init());
    return const ChildDeviceState();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final familyId = prefs.getString(AppConstants.prefFamilyId);
    final childId = prefs.getString(AppConstants.prefChildId);
    final childName = prefs.getString(AppConstants.prefChildName);

    final hasPerm =
        await ref.read(nativeUsageServiceProvider).hasUsagePermission();

    final isLinked = familyId != null &&
        familyId.isNotEmpty &&
        childId != null &&
        childId.isNotEmpty;

    // Load cached rules for offline support
    RuleModel? cachedRules;
    if (isLinked) {
      cachedRules = await RuleCacheService.loadRules(
        familyId: familyId,
        childId: childId,
      );
      if (cachedRules != null) {
        debugPrint('RuleCacheService: loaded cached rules for child');
      }
    }

    state = state.copyWith(
      isLinked: isLinked,
      familyId: familyId,
      childId: childId,
      childName: childName,
      hasUsagePermission: hasPerm,
      currentRules: cachedRules,
    );

    if (isLinked) {
      // Start monitoring service if linked
      await ref.read(nativeUsageServiceProvider).startMonitoringService(
            childName: childName ?? 'Child',
            familyId: familyId,
            childId: childId,
          );
      // Run initial sync
      await syncUsageNow();
    }
  }

  /// Refreshes the usage permission status (e.g. after returning from settings).
  Future<bool> checkPermission() async {
    final hasPerm =
        await ref.read(nativeUsageServiceProvider).hasUsagePermission();
    state = state.copyWith(hasUsagePermission: hasPerm);
    return hasPerm;
  }

  /// Opens the native Android Usage Access Settings screen.
  Future<void> openSettings() async {
    await ref.read(nativeUsageServiceProvider).openUsageSettings();
  }

  /// Validates the 6-digit code, signs in anonymously, and links this device to the child profile.
  /// Order:
  ///   1. Sign in anonymously FIRST (required before any Firestore read/write).
  ///   2. Read linkCodes/{code} (get only).
  ///   3. Do NOT read the child document before linking.
  ///   4. ONE atomic batch: update child doc + delete linkCodes/{code}.
  ///   5. Write users/{deviceUid} (done inside linkChildDevice after the batch).
  Future<bool> linkWithCode(String code) async {
    state = state.copyWith(isSyncing: true, errorMessage: null);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final familyRepo = ref.read(familyRepositoryProvider);
      final nativeService = ref.read(nativeUsageServiceProvider);

      // 1a. Sign in anonymously FIRST.
      String deviceUid;
      try {
        final signedInUser = await authRepo.signInChildDevice();
        deviceUid = signedInUser.uid;
      } catch (_) {
        state = state.copyWith(
          isSyncing: false,
          errorMessage:
              'Unable to sign in. Please check your internet connection and try again.',
        );
        return false;
      }

      // 1b. Read linkCodes/{code} (get only).
      final trimmedCode = code.trim();
      final codeData = await familyRepo.getLinkCodeData(trimmedCode);
      if (codeData == null) {
        state = state.copyWith(
          isSyncing: false,
          errorMessage: 'Invalid or expired code.',
        );
        return false;
      }

      final familyId = codeData['familyId'] as String?;
      final childId = codeData['childId'] as String?;
      final expiresAt = codeData['expiresAt'];

      if (familyId == null || childId == null || expiresAt == null) {
        state = state.copyWith(
          isSyncing: false,
          errorMessage: 'Invalid or expired code.',
        );
        return false;
      }

      // Check expiry (rules also enforce server-side).
      if (expiresAt is Timestamp && DateTime.now().isAfter(expiresAt.toDate())) {
        state = state.copyWith(
          isSyncing: false,
          errorMessage: 'Invalid or expired code.',
        );
        return false;
      }

      // Get device model name.
      final deviceName = await nativeService.getDeviceModelName();

      // 1d. ONE atomic batch: update child doc + delete linkCodes/{code}.
      await familyRepo.linkChildDevice(
        familyId: familyId,
        childId: childId,
        childName: '', // filled after reading child doc post-link
        linkCode: trimmedCode,
        deviceUid: deviceUid,
        deviceName: deviceName,
      );

      // Read child name AFTER linking (rules allow read when deviceUid == request.auth.uid).
      String? childName;
      try {
        childName = await familyRepo.getChildName(familyId, childId);
      } catch (_) {
        childName = null;
      }

      // Persist child link info in SharedPreferences.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefUserRole, AppConstants.roleChild);
      await prefs.setString(AppConstants.prefFamilyId, familyId);
      await prefs.setString(AppConstants.prefChildId, childId);
      await prefs.setString(AppConstants.prefChildName, childName ?? '');

      // Start native monitoring notification & service.
      await nativeService.startMonitoringService(
        childName: childName ?? 'Child',
        familyId: familyId,
        childId: childId,
      );

      state = state.copyWith(
        isLinked: true,
        familyId: familyId,
        childId: childId,
        childName: childName,
        isSyncing: false,
        errorMessage: null,
      );

      // Initial sync.
      await syncUsageNow();
      return true;
    } on FirebaseException catch (e) {
      debugPrint('Firebase error linking device: $e');
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Invalid or expired code.',
      );
      return false;
    } catch (e) {
      debugPrint('Error linking device: $e');
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Failed to link device. Please try again.',
      );
      return false;
    }
  }

  /// Queries native UsageStats and uploads today's stats to Firestore.
  Future<void> syncUsageNow() async {
    final familyId = state.familyId;
    final childId = state.childId;

    if (familyId == null || childId == null) return;

    state = state.copyWith(isSyncing: true);

    try {
      final nativeService = ref.read(nativeUsageServiceProvider);
      final usageRepo = ref.read(usageRepositoryProvider);

      // Query native usage
      final apps = await nativeService.getTodayUsage();

      int totalMs = 0;
      for (final app in apps.values) {
        totalMs += app.ms;
      }

      final todayKey = AppDateUtils.formatDateKey(DateTime.now());

      await usageRepo.saveUsageDay(
        familyId: familyId,
        childId: childId,
        dateKey: todayKey,
        totalMs: totalMs,
        apps: apps,
      );

      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: DateTime.now(),
        errorMessage: null,
      );
    } catch (e) {
      debugPrint('Error syncing usage: $e');
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Sync error: $e',
      );
    }
  }

  /// Unlinks this device and clears local state (for testing or re-pairing).
  Future<void> unlinkDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefUserRole);
    await prefs.remove(AppConstants.prefFamilyId);
    await prefs.remove(AppConstants.prefChildId);
    await prefs.remove(AppConstants.prefChildName);

    state = const ChildDeviceState();
  }
}

final childModeProvider =
    NotifierProvider<ChildModeNotifier, ChildDeviceState>(ChildModeNotifier.new);

/// Exposes the current rules for the linked child (live from Firestore).
/// Use `childRulesCacheProvider` alongside it to cache changes locally.
final childCurrentRulesProvider =
    Provider.family<AsyncValue<RuleModel?>, ({String familyId, String childId})>(
        (ref, arg) {
  return ref.watch(childRulesStreamProvider(arg));
});
