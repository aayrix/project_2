import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../dashboard/screens/parent_home_screen.dart';

class ParentAuthScreen extends ConsumerWidget {
  const ParentAuthScreen({super.key});

  String _formatErrorMessage(Object error) {
    final str = error.toString();
    if (str.contains('10') || str.contains('DEVELOPER_ERROR')) {
      return 'Developer Error (Code 10): Missing debug SHA-1 key in Firebase Console. Please add your SHA-1 fingerprint in Firebase Project Settings.';
    }
    if (str.contains('12500')) {
      return 'Sign-In Error (Code 12500): Missing Support Email in Firebase Console. Please select a support email under Project Settings.';
    }
    return str.replaceAll('Exception: ', '').replaceAll('PlatformException(', '');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen<AsyncValue<void>>(authControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        final message = _formatErrorMessage(next.error!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Sign In'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 1),

              // Orbit Icon & Title
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bubble_chart_rounded,
                    size: 44,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppConstants.appName,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppConstants.appTagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Spacer(flex: 2),

              // Explanatory card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Parent Space',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in with your Google account to manage your family, link your children\'s phones, and view real-time screen time.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Google Sign-In Button
              OutlinedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final success = await ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle();
                        if (context.mounted && success) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const ParentHomeScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(
                    color: colorScheme.outlineVariant,
                    width: 1.5,
                  ),
                  backgroundColor: Colors.white,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Google G Icon
                          Image.network(
                            'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                            height: 22,
                            width: 22,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.login_rounded,
                              size: 22,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Continue with Google',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
              ),

              const Spacer(flex: 3),

              // Footnote
              Text(
                'No passwords needed. Fast, secure authentication via Google.',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          )),
        ),
      ),
    );
  }
}
