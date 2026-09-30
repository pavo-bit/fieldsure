import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/web.dart';

Future<QueryExecutor> createEncryptedDatabase({
  required String name,
  required String encryptionKey,
}) async {
  debugPrint('[Database] Warning: Web platform does not support SQLCipher. Using unencrypted WebDatabase.');
  return WebDatabase(name);
}
