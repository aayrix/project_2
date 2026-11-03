import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/family_provider.dart';
import '../../../core/utils/category_mapper.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/app_usage_model.dart';
import '../../../data/models/child_model.dart';
import '../../../data/models/usage_day_model.dart';

class ChildDetailScreen extends ConsumerWidget {
  final String familyId;
  final String childId;

  const ChildDetailScreen({
    super.key,
    required this.familyId,
    required this.childId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childAsync = ref.watch(childDetailStreamProvider(
      (familyId: familyId, childId: childId),
    ));

    final usageAsync = ref.watch(childTodayUsageStreamProvider(
      (familyId: familyId, childId: childId),
    ));

    return Scaffold(
      appBar: AppBar(
        title: childAsync.when(
          data: (child) => Text(child?.name ?? 'Child Details'),
          loading: () => const Text('Loading...'),
          error: (_, _) => const Text('Child Details'),
        ),
      ),
      body: childAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (child) {
          if (child == null) {
            return const Center(child: Text('Child profile not found.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(context, child, ref),
                const SizedBox(height: 20),

                // Usage Section
                usageAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Text('Error loading usage: $err'),
                  data: (usage) {
                    return _buildUsageContent(context, usage);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(
      BuildContext context, ChildModel child, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      colorScheme.primaryContainer.withValues(alpha: 0.7),
                  child: Text(
                    child.name.isNotEmpty ? child.name[0].toUpperCase() : 'C',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${child.age} years old • ${child.deviceName ?? "No device linked"}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      child.isLinked
                          ? Icons.check_circle_rounded
                          : Icons.access_time_rounded,
                      size: 18,
                      color: child.isLinked ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      child.isLinked
                          ? 'Device Active'
                          : 'Waiting to link (Code: ${child.linkCode})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: child.isLinked ? Colors.green : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Last seen: ${AppDateUtils.formatLastSeen(child.lastSeen)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageContent(BuildContext context, UsageDayModel? usage) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalMs = usage?.totalMs ?? 0;
    final apps = usage?.sortedApps ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Total Time Card
        Card(
          color: colorScheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY\'S TOTAL SCREEN TIME',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.8),
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppDateUtils.formatDurationMs(totalMs),
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Updated ${AppDateUtils.formatLastSeen(usage?.updatedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Apps List Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'App Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${apps.length} apps tracked',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (apps.isEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
              child: Column(
                children: [
                  Icon(
                    Icons.phone_android_rounded,
                    size: 48,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No usage recorded today',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'When your child uses apps on their device, usage will appear here automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: apps.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, index) {
              final app = apps[index];
              final percentage = totalMs > 0 ? (app.ms / totalMs).clamp(0.0, 1.0) : 0.0;
              return _buildAppItem(context, app, percentage);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildAppItem(
      BuildContext context, AppUsageModel app, double percentage) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final catColor = CategoryMapper.categoryColor(app.category);
    final catIcon = CategoryMapper.categoryIcon(app.category);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                // Category Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(catIcon, color: catColor, size: 24),
                ),
                const SizedBox(width: 14),

                // Name & Category Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          CategoryMapper.categoryDisplayName(app.category),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: catColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Duration Text
                Text(
                  AppDateUtils.formatDurationMs(app.ms),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Usage percentage bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 6,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(catColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
