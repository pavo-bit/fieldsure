import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing app lock and biometric authentication
class AppLockService {
  final LocalAuthentication _localAuth;
  final FlutterSecureStorage _secureStorage;
  
  static const String _keyAppLockEnabled = 'app_lock_enabled';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyAutoLockTimeout = 'auto_lock_timeout_seconds';
  static const String _keyLastActiveTime = 'last_active_time';
  
  DateTime? _lastActiveTime;
  bool _isAuthenticated = false;

  AppLockService({
    LocalAuthentication? localAuth,
    FlutterSecureStorage? secureStorage,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Check if device supports biometric authentication
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    }
  }

  /// Check if app lock is enabled
  Future<bool> isAppLockEnabled() async {
    final value = await _secureStorage.read(key: _keyAppLockEnabled);
    return value == 'true';
  }

  /// Enable or disable app lock
  Future<void> setAppLockEnabled(bool enabled) async {
    await _secureStorage.write(
      key: _keyAppLockEnabled,
      value: enabled.toString(),
    );
    if (!enabled) {
      _isAuthenticated = false;
    }
  }

  /// Check if biometric authentication is enabled
  Future<bool> isBiometricEnabled() async {
    final value = await _secureStorage.read(key: _keyBiometricEnabled);
    return value == 'true';
  }

  /// Enable or disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      // Verify biometrics are available before enabling
      final canCheck = await canCheckBiometrics();
      if (!canCheck) {
        throw Exception('Biometric authentication not available');
      }
    }
    
    await _secureStorage.write(
      key: _keyBiometricEnabled,
      value: enabled.toString(),
    );
  }

  /// Get auto-lock timeout in seconds (default: 60 seconds)
  Future<int> getAutoLockTimeout() async {
    final value = await _secureStorage.read(key: _keyAutoLockTimeout);
    return value != null ? int.tryParse(value) ?? 60 : 60;
  }

  /// Set auto-lock timeout in seconds
  Future<void> setAutoLockTimeout(int seconds) async {
    if (seconds < 0) {
      throw ArgumentError('Timeout must be non-negative');
    }
    await _secureStorage.write(
      key: _keyAutoLockTimeout,
      value: seconds.toString(),
    );
  }

  /// Authenticate user with biometric or device credentials
  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = false,
  }) async {
    try {
      final biometricEnabled = await isBiometricEnabled();
      
      if (!biometricEnabled && biometricOnly) {
        return false;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate) {
        _isAuthenticated = true;
        _lastActiveTime = DateTime.now();
        await _saveLastActiveTime();
      }

      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication error: ${e.message}');
      return false;
    }
  }

  /// Check if user needs to authenticate (based on app lock settings and timeout)
  Future<bool> shouldAuthenticate() async {
    // If app lock is disabled, no auth needed
    final lockEnabled = await isAppLockEnabled();
    if (!lockEnabled) {
      return false;
    }

    // If already authenticated and within timeout, no auth needed
    if (_isAuthenticated) {
      final timeout = await getAutoLockTimeout();
      final lastActive = await _getLastActiveTime();
      
      if (lastActive != null) {
        final elapsed = DateTime.now().difference(lastActive).inSeconds;
        if (elapsed < timeout) {
          return false;
        }
      }
    }

    return true;
  }

  /// Mark user activity (resets auto-lock timer)
  Future<void> recordActivity() async {
    if (_isAuthenticated) {
      _lastActiveTime = DateTime.now();
      await _saveLastActiveTime();
    }
  }

  /// Lock the app (requires re-authentication)
  Future<void> lock() async {
    _isAuthenticated = false;
    _lastActiveTime = null;
    await _secureStorage.delete(key: _keyLastActiveTime);
  }

  /// Check if user is currently authenticated
  bool get isAuthenticated => _isAuthenticated;

  Future<void> _saveLastActiveTime() async {
    if (_lastActiveTime != null) {
      await _secureStorage.write(
        key: _keyLastActiveTime,
        value: _lastActiveTime!.millisecondsSinceEpoch.toString(),
      );
    }
  }

  Future<DateTime?> _getLastActiveTime() async {
    final value = await _secureStorage.read(key: _keyLastActiveTime);
    if (value != null) {
      final ms = int.tryParse(value);
      if (ms != null) {
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }
    return null;
  }
}

/// Provider for AppLockService
final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService();
});

/// Provider for checking if authentication is required
final shouldAuthenticateProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(appLockServiceProvider);
  return await service.shouldAuthenticate();
});

/// Provider for checking if biometrics are available
final biometricsAvailableProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(appLockServiceProvider);
  return await service.canCheckBiometrics();
});
