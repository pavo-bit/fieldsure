import 'package:flutter_test/flutter_test.dart';
import 'package:fieldsure_mobile/core/capture/quality_checker.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

void main() {
  group('QualityChecker', () {
    late QualityChecker checker;

    setUp(() {
      checker = const QualityChecker();
    });

    test('blur detection - sharp image passes', () async {
      // Create a sharp test image with clear edges
      final image = img.Image(width: 100, height: 100);
      
      // Draw a checkerboard pattern (high frequency = sharp)
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 100; x++) {
          final isBlack = ((x ~/ 10) + (y ~/ 10)) % 2 == 0;
          image.setPixelRgba(x, y, isBlack ? 0 : 255, isBlack ? 0 : 255, isBlack ? 0 : 255, 255);
        }
      }

      final bytes = Uint8List.fromList(img.encodeJpg(image));
      final results = await checker.checkQuality(bytes);
      
      final blurResult = results.firstWhere(
        (r) => r.metrics.containsKey('laplacian_variance'),
      );
      
      expect(blurResult.passed, isTrue);
      expect(blurResult.metrics['laplacian_variance'], greaterThan(100.0));
    });

    test('blur detection - blurry image fails', () async {
      // Create a blurry image (solid color = no edges)
      final image = img.Image(width: 100, height: 100);
      image.clear(img.ColorRgb8(128, 128, 128));

      final bytes = Uint8List.fromList(img.encodeJpg(image));
      final results = await checker.checkQuality(bytes);
      
      final blurResult = results.firstWhere(
        (r) => r.metrics.containsKey('laplacian_variance'),
      );
      
      expect(blurResult.passed, isFalse);
      expect(blurResult.failureReason, contains('blurry'));
    });

    test('exposure detection - underexposed fails', () async {
      // Create dark image
      final image = img.Image(width: 100, height: 100);
      image.clear(img.ColorRgb8(20, 20, 20));

      final bytes = Uint8List.fromList(img.encodeJpg(image));
      final results = await checker.checkQuality(bytes);
      
      final exposureResult = results.firstWhere(
        (r) => r.metrics.containsKey('mean_brightness'),
      );
      
      expect(exposureResult.passed, isFalse);
      expect(exposureResult.failureReason, contains('underexposed'));
    });

    test('exposure detection - overexposed fails', () async {
      // Create bright image
      final image = img.Image(width: 100, height: 100);
      image.clear(img.ColorRgb8(250, 250, 250));

      final bytes = Uint8List.fromList(img.encodeJpg(image));
      final results = await checker.checkQuality(bytes);
      
      final exposureResult = results.firstWhere(
        (r) => r.metrics.containsKey('mean_brightness'),
      );
      
      expect(exposureResult.passed, isFalse);
      expect(exposureResult.failureReason, contains('overexposed'));
    });

    test('exposure detection - well exposed passes', () async {
      // Create properly exposed image
      final image = img.Image(width: 100, height: 100);
      image.clear(img.ColorRgb8(128, 128, 128));

      final bytes = Uint8List.fromList(img.encodeJpg(image));
      final results = await checker.checkQuality(bytes);
      
      final exposureResult = results.firstWhere(
        (r) => r.metrics.containsKey('mean_brightness'),
      );
      
      expect(exposureResult.passed, isTrue);
      expect(exposureResult.metrics['mean_brightness'], greaterThan(40.0));
      expect(exposureResult.metrics['mean_brightness'], lessThan(220.0));
    });

    test('glare detection - high glare fails', () async {
      // Create image with lots of bright pixels
      final image = img.Image(width: 100, height: 100);
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 100; x++) {
          // 30% of pixels are very bright
          final isBright = (x + y) % 3 == 0;
          final value = isBright ? 250 : 128;
          image.setPixelRgba(x, y, value, value, value, 255);
        }
      }

      final bytes = Uint8List.fromList(img.encodeJpg(image));
      final results = await checker.checkQuality(bytes);
      
      final glareResult = results.firstWhere(
        (r) => r.metrics.containsKey('glare_ratio'),
      );
      
      expect(glareResult.passed, isFalse);
      expect(glareResult.failureReason, contains('Glare'));
    });
  });
}
