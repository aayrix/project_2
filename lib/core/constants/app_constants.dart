class AppConstants {
  // App Info
  static const String appName = 'Orbit Family';
  static const String appTagline = 'Freedom within a circle.';

  // Firestore Collections
  static const String colUsers = 'users';
  static const String colFamilies = 'families';
  static const String colChildren = 'children';
  static const String colUsageDays = 'usageDays';
  static const String colRules = 'rules';
  static const String colLinkCodes = 'linkCodes';

  // Child Rules document
  static const String docMainRule = 'main';

  // User Roles
  static const String roleParent = 'parent';
  static const String roleChild = 'child';

  // App Categories
  static const String categoryVideo = 'video';
  static const String categorySocial = 'social';
  static const String categoryBrowsing = 'browsing';
  static const String categoryGames = 'games';
  static const String categoryEducation = 'education';
  static const String categoryCommunication = 'communication';
  static const String categoryOther = 'other';

  // Link code expiration duration (15 minutes)
  static const Duration linkCodeValidity = Duration(minutes: 15);

  // SharedPreferences Keys
  static const String prefUserRole = 'user_role';
  static const String prefFamilyId = 'linked_family_id';
  static const String prefChildId = 'linked_child_id';
  static const String prefChildName = 'linked_child_name';

  // MethodChannel
  static const String methodChannelName = 'com.orbitfamily.app/usage';

  // Always-allowed apps (never blocked by enforcement).
  // Must match the list in EnforcementAccessibilityService.kt.
  static const List<String> alwaysAllowedPackages = [
    'com.orbitfamily.app', // Orbit Family itself
    'com.android.systemui', // System UI
    'com.android.settings', // Settings (so child is not stuck)
    'com.android.server.telecom', // Phone/dialer
    'com.android.incallui', // In-call UI
  ];
}
