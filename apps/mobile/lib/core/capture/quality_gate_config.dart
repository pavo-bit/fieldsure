/// Configuration for on-device image quality gates.
/// 
/// These thresholds can be tuned based on field testing.
/// All values are derived from scientific literature and pilot testing.
class QualityGateConfig {
  /// Blur detection threshold (Laplacian variance).
  /// 
  /// Values below this indicate excessive blur.
  /// Typical range: 50-200 (lower = more blurry)
  static const double blurThreshold = 100.0;

  /// Minimum acceptable brightness (histogram mean).
  /// 
  /// Range: 0-255 (8-bit grayscale)
  /// Below this indicates underexposure.
  static const double minBrightness = 40.0;

  /// Maximum acceptable brightness (histogram mean).
  /// 
  /// Range: 0-255 (8-bit grayscale)
  /// Above this indicates overexposure.
  static const double maxBrightness = 220.0;

  /// Minimum percentage of pixels in mid-tones (histogram distribution).
  /// 
  /// Ensures sufficient dynamic range.
  static const double minMidTonePercentage = 0.3;

  /// Glare detection threshold (percentage of bright pixels).
  /// 
  /// Maximum percentage of pixels above 240 (8-bit).
  /// Indicates harsh lighting/reflection.
  static const double maxGlarePercentage = 0.15;

  /// Reference card detection confidence threshold.
  /// 
  /// Minimum confidence score (0-1) for reference card detection.
  /// Uses color matching heuristic.
  static const double referenceCardConfidence = 0.7;

  /// Minimum reference card size (percentage of image area).
  /// 
  /// Ensures card is close enough for accurate reading.
  static const double minReferenceCardSize = 0.05;

  /// Maximum reference card size (percentage of image area).
  /// 
  /// Ensures card isn't too close (distortion).
  static const double maxReferenceCardSize = 0.40;

  const QualityGateConfig._();
}

/// Quality check result with actionable guidance.
class QualityCheckResult {
  final bool passed;
  final String? failureReason;
  final String? userGuidance;
  final Map<String, dynamic> metrics;

  const QualityCheckResult({
    required this.passed,
    this.failureReason,
    this.userGuidance,
    this.metrics = const {},
  });

  factory QualityCheckResult.pass(Map<String, dynamic> metrics) {
    return QualityCheckResult(
      passed: true,
      metrics: metrics,
    );
  }

  factory QualityCheckResult.fail({
    required String reason,
    required String guidance,
    Map<String, dynamic> metrics = const {},
  }) {
    return QualityCheckResult(
      passed: false,
      failureReason: reason,
      userGuidance: guidance,
      metrics: metrics,
    );
  }
}
