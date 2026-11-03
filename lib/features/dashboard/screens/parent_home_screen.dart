import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/family_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/child_model.dart';
import '../../auth/screens/role_selection_screen.dart';
import '../../family/screens/add_child_screen.dart';
import 'child_detail_screen.dart';

class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of FamilyTime?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(authControllerProvider.notifier).signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final familyIdAsync = ref.watch(currentFamilyIdProvider);
    final childrenAsync = ref.watch(childrenStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
      body: familyIdAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 48, color: colorScheme.error),
                const SizedBox(height: 12),
                Text('Error loading family: $err',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(currentFamilyIdProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (familyId) {
          if (familyId == null) {
            return const Center(child: Text('No family found.'));
          }

          return childrenAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error loading children: $err'),
              ),
            ),
            data: (children) {
              if (children.isEmpty) {
                return _buildEmptyState(context, colorScheme);
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(childrenStreamProvider);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(20.0),
                  itemCount: children.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (ctx, index) {
                    final child = children[index];
                    return _ChildCard(
                      familyId: familyId,
                      child: child,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddChildScreen()),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Child'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.child_care_rounded,
                size: 50,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Children Added Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your child to generate a 6-digit link code and start tracking their screen time.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddChildScreen()),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Child Profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildCard extends ConsumerWidget {
  final String familyId;
  final ChildModel child;

  const _ChildCard({
    required this.familyId,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Watch today's usage for this child
    final usageAsync = ref.watch(childTodayUsageStreamProvider(
      (familyId: familyId, childId: child.id),
    ));

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChildDetailScreen(
                familyId: familyId,
                childId: child.id,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name, Age, Status Pill
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        colorScheme.primaryContainer.withValues(alpha: 0.7),
                    child: Text(
                      child.name.isNotEmpty
                          ? child.name[0].toUpperCase()
                          : 'C',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${child.age} years old',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(colorScheme),
                ],
              ),
              const Divider(height: 28),

              // Bottom Stats Row: Today's Screen Time & Last Seen
              Row(
                children: [
                  // Screen time stat
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s Screen Time',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        usageAsync.when(
                          loading: () => const Text('Loading...'),
                          error: (_, _) => const Text('N/A'),
                          data: (usage) {
                            final totalMs = usage?.totalMs ?? 0;
                            return Text(
                              AppDateUtils.formatDurationMs(totalMs),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Last seen stat
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Last Seen',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppDateUtils.formatLastSeen(child.lastSeen),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ColorScheme colorScheme) {
    if (child.isLinked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              child.deviceName ?? 'Linked',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Code: ${child.linkCode}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade800,
          ),
        ),
      );
    }
  }
}
