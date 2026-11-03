import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/child_mode_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/parent_auth_screen.dart';
import 'features/auth/screens/role_selection_screen.dart';
import 'features/child_device/screens/child_monitoring_screen.dart';
import 'features/child_device/screens/link_device_screen.dart';
import 'features/child_device/screens/permission_request_screen.dart';
import 'features/dashboard/screens/parent_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseInitialized = false;
  String? firebaseError;

  try {
    await Firebase.initializeApp();
    firebaseInitialized = true;
  } catch (e) {
    firebaseError = e.toString();
  }

  runApp(
    ProviderScope(
      child: OrbitFamilyApp(
        isFirebaseReady: firebaseInitialized,
        firebaseErrorMessage: firebaseError,
      ),
    ),
  );
}

class OrbitFamilyApp extends ConsumerWidget {
  final bool isFirebaseReady;
  final String? firebaseErrorMessage;

  const OrbitFamilyApp({
    super.key,
    required this.isFirebaseReady,
    this.firebaseErrorMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: !isFirebaseReady
          ? _FirebaseSetupScreen(errorMessage: firebaseErrorMessage)
          : const _AppRouter(),
    );
  }
}

/// Dynamic gatekeeper directing the user to Parent, Child, or Role Selection.
class _AppRouter extends ConsumerWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(persistedRoleProvider);
    final authUserAsync = ref.watch(authStateProvider);

    return roleAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const RoleSelectionScreen(),
      data: (savedRole) {
        if (savedRole == AppConstants.roleChild) {
          final childState = ref.watch(childModeProvider);
          if (childState.isLinked) {
            if (!childState.hasUsagePermission) {
              return const PermissionRequestScreen();
            }
            return const ChildMonitoringScreen();
          }
          return const LinkDeviceScreen();
        }

        if (savedRole == AppConstants.roleParent) {
          return authUserAsync.when(
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const ParentAuthScreen(),
            data: (user) {
              if (user != null) {
                return const ParentHomeScreen();
              }
              return const ParentAuthScreen();
            },
          );
        }

        // Default: First-time launch role selection
        return const RoleSelectionScreen();
      },
    );
  }
}

/// Fallback guidance screen if Firebase hasn't been configured yet with real credentials.
class _FirebaseSetupScreen extends StatelessWidget {
  final String? errorMessage;

  const _FirebaseSetupScreen({this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: 20),
              Text(
                'Firebase Project Required',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'To run Orbit Family, download your google-services.json from the Firebase Console and place it in android/app/google-services.json.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              if (errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    errorMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              FilledButton.tonal(
                onPressed: () {
                  // Restart the app
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen(),
                    ),
                  );
                },
                child: const Text('Try Again / Preview UI Offline'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
