import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/child_mode_provider.dart';
import 'child_monitoring_screen.dart';
import 'permission_request_screen.dart';

class LinkDeviceScreen extends ConsumerStatefulWidget {
  const LinkDeviceScreen({super.key});

  @override
  ConsumerState<LinkDeviceScreen> createState() => _LinkDeviceScreenState();
}

class _LinkDeviceScreenState extends ConsumerState<LinkDeviceScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    if (!_formKey.currentState!.validate()) return;

    final code = _codeController.text.trim();
    final childNotifier = ref.read(childModeProvider.notifier);

    final success = await childNotifier.linkWithCode(code);

    if (mounted && success) {
      final childState = ref.read(childModeProvider);
      if (childState.hasUsagePermission) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ChildMonitoringScreen()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PermissionRequestScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final childState = ref.watch(childModeProvider);
    final isSyncing = childState.isSyncing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Family'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.phonelink_setup_rounded,
                      size: 40,
                      color: colorScheme.secondary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Enter Family Link Code',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ask your parent for the 6-digit code shown on their screen.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 36),

                // 6-digit input
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: theme.textTheme.headlineMedium?.copyWith(
                    letterSpacing: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: TextStyle(
                      letterSpacing: 12,
                      color: colorScheme.outlineVariant,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter the 6-digit code';
                    }
                    if (val.trim().length != 6) {
                      return 'Code must be exactly 6 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Error message display if any
                if (childState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: colorScheme.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            childState.errorMessage!,
                            style: TextStyle(
                              color: colorScheme.onErrorContainer,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isSyncing ? null : _submitCode,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSyncing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Connect Device',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
