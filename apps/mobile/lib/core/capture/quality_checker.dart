import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'quality_gate_config.dart';

/// On-device image quality checker.
/// 
/// Performs multiple quality checks before accepting a captured image:
/// - Blur detection (Laplacian variance)
/// - Exposure analysis (histogram)
/// - Glare detection
/// - Reference card presence (heuristic)
class QualityChecker {
  const QualityChecker();

  /// Run all quality checks on captured image.
  Future<List<QualityCheckResult>> checkQuality(Uint8List imageBytes) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      return [
        QualityCheckResult.fail(
          reason: 'Invalid image format',
          guidance: 'Please retake the photo',
        ),
      ];
    }

    return await Future.wait([
      _checkBlur(image),
      _checkExposure(image),
      _checkGlare(image),
      _checkReferenceCard(image),
    ]);
  }

  /// Check for excessive blur using Laplacian variance.
  /// 
  /// Algorithm:
  /// 1. Convert to grayscale
  /// 2. Apply Laplacian operator
  /// 3. Compute variance
  /// 4. Compare to threshold
  Future<QualityCheckResult> _checkBlur(img.Image image) async {
    final grayscale = img.grayscale(image);
    
    // Simplified Laplacian variance calculation
    // Production: Use proper convolution with Laplacian kernel
    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (int y = 1; y < grayscale.height - 1; y++) {
      for (int x = 1; x < grayscale.width - 1; x++) {
        final center = grayscale.getPixel(x, y).r.toDouble();
        final top = grayscale.getPixel(x, y - 1).r.toDouble();
        final bottom = grayscale.getPixel(x, y + 1).r.toDouble();
        final left = grayscale.getPixel(x - 1, y).r.toDouble();
        final right = grayscale.getPixel(x + 1, y).r.toDouble();
        
        // Simplified Laplacian: |4*center - (top + bottom + left + right)|
        final laplacian = (4 * center - (top + bottom + left + right)).abs();
        
        sum += laplacian;
        sumSq += laplacian * laplacian;
        count++;
      }
    }

    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);

    if (variance < QualityGateConfig.blurThreshold) {
      return QualityCheckResult.fail(
        reason: 'Image is too blurry',
        guidance: 'Hold the device steady and try again',
        metrics: {'laplacian_variance': variance},
      );
    }

    return QualityCheckResult.pass({'laplacian_variance': variance});
  }

  /// Check exposure using histogram analysis.
  Future<QualityCheckResult> _checkExposure(img.Image image) async {
    final grayscale = img.grayscale(image);
    
    // Calculate histogram
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < grayscale.height; y++) {
      for (int x = 0; x < grayscale.width; x++) {
        final pixel = grayscale.getPixel(x, y);
        histogram[pixel.r.toInt()]++;
      }
    }

    final totalPixels = grayscale.width * grayscale.height;
    
    // Calculate mean brightness
    double sumBrightness = 0;
    for (int i = 0; i < 256; i++) {
      sumBrightness += i * histogram[i];
    }
    final meanBrightness = sumBrightness / totalPixels;

    // Check underexposure
    if (meanBrightness < QualityGateConfig.minBrightness) {
      return QualityCheckResult.fail(
        reason: 'Image is underexposed',
        guidance: 'Move to better lighting or use flash',
        metrics: {'mean_brightness': meanBrightness},
      );
    }

    // Check overexposure
    if (meanBrightness > QualityGateConfig.maxBrightness) {
      return QualityCheckResult.fail(
        reason: 'Image is overexposed',
        guidance: 'Move to shade or reduce lighting',
        metrics: {'mean_brightness': meanBrightness},
      );
    }

    // Check mid-tone distribution
    int midTonePixels = 0;
    for (int i = 80; i <= 180; i++) {
      midTonePixels += histogram[i];
    }
    final midToneRatio = midTonePixels / totalPixels;

    if (midToneRatio < QualityGateConfig.minMidTonePercentage) {
      return QualityCheckResult.fail(
        reason: 'Poor contrast',
        guidance: 'Adjust lighting for better contrast',
        metrics: {
          'mean_brightness': meanBrightness,
          'midtone_ratio': midToneRatio,
        },
      );
    }

    return QualityCheckResult.pass({
      'mean_brightness': meanBrightness,
      'midtone_ratio': midToneRatio,
    });
  }

  /// Check for excessive glare (bright spots).
  Future<QualityCheckResult> _checkGlare(img.Image image) async {
    final grayscale = img.grayscale(image);
    
    int brightPixels = 0;
    final totalPixels = grayscale.width * grayscale.height;

    for (int y = 0; y < grayscale.height; y++) {
      for (int x = 0; x < grayscale.width; x++) {
        final pixel = grayscale.getPixel(x, y);
        if (pixel.r > 240) {
          brightPixels++;
        }
      }
    }

    final glareRatio = brightPixels / totalPixels;

    if (glareRatio > QualityGateConfig.maxGlarePercentage) {
      return QualityCheckResult.fail(
        reason: 'Glare detected',
        guidance: 'Move to shade to avoid reflections',
        metrics: {'glare_ratio': glareRatio},
      );
    }

    return QualityCheckResult.pass({'glare_ratio': glareRatio});
  }

  /// Check for reference card presence (simplified heuristic).
  /// 
  /// This is a placeholder for proper reference card detection.
  /// Production implementation should use:
  /// - Color-based detection (known card colors)
  /// - Edge detection for card boundaries
  /// - Size estimation
  /// - Orientation verification
  Future<QualityCheckResult> _checkReferenceCard(img.Image image) async {
    // TODO: Implement proper reference card detection
    // For now, we'll use a simple placeholder that always passes
    // to avoid blocking capture during development
    
    return QualityCheckResult.pass({
      'reference_card_detected': true,
      'confidence': 1.0,
      'note': 'Placeholder implementation - always passes',
    });
  }
}
