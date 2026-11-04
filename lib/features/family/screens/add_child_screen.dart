import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/family_provider.dart';
import '../../../data/models/child_model.dart';

class AddChildScreen extends ConsumerStatefulWidget {
  const AddChildScreen({super.key});

  @override
  ConsumerState<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends ConsumerState<AddChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  ChildModel? _createdChild;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _generateCode() async {
    if (!_formKey.currentState!.validate()) return;

    final age = int.tryParse(_ageController.text.trim()) ?? 10;
    final child = await ref.read(familyControllerProvider.notifier).addChild(
          name: _nameController.text.trim(),
          age: age,
        );

    if (mounted && child != null) {
      setState(() {
        _createdChild = child;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(familyControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Child'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: _createdChild == null
              ? _buildForm(theme, colorScheme, isLoading)
              : _buildCodeGeneratedView(theme, colorScheme),
        ),
      ),
    );
  }

  Widget _buildForm(
      ThemeData theme, ColorScheme colorScheme, bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'You will get a 6-digit link code to connect your child\'s phone to this family.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Child\'s Name',
              hintText: 'e.g. Leo',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your child\'s name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Child\'s Age',
              hintText: 'e.g. 12',
              prefixIcon: Icon(Icons.cake_outlined),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter child\'s age';
              }
              final parsed = int.tryParse(val);
              if (parsed == null || parsed < 2 || parsed > 18) {
                return 'Please enter a valid age (2 - 18)';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          FilledButton(
            onPressed: isLoading ? null : _generateCode,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Generate Link Code',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeGeneratedView(ThemeData theme, ColorScheme colorScheme) {
    final child = _createdChild!;
    // Formatted code with spaces: e.g. "4 8 2   9 1 0"
    final code = child.linkCode;
    final formattedCode = code.length == 6
        ? '${code.substring(0, 3)}  ${code.substring(3, 6)}'
        : code;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.green,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Profile created for ${child.name}!',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter this code on your child\'s phone to link the device.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),

        // Code Box
        Card(
          elevation: 0,
          color: colorScheme.primaryContainer.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                Text(
                  '6-DIGIT LINK CODE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  formattedCode,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text(
                      'Valid for 24 hours',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link code copied to clipboard!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy Code'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // 3-step Instructions
        Text(
          'Next Steps on Child\'s Phone:',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildStepItem('1', 'Install & open Orbit Family on child\'s phone'),
        _buildStepItem('2', 'Tap "This is my Child\'s Device"'),
        _buildStepItem('3', 'Enter the 6-digit code: $code'),
        _buildStepItem('4', 'Grant Usage Access & notification permissions'),

        const SizedBox(height: 32),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Done',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
