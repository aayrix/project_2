import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/child_model.dart';
import '../../data/models/rule_model.dart';
import '../../data/models/usage_day_model.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

/// Provides the current parent's familyId.
final currentFamilyIdProvider = FutureProvider<String?>((ref) async {
  final userProfile = await ref.watch(currentUserProfileProvider.future);
  if (userProfile == null) return null;

  if (userProfile.familyId != null && userProfile.familyId!.isNotEmpty) {
    return userProfile.familyId;
  }

  // Fallback: fetch or create family
  final familyRepo = ref.read(familyRepositoryProvider);
  final familyId = await familyRepo.getOrCreateFamily(userProfile);
  // Invalidate profile so it picks up the familyId
  ref.invalidate(currentUserProfileProvider);
  return familyId;
});

/// Streams the list of children belonging to the current parent's family.
final childrenStreamProvider = StreamProvider<List<ChildModel>>((ref) {
  final familyIdAsync = ref.watch(currentFamilyIdProvider);
  final familyId = familyIdAsync.value;

  if (familyId == null || familyId.isEmpty) {
    return const Stream.empty();
  }

  final familyRepo = ref.watch(familyRepositoryProvider);
  return familyRepo.streamChildren(familyId);
});

/// Streams a specific child profile by childId.
final childDetailStreamProvider =
    StreamProvider.family<ChildModel?, ({String familyId, String childId})>(
        (ref, arg) {
  final familyRepo = ref.watch(familyRepositoryProvider);
  return familyRepo.streamChild(arg.familyId, arg.childId);
});

/// Streams today's usage stats for a specific child.
final childTodayUsageStreamProvider =
    StreamProvider.family<UsageDayModel?, ({String familyId, String childId})>(
        (ref, arg) {
  final usageRepo = ref.watch(usageRepositoryProvider);
  return usageRepo.streamTodayUsage(
    familyId: arg.familyId,
    childId: arg.childId,
  );
});

/// Streams the rules/main document for a specific child.
final childRulesStreamProvider =
    StreamProvider.family<RuleModel?, ({String familyId, String childId})>(
        (ref, arg) {
  final usageRepo = ref.watch(usageRepositoryProvider);
  return usageRepo.streamRules(
    familyId: arg.familyId,
    childId: arg.childId,
  );
});

/// Controller for adding children and generating link codes.
class FamilyController extends AsyncNotifier<ChildModel?> {
  @override
  FutureOr<ChildModel?> build() {
    return null;
  }

  Future<ChildModel?> addChild({
    required String name,
    required int age,
  }) async {
    state = const AsyncValue.loading();
    try {
      final familyId = await ref.read(currentFamilyIdProvider.future);
      if (familyId == null) {
        throw Exception('Family not found for current parent.');
      }

      final familyRepo = ref.read(familyRepositoryProvider);
      final child = await familyRepo.addChild(
        familyId: familyId,
        name: name,
        age: age,
      );

      state = AsyncValue.data(child);
      return child;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<String?> regenerateLinkCode({
    required String familyId,
    required String childId,
    String? oldCode,
  }) async {
    try {
      final familyRepo = ref.read(familyRepositoryProvider);
      return await familyRepo.regenerateLinkCode(
        familyId: familyId,
        childId: childId,
        oldCode: oldCode,
      );
    } catch (e) {
      return null;
    }
  }
}

final familyControllerProvider =
    AsyncNotifierProvider<FamilyController, ChildModel?>(FamilyController.new);
