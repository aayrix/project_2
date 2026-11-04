import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/family_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/utils/category_mapper.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/app_usage_model.dart';
import '../../../data/models/child_model.dart';
import '../../../data/models/rule_model.dart';
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 20),

                // Limits Section
                LimitsSection(
                  familyId: familyId,
                  childId: childId,
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
            const SizedBox(height: 16),

            // Edit & Remove actions
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showEditChildDialog(
                    context, ref, child, familyId, childId,
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit child'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _confirmRemoveChild(
                    context, ref, child, familyId, childId,
                  ),
                  icon: const Icon(Icons.delete_rounded, size: 18),
                  label: const Text('Remove child'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Shows dialog to edit child name and age.
  Future<void> _showEditChildDialog(
    BuildContext context,
    WidgetRef ref,
    ChildModel child,
    String familyId,
    String childId,
  ) async {
    final nameController = TextEditingController(text: child.name);
    final ageController = TextEditingController(text: child.age.toString());
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Child'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter an age';
                  }
                  final parsed = int.tryParse(val);
                  if (parsed == null || parsed < 2 || parsed > 18) {
                    return 'Please enter a valid age (2 - 18)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(familyControllerProvider.notifier).updateChild(
          familyId: familyId,
          childId: childId,
          name: nameController.text.trim(),
          age: int.parse(ageController.text.trim()),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Child updated successfully.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update child: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  /// Shows confirmation dialog to remove child.
  Future<void> _confirmRemoveChild(
    BuildContext context,
    WidgetRef ref,
    ChildModel child,
    String familyId,
    String childId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Child?'),
        content: Text(
          'This will permanently delete "${child.name}" and all their data. '
          'This cannot be undone. The linked device will be disconnected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(familyControllerProvider.notifier).removeChild(
          familyId: familyId,
          childId: childId,
          linkCode: child.linkCode,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Child removed successfully.')),
          );
          Navigator.of(context).pop(); // Return to parent home
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove child: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
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
        const SizedBox(height: 20),

        // fl_chart Category Breakdown Chart
        if (apps.isNotEmpty && totalMs > 0) ...[
          _buildCategoryChart(context, apps, totalMs),
          const SizedBox(height: 24),
        ],

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

  Widget _buildCategoryChart(
      BuildContext context, List<AppUsageModel> apps, int totalMs) {
    final theme = Theme.of(context);

    // Group milliseconds by category
    final Map<String, int> categoryTotals = {};
    for (final app in apps) {
      categoryTotals[app.category] =
          (categoryTotals[app.category] ?? 0) + app.ms;
    }

    // Filter categories with positive usage and sort descending
    final sortedCategories = categoryTotals.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = sortedCategories.map((entry) {
      final percentage = (entry.value / totalMs) * 100;
      final color = CategoryMapper.categoryColor(entry.key);
      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: percentage >= 10 ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: 46,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category Distribution',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 38,
                  sectionsSpace: 3,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: sortedCategories.map((entry) {
                final color = CategoryMapper.categoryColor(entry.key);
                final displayName = CategoryMapper.categoryDisplayName(entry.key);
                final duration = AppDateUtils.formatDurationMs(entry.value);

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$displayName: $duration',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
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

/// Limits section for the child detail screen.
/// Allows the parent to set daily total limit, per-app limits, and blocks.
class LimitsSection extends ConsumerStatefulWidget {
  final String familyId;
  final String childId;

  const LimitsSection({
    super.key,
    required this.familyId,
    required this.childId,
  });

  @override
  ConsumerState<LimitsSection> createState() => _LimitsSectionState();
}

class _LimitsSectionState extends ConsumerState<LimitsSection> {
  final _dailyLimitController = TextEditingController();
  final Map<String, TextEditingController> _appLimitControllers = {};
  final Set<String> _blockedApps = {};
  bool _allBlocked = false;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _dailyLimitController.dispose();
    for (final controller in _appLimitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers(RuleModel? rules, List<AppUsageModel> apps) {
    if (rules != null) {
      if (rules.dailyLimitMs != null && rules.dailyLimitMs! > 0) {
        _dailyLimitController.text = rules.dailyLimitMs.toString();
      }
      _blockedApps.addAll(rules.blockedApps.keys);
      _allBlocked = rules.allBlockedUntil != null;
    }

    for (final app in apps) {
      if (!_appLimitControllers.containsKey(app.packageName)) {
        final controller = TextEditingController();
        final limit = rules?.appLimits[app.packageName];
        if (limit != null && limit > 0) {
          controller.text = limit.toString();
        }
        _appLimitControllers[app.packageName] = controller;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final rulesAsync = ref.watch(childRulesStreamProvider(
      (familyId: widget.familyId, childId: widget.childId),
    ));
    final usageAsync = ref.watch(childTodayUsageStreamProvider(
      (familyId: widget.familyId, childId: widget.childId),
    ));

    return rulesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Text('Error loading rules.'),
      data: (rules) {
        final apps = usageAsync.value?.sortedApps ?? [];
        if (!_initialized) {
          _initializeControllers(rules, apps);
          _initialized = true;
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Screen Time Limits',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Daily total limit
                TextFormField(
                  controller: _dailyLimitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Daily total limit (ms)',
                    hintText: 'e.g. 7200000 for 2 hours',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Block phone for today
                Row(
                  children: [
                    Switch(
                      value: _allBlocked,
                      onChanged: (val) => setState(() => _allBlocked = val),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _allBlocked
                            ? 'Block phone for today (except essential apps)'
                            : 'Block entire phone for today',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Per-app limits
                if (apps.isEmpty)
                  const Text(
                    'No app usage data yet. Limits will apply once apps are tracked.',
                  )
                else ...[
                  Text(
                    'Per-App Limits',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final app in apps)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.appName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  app.packageName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _appLimitControllers[app.packageName],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Limit (ms)',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Checkbox(
                            value: _blockedApps.contains(app.packageName),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _blockedApps.add(app.packageName);
                                } else {
                                  _blockedApps.remove(app.packageName);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 20),

                // Save button
                FilledButton(
                  onPressed: _isSaving ? null : _saveRules,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Limits'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveRules() async {
    final usageRepo = ref.read(usageRepositoryProvider);

    final dailyLimitText = _dailyLimitController.text.trim();
    final dailyLimitMs =
        dailyLimitText.isEmpty ? null : int.tryParse(dailyLimitText);

    final appLimits = <String, int>{};
    _appLimitControllers.forEach((pkg, controller) {
      final val = int.tryParse(controller.text.trim());
      if (val != null && val > 0) {
        appLimits[pkg] = val;
      }
    });

    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final blockedApps = <String, DateTime>{};
    for (final pkg in _blockedApps) {
      blockedApps[pkg] = endOfToday;
    }

    final allBlockedUntil = _allBlocked ? endOfToday : null;

    final rules = RuleModel(
      dailyLimitMs: dailyLimitMs,
      appLimits: appLimits,
      blockedApps: blockedApps,
      allBlockedUntil: allBlockedUntil,
    );

    setState(() => _isSaving = true);

    try {
      await usageRepo.saveRules(
        familyId: widget.familyId,
        childId: widget.childId,
        rules: rules,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Limits saved successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save limits: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
