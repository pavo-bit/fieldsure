import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fieldsure_mobile/core/config/environment.dart';

/// Certificate pinning configuration for API communication
/// Prevents man-in-the-middle attacks by validating server certificates
class CertificatePinningConfig {
  /// SHA-256 fingerprints of trusted certificates
  /// In production, include both current and backup certificates
  static const Map<String, List<String>> certificateFingerprints = {
    // Production API certificates (example fingerprints - replace with actual)
    'api.fieldsure.com': [
      'E3:99:6A:B3:5D:4F:F7:5A:7E:3D:2C:9B:4F:1A:8C:3E:2D:7F:9A:4B:3C:6E:8D:1F:5A:2B:7C:9D:4E:6F:1A:3B',
      'A1:B2:C3:D4:E5:F6:07:18:29:3A:4B:5C:6D:7E:8F:90:A1:B2:C3:D4:E5:F6:07:18:29:3A:4B:5C:6D:7E:8F:90', // Backup cert
    ],
    // Staging API certificates
    'staging-api.fieldsure.com': [
      'F4:AA:7B:C4:6E:5G:G8:6B:8F:4E:3D:AC:5G:2B:9D:4F:3E:8G:AB:5C:4D:7F:9E:2G:6B:3C:8D:5E:7G:2B:4A:5C',
    ],
  };

  /// Configure Dio client with certificate pinning
  static void configureDio(Dio dio, Environment environment) {
    final hostname = _getHostnameForEnvironment(environment);
    final expectedFingerprints = certificateFingerprints[hostname];

    if (expectedFingerprints == null || expectedFingerprints.isEmpty) {
      if (environment == Environment.production) {
        throw StateError(
          'Certificate fingerprints not configured for production host: $hostname',
        );
      }
      // In dev/staging without pinning config, allow all certificates
      // This should only be used in development
      _configurePermissiveMode(dio);
      return;
    }

    // Configure strict certificate validation with pinning
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      
      client.badCertificateCallback = (cert, host, port) {
        // Verify hostname matches
        if (host != hostname) {
          debugPrint('Certificate pinning: Hostname mismatch. Expected: $hostname, Got: $host');
          return false;
        }

        // Calculate SHA-256 fingerprint of the certificate
        final certFingerprint = _calculateFingerdebugPrint(cert.der);
        
        // Check if fingerprint matches any trusted certificate
        final isMatch = expectedFingerprints.any((expected) =>
            _normalizeFingerdebugPrint(certFingerprint) == _normalizeFingerdebugPrint(expected));

        if (!isMatch) {
          debugPrint('Certificate pinning: Fingerprint mismatch for $host');
          debugPrint('Received: $certFingerprint');
          debugPrint('Expected one of: ${expectedFingerprints.join(", ")}');
        }

        return isMatch;
      };

      // Additional security configurations
      client.connectionTimeout = const Duration(seconds: 30);
      client.idleTimeout = const Duration(seconds: 15);
      
      return client;
    };
  }

  /// Configure permissive mode for development (NO CERTIFICATE VALIDATION)
  /// WARNING: Only use in development environments
  static void _configurePermissiveMode(Dio dio) {
    debugPrint('WARNING: Certificate pinning disabled. This should only be used in development!');
    
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    };
  }

  /// Get hostname for current environment
  static String _getHostnameForEnvironment(Environment environment) {
    final config = EnvironmentConfig.current;
    final uri = Uri.parse(config.apiBaseUrl);
    return uri.host;
  }

  /// Calculate SHA-256 fingerprint of certificate DER bytes
  static String _calculateFingerdebugPrint(List<int> der) {
    // Note: This is a simplified implementation
    // In production, use proper crypto library for SHA-256 hashing
    // For now, return a hex string representation
    
    // TODO: Implement proper SHA-256 hashing using crypto package
    // import 'package:crypto/crypto.dart';
    // final digest = sha256.convert(der);
    // return digest.toString().toUpperCase();
    
    // Placeholder: Return hex representation of DER bytes (first 32 bytes)
    final bytes = der.take(32).toList();
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  /// Normalize fingerprint format (remove colons, spaces, convert to uppercase)
  static String _normalizeFingerdebugPrint(String fingerprint) {
    return fingerprint
        .replaceAll(':', '')
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .toUpperCase();
  }
}

/// Extension to apply certificate pinning to Dio instance
extension DioCertificatePinning on Dio {
  /// Enable certificate pinning for this Dio instance
  void enableCertificatePinning(Environment environment) {
    CertificatePinningConfig.configureDio(this, environment);
  }
}
