import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import 'repository_providers.dart';

class ChildDeviceState {
  final bool isLinked;
  final String? familyId;
  final String? childId;
  final String? childName;
  final bool hasUsagePermission;
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final String? errorMessage;

  const ChildDeviceState({
    this.isLinked = false,
    this.familyId,
    this.childId,
    this.childName,
    this.hasUsagePermission = false,
    this.isSyncing = false,
    this.lastSyncTime,
    this.errorMessage,
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

    state = state.copyWith(
      isLinked: isLinked,
      familyId: familyId,
      childId: childId,
      childName: childName,
      hasUsagePermission: hasPerm,
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
  Future<bool> linkWithCode(String code) async {
    state = state.copyWith(isSyncing: true, errorMessage: null);

    try {
      final familyRepo = ref.read(familyRepositoryProvider);
      final authRepo = ref.read(authRepositoryProvider);
      final nativeService = ref.read(nativeUsageServiceProvider);

      // 1. Find child profile by linkCode
      final result = await familyRepo.findChildByLinkCode(code.trim());
      if (result == null) {
        state = state.copyWith(
          isSyncing: false,
          errorMessage: 'Invalid code. Please verify the code with your parent.',
        );
        return false;
      }

      final child = result.child;
      final familyId = result.familyId;

      // 2. Check if expired
      if (child.isCodeExpired) {
        state = state.copyWith(
          isSyncing: false,
          errorMessage: 'This code has expired. Ask your parent to generate a new one.',
        );
        return false;
      }

      // 3. Check if already linked to another device
      if (child.isLinked) {
        state = state.copyWith(
          isSyncing: false,
          errorMessage: 'This child profile is already linked to another device.',
        );
        return false;
      }

      // 4. Anonymous sign in
      final childUser = await authRepo.signInChildDevice();

      // 5. Get device model name
      final deviceName = await nativeService.getDeviceModelName();

      // 6. Link device in Firestore
      await familyRepo.linkChildDevice(
        familyId: familyId,
        childId: child.id,
        childName: child.name,
        deviceUid: childUser.uid,
        deviceName: deviceName,
      );

      // 7. Persist child link info in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefUserRole, AppConstants.roleChild);
      await prefs.setString(AppConstants.prefFamilyId, familyId);
      await prefs.setString(AppConstants.prefChildId, child.id);
      await prefs.setString(AppConstants.prefChildName, child.name);

      // 8. Start native monitoring notification & service
      await nativeService.startMonitoringService(
        childName: child.name,
        familyId: familyId,
        childId: child.id,
      );

      state = state.copyWith(
        isLinked: true,
        familyId: familyId,
        childId: child.id,
        childName: child.name,
        isSyncing: false,
        errorMessage: null,
      );

      // 9. Initial sync
      await syncUsageNow();
      return true;
    } catch (e) {
      debugPrint('Error linking device: $e');
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Failed to link device: ${e.toString()}',
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
