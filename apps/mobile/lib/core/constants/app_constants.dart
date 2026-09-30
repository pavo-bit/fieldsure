/// Core constants used across the FieldSure application.
class AppConstants {
  AppConstants._();

  /// Application name.
  static const String appName = 'FieldSure';

  /// Application tagline.
  static const String tagline = 'Digital Companion for Field Drug Testing';

  /// Brand concept.
  static const String brandConcept = 'Capture. Verify. Record.';

  /// Required disclaimer displayed on result screens.
  static const String disclaimer =
      'Presumptive field-test result. Laboratory confirmation is required.';

  /// API base URL — configured via environment.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  /// Primary action button height.
  static const double primaryButtonHeight = 56.0;

  /// Secondary action button height.
  static const double secondaryButtonHeight = 48.0;

  /// Minimum touch target size.
  static const double minTouchTarget = 44.0;
}
