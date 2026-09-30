import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'dart:io';

/// Create a database connection.
/// 
/// For the demo build, encryption is disabled (using plain sqlite3_flutter_libs).
/// In a production build, switch back to sqlcipher_flutter_libs and enable
/// the PRAGMA key statements below.
Future<QueryExecutor> createEncryptedDatabase({
  required String name,
  required String encryptionKey,
}) async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, name));

  return NativeDatabase.createInBackground(
    file,
    setup: (database) {
      // NOTE: SQLCipher encryption is disabled for this demo build.
      // To re-enable, replace sqlite3_flutter_libs with sqlcipher_flutter_libs
      // in pubspec.yaml and uncomment the following:
      //
      // database.execute("PRAGMA key = '$encryptionKey';");
      // database.execute('PRAGMA cipher_page_size = 4096;');
      // database.execute('PRAGMA kdf_iter = 64000;');
      // database.execute('PRAGMA cipher_hmac_algorithm = HMAC_SHA512;');
      // database.execute('PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA512;');
      
      // Performance optimizations
      database.execute('PRAGMA journal_mode = WAL;');
      database.execute('PRAGMA synchronous = NORMAL;');
      database.execute('PRAGMA temp_store = MEMORY;');
      database.execute('PRAGMA mmap_size = 30000000000;');
    },
  );
}