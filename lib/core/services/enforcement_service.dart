import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';

/// Dart-side bridge to the native enforcement (AccessibilityService + LockActivity).
class EnforcementService {
  static const MethodChannel _channel =
      MethodChannel(AppConstants.methodChannelName);

  /// Checks whether the AccessibilityService is currently enabled on the device.
  Future<bool> isAccessibilityEnabled() async {
    try {
      final bool? enabled =
          await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return enabled ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking accessibility: ${e.message}');
      return false;
    }
  }

  /// Opens the system Accessibility settings so the user can enable the service.
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint('Failed to open accessibility settings: ${e.message}');
    }
  }

  /// Tells the native side that enforcement should be active.
  /// The native AccessibilityService reads cached rules directly from
  /// SharedPreferences, so no data needs to be passed here.
  Future<void> startEnforcement() async {
    try {
      await _channel.invokeMethod('startEnforcement');
    } on PlatformException catch (e) {
      debugPrint('Failed to start enforcement: ${e.message}');
    }
  }

  /// Tells the native side to stop enforcement.
  Future<void> stopEnforcement() async {
    try {
      await _channel.invokeMethod('stopEnforcement');
    } on PlatformException catch (e) {
      debugPrint('Failed to stop enforcement: ${e.message}');
    }
  }
}

final enforcementService = EnforcementService();
