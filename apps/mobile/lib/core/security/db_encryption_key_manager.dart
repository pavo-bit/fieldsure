import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

/// Manages encryption key for SQLCipher database.
/// 
/// Key is stored in platform-specific secure storage:
/// - Android: EncryptedSharedPreferences / Android Keystore
/// - iOS: Keychain
class DbEncryptionKeyManager {
  static const String _keyStorageKey = 'fieldsure_db_encryption_key';
  final FlutterSecureStorage _secureStorage;

  DbEncryptionKeyManager(this._secureStorage);

  /// Get or generate database encryption key.
  /// 
  /// The key is:
  /// 1. Generated once on first app launch
  /// 2. Stored in secure storage
  /// 3. Never changes (database would become unreadable)
  /// 4. Never logged or exposed
  Future<String> getOrGenerateKey() async {
    // Try to retrieve existing key
    String? existingKey = await _secureStorage.read(key: _keyStorageKey);
    
    if (existingKey != null && existingKey.isNotEmpty) {
      return existingKey;
    }

    // Generate new 256-bit key
    final key = _generateSecureKey();
    
    // Store it securely
    await _secureStorage.write(key: _keyStorageKey, value: key);
    
    return key;
  }

  /// Generate a cryptographically secure 256-bit key.
  String _generateSecureKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Clear the encryption key (use with extreme caution - will make DB unreadable).
  /// 
  /// Only call this during:
  /// - Logout (if required by policy)
  /// - Account deletion
  /// - Factory reset
  Future<void> clearKey() async {
    await _secureStorage.delete(key: _keyStorageKey);
  }

  /// Derive key for additional purposes (e.g., file encryption).
  String deriveKey(String purpose, String masterKey) {
    final bytes = utf8.encode('$purpose:$masterKey');
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes);
  }
}
