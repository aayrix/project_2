import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/repositories/usage_repository.dart';
import '../../data/services/native_usage_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository();
});

final usageRepositoryProvider = Provider<UsageRepository>((ref) {
  return UsageRepository();
});

final nativeUsageServiceProvider = Provider<NativeUsageService>((ref) {
  return NativeUsageService();
});
