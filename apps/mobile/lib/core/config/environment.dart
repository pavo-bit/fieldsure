/// Environment configuration for different build flavors.
/// 
/// Usage:
/// - Dev: flutter run --dart-define=ENVIRONMENT=dev
/// - Staging: flutter run --dart-define=ENVIRONMENT=staging  
/// - Prod: flutter run --dart-define=ENVIRONMENT=prod
enum Environment {
  dev,
  staging,
  production;

  static Environment get current {
    const envString = String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');
    return Environment.values.firstWhere(
      (e) => e.name == envString,
      orElse: () => Environment.dev,
    );
  }

  bool get isDev => this == Environment.dev;
  bool get isStaging => this == Environment.staging;
  bool get isProduction => this == Environment.production;
}

/// Environment-specific configuration.
class EnvironmentConfig {
  final String apiBaseUrl;
  final bool requiresHttps;
  final List<String> certificatePins;
  final bool enableDebugLogging;
  final Duration syncInterval;

  const EnvironmentConfig({
    required this.apiBaseUrl,
    required this.requiresHttps,
    required this.certificatePins,
    required this.enableDebugLogging,
    required this.syncInterval,
  });

  static EnvironmentConfig get current {
    final env = Environment.current;
    
    switch (env) {
      case Environment.dev:
        return EnvironmentConfig(
          // Android emulator host handling
          apiBaseUrl: _getDevApiUrl(),
          requiresHttps: false,
          certificatePins: [],
          enableDebugLogging: true,
          syncInterval: const Duration(minutes: 5),
        );
      
      case Environment.staging:
        return const EnvironmentConfig(
          apiBaseUrl: 'https://staging-api.fieldsure.example.com/api/v1',
          requiresHttps: true,
          certificatePins: [
            // TODO: Add actual certificate pins for staging
            'sha256/STAGING_PIN_PLACEHOLDER',
          ],
          enableDebugLogging: true,
          syncInterval: Duration(minutes: 10),
        );
      
      case Environment.production:
        return const EnvironmentConfig(
          apiBaseUrl: 'https://api.fieldsure.example.com/api/v1',
          requiresHttps: true,
          certificatePins: [
            // TODO: Add actual certificate pins for production
            'sha256/PROD_PIN_PLACEHOLDER',
          ],
          enableDebugLogging: false,
          syncInterval: Duration(minutes: 15),
        );
    }
  }

  /// Get dev API URL with Android emulator host handling.
  static String _getDevApiUrl() {
    // Check if running on Android emulator
    const isAndroidEmulator = bool.fromEnvironment('IS_ANDROID_EMULATOR', defaultValue: false);
    
    if (isAndroidEmulator) {
      return 'http://10.0.2.2:3000/api/v1';
    }
    
    return 'http://localhost:3000/api/v1';
  }

  /// Validate configuration on startup.
  void validate() {
    if (requiresHttps && !apiBaseUrl.startsWith('https://')) {
      throw StateError(
        'SECURITY VIOLATION: Production environment requires HTTPS. '
        'Current API URL: $apiBaseUrl'
      );
    }

    if (Environment.current.isProduction && certificatePins.isEmpty) {
      throw StateError(
        'SECURITY VIOLATION: Production environment requires certificate pinning.'
      );
    }
  }
}
