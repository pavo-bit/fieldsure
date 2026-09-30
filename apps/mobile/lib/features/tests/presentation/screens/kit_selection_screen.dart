import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/test_kits_repository.dart';
import '../../domain/test_kit_model.dart';
import '../controllers/new_test_controller.dart';

final _testKitsFutureProvider = FutureProvider<List<TestKitModel>>((ref) {
  final repo = ref.watch(testKitsRepositoryProvider);
  return repo.fetchAndCacheTestKits();
});

class KitSelectionScreen extends ConsumerWidget {
  const KitSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(newTestControllerProvider);
    final asyncKits = ref.watch(_testKitsFutureProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Select Test Kit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: asyncKits.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) {
            if (err is TestKitsFallbackException) {
              return _buildKitsList(context, ref, state, err.fallbackKits, warningMessage: err.message);
            }
            return Center(
              child: Text(
                'Unable to load test kits.\n$err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error),
              ),
            );
          },
          data: (kits) => _buildKitsList(context, ref, state, kits),
        ),
      ),
    );
  }

  Widget _buildKitsList(BuildContext context, WidgetRef ref, dynamic state, List<TestKitModel> kits, {String? warningMessage}) {
    final activeKits = kits.where((k) => k.active).toList();
    
    if (activeKits.isEmpty) {
      return const Center(
        child: Text('No active test kits available.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (warningMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.warning),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Offline Mode: $warningMessage.\nUsing locally cached configuration.',
                      style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: ListView.separated(
              itemCount: activeKits.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final kit = activeKits[index];
                final isSelected = state.selectedKit?.id == kit.id;
                final isDemo = kit.code.toUpperCase().contains('DEMO');

                return InkWell(
                  onTap: () {
                    ref.read(newTestControllerProvider.notifier).selectKit(kit);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryOrange.withValues(alpha: 0.1) : AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryOrange : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      kit.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryText,
                                      ),
                                    ),
                                  ),
                                  if (isDemo)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'DEMO',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                kit.code,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondaryText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Configuration: ${kit.configurationVersion}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? AppColors.primaryOrange : AppColors.border,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: state.selectedKit != null ? () => context.push('/tests/new/preparation') : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
