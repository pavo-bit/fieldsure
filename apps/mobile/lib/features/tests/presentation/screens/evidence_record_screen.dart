import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/evidence_controller.dart';

class EvidenceRecordScreen extends ConsumerWidget {
  final String testId;

  const EvidenceRecordScreen({super.key, required this.testId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evidenceAsync = ref.watch(evidenceProvider(testId));
    final verificationState = ref.watch(verificationControllerProvider(testId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Evidence Record'),
      ),
      body: SafeArea(
        child: evidenceAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Text('Error loading evidence:\n$err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error)),
          ),
          data: (evidence) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Cryptographic Evidence',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _HashRow(label: 'Image Hash (SHA-256)', value: evidence.imageHash),
                        const Divider(height: 24),
                        _HashRow(label: 'Record Hash', value: evidence.recordHash),
                        const Divider(height: 24),
                        _HashRow(label: 'Signature', value: evidence.signature),
                        const Divider(height: 24),
                        _HashRow(
                          label: 'Signed At',
                          value: DateTime.parse(evidence.signedAt).toLocal().toString().split('.')[0],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Verification Section
                  if (verificationState.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (verificationState.hasError)
                    Text(
                      'Verification Error: ${verificationState.error}',
                      style: const TextStyle(color: AppColors.error),
                    )
                  else if (verificationState.value != null)
                    _VerificationResultCard(result: verificationState.value!)
                  else
                    ElevatedButton.icon(
                      icon: const Icon(Icons.verified_user_rounded),
                      label: const Text('Verify Evidence'),
                      onPressed: () {
                        ref.read(verificationControllerProvider(testId).notifier).verify();
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HashRow extends StatelessWidget {
  final String label;
  final String value;

  const _HashRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: AppColors.primaryText,
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _VerificationResultCard extends StatelessWidget {
  final VerificationResult result;

  const _VerificationResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final bool isVerified = result.verified;
    final Color color = isVerified ? AppColors.success : AppColors.error;
    final IconData icon = isVerified ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                isVerified ? 'Evidence Verified' : 'Integrity Failed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(label: 'Overall Integrity', value: result.integrity, color: color),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Image Integrity',
            value: result.imageIntegrity,
            color: result.imageIntegrity == 'VALID' ? AppColors.success : AppColors.error,
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Record Integrity',
            value: result.recordIntegrity,
            color: result.recordIntegrity == 'VALID' ? AppColors.success : AppColors.error,
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Digital Signature',
            value: result.signature,
            color: result.signature == 'VALID' ? AppColors.success : AppColors.error,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.secondaryText),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
