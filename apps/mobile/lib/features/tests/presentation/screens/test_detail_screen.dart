import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/test_detail_controller.dart';
import '../../domain/test_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class TestDetailScreen extends ConsumerWidget {
  final String testId;
  const TestDetailScreen({super.key, required this.testId});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DRAFT':
        return AppColors.secondaryText;
      case 'CAPTURED':
      case 'UPLOADING':
      case 'PROCESSING':
        return AppColors.primaryOrange;
      case 'COMPLETED':
        return AppColors.success;
      case 'FAILED':
        return AppColors.error;
      case 'INCONCLUSIVE':
        return AppColors.warning;
      case 'PENDING_SYNC':
        return AppColors.deepOrange;
      default:
        return AppColors.secondaryText;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'DRAFT':
        return Icons.edit_document;
      case 'CAPTURED':
        return Icons.camera_alt_rounded;
      case 'UPLOADING':
        return Icons.cloud_upload_rounded;
      case 'PROCESSING':
        return Icons.hourglass_top_rounded;
      case 'COMPLETED':
        return Icons.check_circle_rounded;
      case 'FAILED':
        return Icons.error_rounded;
      case 'INCONCLUSIVE':
        return Icons.help_rounded;
      case 'PENDING_SYNC':
        return Icons.sync_problem_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Widget _buildStateAction(BuildContext context, TestModel test) {
    switch (test.status) {
      case 'DRAFT':
        return ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Camera capture will be enabled in Phase 3.')),
            );
          },
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: const Text('Capture Kit'),
        );
      case 'CAPTURED':
        return ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: const Text('Process Kit'),
        );
      case 'FAILED':
        return OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: const Text('Retry'),
        );
      case 'COMPLETED':
        return ElevatedButton(
          onPressed: () => context.push('/tests/${test.id}/evidence'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: AppColors.success,
            foregroundColor: AppColors.white,
          ),
          child: const Text('View Evidence Record'),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTest = ref.watch(testDetailProvider(testId));
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Test Detail'),
        leading: IconButton(
          icon: const Icon(Icons.home_rounded),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: SafeArea(
        child: asyncTest.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Text('Unable to load test.\n$err', style: const TextStyle(color: AppColors.error)),
          ),
          data: (test) {
            if (test == null) {
              return const Center(child: Text('Test not found.'));
            }

            final isSynced = test.testNumber != null;
            final syncStatus = isSynced ? 'SYNCED' : 'SYNC PENDING';
            final syncColor = isSynced ? AppColors.success : AppColors.warning;

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                test.testNumber ?? 'Local Draft',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: syncColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                syncStatus,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: syncColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isSynced) ...[
                          const SizedBox(height: 4),
                          Text(
                            test.id,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getStatusColor(test.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(test.status)),
                    ),
                    child: Row(
                      children: [
                        Icon(_getStatusIcon(test.status), color: _getStatusColor(test.status), size: 28),
                        const SizedBox(width: 12),
                        Text(
                          test.status,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _getStatusColor(test.status),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Details
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _DetailRow(label: 'Case ID', value: test.caseId ?? 'N/A'),
                          const Divider(height: 24),
                          _DetailRow(label: 'Sample ID', value: test.sampleId ?? 'N/A'),
                          const Divider(height: 24),
                          _DetailRow(label: 'Kit ID', value: test.kitId),
                          const Divider(height: 24),
                          _DetailRow(label: 'Operator Badge', value: user?.operatorId ?? 'Unknown'),
                          const Divider(height: 24),
                          _DetailRow(
                            label: 'Created At',
                            value: DateTime.parse(test.clientCreatedAt).toLocal().toString().split('.')[0],
                          ),
                          if (test.result != null) ...[
                            const Divider(height: 24),
                            const Text(
                              'Classification',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _DetailRow(label: 'Analysis Result', value: test.result!),
                            if (test.confidence != null) ...[
                              const SizedBox(height: 12),
                              _DetailRow(label: 'Confidence', value: '${(test.confidence! * 100).toStringAsFixed(1)}%'),
                            ],
                            if (test.algorithmVersion != null) ...[
                              const SizedBox(height: 12),
                              _DetailRow(label: 'Algorithm Version', value: test.algorithmVersion!),
                            ],
                            if (test.modelVersion != null) ...[
                              const SizedBox(height: 12),
                              _DetailRow(label: 'Model Version', value: test.modelVersion!),
                            ],
                          ],
                          if (test.verificationStatus != null) ...[
                            const Divider(height: 24),
                            const Text(
                              'Evidence',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _DetailRow(
                              label: 'Verification Status',
                              value: test.verificationStatus!,
                              valueColor: test.verificationStatus == 'VERIFIED' ? AppColors.success : AppColors.error,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Dynamic Actions
                  _buildStateAction(context, test),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

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
            style: TextStyle(
              color: valueColor ?? AppColors.primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
