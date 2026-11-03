import 'package:intl/intl.dart';

class AppDateUtils {
  /// Returns date formatted as 'yyyy-MM-dd' for Firestore document IDs.
  static String formatDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Converts milliseconds into human-readable duration, e.g. "2h 15m" or "42m".
  static String formatDurationMs(int totalMs) {
    if (totalMs <= 0) return '0m';

    final totalSeconds = totalMs ~/ 1000;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final hours = totalSeconds ~/ 3600;

    if (hours > 0) {
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h';
    }
    if (minutes > 0) {
      return '${minutes}m';
    }
    return '< 1m';
  }

  /// Returns friendly relative time string (e.g. "Just now", "10m ago", "Yesterday at 4:30 PM").
  static String formatLastSeen(DateTime? dateTime) {
    if (dateTime == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24 && dateTime.day == now.day) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1 || (difference.inHours < 48 && dateTime.day == now.subtract(const Duration(days: 1)).day)) {
      return 'Yesterday at ${DateFormat('h:mm a').format(dateTime)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  /// Returns the start of today (midnight 00:00:00) in local time epoch milliseconds.
  static int getTodayStartMillis() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return startOfDay.millisecondsSinceEpoch;
  }
}
