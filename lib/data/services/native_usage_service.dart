import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/category_mapper.dart';
import '../models/app_usage_model.dart';

class NativeUsageService {
  static const MethodChannel _channel =
      MethodChannel(AppConstants.methodChannelName);

  /// Checks if the PACKAGE_USAGE_STATS permission has been granted by the user.
  Future<bool> hasUsagePermission() async {
    try {
      final bool? hasPermission =
          await _channel.invokeMethod<bool>('hasUsagePermission');
      return hasPermission ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Opens Android's native "Apps with Usage Access" settings screen.
  Future<void> openUsageSettings() async {
    try {
      await _channel.invokeMethod('openUsageSettings');
    } on PlatformException catch (e) {
      debugPrint('Failed to open usage settings: ${e.message}');
    }
  }

  /// Queries native UsageStatsManager for today's foreground app usage (midnight to now).
  Future<Map<String, AppUsageModel>> getTodayUsage() async {
    try {
      final List<dynamic>? rawList =
          await _channel.invokeMethod<List<dynamic>>('getTodayUsage');

      if (rawList == null) return {};

      final Map<String, AppUsageModel> apps = {};
      for (final item in rawList) {
        if (item is Map) {
          final packageName = item['packageName'] as String? ?? '';
          if (packageName.isEmpty) continue;

          final appName = item['appName'] as String? ?? packageName;
          final ms = (item['ms'] as num?)?.toInt() ?? 0;
          final androidCategory = (item['category'] as num?)?.toInt();

          final resolvedCategory =
              CategoryMapper.resolveCategory(packageName, androidCategory);

          apps[packageName] = AppUsageModel(
            packageName: packageName,
            appName: appName,
            category: resolvedCategory,
            ms: ms,
          );
        }
      }

      return apps;
    } on PlatformException catch (e) {
      debugPrint('Error querying today usage: ${e.message}');
      return {};
    }
  }

  /// Starts the persistent foreground notification and schedules periodic WorkManager sync.
  Future<void> startMonitoringService({
    required String childName,
    required String familyId,
    required String childId,
  }) async {
    try {
      await _channel.invokeMethod('startMonitoringService', {
        'childName': childName,
        'familyId': familyId,
        'childId': childId,
      });
    } on PlatformException catch (e) {
      debugPrint('Error starting monitoring service: ${e.message}');
    }
  }

  /// Returns the Android device model/brand name for friendly device naming.
  Future<String> getDeviceModelName() async {
    try {
      final String? name =
          await _channel.invokeMethod<String>('getDeviceModelName');
      return name ?? 'Android Device';
    } on PlatformException catch (_) {
      return 'Android Device';
    }
  }
}
