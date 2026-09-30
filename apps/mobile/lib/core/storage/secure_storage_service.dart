import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../models/auth_tokens.dart';

/// Provider for the secure storage service.
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
  return SecureStorageService(storage);
});

/// Service responsible for securely persisting tokens and session credentials.
/// Never stores secrets in unencrypted SharedPreferences.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  static const String _keyAccessToken = 'fieldsure_access_token';
  static const String _keyRefreshToken = 'fieldsure_refresh_token';
  static const String _keyUser = 'fieldsure_user_profile';

  SecureStorageService(this._storage);

  /// Save authentication tokens securely.
  Future<void> saveTokens(AuthTokens tokens) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: tokens.accessToken),
      _storage.write(key: _keyRefreshToken, value: tokens.refreshToken),
    ]);
  }

  /// Retrieve stored authentication tokens if available.
  Future<AuthTokens?> getTokens() async {
    try {
      final access = await _storage.read(key: _keyAccessToken);
      final refresh = await _storage.read(key: _keyRefreshToken);

      if (access != null && refresh != null && access.isNotEmpty && refresh.isNotEmpty) {
        return AuthTokens(accessToken: access, refreshToken: refresh);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Retrieve the current access token.
  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _keyAccessToken);
    } catch (_) {
      return null;
    }
  }

  /// Retrieve the current refresh token.
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (_) {
      return null;
    }
  }

  /// Save the active user profile locally for fast startup.
  Future<void> saveUser(UserModel user) async {
    final jsonStr = jsonEncode(user.toJson());
    await _storage.write(key: _keyUser, value: jsonStr);
  }

  /// Retrieve cached user profile.
  Future<UserModel?> getUser() async {
    try {
      final jsonStr = await _storage.read(key: _keyUser);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Clear all credentials and tokens on logout.
  Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: _keyAccessToken),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyUser),
    ]);
  }
}
