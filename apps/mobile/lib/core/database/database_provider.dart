import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_database.dart';
import '../security/db_encryption_key_manager.dart';
import 'encrypted_database.dart' if (dart.library.html) 'web_database.dart';

/// Provider for secure storage service.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
});

/// Provider for database encryption key manager.
final dbEncryptionKeyManagerProvider = Provider<DbEncryptionKeyManager>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return DbEncryptionKeyManager(storage);
});

/// Provider for encrypted app database.
/// 
/// The database is:
/// - Encrypted at rest with SQLCipher
/// - Key stored in platform-specific secure storage
/// - Automatically initialized on first access
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'appDatabaseProvider must be overridden with an async value. '
    'Use initializeDatabase() in main.dart'
  );
});

/// Initialize the encrypted database.
/// 
/// Call this in main() before runApp():
/// ```dart
/// final database = await initializeDatabase(container);
/// ```
Future<AppDatabase> initializeDatabase(ProviderContainer container) async {
  final keyManager = container.read(dbEncryptionKeyManagerProvider);
  final encryptionKey = await keyManager.getOrGenerateKey();
  
  final executor = await createEncryptedDatabase(
    name: 'fieldsure_encrypted.db',
    encryptionKey: encryptionKey,
  );
  
  return AppDatabase(executor);
}
