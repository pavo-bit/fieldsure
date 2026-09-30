import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldsure_mobile/core/classification/offline_classifier.dart';
import 'package:fieldsure_mobile/core/localization/app_localizations.dart';

/// Displays drug test result with presumptive label, quality metrics, and disclaimers
class ResultDetailScreen extends ConsumerWidget {
  final String testId;

  const ResultDetailScreen({
    super.key,
    required this.testId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // In production, fetch test from database with result data
    // For now, show structure with mock data
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.testResult),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareResult(context),
            tooltip: l10n.shareResult,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPresumptiveDisclaimer(theme, l10n),
            _buildResultCard(theme, l10n),
            _buildCandidateClasses(theme, l10n),
            _buildQualityMetrics(theme, l10n),
            _buildQualityFlags(theme, l10n),
            _buildKitValidation(theme, l10n),
            _buildCaptureMetadata(theme, l10n),
            _buildChainOfCustody(theme, l10n),
            _buildActions(theme, l10n),
            _buildPermanentDisclaimer(theme, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildPresumptiveDisclaimer(ThemeData theme, AppLocalizations l10n) {
    return Container(
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.onErrorContainer,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.presumptiveResultTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.presumptiveResultWarning,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.onErrorContainer,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.gavel,
                      color: theme.colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CRITICAL REQUIREMENT',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Laboratory confirmation is REQUIRED for forensic or evidentiary use. This field test does NOT independently identify controlled substances.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme, AppLocalizations l10n) {
    // Mock data - IN PRODUCTION: fetch from API SafeClassificationResult
    // NO LONGER using POSITIVE/NEGATIVE - use colorimetric measurements
    const observedColorLab = {'L': 65.5, 'a': 18.2, 'b': -35.7};
    const colorDistance = 12.3;
    const nearestReferenceLabel = 'Blue-Purple range';
    const qualityStatus = 'ACCEPTABLE'; // ACCEPTABLE, MARGINAL, REJECTED
    const validationStatus = 'UNVALIDATED'; // CRITICAL WARNING
    const kitValidationStatus = 'UNVALIDATED'; // CRITICAL WARNING

    // Determine display based on quality and validation status
    const isQualityAcceptable = qualityStatus == 'ACCEPTABLE';
    const isValidated = validationStatus == 'VALIDATED' && kitValidationStatus == 'VALIDATED';
    
    final resultColor = !isQualityAcceptable
        ? theme.colorScheme.error
        : !isValidated
            ? Colors.orange
            : theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Show validation warning icon prominently
            if (!isValidated)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.science_outlined, color: Colors.orange, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'UNVALIDATED CLASSIFIER - DEMONSTRATION ONLY',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            if (!isValidated) const SizedBox(height: 16),
            
            // Display colorimetric measurement as primary result
            Icon(
              Icons.palette_outlined,
              size: 64,
              color: resultColor,
            ),
            const SizedBox(height: 16),
            Text(
              nearestReferenceLabel,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: resultColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Color Distance: ${colorDistance.toStringAsFixed(1)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'L: ${observedColorLab['L']!.toStringAsFixed(1)}, '
              'a: ${observedColorLab['a']!.toStringAsFixed(1)}, '
              'b: ${observedColorLab['b']!.toStringAsFixed(1)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            
            // Quality status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: resultColor),
              ),
              child: Text(
                'Quality: $qualityStatus',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: resultColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Validation status badge (always shown)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: validationStatus == 'VALIDATED'
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: validationStatus == 'VALIDATED'
                      ? theme.colorScheme.primary
                      : Colors.orange,
                ),
              ),
              child: Text(
                'Classifier: $validationStatus',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: validationStatus == 'VALIDATED'
                      ? theme.colorScheme.primary
                      : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateClasses(ThemeData theme, AppLocalizations l10n) {
    // REMOVED: No longer showing candidate classes with confidence scores
    // Colorimetric measurement is the primary result format
    // If needed for debugging, show reference color chart comparison instead
    return const SizedBox.shrink();
  }

  Widget _buildQualityMetrics(ThemeData theme, AppLocalizations l10n) {
    // Mock data
    const deltaE = 12.3;
    const blurScore = 145.2;
    const exposureScore = 128.5;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.qualityMetrics,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildMetricRow(
              l10n.deltaE,
              deltaE.toStringAsFixed(2),
              deltaE < 15 ? Icons.check_circle : Icons.warning,
              deltaE < 15 ? theme.colorScheme.primary : Colors.orange,
              theme,
            ),
            _buildMetricRow(
              l10n.blurScore,
              blurScore.toStringAsFixed(2),
              blurScore > 100 ? Icons.check_circle : Icons.warning,
              blurScore > 100 ? theme.colorScheme.primary : Colors.orange,
              theme,
            ),
            _buildMetricRow(
              l10n.exposureScore,
              exposureScore.toStringAsFixed(1),
              Icons.check_circle,
              theme.colorScheme.primary,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityFlags(ThemeData theme, AppLocalizations l10n) {
    // Mock data
    final qualityFlags = [
      QualityFlag.underExposure,
    ];

    if (qualityFlags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  l10n.qualityFlags,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...qualityFlags.map((flag) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getQualityFlagDescription(flag, l10n),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  String _getQualityFlagDescription(QualityFlag flag, AppLocalizations l10n) {
    switch (flag) {
      case QualityFlag.blur:
        return l10n.qualityFlagBlur;
      case QualityFlag.underExposure:
        return l10n.qualityFlagUnderExposure;
      case QualityFlag.overExposure:
        return l10n.qualityFlagOverExposure;
      case QualityFlag.glare:
        return l10n.qualityFlagGlare;
      case QualityFlag.referenceCardMissing:
        return l10n.qualityFlagRefCardMissing;
      case QualityFlag.referenceCardTooSmall:
        return l10n.qualityFlagRefCardSmall;
      case QualityFlag.referenceCardAngle:
        return l10n.qualityFlagRefCardAngle;
      case QualityFlag.lowConfidence:
        return l10n.qualityFlagLowConfidence;
    }
  }

  Widget _buildKitValidation(ThemeData theme, AppLocalizations l10n) {
    // Mock data - IN PRODUCTION: fetch from API SafeClassificationResult
    const kitValidationStatus = 'UNVALIDATED'; // UNVALIDATED, PILOT, VALIDATED
    const kitCode = 'DEMO-CONFIG-v1';
    const kitLotNumber = 'LOT-2026-09-001';
    const kitExpiry = '2027-09-30';

    final isUnvalidated = kitValidationStatus == 'UNVALIDATED';
    final isPilot = kitValidationStatus == 'PILOT';
    final statusColor = isUnvalidated 
        ? Colors.orange 
        : isPilot 
            ? Colors.amber 
            : theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isUnvalidated ? Colors.orange.withValues(alpha: 0.05) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.kitValidation,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Validation status with warning if not validated
            _buildInfoRow(
              l10n.kitStatus,
              kitValidationStatus,
              isUnvalidated ? Icons.warning_amber : isPilot ? Icons.science : Icons.verified,
              statusColor,
              theme,
            ),
            
            // Show warning message for unvalidated kits
            if (isUnvalidated) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This test kit configuration has NOT been scientifically validated. Results are for demonstration purposes only.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (isPilot) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.science, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This test kit is in pilot/validation phase. Results are presumptive only.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            _buildInfoRow(
              'Kit Code',
              kitCode,
              Icons.inventory_2_outlined,
              theme.colorScheme.onSurface,
              theme,
            ),
            _buildInfoRow(
              l10n.lotNumber,
              kitLotNumber,
              Icons.qr_code,
              theme.colorScheme.onSurface,
              theme,
            ),
            _buildInfoRow(
              l10n.expiryDate,
              kitExpiry,
              Icons.calendar_today,
              theme.colorScheme.onSurface,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureMetadata(ThemeData theme, AppLocalizations l10n) {
    // Mock data
    const capturedAt = '2026-09-29 14:30:45';
    const deviceId = 'DEVICE-12345';
    const appVersion = '1.0.0';
    const gpsLat = '28.6139';
    const gpsLon = '77.2090';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.info_outline),
        title: Text(
          l10n.captureMetadata,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildMetadataRow(l10n.capturedAt, capturedAt, theme),
                _buildMetadataRow(l10n.deviceId, deviceId, theme),
                _buildMetadataRow(l10n.appVersion, appVersion, theme),
                _buildMetadataRow(l10n.gpsCoordinates, '$gpsLat, $gpsLon', theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChainOfCustody(ThemeData theme, AppLocalizations l10n) {
    // Mock data
    final custodyEvents = [
      ('Collected', 'Officer John Doe', '2026-09-29 14:25:00'),
      ('Photographed', 'Officer John Doe', '2026-09-29 14:30:45'),
      ('Sealed', 'Officer John Doe', '2026-09-29 14:32:00'),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.verified_user),
        title: Text(
          l10n.chainOfCustody,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: custodyEvents.map((event) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.$1,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              event.$2,
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              event.$3,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to request lab confirmation
            },
            icon: const Icon(Icons.science),
            label: Text(l10n.requestLabConfirmation),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: View full evidence package
            },
            icon: const Icon(Icons.folder),
            label: Text(l10n.viewEvidencePackage),
          ),
        ],
      ),
    );
  }

  Widget _buildPermanentDisclaimer(ThemeData theme, AppLocalizations l10n) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.gavel,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.legalDisclaimer,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.presumptiveTestDisclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.labConfirmationRequired,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _shareResult(BuildContext context) {
    // TODO: Implement result sharing with proper redaction
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.shareNotImplemented),
      ),
    );
  }
}
