import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/child_mode_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../auth/screens/role_selection_screen.dart';
import 'accessibility_disclosure_screen.dart';
import 'permission_request_screen.dart';

class ChildMonitoringScreen extends ConsumerStatefulWidget {
  const ChildMonitoringScreen({super.key});

  @override
  ConsumerState<ChildMonitoringScreen> createState() =>
      _ChildMonitoringScreenState();
}

class _ChildMonitoringScreenState extends ConsumerState<ChildMonitoringScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(childModeProvider.notifier).checkPermission();
      _checkAccessibility();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Recheck permission and run a fresh sync on resume
      ref.read(childModeProvider.notifier).checkPermission();
      ref.read(childModeProvider.notifier).syncUsageNow();
      _checkAccessibility();
    }
  }

  Future<void> _unlinkDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink This Device?'),
        content: const Text(
          'This will disconnect this phone from your family. To re-link, a new 6-digit code will be required.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(childModeProvider.notifier).unlinkDevice();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          (route) => false,
        );
      }
    }
  }

  /// Checks if Accessibility is enabled; if not, shows the disclosure screen.
  Future<void> _checkAccessibility() async {
    if (!mounted) return;
    final enabled =
        await ref.read(nativeUsageServiceProvider).isAccessibilityEnabled();
    if (!enabled && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AccessibilityDisclosureScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final childState = ref.watch(childModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orbit Family Child'),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'unlink') {
                _unlinkDevice();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'unlink',
                child: Row(
                  children: [
                    Icon(Icons.link_off_rounded, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Unlink Device', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Active Monitoring Hero Banner
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.shade600,
                      Colors.teal.shade700,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Monitoring is ON',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Linked for ${childState.childName ?? "Child"}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Permission Warning if revoked
              if (!childState.hasUsagePermission) ...[
                Card(
                  color: Colors.amber.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.amber.shade400, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.amber.shade900, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Usage Access is Disabled',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Orbit Family cannot track app usage without the Usage Access permission.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const PermissionRequestScreen(),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.amber.shade900,
                          ),
                          child: const Text('Re-enable Permission'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Sync Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.sync_rounded,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Background Sync',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              childState.lastSyncTime != null
                                  ? 'Synced ${AppDateUtils.formatLastSeen(childState.lastSyncTime)}'
                                  : 'Sync scheduled every 15m',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: childState.isSyncing
                            ? null
                            : () {
                                ref
                                    .read(childModeProvider.notifier)
                                    .syncUsageNow();
                              },
                        child: childState.isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Sync Now'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Loaded Limits (debug/info)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.gavel_outlined,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Loaded Limits',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ref
                          .watch(childCurrentRulesProvider(
                            (familyId: childState.familyId ?? '',
                                childId: childState.childId ?? ''),
                          ))
                          .when(
                        data: (rules) {
                          if (rules == null) {
                            return const Text(
                              'No rules loaded yet.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            );
                          }
                          final dailyLimit = rules.dailyLimitMs;
                          final blockedCount = rules.blockedApps.length;
                          final allBlocked = rules.allBlockedUntil != null;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily total limit: ${dailyLimit == null ? 'Unlimited' : AppDateUtils.formatDurationMs(dailyLimit)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Blocked apps: $blockedCount',
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Phone blocked: ${allBlocked ? 'Yes' : 'No'}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              if (rules.allBlockedUntil != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Block until: ${AppDateUtils.formatLastSeen(rules.allBlockedUntil)}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                'Enforcement works offline from cached rules.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => const Text('Loading rules...'),
                        error: (_, __) => const Text('Error loading rules.'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Transparency & Privacy Info
              Text(
                'Transparency Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              _buildInfoTile(
                icon: Icons.check_circle_outline_rounded,
                iconColor: Colors.green,
                title: 'What is shared with your parents',
                body:
                    '• Total daily screen time\n• Time spent in each app\n• Basic app category (e.g. Gaming, Video)\n• Last time the device was online',
              ),
              const SizedBox(height: 12),

              _buildInfoTile(
                icon: Icons.cancel_outlined,
                iconColor: Colors.redAccent,
                title: 'What is NEVER shared',
                body:
                    '• Chat messages or WhatsApp texts\n• Photos, videos, or camera access\n• Passwords or keystrokes\n• Personal accounts or search queries',
              ),
              const SizedBox(height: 16),

              // Persistent notification reminder
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A persistent notification stays in your notification shade so you always know monitoring is running.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
