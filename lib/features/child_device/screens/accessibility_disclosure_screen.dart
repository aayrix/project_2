import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/repository_providers.dart';

/// Disclosure screen explaining why Accessibility is needed for enforcement.
/// The child must grant Accessibility before screen-time limits can be enforced.
class AccessibilityDisclosureScreen extends ConsumerStatefulWidget {
  const AccessibilityDisclosureScreen({super.key});

  @override
  ConsumerState<AccessibilityDisclosureScreen> createState() =>
      _AccessibilityDisclosureScreenState();
}

class _AccessibilityDisclosureScreenState
    extends ConsumerState<AccessibilityDisclosureScreen>
    with WidgetsBindingObserver {
  StreamSubscription<bool>? _accessibilitySubscription;
  bool _isOpeningSettings = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAccessibility();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccessibility();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accessibilitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAccessibility() async {
    final enabled =
        await ref.read(nativeUsageServiceProvider).isAccessibilityEnabled();
    if (enabled && mounted) {
      setState(() => _errorMessage = null);
      // Small delay to let the user see the enabled state before popping
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _openSettings() async {
    setState(() {
      _isOpeningSettings = true;
      _errorMessage = null;
    });
    try {
      await ref.read(nativeUsageServiceProvider).openAccessibilitySettings();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not open settings: $e. Please open Settings manually.';
        });
      }
    } finally {
      if (mounted) setState(() => _isOpeningSettings = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessibility Permission'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // Icon
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer
                              .withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.accessibility_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Accessibility Permission Needed',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Explanation
                    Text(
                      'Orbit Family uses Android Accessibility to detect which app is in the foreground. '
                      'This allows us to enforce your screen-time limits and blocks — even without internet.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // What is detected
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What Orbit Family detects:',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDetectRow(
                                'Foreground app name (e.g., YouTube, Chrome)'),
                            _buildDetectRow(
                                'When you open and switch between apps'),
                            _buildDetectRow(
                                'App usage time for limit enforcement'),
                            const SizedBox(height: 8),
                            Text(
                              'What we never detect:',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDetectRow(
                                'Keystrokes or text you type', isNot: true),
                            _buildDetectRow(
                                'Passwords or personal data', isNot: true),
                            _buildDetectRow(
                                'Message content or notifications',
                                isNot: true),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Android 13+ restricted settings hint
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'On some Android 13+ devices, Accessibility is under "Restricted settings". '
                              'Go to: Settings > Apps > Orbit Family > menu (⋮) > Allow restricted settings, '
                              'then turn on Accessibility for Orbit Family.',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Error message (if any)
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Pinned action buttons at bottom
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Enable button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isOpeningSettings ? null : _openSettings,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isOpeningSettings
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Open Accessibility Settings',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Skip for now (limits will not be enforced)',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectRow(String text, {bool isNot = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isNot ? Icons.cancel : Icons.check_circle,
            size: 18,
            color: isNot ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
