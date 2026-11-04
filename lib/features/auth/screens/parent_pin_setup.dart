import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/services/pin_service.dart';
import '../../../core/services/rule_cache_service.dart';
import '../../../data/models/rule_model.dart';

/// Screen where the parent sets a PIN for child-mode unlock.
/// The PIN is hashed with a salt (never plain text) and saved to rules/main.
class ParentPinSetupScreen extends ConsumerStatefulWidget {
  final String familyId;
  final String childId;

  const ParentPinSetupScreen({
    super.key,
    required this.familyId,
    required this.childId,
  });

  @override
  ConsumerState<ParentPinSetupScreen> createState() =>
      _ParentPinSetupScreenState();
}

class _ParentPinSetupScreenState extends ConsumerState<ParentPinSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    if (!_formKey.currentState!.validate()) return;

    final pin = _pinController.text.trim();
    final usageRepo = ref.read(usageRepositoryProvider);

    // Hash PIN locally
    final prefs = await SharedPreferences.getInstance();
    final pinService = PinService(prefs);
    final result = pinService.setPin(pin);

    // Save hash + salt to rules/main
    final rules = RuleModel(
      parentPinHash: result['hash'],
      parentPinSalt: result['salt'],
    );

    setState(() => _isSaving = true);

    try {
      await usageRepo.saveRules(
        familyId: widget.familyId,
        childId: widget.childId,
        rules: rules,
      );

      // Cache locally too
      await RuleCacheService.saveRules(
        familyId: widget.familyId,
        childId: widget.childId,
        rules: rules,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parent PIN set successfully.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set PIN: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Parent PIN'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Create Parent PIN',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This PIN unlocks extra time on your child\'s device and '
                  'protects leaving child mode.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _pinController,
                  obscureText: true,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Enter PIN (4-6 digits)',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a PIN';
                    }
                    if (val.trim().length < 4 || val.trim().length > 6) {
                      return 'PIN must be 4-6 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Confirm PIN',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please confirm your PIN';
                    }
                    if (val.trim() != _pinController.text.trim()) {
                      return 'PINs do not match';
                    }
                    return null;
                  },
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _isSaving ? null : _savePin,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Set PIN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
