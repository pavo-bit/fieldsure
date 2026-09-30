import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/new_test_controller.dart';

class TestPreparationScreen extends ConsumerWidget {
  const TestPreparationScreen({super.key});

  void _onStartTest(BuildContext context, WidgetRef ref) async {
    final draft = await ref.read(newTestControllerProvider.notifier).submitTest();
    if (draft != null) {
      if (context.mounted) {
        // Clear new test state
        ref.read(newTestControllerProvider.notifier).clear();
        // Go to Camera Capture
        context.go('/tests/${draft.id}/capture');
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(newTestControllerProvider).error ?? 'Unable to start test'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(newTestControllerProvider);
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Test Preparation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Verify Test Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please ensure the following information is correct before initiating the chemical test.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryText,
                    ),
              ),
              const SizedBox(height: 24),
              
              _DetailRow(label: 'Case ID', value: state.caseId),
              const Divider(height: 24),
              _DetailRow(label: 'Sample ID', value: state.sampleId),
              const Divider(height: 24),
              _DetailRow(label: 'Test Kit', value: state.selectedKit?.name ?? 'Unknown'),
              const Divider(height: 24),
              _DetailRow(label: 'Configuration', value: state.selectedKit?.configurationVersion ?? 'Unknown'),
              const Divider(height: 24),
              _DetailRow(label: 'Operator Badge', value: user?.operatorId ?? 'Unknown'),
              
              const Spacer(),
              
              if (state.isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: const Text('Back'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _onStartTest(context, ref),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: const Text('Start Test'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
