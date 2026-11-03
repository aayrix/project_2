import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class CategoryMapper {
  /// Known package names mapped to standard categories.
  static const Map<String, String> _knownPackages = {
    // Video
    'com.google.android.youtube': AppConstants.categoryVideo,
    'com.google.android.apps.youtube.kids': AppConstants.categoryVideo,
    'com.netflix.mediaclient': AppConstants.categoryVideo,
    'com.disney.disneyplus': AppConstants.categoryVideo,
    'tv.twitch.android.app': AppConstants.categoryVideo,
    'com.amazon.avod.thirdpartyclient': AppConstants.categoryVideo,

    // Social
    'com.instagram.android': AppConstants.categorySocial,
    'com.facebook.katana': AppConstants.categorySocial,
    'com.facebook.orca': AppConstants.categoryCommunication,
    'com.facebook.lite': AppConstants.categorySocial,
    'com.zhiliaoapp.musically': AppConstants.categorySocial,
    'com.ss.android.ugc.trill': AppConstants.categorySocial,
    'com.twitter.android': AppConstants.categorySocial,
    'com.snapchat.android': AppConstants.categorySocial,
    'com.reddit.frontpage': AppConstants.categorySocial,
    'com.pinterest': AppConstants.categorySocial,

    // Communication
    'com.whatsapp': AppConstants.categoryCommunication,
    'com.whatsapp.w4b': AppConstants.categoryCommunication,
    'org.telegram.messenger': AppConstants.categoryCommunication,
    'com.discord': AppConstants.categoryCommunication,
    'com.google.android.apps.messaging': AppConstants.categoryCommunication,
    'com.google.android.dialer': AppConstants.categoryCommunication,
    'com.viber.voip': AppConstants.categoryCommunication,

    // Browsing
    'com.android.chrome': AppConstants.categoryBrowsing,
    'org.mozilla.firefox': AppConstants.categoryBrowsing,
    'com.microsoft.emmx': AppConstants.categoryBrowsing,
    'com.brave.browser': AppConstants.categoryBrowsing,
    'com.opera.browser': AppConstants.categoryBrowsing,
    'com.opera.mini.native': AppConstants.categoryBrowsing,

    // Education
    'com.duolingo': AppConstants.categoryEducation,
    'org.khanacademy.android': AppConstants.categoryEducation,
    'com.google.android.apps.classroom': AppConstants.categoryEducation,
    'com.photomath.android': AppConstants.categoryEducation,
    'com.quizlet.quizletandroid': AppConstants.categoryEducation,

    // Games (common examples)
    'com.kiloo.subwaysurf': AppConstants.categoryGames,
    'com.roblox.client': AppConstants.categoryGames,
    'com.mojang.minecraftpe': AppConstants.categoryGames,
    'com.king.candycrushsaga': AppConstants.categoryGames,
    'com.supercell.clashofclans': AppConstants.categoryGames,
    'com.supercell.brawlstars': AppConstants.categoryGames,
  };

  /// Resolves the category for a given packageName, with optional Android native category fallback.
  static String resolveCategory(String packageName, [int? androidCategory]) {
    final normalized = packageName.trim().toLowerCase();
    if (_knownPackages.containsKey(normalized)) {
      return _knownPackages[normalized]!;
    }

    // Android ApplicationInfo.category fallback
    // 0: CATEGORY_GAME, 1: CATEGORY_AUDIO, 2: CATEGORY_VIDEO,
    // 3: CATEGORY_IMAGE, 4: CATEGORY_SOCIAL, 5: CATEGORY_NEWS,
    // 6: CATEGORY_MAPS, 7: CATEGORY_PRODUCTIVITY
    if (androidCategory != null) {
      switch (androidCategory) {
        case 0:
          return AppConstants.categoryGames;
        case 1:
        case 2:
          return AppConstants.categoryVideo;
        case 4:
          return AppConstants.categorySocial;
        case 5:
          return AppConstants.categoryBrowsing;
        case 7:
          return AppConstants.categoryOther;
        default:
          return AppConstants.categoryOther;
      }
    }

    return AppConstants.categoryOther;
  }

  /// Returns user-friendly capitalized category title.
  static String categoryDisplayName(String category) {
    switch (category) {
      case AppConstants.categoryVideo:
        return 'Video & Streaming';
      case AppConstants.categorySocial:
        return 'Social Media';
      case AppConstants.categoryBrowsing:
        return 'Browsing';
      case AppConstants.categoryGames:
        return 'Gaming';
      case AppConstants.categoryEducation:
        return 'Education';
      case AppConstants.categoryCommunication:
        return 'Communication';
      default:
        return 'Other';
    }
  }

  /// Returns an icon corresponding to the app category.
  static IconData categoryIcon(String category) {
    switch (category) {
      case AppConstants.categoryVideo:
        return Icons.play_circle_fill_rounded;
      case AppConstants.categorySocial:
        return Icons.people_alt_rounded;
      case AppConstants.categoryBrowsing:
        return Icons.public_rounded;
      case AppConstants.categoryGames:
        return Icons.sports_esports_rounded;
      case AppConstants.categoryEducation:
        return Icons.school_rounded;
      case AppConstants.categoryCommunication:
        return Icons.chat_bubble_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  /// Returns a distinctive color for the app category.
  static Color categoryColor(String category) {
    switch (category) {
      case AppConstants.categoryVideo:
        return const Color(0xFFE53935); // Crimson
      case AppConstants.categorySocial:
        return const Color(0xFF8E24AA); // Purple
      case AppConstants.categoryBrowsing:
        return const Color(0xFF1E88E5); // Blue
      case AppConstants.categoryGames:
        return const Color(0xFFFB8C00); // Orange
      case AppConstants.categoryEducation:
        return const Color(0xFF43A047); // Green
      case AppConstants.categoryCommunication:
        return const Color(0xFF00ACC1); // Cyan
      default:
        return const Color(0xFF5E35B1); // Deep Indigo
    }
  }
}
